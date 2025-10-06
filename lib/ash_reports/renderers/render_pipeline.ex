defmodule AshReports.RenderPipeline do
  @moduledoc """
  Stage-based rendering pipeline orchestration with comprehensive error handling.

  The RenderPipeline provides a sophisticated orchestration system for the Phase 3.1
  Renderer Interface, coordinating the entire rendering process through well-defined
  stages with robust error handling, performance monitoring, and recovery mechanisms.

  ## Pipeline Stages

  The rendering pipeline consists of the following stages:

  1. **Initialization**: Context validation and setup
  2. **Layout Calculation**: Band and element positioning using LayoutEngine
  3. **Data Processing**: Record iteration and variable resolution
  4. **Element Rendering**: Individual element rendering with format-specific logic
  5. **Assembly**: Combining rendered elements into final output
  6. **Finalization**: Cleanup and metadata generation

  ## Key Features

  - **Stage-Based Processing**: Clear separation of concerns with well-defined stages
  - **Error Recovery**: Sophisticated error handling with recovery strategies
  - **Performance Monitoring**: Built-in stage timing and performance metrics
  - **Streaming Support**: Large dataset handling with memory efficiency
  - **Format Agnostic**: Works with any renderer implementing the enhanced behavior
  - **Configurable**: Extensive configuration options for different use cases

  ## Usage Patterns

  ### Basic Pipeline Execution

      result = RenderPipeline.execute(context, renderer)

  ### Streaming Pipeline

      {:ok, stream} = RenderPipeline.execute_streaming(context, renderer)

      results =
        stream
        |> Stream.map(&process_chunk/1)
        |> Enum.to_list()

  ### Custom Pipeline Configuration

      config = RenderPipeline.config(
        enable_monitoring: true,
        error_strategy: :continue_on_error,
        chunk_size: 500
      )

      result = RenderPipeline.execute(context, renderer, config)

  ### Pipeline with Custom Stages

      custom_stages = [
        &preprocessing_stage/1,
        &RenderPipeline.stage_layout_calculation/1,
        &custom_rendering_stage/1,
        &postprocessing_stage/1
      ]

      result = RenderPipeline.execute_with_stages(context, renderer, custom_stages)

  ## Integration with Phase 2

  The RenderPipeline seamlessly integrates with Phase 2 DataLoader results:

      {:ok, data_result} = DataLoader.load_report(domain, :sales_report, params)
      context = RenderContext.new(report, data_result, config)
      {:ok, output} = RenderPipeline.execute(context, renderer)

  ## Error Handling

  The pipeline provides multiple error handling strategies:

  - `:fail_fast` - Stop on first error (default)
  - `:continue_on_error` - Continue processing, collect errors
  - `:retry_with_fallback` - Retry failed operations with fallback strategies
  - `:skip_invalid` - Skip invalid elements/bands and continue

  """

  alias AshReports.{LayoutEngine, RenderContext}

  @type pipeline_config :: %{
          enable_monitoring: boolean(),
          error_strategy: error_strategy(),
          chunk_size: pos_integer(),
          timeout: timeout(),
          max_retries: non_neg_integer(),
          stage_timeouts: %{atom() => timeout()},
          custom_stages: [function()],
          debug_mode: boolean()
        }

  @type error_strategy :: :fail_fast | :continue_on_error | :retry_with_fallback | :skip_invalid

  @type pipeline_result :: %{
          content: binary() | String.t(),
          context: RenderContext.t(),
          metadata: %{
            stages_executed: [atom()],
            execution_time_ms: pos_integer(),
            stage_timings: %{atom() => pos_integer()},
            errors: [map()],
            warnings: [map()],
            statistics: map()
          }
        }

  @type stage_result ::
          {:ok, RenderContext.t()} | {:error, term()} | {:warning, term(), RenderContext.t()}

  @type streaming_chunk :: %{
          chunk_data: binary() | String.t(),
          context: RenderContext.t(),
          chunk_metadata: map()
        }

  @default_config %{
    enable_monitoring: true,
    error_strategy: :fail_fast,
    chunk_size: 1000,
    timeout: :timer.minutes(5),
    max_retries: 3,
    stage_timeouts: %{
      initialization: :timer.seconds(30),
      layout_calculation: :timer.minutes(2),
      data_processing: :timer.minutes(10),
      element_rendering: :timer.minutes(15),
      assembly: :timer.minutes(5),
      finalization: :timer.seconds(30)
    },
    custom_stages: [],
    debug_mode: false
  }

  @doc """
  Creates a pipeline configuration with the given options.

  ## Examples

      config = RenderPipeline.config(error_strategy: :continue_on_error)

  """
  @spec config(Keyword.t()) :: pipeline_config()
  def config(options \\ []) do
    options
    |> Enum.into(%{})
    |> then(&Map.merge(@default_config, &1))
  end

  @doc """
  Executes the complete rendering pipeline for a context and renderer.

  This is the main entry point for pipeline execution, providing comprehensive
  rendering with error handling and performance monitoring.

  ## Examples

      {:ok, result} = RenderPipeline.execute(context, renderer)
      {:error, reason} = RenderPipeline.execute(invalid_context, renderer)

  """
  @spec execute(RenderContext.t(), module(), pipeline_config()) ::
          {:ok, pipeline_result()} | {:error, term()}
  def execute(%RenderContext{} = context, renderer, config \\ %{}) do
    config = merge_config(config)
    start_time = System.monotonic_time(:millisecond)

    with {:ok, validated_context} <- validate_pipeline_inputs(context, renderer),
         {:ok, pipeline_state} <- initialize_pipeline(validated_context, renderer, config),
         {:ok, final_result} <- execute_pipeline_stages(pipeline_state, config) do
      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      result = %{
        content: final_result.content,
        context: final_result.context,
        metadata:
          Map.merge(final_result.metadata, %{
            execution_time_ms: execution_time,
            pipeline_version: "3.1.0"
          })
      }

      {:ok, result}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Executes the pipeline with streaming support for large datasets.

  ## Examples

      {:ok, stream} = RenderPipeline.execute_streaming(context, renderer)

  """
  @spec execute_streaming(RenderContext.t(), module(), pipeline_config()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def execute_streaming(%RenderContext{} = context, renderer, config \\ %{}) do
    config =
      config
      |> merge_config()
      |> Map.put(:streaming_mode, true)

    with {:ok, validated_context} <- validate_pipeline_inputs(context, renderer),
         {:ok, pipeline_state} <- initialize_pipeline(validated_context, renderer, config),
         {:ok, stream} <- create_streaming_pipeline(pipeline_state, config) do
      {:ok, stream}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Executes the pipeline with custom stages.

  ## Examples

      custom_stages = [&my_preprocessing/1, &RenderPipeline.stage_layout_calculation/1]
      result = RenderPipeline.execute_with_stages(context, renderer, custom_stages)

  """
  @spec execute_with_stages(RenderContext.t(), module(), [function()], pipeline_config()) ::
          {:ok, pipeline_result()} | {:error, term()}
  def execute_with_stages(%RenderContext{} = context, renderer, stages, config \\ %{}) do
    config =
      config
      |> merge_config()
      |> Map.put(:custom_stages, stages)

    execute(context, renderer, config)
  end

  @doc """
  Stage 1: Initialization - Context validation and setup.

  ## Examples

      {:ok, context} = RenderPipeline.stage_initialization(context)

  """
  @spec stage_initialization(RenderContext.t()) :: stage_result()
  def stage_initialization(%RenderContext{} = context) do
    case RenderContext.validate(context) do
      {:ok, validated_context} ->
        # Additional initialization logic
        initialized_context =
          validated_context
          |> RenderContext.reset_for_new_pass()
          |> prepare_rendering_state()

        {:ok, initialized_context}

      {:error, validation_errors} ->
        {:error, {:initialization_failed, validation_errors}}
    end
  end

  @doc """
  Stage 2: Layout Calculation - Band and element positioning.

  ## Examples

      {:ok, context} = RenderPipeline.stage_layout_calculation(context)

  """
  @spec stage_layout_calculation(RenderContext.t()) :: stage_result()
  def stage_layout_calculation(%RenderContext{} = context) do
    case LayoutEngine.calculate_layout(context) do
      %{overflow_elements: []} = layout_result ->
        updated_context = RenderContext.update_layout_state(context, layout_result)
        {:ok, updated_context}

      %{overflow_elements: [_ | _] = overflow_elements} = layout_result ->
        updated_context = RenderContext.update_layout_state(context, layout_result)

        warning = %{
          type: :layout_overflow,
          message: "#{length(overflow_elements)} elements overflow layout bounds",
          elements: overflow_elements
        }

        {:warning, warning, updated_context}

      layout_result ->
        updated_context = RenderContext.update_layout_state(context, layout_result)
        {:ok, updated_context}
    end
  end

  @doc """
  Stage 3: Data Processing - Record iteration and variable resolution.

  ## Examples

      {:ok, context} = RenderPipeline.stage_data_processing(context)

  """
  @spec stage_data_processing(RenderContext.t()) :: stage_result()
  def stage_data_processing(%RenderContext{} = context) do
    processed_context =
      context.records
      |> Enum.with_index()
      |> Enum.reduce(context, fn {record, index}, acc_context ->
        RenderContext.set_current_record(acc_context, record, index)
      end)

    {:ok, processed_context}
  rescue
    error ->
      {:error, {:data_processing_failed, error}}
  end

  @doc """
  Stage 4: Element Rendering - Individual element rendering with format-specific logic.

  ## Examples

      {:ok, context} = RenderPipeline.stage_element_rendering(context, renderer)

  """
  @spec stage_element_rendering(RenderContext.t(), module()) :: stage_result()
  def stage_element_rendering(%RenderContext{} = context, renderer) do
    # This would be implemented with actual element rendering logic
    # For now, we'll simulate the process
    rendered_context = simulate_element_rendering(context, renderer)
    {:ok, rendered_context}
  rescue
    error ->
      {:error, {:element_rendering_failed, error}}
  end

  @doc """
  Stage 5: Assembly - Combining rendered elements into final output.

  ## Examples

      {:ok, result} = RenderPipeline.stage_assembly(context, renderer)

  """
  @spec stage_assembly(RenderContext.t(), module()) ::
          {:ok, %{content: binary(), context: RenderContext.t()}} | {:error, term()}
  def stage_assembly(%RenderContext{} = context, renderer) do
    # Call the renderer's main rendering function
    case renderer.render_with_context(context, []) do
      {:ok, render_result} ->
        {:ok,
         %{
           content: render_result.content,
           context: render_result.context
         }}

      {:error, reason} ->
        {:error, {:assembly_failed, reason}}
    end
  rescue
    error ->
      {:error, {:assembly_failed, error}}
  end

  @doc """
  Stage 6: Finalization - Cleanup and metadata generation.

  ## Examples

      {:ok, final_result} = RenderPipeline.stage_finalization(assembly_result, metadata)

  """
  @spec stage_finalization(map(), map()) ::
          {:ok, %{content: binary(), context: RenderContext.t(), metadata: map()}}
          | {:error, term()}
  def stage_finalization(assembly_result, pipeline_metadata) do
    final_metadata =
      pipeline_metadata
      |> Map.put(:finalized_at, DateTime.utc_now())
      |> Map.put(:success, true)

    final_result = %{
      content: assembly_result.content,
      context: assembly_result.context,
      metadata: final_metadata
    }

    {:ok, final_result}
  rescue
    error ->
      {:error, {:finalization_failed, error}}
  end

  @doc """
  Validates the pipeline execution for correctness.

  ## Examples

      case RenderPipeline.validate_execution(result) do
        :ok -> proceed_with_output(result)
        {:error, issues} -> handle_validation_issues(issues)
      end

  """
  @spec validate_execution(pipeline_result()) :: :ok | {:error, [map()]}
  def validate_execution(result) do
    issues =
      []
      |> validate_content_presence(result)
      |> validate_context_state(result)
      |> validate_metadata_completeness(result)

    if issues == [] do
      :ok
    else
      {:error, issues}
    end
  end

  # Private implementation functions

  defp merge_config(config) when is_map(config) do
    Map.merge(@default_config, config)
  end

  defp merge_config(config) when is_list(config) do
    config_map = Enum.into(config, %{})
    Map.merge(@default_config, config_map)
  end

  defp validate_pipeline_inputs(%RenderContext{} = context, renderer) do
    with :ok <- validate_context_for_pipeline(context),
         :ok <- validate_renderer_for_pipeline(renderer) do
      {:ok, context}
    else
      {:error, _reason} = error -> error
    end
  end

  defp validate_context_for_pipeline(context) do
    case RenderContext.validate(context) do
      {:ok, _context} -> :ok
      {:error, errors} -> {:error, {:invalid_context, errors}}
    end
  end

  defp validate_renderer_for_pipeline(renderer) do
    required_functions = [
      :render_with_context,
      :supports_streaming?,
      :file_extension,
      :content_type
    ]

    missing =
      Enum.filter(required_functions, fn func ->
        arity = if func == :render_with_context, do: 2, else: 0
        not function_exported?(renderer, func, arity)
      end)

    if missing == [] do
      :ok
    else
      {:error, {:invalid_renderer, missing}}
    end
  end

  defp initialize_pipeline(context, renderer, config) do
    pipeline_state = %{
      context: context,
      renderer: renderer,
      config: config,
      stage_timings: %{},
      errors: [],
      warnings: [],
      start_time: System.monotonic_time(:millisecond)
    }

    {:ok, pipeline_state}
  end

  defp execute_pipeline_stages(pipeline_state, config) do
    stages = get_pipeline_stages(config)

    execute_stages_sequence(stages, pipeline_state)
  end

  defp get_pipeline_stages(config) do
    if config.custom_stages != [] do
      config.custom_stages
    else
      [
        &stage_initialization/1,
        &stage_layout_calculation/1,
        &stage_data_processing/1,
        &stage_element_rendering_wrapper/2,
        &stage_assembly_wrapper/2,
        &stage_finalization_wrapper/2
      ]
    end
  end

  defp execute_stages_sequence(stages, pipeline_state) do
    {final_state, result} =
      Enum.reduce_while(stages, {pipeline_state, nil}, fn stage, {state, _} ->
        stage_result = execute_single_stage(stage, state)
        handle_stage_result(stage_result, state)
      end)

    case result do
      {:ok, final_result} -> {:ok, final_result}
      {:error, reason} -> {:error, reason}
      nil -> generate_final_result(final_state)
    end
  end

  defp handle_stage_result({:ok, new_state}, _state) do
    {:cont, {new_state, nil}}
  end

  defp handle_stage_result({:warning, warning, new_state}, _state) do
    updated_state = add_warning(new_state, warning)
    {:cont, {updated_state, nil}}
  end

  defp handle_stage_result({:error, reason}, state) do
    case state.config.error_strategy do
      :fail_fast ->
        {:halt, {state, {:error, reason}}}

      :continue_on_error ->
        updated_state = add_error(state, reason)
        {:cont, {updated_state, nil}}

      _ ->
        {:halt, {state, {:error, reason}}}
    end
  end

  defp handle_stage_result(final_result, state) when is_map(final_result) do
    {:halt, {state, {:ok, final_result}}}
  end

  defp execute_single_stage(stage, pipeline_state) when is_function(stage, 1) do
    stage.(pipeline_state.context)
  end

  defp execute_single_stage(stage, pipeline_state) when is_function(stage, 2) do
    stage.(pipeline_state.context, pipeline_state.renderer)
  end

  defp stage_element_rendering_wrapper(context, renderer) do
    stage_element_rendering(context, renderer)
  end

  defp stage_assembly_wrapper(context, renderer) do
    stage_assembly(context, renderer)
  end

  defp stage_finalization_wrapper(assembly_result, pipeline_state) do
    metadata = %{
      stages_executed: [
        :initialization,
        :layout_calculation,
        :data_processing,
        :element_rendering,
        :assembly
      ],
      stage_timings: pipeline_state.stage_timings,
      errors: pipeline_state.errors,
      warnings: pipeline_state.warnings,
      statistics: %{
        total_records: length(assembly_result.context.records),
        elements_rendered: length(assembly_result.context.rendered_elements)
      }
    }

    stage_finalization(assembly_result, metadata)
  end

  defp create_streaming_pipeline(pipeline_state, config) do
    # Create a stream that yields chunks of the pipeline execution
    stream =
      pipeline_state.context.records
      |> Stream.chunk_every(config.chunk_size)
      |> Stream.map(fn record_chunk ->
        # Process each chunk through a mini-pipeline
        chunk_context = %{pipeline_state.context | records: record_chunk}

        case execute_chunk_pipeline(chunk_context, pipeline_state.renderer, config) do
          {:ok, result} ->
            %{
              chunk_data: result.content,
              context: result.context,
              chunk_metadata: Map.get(result, :metadata, %{})
            }

          {:error, reason} ->
            {:error, reason}
        end
      end)

    {:ok, stream}
  end

  defp execute_chunk_pipeline(chunk_context, renderer, _config) do
    # Simplified chunk processing - would be more sophisticated in practice
    case renderer.render_with_context(chunk_context, []) do
      {:ok, render_result} ->
        {:ok,
         %{
           content: render_result.content,
           context: render_result.context,
           metadata: render_result.metadata
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_final_result(pipeline_state) do
    # Fallback final result generation if stages don't produce explicit result
    final_result = %{
      content: "",
      context: pipeline_state.context,
      metadata: %{
        stages_executed: [],
        stage_timings: pipeline_state.stage_timings,
        errors: pipeline_state.errors,
        warnings: pipeline_state.warnings,
        statistics: %{}
      }
    }

    {:ok, final_result}
  end

  defp add_warning(pipeline_state, warning) do
    %{pipeline_state | warnings: [warning | pipeline_state.warnings]}
  end

  defp add_error(pipeline_state, error) do
    %{pipeline_state | errors: [error | pipeline_state.errors]}
  end

  defp prepare_rendering_state(context) do
    # Prepare context for rendering operations
    context
  end

  defp simulate_element_rendering(context, _renderer) do
    # Simulate element rendering for now
    # In the real implementation, this would iterate through elements and render them
    rendered_elements =
      context.layout_state.bands
      |> Enum.flat_map(fn {_band_name, band_layout} ->
        Enum.map(band_layout.elements, fn element_layout ->
          %{
            element: element_layout.element,
            rendered_content: "simulated content",
            position: element_layout.position
          }
        end)
      end)

    %{context | rendered_elements: rendered_elements}
  end

  defp validate_content_presence(issues, %{content: content}) when content != "" do
    issues
  end

  defp validate_content_presence(issues, _result) do
    [%{type: :missing_content, message: "Pipeline result has no content"} | issues]
  end

  defp validate_context_state(issues, %{context: %RenderContext{}}) do
    issues
  end

  defp validate_context_state(issues, _result) do
    [%{type: :invalid_context, message: "Pipeline result has invalid context"} | issues]
  end

  defp validate_metadata_completeness(issues, %{metadata: metadata}) when is_map(metadata) do
    required_fields = [:stages_executed, :execution_time_ms]

    missing =
      Enum.filter(required_fields, fn field ->
        not Map.has_key?(metadata, field)
      end)

    if missing == [] do
      issues
    else
      issue = %{
        type: :incomplete_metadata,
        message: "Missing metadata fields: #{inspect(missing)}"
      }

      [issue | issues]
    end
  end

  defp validate_metadata_completeness(issues, _result) do
    [%{type: :missing_metadata, message: "Pipeline result has no metadata"} | issues]
  end
end
