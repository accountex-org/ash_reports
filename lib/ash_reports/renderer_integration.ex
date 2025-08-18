defmodule AshReports.RendererIntegration do
  @moduledoc """
  Integration layer connecting Phase 3.1 Renderer Interface with Phase 2 DataLoader.

  This module provides seamless integration between the DataLoader system (Phase 2)
  and the Renderer Interface (Phase 3.1), enabling smooth data flow from query
  execution through variable processing to final rendered output.

  ## Key Features

  - **Seamless Data Flow**: Direct integration from DataLoader results to rendered output
  - **Context Transformation**: Automatic conversion of DataLoader results to RenderContext
  - **Variable Integration**: Full support for Phase 2 variable processing
  - **Group Processing**: Integration with Phase 2 group processing results
  - **Performance Optimization**: Efficient data transformation with minimal overhead
  - **Error Propagation**: Comprehensive error handling across phases

  ## Integration Architecture

  The integration follows this flow:

  1. **DataLoader Execution**: Load data using Phase 2 DataLoader system
  2. **Context Creation**: Transform DataLoader results into RenderContext
  3. **Pipeline Execution**: Use Phase 3.1 RenderPipeline for rendering
  4. **Result Transformation**: Convert pipeline results to final output format

  ## Usage Patterns

  ### Basic Integration

      {:ok, rendered_output} = RendererIntegration.render_report(
        domain,
        :sales_report,
        params,
        renderer: MyReport.Html
      )

  ### With Custom Configuration

      config = %{
        data_config: DataLoader.config(chunk_size: 500),
        render_config: RenderConfig.new(format: :pdf),
        pipeline_config: RenderPipeline.config(error_strategy: :continue_on_error)
      }

      {:ok, output} = RendererIntegration.render_report(
        domain,
        :report_name,
        params,
        config
      )

  ### Streaming Integration

      {:ok, stream} = RendererIntegration.stream_report(
        domain,
        :large_report,
        params,
        renderer: MyReport.Html
      )

  ### Pipeline Integration with Custom Variables

      variables = [
        %Variable{name: :total, type: :sum, expression: expr(amount)},
        %Variable{name: :count, type: :count, expression: expr(1)}
      ]

      {:ok, output} = RendererIntegration.render_with_variables(
        domain,
        :custom_report,
        params,
        variables,
        renderer: MyReport.Pdf
      )

  ## Performance Considerations

  - **Memory Efficiency**: Automatic streaming for large datasets
  - **Cache Integration**: Leverages Phase 2 caching for optimal performance
  - **Parallel Processing**: Utilizes Phase 2 parallel processing capabilities
  - **Resource Management**: Comprehensive resource cleanup and management

  """

  alias AshReports.{
    DataLoader,
    RenderContext,
    Renderer,
    RenderPipeline,
    Variable
  }

  @type render_options :: [
          renderer: module(),
          data_config: Keyword.t(),
          render_config: map(),
          pipeline_config: map(),
          streaming: boolean(),
          variables: [Variable.t()],
          timeout: timeout()
        ]

  @type integration_result :: %{
          content: binary() | String.t(),
          format: atom(),
          metadata: %{
            data_metadata: map(),
            render_metadata: map(),
            integration_metadata: map()
          }
        }

  @type streaming_result :: %{
          stream: Enumerable.t(),
          format: atom(),
          metadata: map()
        }

  @doc """
  Renders a complete report using integrated Phase 2 and Phase 3.1 systems.

  This is the main entry point for integrated rendering, providing a complete
  solution from data loading through final output generation.

  ## Examples

      {:ok, result} = RendererIntegration.render_report(
        MyApp.Domain,
        :sales_report,
        %{region: "West", year: 2024},
        renderer: MyReport.Html
      )

  """
  @spec render_report(module(), atom(), map(), render_options()) ::
          {:ok, integration_result()} | {:error, term()}
  def render_report(domain, report_name, params, options \\ []) do
    start_time = System.monotonic_time(:microsecond)

    with {:ok, config} <- build_integration_config(options),
         {:ok, report} <- get_report_definition(domain, report_name),
         {:ok, data_result} <- load_report_data(domain, report_name, params, config),
         {:ok, render_context} <- create_render_context(report, data_result, config),
         {:ok, pipeline_result} <- execute_render_pipeline(render_context, config),
         {:ok, final_result} <- transform_final_result(pipeline_result, config, start_time) do
      {:ok, final_result}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Renders a report with streaming support for large datasets.

  ## Examples

      {:ok, stream_result} = RendererIntegration.stream_report(
        MyApp.Domain,
        :large_report,
        params,
        renderer: MyReport.Html
      )

  """
  @spec stream_report(module(), atom(), map(), render_options()) ::
          {:ok, streaming_result()} | {:error, term()}
  def stream_report(domain, report_name, params, options \\ []) do
    options = Keyword.put(options, :streaming, true)

    with {:ok, config} <- build_integration_config(options),
         {:ok, report} <- get_report_definition(domain, report_name),
         {:ok, data_stream} <- create_data_stream(domain, report_name, params, config),
         {:ok, render_stream} <- create_render_stream(report, data_stream, config) do
      result = %{
        stream: render_stream,
        format: get_output_format(config),
        metadata: %{
          streaming: true,
          chunk_size: config.data_config[:chunk_size],
          integration_version: "3.1.0"
        }
      }

      {:ok, result}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Renders a report with custom variables, overriding report-defined variables.

  ## Examples

      variables = [
        %Variable{name: :total, type: :sum, expression: expr(amount)}
      ]

      {:ok, result} = RendererIntegration.render_with_variables(
        domain,
        :report_name,
        params,
        variables,
        renderer: MyReport.Pdf
      )

  """
  @spec render_with_variables(module(), atom(), map(), [Variable.t()], render_options()) ::
          {:ok, integration_result()} | {:error, term()}
  def render_with_variables(domain, report_name, params, variables, options \\ []) do
    options = Keyword.put(options, :variables, variables)
    render_report(domain, report_name, params, options)
  end

  @doc """
  Renders a report directly from pre-loaded DataLoader results.

  Useful when you already have DataLoader results and want to skip the data
  loading phase.

  ## Examples

      {:ok, data_result} = DataLoader.load_report(domain, :report_name, params)
      {:ok, output} = RendererIntegration.render_from_data_result(
        report,
        data_result,
        renderer: MyReport.Html
      )

  """
  @spec render_from_data_result(map(), map(), render_options()) ::
          {:ok, integration_result()} | {:error, term()}
  def render_from_data_result(report, data_result, options \\ []) do
    start_time = System.monotonic_time(:microsecond)

    with {:ok, config} <- build_integration_config(options),
         {:ok, render_context} <- create_render_context(report, data_result, config),
         {:ok, pipeline_result} <- execute_render_pipeline(render_context, config),
         {:ok, final_result} <- transform_final_result(pipeline_result, config, start_time) do
      {:ok, final_result}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Validates that the integration can handle the given report and configuration.

  ## Examples

      case RendererIntegration.validate_integration(domain, :report_name, config) do
        :ok -> proceed_with_rendering()
        {:error, issues} -> handle_validation_issues(issues)
      end

  """
  @spec validate_integration(module(), atom(), render_options()) :: :ok | {:error, [map()]}
  def validate_integration(domain, report_name, options \\ []) do
    with {:ok, config} <- build_integration_config(options),
         {:ok, _report} <- get_report_definition(domain, report_name),
         :ok <- validate_renderer_compatibility(config.renderer),
         :ok <- validate_configuration_compatibility(config) do
      :ok
    else
      {:error, reason} ->
        {:error, [%{type: :integration_validation_failed, reason: reason}]}
    end
  end

  @doc """
  Gets integration performance metrics.

  ## Examples

      metrics = RendererIntegration.get_metrics()

  """
  @spec get_metrics() :: map()
  def get_metrics do
    %{
      data_loader: DataLoader.get_metrics(),
      integration: %{
        total_integrations: get_total_integrations(),
        average_integration_time_ms: get_average_integration_time(),
        cache_efficiency: get_cache_efficiency(),
        error_rate: get_error_rate()
      }
    }
  end

  @doc """
  Clears integration caches and resets metrics.

  ## Examples

      RendererIntegration.clear_caches()

  """
  @spec clear_caches() :: :ok
  def clear_caches do
    DataLoader.clear_cache()
    clear_integration_cache()
    :ok
  end

  # Private implementation functions

  defp build_integration_config(options) do
    config = %{
      renderer: Keyword.get(options, :renderer),
      data_config: Keyword.get(options, :data_config, []),
      render_config: Keyword.get(options, :render_config, %{}),
      pipeline_config: Keyword.get(options, :pipeline_config, %{}),
      streaming: Keyword.get(options, :streaming, false),
      variables: Keyword.get(options, :variables, []),
      timeout: Keyword.get(options, :timeout, :timer.minutes(10))
    }

    case validate_integration_config(config) do
      :ok -> {:ok, config}
      {:error, _reason} = error -> error
    end
  end

  defp validate_integration_config(%{renderer: nil}) do
    {:error, :missing_renderer}
  end

  defp validate_integration_config(_config) do
    # Additional validation logic would go here
    :ok
  end

  defp get_report_definition(domain, report_name) do
    # Get report from domain using existing DataLoader logic
    case apply(domain, :__ash_reports_config__, []) do
      %{reports: reports} ->
        case Enum.find(reports, &(&1.name == report_name)) do
          nil -> {:error, {:report_not_found, report_name}}
          report -> {:ok, report}
        end

      _ ->
        {:error, {:no_reports_configured, domain}}
    end
  catch
    _, _ ->
      {:error, {:invalid_domain, domain}}
  end

  defp load_report_data(domain, report_name, params, config) do
    data_config = DataLoader.config(config.data_config)

    if config.variables != [] do
      DataLoader.load_report_with_variables(
        domain,
        report_name,
        params,
        config.variables,
        data_config
      )
    else
      DataLoader.load_report(domain, report_name, params, data_config)
    end
  end

  defp create_render_context(report, data_result, config) do
    render_config = merge_render_config(config.render_config, config)
    context = RenderContext.new(report, data_result, render_config)

    case RenderContext.validate(context) do
      {:ok, validated_context} -> {:ok, validated_context}
      {:error, _reason} = error -> error
    end
  end

  defp merge_render_config(render_config, integration_config) do
    # Merge render configuration with integration-specific settings
    base_config = if is_map(render_config), do: render_config, else: %{}

    Map.merge(base_config, %{
      streaming: integration_config.streaming,
      timeout: integration_config.timeout
    })
  end

  defp execute_render_pipeline(render_context, config) do
    pipeline_config = RenderPipeline.config(config.pipeline_config)

    if config.streaming do
      RenderPipeline.execute_streaming(render_context, config.renderer, pipeline_config)
    else
      RenderPipeline.execute(render_context, config.renderer, pipeline_config)
    end
  end

  defp transform_final_result(pipeline_result, config, start_time) do
    end_time = System.monotonic_time(:microsecond)
    integration_time = end_time - start_time

    final_result = %{
      content: pipeline_result.content,
      format: get_output_format(config),
      metadata: %{
        data_metadata: extract_data_metadata(pipeline_result),
        render_metadata: pipeline_result.metadata,
        integration_metadata: %{
          integration_time_us: integration_time,
          integration_version: "3.1.0",
          data_phase: "2.4.0",
          render_phase: "3.1.0",
          success: true
        }
      }
    }

    {:ok, final_result}
  end

  defp extract_data_metadata(pipeline_result) do
    context = pipeline_result.context

    %{
      record_count: length(context.records),
      variable_count: map_size(context.variables),
      group_count: map_size(context.groups),
      data_processing_metadata: Map.get(context.metadata, :data_processing, %{})
    }
  end

  defp get_output_format(config) do
    if config.renderer do
      # Try to determine format from renderer module name
      case Atom.to_string(config.renderer) do
        module_name ->
          cond do
            String.contains?(module_name, "Html") -> :html
            String.contains?(module_name, "Pdf") -> :pdf
            String.contains?(module_name, "Json") -> :json
            String.contains?(module_name, "Csv") -> :csv
            true -> :unknown
          end
      end
    else
      :unknown
    end
  end

  defp create_data_stream(domain, report_name, params, config) do
    data_config =
      config.data_config
      |> DataLoader.config()
      |> Keyword.put(:streaming, true)

    if config.variables != [] do
      # For now, streaming with variables uses standard load then stream transformation
      case DataLoader.load_report_with_variables(
             domain,
             report_name,
             params,
             config.variables,
             data_config
           ) do
        {:ok, data_result} ->
          stream =
            data_result.records
            |> Stream.chunk_every(data_config[:chunk_size] || 1000)
            |> Stream.map(fn chunk ->
              %{data_result | records: chunk}
            end)

          {:ok, stream}

        {:error, _reason} = error ->
          error
      end
    else
      DataLoader.stream_report(domain, report_name, params, data_config)
    end
  end

  defp create_render_stream(report, data_stream, config) do
    render_stream =
      data_stream
      |> Stream.map(fn data_chunk ->
        case create_render_context(report, data_chunk, config) do
          {:ok, context} ->
            case execute_render_pipeline(context, config) do
              {:ok, pipeline_result} ->
                %{
                  content: pipeline_result.content,
                  metadata: pipeline_result.metadata
                }

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
      end)

    {:ok, render_stream}
  end

  defp validate_renderer_compatibility(renderer) when is_atom(renderer) do
    case Renderer.validate_renderer_module(renderer) do
      :ok -> :ok
      {:error, _missing} -> {:error, :incompatible_renderer}
    end
  end

  defp validate_renderer_compatibility(_), do: {:error, :invalid_renderer}

  defp validate_configuration_compatibility(_config) do
    # Additional configuration validation would go here
    :ok
  end

  # Metrics and cache management (placeholder implementations)

  defp get_total_integrations, do: 0
  defp get_average_integration_time, do: 0.0
  defp get_cache_efficiency, do: 0.0
  defp get_error_rate, do: 0.0
  defp clear_integration_cache, do: :ok
end
