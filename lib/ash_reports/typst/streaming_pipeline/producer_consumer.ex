defmodule AshReports.Typst.StreamingPipeline.ProducerConsumer do
  @moduledoc """
  GenStage ProducerConsumer for transforming streamed records.

  This stage acts as both consumer (receiving records from Producer) and producer
  (emitting transformed records to downstream consumers). It integrates with
  `AshReports.Typst.DataProcessor` to apply transformations.

  ## Architecture

      Producer → ProducerConsumer → Consumer
      (Query)    (Transform)        (Render)

  The ProducerConsumer:
  1. Receives raw Ash records from Producer
  2. Applies transformations (formatting, calculations, aggregations)
  3. Emits transformed data structures for rendering

  ## Transformation Pipeline

  Each record goes through the following transformations:
  - Field extraction and mapping
  - Data type conversions
  - Calculations and computed fields
  - Formatting (dates, numbers, currency)
  - Aggregations (group-by, sum, count)

  ## Backpressure

  GenStage automatically handles backpressure:
  - If downstream consumer is slow, this stage slows down
  - If upstream producer is slow, this stage waits
  - Memory usage stays bounded

  ## Configuration

      config :ash_reports, :streaming,
        producer_consumer_max_demand: 500,
        producer_consumer_min_demand: 100

  ## Usage

  ProducerConsumers are typically started via the StreamingPipeline API:

      {:ok, producer_consumer_pid} = StreamingPipeline.ProducerConsumer.start_link(
        stream_id: "abc123",
        subscribe_to: [{producer_pid, max_demand: 500}],
        transformer: &MyModule.transform/1
      )

  ## Telemetry

  Emits the following events:
  - `[:ash_reports, :streaming, :producer_consumer, :batch_transformed]`
  - `[:ash_reports, :streaming, :producer_consumer, :error]`
  """

  use GenStage
  require Logger

  alias AshReports.Typst.{DataProcessor, StreamingPipeline}
  alias StreamingPipeline.Registry

  @default_max_demand 500
  @default_min_demand 100
  @default_buffer_size 1000

  # Client API

  @doc """
  Starts a ProducerConsumer GenStage process.

  ## Options

  - `:stream_id` - Unique identifier for this pipeline (required)
  - `:subscribe_to` - List of producers to subscribe to (required)
  - `:transformer` - Function to transform records (default: identity)
  - `:report_config` - Report configuration for DataProcessor (optional)
  - `:transformation_opts` - Options for DataProcessor.convert_records/2 (optional)
  - `:aggregations` - List of global aggregation functions to apply (default: [])
    - Supported: `:sum`, `:count`, `:avg`, `:min`, `:max`, `:running_total`
  - `:grouped_aggregations` - List of grouped aggregation configurations (default: [])
    - Each config is a map with:
      - `:group_by` - Field or list of fields to group by (required)
      - `:aggregations` - List of aggregation types (required)
      - `:fields` - Specific fields to aggregate (optional, defaults to all numeric)
  - `:buffer_size` - Maximum buffer size (default: 1000)
  - `:max_demand` - Maximum demand from producer (default: 500)
  - `:min_demand` - Minimum demand from producer (default: 100)
  - `:enable_telemetry` - Enable detailed telemetry events (default: true)

  ## Examples

      # Global aggregations only
      ProducerConsumer.start_link(
        stream_id: "report-1",
        subscribe_to: [{producer, []}],
        aggregations: [:sum, :count, :avg]
      )

      # Grouped aggregations
      ProducerConsumer.start_link(
        stream_id: "report-2",
        subscribe_to: [{producer, []}],
        grouped_aggregations: [
          %{group_by: :territory, aggregations: [:sum, :count]},
          %{group_by: [:territory, :customer_name], aggregations: [:sum, :count]}
        ]
      )
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    stream_id = Keyword.fetch!(opts, :stream_id)
    subscribe_to = Keyword.fetch!(opts, :subscribe_to)
    transformer = Keyword.get(opts, :transformer, &identity/1)
    report_config = Keyword.get(opts, :report_config, %{})
    transformation_opts = Keyword.get(opts, :transformation_opts, [])
    aggregations = Keyword.get(opts, :aggregations, [])
    grouped_aggregations = Keyword.get(opts, :grouped_aggregations, [])
    buffer_size = Keyword.get(opts, :buffer_size, @default_buffer_size)
    max_demand = Keyword.get(opts, :max_demand, @default_max_demand)
    min_demand = Keyword.get(opts, :min_demand, @default_min_demand)
    enable_telemetry = Keyword.get(opts, :enable_telemetry, true)

    # Update Registry with our PID
    Registry.update_producer_consumer(stream_id, self())

    # Initialize aggregation state
    aggregation_state = initialize_aggregations(aggregations)

    # Initialize grouped aggregation state
    grouped_aggregation_state = initialize_grouped_aggregations(grouped_aggregations)

    state = %{
      stream_id: stream_id,
      transformer: transformer,
      report_config: report_config,
      transformation_opts: transformation_opts,
      aggregations: aggregations,
      aggregation_state: aggregation_state,
      grouped_aggregations: grouped_aggregations,
      grouped_aggregation_state: grouped_aggregation_state,
      buffer_size: buffer_size,
      max_demand: max_demand,
      min_demand: min_demand,
      enable_telemetry: enable_telemetry,
      total_transformed: 0,
      records_buffered: 0,
      errors: []
    }

    Logger.debug("StreamingPipeline.ProducerConsumer started for stream #{stream_id}")

    # Subscribe to producer(s) with buffer configuration
    {:producer_consumer, state,
     subscribe_to: format_subscriptions(subscribe_to, max_demand, min_demand),
     buffer_size: buffer_size}
  end

  @impl true
  def handle_events(events, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Transform events
    case transform_batch(events, state) do
      {:ok, transformed_events, new_aggregation_state, new_grouped_aggregation_state} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Emit telemetry
        if state.enable_telemetry do
          :telemetry.execute(
            [:ash_reports, :streaming, :producer_consumer, :batch_transformed],
            %{
              records_in: length(events),
              records_out: length(transformed_events),
              duration_ms: duration,
              records_buffered: length(transformed_events)
            },
            %{stream_id: state.stream_id}
          )

          # Emit aggregation telemetry if aggregations are enabled
          if state.aggregations != [] or state.grouped_aggregations != [] do
            :telemetry.execute(
              [:ash_reports, :streaming, :producer_consumer, :aggregation_computed],
              %{records_processed: length(transformed_events)},
              %{
                stream_id: state.stream_id,
                aggregations: new_aggregation_state,
                grouped_aggregations: new_grouped_aggregation_state
              }
            )
          end
        end

        # Check buffer size and emit warning if near capacity
        buffer_usage = length(transformed_events)

        if buffer_usage > state.buffer_size * 0.8 do
          Logger.warning(
            "ProducerConsumer #{state.stream_id} buffer at #{buffer_usage}/#{state.buffer_size} (#{trunc(buffer_usage / state.buffer_size * 100)}%)"
          )

          if state.enable_telemetry do
            :telemetry.execute(
              [:ash_reports, :streaming, :producer_consumer, :buffer_full],
              %{buffer_size: state.buffer_size, records_buffered: buffer_usage},
              %{stream_id: state.stream_id}
            )
          end
        end

        new_total = state.total_transformed + length(transformed_events)

        {:noreply, transformed_events,
         %{
           state
           | total_transformed: new_total,
             records_buffered: buffer_usage,
             aggregation_state: new_aggregation_state,
             grouped_aggregation_state: new_grouped_aggregation_state
         }}

      {:error, reason} ->
        Logger.error(
          "ProducerConsumer #{state.stream_id} transformation failed: #{inspect(reason)}"
        )

        if state.enable_telemetry do
          :telemetry.execute(
            [:ash_reports, :streaming, :producer_consumer, :error],
            %{records: length(events)},
            %{stream_id: state.stream_id, reason: reason}
          )
        end

        Registry.update_status(state.stream_id, :failed)

        # Pass through empty list on error
        {:noreply, [], %{state | errors: [reason | state.errors]}}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning(
      "ProducerConsumer #{state.stream_id} received unexpected message: #{inspect(msg)}"
    )

    {:noreply, [], state}
  end

  # Private Functions

  defp transform_batch(events, state) do
    try do
      # Step 1: Apply DataProcessor conversion if transformation_opts provided
      converted_events =
        if state.transformation_opts != [] do
          case DataProcessor.convert_records(events, state.transformation_opts) do
            {:ok, converted} ->
              converted

            {:error, reason} ->
              Logger.error(
                "ProducerConsumer #{state.stream_id} DataProcessor conversion failed: #{inspect(reason)}"
              )

              # Fall back to raw events
              events
          end
        else
          events
        end

      # Step 2: Apply custom transformer function to each event
      transformed =
        converted_events
        |> Enum.map(fn event ->
          transform_record(event, state)
        end)
        # Filter out any nil results
        |> Enum.reject(&is_nil/1)

      # Step 3: Update global aggregations
      new_aggregation_state =
        update_aggregations(transformed, state.aggregation_state, state.aggregations)

      # Step 4: Update grouped aggregations
      new_grouped_aggregation_state =
        update_grouped_aggregations(
          transformed,
          state.grouped_aggregation_state,
          state.grouped_aggregations
        )

      {:ok, transformed, new_aggregation_state, new_grouped_aggregation_state}
    rescue
      exception ->
        {:error, exception}
    end
  end

  defp transform_record(record, state) do
    try do
      # Apply custom transformer if provided
      state.transformer.(record)
    rescue
      exception ->
        Logger.error("Failed to transform record: #{inspect(exception)}")
        nil
    end
  end

  defp initialize_aggregations(aggregations) do
    Enum.reduce(aggregations, %{}, fn agg, acc ->
      case agg do
        :sum -> Map.put(acc, :sum, %{})
        :count -> Map.put(acc, :count, 0)
        :avg -> Map.put(acc, :avg, %{sum: %{}, count: 0})
        :min -> Map.put(acc, :min, %{})
        :max -> Map.put(acc, :max, %{})
        :running_total -> Map.put(acc, :running_total, %{})
        _ -> acc
      end
    end)
  end

  defp update_aggregations(records, aggregation_state, aggregations) do
    Enum.reduce(aggregations, aggregation_state, fn agg, state ->
      case agg do
        :count ->
          Map.update!(state, :count, &(&1 + length(records)))

        :sum ->
          new_sums = calculate_sums(records, state.sum)
          Map.put(state, :sum, new_sums)

        :avg ->
          new_count = state.avg.count + length(records)
          new_sums = calculate_sums(records, state.avg.sum)
          Map.put(state, :avg, %{sum: new_sums, count: new_count})

        :min ->
          new_mins = calculate_mins(records, state.min)
          Map.put(state, :min, new_mins)

        :max ->
          new_maxs = calculate_maxs(records, state.max)
          Map.put(state, :max, new_maxs)

        :running_total ->
          new_totals = calculate_running_totals(records, state.running_total)
          Map.put(state, :running_total, new_totals)

        _ ->
          state
      end
    end)
  end

  defp calculate_sums(records, current_sums) do
    Enum.reduce(records, current_sums, fn record, sums ->
      Enum.reduce(record, sums, fn {key, value}, acc ->
        if is_number(value) do
          Map.update(acc, key, value, &(&1 + value))
        else
          acc
        end
      end)
    end)
  end

  defp calculate_mins(records, current_mins) do
    Enum.reduce(records, current_mins, fn record, mins ->
      Enum.reduce(record, mins, fn {key, value}, acc ->
        if is_number(value) do
          Map.update(acc, key, value, &min(&1, value))
        else
          acc
        end
      end)
    end)
  end

  defp calculate_maxs(records, current_maxs) do
    Enum.reduce(records, current_maxs, fn record, maxs ->
      Enum.reduce(record, maxs, fn {key, value}, acc ->
        if is_number(value) do
          Map.update(acc, key, value, &max(&1, value))
        else
          acc
        end
      end)
    end)
  end

  defp calculate_running_totals(records, current_totals) do
    Enum.reduce(records, current_totals, fn record, totals ->
      Enum.reduce(record, totals, fn {key, value}, acc ->
        if is_number(value) do
          Map.update(acc, key, value, &(&1 + value))
        else
          acc
        end
      end)
    end)
  end

  # Grouped Aggregation Functions

  defp initialize_grouped_aggregations(grouped_configs) do
    Enum.reduce(grouped_configs, %{}, fn config, acc ->
      group_key = normalize_group_by(config.group_by)
      Map.put(acc, group_key, %{})
    end)
  end

  defp update_grouped_aggregations(records, grouped_state, grouped_configs) do
    Enum.reduce(grouped_configs, grouped_state, fn config, state ->
      group_key = normalize_group_by(config.group_by)
      current_groups = Map.get(state, group_key, %{})

      updated_groups =
        Enum.reduce(records, current_groups, fn record, groups ->
          # Extract group value(s) from record
          record_group_value = extract_group_value(record, config.group_by)

          # Get or initialize aggregation state for this group
          group_agg_state =
            Map.get(groups, record_group_value, initialize_aggregations(config.aggregations))

          # Update aggregations for this group with single record
          updated_group_agg = update_aggregations([record], group_agg_state, config.aggregations)

          Map.put(groups, record_group_value, updated_group_agg)
        end)

      Map.put(state, group_key, updated_groups)
    end)
  end

  defp normalize_group_by(group_by) when is_list(group_by), do: group_by
  defp normalize_group_by(group_by) when is_atom(group_by), do: [group_by]

  defp extract_group_value(record, group_by) when is_list(group_by) do
    # Multi-field grouping - create tuple of values
    values = Enum.map(group_by, fn field -> Map.get(record, field) end)
    List.to_tuple(values)
  end

  defp extract_group_value(record, group_by) when is_atom(group_by) do
    # Single field grouping
    Map.get(record, group_by)
  end

  defp format_subscriptions(subscribe_to, max_demand, min_demand) do
    Enum.map(subscribe_to, fn
      {producer, opts} ->
        # Override with provided options
        {producer, Keyword.merge([max_demand: max_demand, min_demand: min_demand], opts)}

      producer when is_pid(producer) or is_atom(producer) ->
        # Use defaults
        {producer, [max_demand: max_demand, min_demand: min_demand]}
    end)
  end

  defp identity(x), do: x
end
