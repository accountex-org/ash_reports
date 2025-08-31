defmodule AshReports.RenderStrategy do
  @moduledoc """
  Strategy pattern implementation for different rendering approaches.

  This module provides a strategy pattern for handling different rendering
  scenarios, improving flexibility and maintainability of the rendering system.

  ## Design Benefits

  - **Strategy Pattern**: Clean separation of different rendering approaches
  - **Extensibility**: Easy to add new rendering strategies
  - **Testability**: Individual strategies can be tested in isolation
  - **Configuration-Driven**: Strategy selection based on requirements

  ## Available Strategies

  - `:streaming` - For large datasets with memory efficiency
  - `:batch` - For medium datasets with balanced performance
  - `:immediate` - For small datasets with fast response times
  - `:lazy` - For on-demand rendering with caching
  - `:parallel` - For multi-threaded rendering of independent sections

  ## Usage

      # Select strategy based on data size and requirements
      strategy = RenderStrategy.select_strategy(data_size: 10000, format: :pdf)

      # Execute rendering with the selected strategy
      {:ok, result} = RenderStrategy.execute(strategy, context, options)

  """

  alias AshReports.RenderContext

  @typedoc "Rendering strategy type"
  @type strategy_type ::
          :streaming
          | :batch
          | :immediate
          | :lazy
          | :parallel

  @typedoc "Strategy configuration"
  @type strategy_config :: %{
          type: strategy_type(),
          options: keyword(),
          thresholds: keyword(),
          optimizations: keyword()
        }

  @typedoc "Strategy selection criteria"
  @type selection_criteria :: %{
          data_size: non_neg_integer(),
          format: atom(),
          memory_limit: non_neg_integer(),
          performance_priority: :speed | :memory | :balanced
        }

  @doc """
  Selects the optimal rendering strategy based on the given criteria.

  ## Parameters

  - `criteria` - Map containing selection criteria

  ## Examples

      iex> strategy = AshReports.RenderStrategy.select_strategy(%{
      ...>   data_size: 1000,
      ...>   format: :html,
      ...>   performance_priority: :speed
      ...> })
      iex> strategy.type
      :immediate

  """
  @spec select_strategy(selection_criteria()) :: strategy_config()
  def select_strategy(criteria) do
    strategy_type = determine_strategy_type(criteria)
    create_strategy_config(strategy_type, criteria)
  end

  @doc """
  Executes rendering using the specified strategy.

  ## Parameters

  - `strategy` - The strategy configuration to use
  - `context` - The render context
  - `options` - Additional rendering options

  ## Examples

      strategy = RenderStrategy.select_strategy(%{data_size: 5000, format: :pdf})
      {:ok, result} = RenderStrategy.execute(strategy, context, [])

  """
  @spec execute(strategy_config(), RenderContext.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def execute(strategy, context, options \\ [])

  def execute(%{type: :streaming} = strategy, context, options) do
    execute_streaming_strategy(context, strategy.options, options)
  end

  def execute(%{type: :batch} = strategy, context, options) do
    execute_batch_strategy(context, strategy.options, options)
  end

  def execute(%{type: :immediate} = strategy, context, options) do
    execute_immediate_strategy(context, strategy.options, options)
  end

  def execute(%{type: :lazy} = strategy, context, options) do
    execute_lazy_strategy(context, strategy.options, options)
  end

  def execute(%{type: :parallel} = strategy, context, options) do
    execute_parallel_strategy(context, strategy.options, options)
  end

  @doc """
  Gets the recommended memory allocation for a strategy.

  ## Examples

      strategy = RenderStrategy.select_strategy(%{data_size: 10000, format: :pdf})
      memory_mb = RenderStrategy.memory_recommendation(strategy)

  """
  @spec memory_recommendation(strategy_config()) :: non_neg_integer()
  def memory_recommendation(%{type: :streaming}), do: 50
  def memory_recommendation(%{type: :batch}), do: 200
  def memory_recommendation(%{type: :immediate}), do: 100
  def memory_recommendation(%{type: :lazy}), do: 150
  def memory_recommendation(%{type: :parallel}), do: 300

  # Private implementation functions

  defp determine_strategy_type(%{data_size: size, format: format, performance_priority: priority}) do
    cond do
      should_use_streaming?(size, priority) -> :streaming
      should_use_batch?(size, format) -> :batch
      should_use_immediate?(size, priority, format) -> :immediate
      true -> :batch
    end
  end

  defp should_use_streaming?(size, priority) do
    size > 50000 or (size > 5000 and priority == :memory)
  end

  defp should_use_batch?(size, format) do
    size > 10000 and format == :pdf
  end

  defp should_use_immediate?(size, priority, format) do
    (size < 1000 and priority == :speed) or
      (format in [:html, :json] and size < 5000)
  end

  defp determine_strategy_type(%{data_size: size}) do
    cond do
      size > 50000 -> :streaming
      size > 10000 -> :batch
      size < 1000 -> :immediate
      true -> :batch
    end
  end

  defp create_strategy_config(type, criteria) do
    base_options = get_base_options_for_type(type)
    optimized_options = optimize_for_criteria(base_options, criteria)

    %{
      type: type,
      options: optimized_options,
      thresholds: get_thresholds_for_type(type),
      optimizations: get_optimizations_for_type(type)
    }
  end

  defp get_base_options_for_type(:streaming) do
    [chunk_size: 1000, memory_limit: 50_000_000, buffer_size: 8192]
  end

  defp get_base_options_for_type(:batch) do
    [batch_size: 5000, memory_limit: 200_000_000, parallel_batches: false]
  end

  defp get_base_options_for_type(:immediate) do
    [cache_results: true, memory_limit: 100_000_000, optimize_for_speed: true]
  end

  defp get_base_options_for_type(:lazy) do
    [cache_enabled: true, lazy_load_relationships: true, memory_limit: 150_000_000]
  end

  defp get_base_options_for_type(:parallel) do
    [worker_count: System.schedulers(), memory_limit: 300_000_000, chunk_overlap: false]
  end

  defp optimize_for_criteria(base_options, criteria) do
    base_options
    |> optimize_for_format(Map.get(criteria, :format))
    |> optimize_for_performance(Map.get(criteria, :performance_priority))
    |> optimize_for_memory(Map.get(criteria, :memory_limit))
  end

  defp optimize_for_format(options, :pdf) do
    Keyword.merge(options,
      high_quality_images: true,
      vector_graphics: true,
      compression: :balanced
    )
  end

  defp optimize_for_format(options, :html) do
    Keyword.merge(options,
      css_optimization: true,
      inline_styles: false,
      responsive_images: true
    )
  end

  defp optimize_for_format(options, _format), do: options

  defp optimize_for_performance(options, :speed) do
    Keyword.merge(options,
      cache_aggressively: true,
      parallel_processing: true,
      skip_validations: false
    )
  end

  defp optimize_for_performance(options, :memory) do
    Keyword.merge(options,
      stream_processing: true,
      garbage_collect_frequently: true,
      cache_sparingly: true
    )
  end

  defp optimize_for_performance(options, _priority), do: options

  defp optimize_for_memory(options, nil), do: options

  defp optimize_for_memory(options, limit) when is_integer(limit) do
    Keyword.put(options, :memory_limit, limit)
  end

  defp get_thresholds_for_type(:streaming) do
    [max_chunk_size: 2000, memory_warning: 40_000_000, memory_critical: 45_000_000]
  end

  defp get_thresholds_for_type(:batch) do
    [max_batch_size: 10000, memory_warning: 150_000_000, memory_critical: 180_000_000]
  end

  defp get_thresholds_for_type(_type) do
    [memory_warning: 80_000_000, memory_critical: 90_000_000]
  end

  defp get_optimizations_for_type(:streaming) do
    [prefetch_enabled: true, compression_enabled: true, gc_frequency: :high]
  end

  defp get_optimizations_for_type(:parallel) do
    [work_stealing: true, load_balancing: true, fault_tolerance: :high]
  end

  defp get_optimizations_for_type(_type) do
    [gc_frequency: :normal, compression_enabled: false]
  end

  # Strategy execution implementations

  defp execute_streaming_strategy(context, strategy_options, _render_options) do
    # Placeholder for streaming strategy implementation
    chunk_size = Keyword.get(strategy_options, :chunk_size, 1000)

    # This would implement actual streaming logic
    {:ok,
     %{
       strategy: :streaming,
       chunk_size: chunk_size,
       estimated_memory: calculate_memory_usage(context, :streaming)
     }}
  end

  defp execute_batch_strategy(context, strategy_options, _render_options) do
    # Placeholder for batch strategy implementation
    batch_size = Keyword.get(strategy_options, :batch_size, 5000)

    {:ok,
     %{
       strategy: :batch,
       batch_size: batch_size,
       estimated_memory: calculate_memory_usage(context, :batch)
     }}
  end

  defp execute_immediate_strategy(context, _strategy_options, _render_options) do
    # Placeholder for immediate strategy implementation
    {:ok,
     %{
       strategy: :immediate,
       estimated_memory: calculate_memory_usage(context, :immediate)
     }}
  end

  defp execute_lazy_strategy(context, strategy_options, _render_options) do
    # Placeholder for lazy strategy implementation
    cache_enabled = Keyword.get(strategy_options, :cache_enabled, true)

    {:ok,
     %{
       strategy: :lazy,
       cache_enabled: cache_enabled,
       estimated_memory: calculate_memory_usage(context, :lazy)
     }}
  end

  defp execute_parallel_strategy(context, strategy_options, _render_options) do
    # Placeholder for parallel strategy implementation
    worker_count = Keyword.get(strategy_options, :worker_count, System.schedulers())

    {:ok,
     %{
       strategy: :parallel,
       worker_count: worker_count,
       estimated_memory: calculate_memory_usage(context, :parallel)
     }}
  end

  defp calculate_memory_usage(_context, strategy_type) do
    # Simplified memory calculation
    case strategy_type do
      # 50MB
      :streaming -> 50_000_000
      # 200MB
      :batch -> 200_000_000
      # 100MB
      :immediate -> 100_000_000
      # 150MB
      :lazy -> 150_000_000
      # 300MB
      :parallel -> 300_000_000
    end
  end
end
