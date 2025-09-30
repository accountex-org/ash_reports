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
  @default_max_groups_per_config 10_000
  @default_transformer_timeout 5000

  # Client API

  @doc """
  Starts a ProducerConsumer GenStage process.

  ## Options

  - `:stream_id` - Unique identifier for this pipeline (required)
  - `:subscribe_to` - List of producers to subscribe to (required)
  - `:transformer` - Function to transform records (default: identity)
    - Must be arity-1 function accepting a record map
    - Should be pure and deterministic
    - See "Transformer Security" section below for important security considerations
  - `:transformer_timeout` - Maximum milliseconds for transformer execution per record (default: 5000)
  - `:report_config` - Report configuration for DataProcessor (optional)
  - `:transformation_opts` - Options for DataProcessor.convert_records/2 (optional)
  - `:aggregations` - List of global aggregation functions to apply (default: [])
    - Supported: `:sum`, `:count`, `:avg`, `:min`, `:max`, `:running_total`
  - `:grouped_aggregations` - List of grouped aggregation configurations (default: [])
    - Each config is a map with:
      - `:group_by` - Field or list of fields to group by (required)
      - `:aggregations` - List of aggregation types (required)
      - `:fields` - Specific fields to aggregate (optional, defaults to all numeric)
      - `:max_groups` - Maximum number of unique groups allowed (optional, default: 10000)
  - `:buffer_size` - Maximum buffer size (default: 1000)
  - `:max_demand` - Maximum demand from producer (default: 500)
  - `:min_demand` - Minimum demand from producer (default: 100)
  - `:enable_telemetry` - Enable detailed telemetry events (default: true)

  ## Security Considerations

  ### Grouped Aggregations

  Grouped aggregations can grow unbounded if grouping by high-cardinality fields
  (e.g., user_id, transaction_id). To prevent memory exhaustion:

  - Each grouping configuration has a `max_groups` limit (default: 10,000)
  - Once limit is reached, new groups are rejected and warning is logged
  - Telemetry event `[:ash_reports, :streaming, :producer_consumer, :group_limit_reached]` is emitted
  - Consider the memory impact: 10K groups × ~500 bytes/group ≈ 5MB per grouping config

  ### Transformer Security

  **IMPORTANT**: User-provided transformer functions execute with full system privileges
  and can pose significant security risks if not properly validated.

  #### Risks

  - **Infinite loops**: Transformer could hang forever, blocking the entire pipeline
  - **Memory exhaustion**: Unbounded memory allocation can crash the BEAM VM
  - **System access**: Transformers can read files, make network calls, execute commands
  - **Data exfiltration**: Malicious code could send data to external systems

  #### Protections

  - **Timeout enforcement**: Each transformer call has a timeout (default: 5 seconds)
  - **Arity validation**: Function arity is checked at initialization (must be arity-1)
  - **Error isolation**: Transformer errors are caught and logged, record is skipped
  - **Supervisor restart**: Severe errors crash the process for clean restart

  #### Safe Transformer Guidelines

  DO:
  - Keep transformers pure and side-effect free
  - Use simple data transformations (map updates, calculations)
  - Return nil to filter out records
  - Keep execution time under 100ms per record

  DON'T:
  - Make external API calls or database queries
  - Read/write files or perform I/O operations
  - Use Process.sleep/1 or other blocking operations
  - Store state in Agent/GenServer/ETS
  - Spawn processes or tasks

  #### Example Safe Transformer

      transformer = fn record ->
        record
        |> Map.put(:full_name, "\#{record.first_name} \#{record.last_name}")
        |> Map.update(:amount, 0, &Decimal.mult(&1, Decimal.new("1.10")))
      end

  #### Example UNSAFE Transformer

      # DO NOT DO THIS
      transformer = fn record ->
        # UNSAFE: External API call
        {:ok, response} = HTTPoison.get("https://api.example.com/enrich/\#{record.id}")

        # UNSAFE: File I/O
        File.write!("/tmp/records.log", inspect(record))

        # UNSAFE: Unbounded memory
        :ets.insert(:cache, {record.id, record})

        record
      end

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
    transformer_timeout = Keyword.get(opts, :transformer_timeout, @default_transformer_timeout)
    report_config = Keyword.get(opts, :report_config, %{})
    transformation_opts = Keyword.get(opts, :transformation_opts, [])
    aggregations = Keyword.get(opts, :aggregations, [])
    grouped_aggregations = Keyword.get(opts, :grouped_aggregations, [])
    buffer_size = Keyword.get(opts, :buffer_size, @default_buffer_size)
    max_demand = Keyword.get(opts, :max_demand, @default_max_demand)
    min_demand = Keyword.get(opts, :min_demand, @default_min_demand)
    enable_telemetry = Keyword.get(opts, :enable_telemetry, true)

    # Validate transformer function arity (security: must be arity-1)
    validate_transformer_arity!(transformer, stream_id)

    # Update Registry with our PID
    Registry.update_producer_consumer(stream_id, self())

    # Initialize aggregation state
    aggregation_state = initialize_aggregations(aggregations)

    # Normalize grouped aggregations to ensure max_groups is set
    normalized_grouped_aggregations = normalize_grouped_aggregations(grouped_aggregations)

    # Initialize grouped aggregation state
    grouped_aggregation_state = initialize_grouped_aggregations(normalized_grouped_aggregations)

    state = %{
      stream_id: stream_id,
      transformer: transformer,
      transformer_timeout: transformer_timeout,
      report_config: report_config,
      transformation_opts: transformation_opts,
      aggregations: aggregations,
      aggregation_state: aggregation_state,
      grouped_aggregations: normalized_grouped_aggregations,
      grouped_aggregation_state: grouped_aggregation_state,
      group_counts: %{},
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

    # Transform events - if this crashes, let the supervisor restart the process
    {:ok, transformed_events, new_aggregation_state, new_grouped_aggregation_state, new_group_counts} =
      transform_batch(events, state)

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
         grouped_aggregation_state: new_grouped_aggregation_state,
         group_counts: new_group_counts
     }}
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
    {new_grouped_aggregation_state, new_group_counts} =
      update_grouped_aggregations(
        transformed,
        state.grouped_aggregation_state,
        state.grouped_aggregations,
        state.group_counts,
        state.stream_id,
        state.enable_telemetry
      )

    {:ok, transformed, new_aggregation_state, new_grouped_aggregation_state, new_group_counts}
  end

  defp transform_record(record, state) do
    # Apply custom transformer with timeout protection (security: prevent infinite loops)
    task =
      Task.async(fn ->
        try do
          state.transformer.(record)
        rescue
          # Only catch specific, expected errors from user-provided transformers
          # Let system errors (e.g., VM errors) crash the process
          e in [RuntimeError, ArgumentError, KeyError, FunctionClauseError, ArithmeticError] ->
            Logger.error(
              "Failed to transform record: #{Exception.message(e)} - Record will be skipped"
            )

            nil
        end
      end)

    case Task.yield(task, state.transformer_timeout) || Task.shutdown(task) do
      {:ok, result} ->
        result

      nil ->
        # Timeout - transformer took too long
        Logger.error(
          "Transformer timeout after #{state.transformer_timeout}ms for stream #{state.stream_id} - Record will be skipped"
        )

        nil

      {:exit, reason} ->
        # Task crashed with unexpected error
        Logger.error(
          "Transformer crashed for stream #{state.stream_id}: #{inspect(reason)} - Record will be skipped"
        )

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
    # Single-pass optimization: update all aggregations in one iteration
    # Instead of looping through records multiple times (once per aggregation type),
    # we loop through records once and update all aggregations simultaneously

    # Fast path: if only count, no need to iterate records
    if aggregations == [:count] do
      Map.update!(aggregation_state, :count, &(&1 + length(records)))
    else
      # Build set of required aggregations for quick lookup
      agg_set = MapSet.new(aggregations)

      # Single pass through all records and fields
      Enum.reduce(records, aggregation_state, fn record, state ->
        Enum.reduce(record, state, fn {key, value}, acc ->
          # Only process numeric values
          if is_number(value) do
            acc
            |> update_sum_if_needed(key, value, agg_set)
            |> update_avg_if_needed(key, value, agg_set)
            |> update_min_if_needed(key, value, agg_set)
            |> update_max_if_needed(key, value, agg_set)
            |> update_running_total_if_needed(key, value, agg_set)
          else
            acc
          end
        end)
        |> update_count_if_needed(agg_set)
        |> update_avg_count_if_needed(agg_set)
      end)
    end
  end

  # Optimized aggregation helpers - O(1) updates per field
  # These are called once per field during the single-pass iteration

  defp update_sum_if_needed(state, key, value, agg_set) do
    if MapSet.member?(agg_set, :sum) do
      Map.update!(state, :sum, fn sums ->
        Map.update(sums, key, value, &(&1 + value))
      end)
    else
      state
    end
  end

  defp update_avg_if_needed(state, key, value, agg_set) do
    if MapSet.member?(agg_set, :avg) do
      Map.update!(state, :avg, fn avg_state ->
        # Update the sum for this specific field
        %{avg_state | sum: Map.update(avg_state.sum, key, value, &(&1 + value))}
      end)
    else
      state
    end
  end

  defp update_avg_count_if_needed(state, agg_set) do
    # Increment count for avg aggregation (once per record, not per field)
    if MapSet.member?(agg_set, :avg) do
      Map.update!(state, :avg, fn avg_state ->
        %{avg_state | count: avg_state.count + 1}
      end)
    else
      state
    end
  end

  defp update_min_if_needed(state, key, value, agg_set) do
    if MapSet.member?(agg_set, :min) do
      Map.update!(state, :min, fn mins ->
        Map.update(mins, key, value, &min(&1, value))
      end)
    else
      state
    end
  end

  defp update_max_if_needed(state, key, value, agg_set) do
    if MapSet.member?(agg_set, :max) do
      Map.update!(state, :max, fn maxs ->
        Map.update(maxs, key, value, &max(&1, value))
      end)
    else
      state
    end
  end

  defp update_running_total_if_needed(state, key, value, agg_set) do
    if MapSet.member?(agg_set, :running_total) do
      Map.update!(state, :running_total, fn totals ->
        Map.update(totals, key, value, &(&1 + value))
      end)
    else
      state
    end
  end

  defp update_count_if_needed(state, agg_set) do
    if MapSet.member?(agg_set, :count) do
      Map.update!(state, :count, &(&1 + 1))
    else
      state
    end
  end

  # Grouped Aggregation Functions

  defp normalize_grouped_aggregations(grouped_configs) do
    Enum.map(grouped_configs, fn config ->
      Map.put_new(config, :max_groups, @default_max_groups_per_config)
    end)
  end

  defp initialize_grouped_aggregations(grouped_configs) do
    Enum.reduce(grouped_configs, %{}, fn config, acc ->
      group_key = normalize_group_by(config.group_by)
      Map.put(acc, group_key, %{})
    end)
  end

  defp update_grouped_aggregations(
         records,
         grouped_state,
         grouped_configs,
         group_counts,
         stream_id,
         enable_telemetry
       ) do
    # Process each grouping configuration, tracking group counts and enforcing limits
    {new_grouped_state, new_group_counts} =
      Enum.reduce(grouped_configs, {grouped_state, group_counts}, fn config,
                                                                      {state, counts} ->
        group_key = normalize_group_by(config.group_by)
        current_groups = Map.get(state, group_key, %{})
        current_count = Map.get(counts, group_key, 0)
        max_groups = Map.get(config, :max_groups, @default_max_groups_per_config)

        # Process records for this grouping configuration
        {updated_groups, new_count, rejected_count} =
          Enum.reduce(records, {current_groups, current_count, 0}, fn record,
                                                                       {groups, count, rejected} ->
            # Extract group value(s) from record
            record_group_value = extract_group_value(record, config.group_by)

            # Check if this is an existing group or a new one
            case Map.has_key?(groups, record_group_value) do
              true ->
                # Existing group - update aggregations
                group_agg_state = Map.get(groups, record_group_value)
                updated_group_agg = update_aggregations([record], group_agg_state, config.aggregations)
                {Map.put(groups, record_group_value, updated_group_agg), count, rejected}

              false ->
                # New group - check if we're at the limit
                if count >= max_groups do
                  # Reject new group - emit warning and telemetry
                  if rejected == 0 do
                    # Only log once per batch to avoid spam
                    Logger.warning(
                      "ProducerConsumer #{stream_id} reached group limit (#{max_groups}) for grouping #{inspect(group_key)} - rejecting new groups"
                    )

                    if enable_telemetry do
                      :telemetry.execute(
                        [:ash_reports, :streaming, :producer_consumer, :group_limit_reached],
                        %{max_groups: max_groups, current_count: count},
                        %{stream_id: stream_id, group_by: group_key}
                      )
                    end
                  end

                  {groups, count, rejected + 1}
                else
                  # Accept new group
                  group_agg_state = initialize_aggregations(config.aggregations)
                  updated_group_agg = update_aggregations([record], group_agg_state, config.aggregations)
                  {Map.put(groups, record_group_value, updated_group_agg), count + 1, rejected}
                end
            end
          end)

        # Log if any groups were rejected
        if rejected_count > 0 do
          Logger.warning(
            "ProducerConsumer #{stream_id} rejected #{rejected_count} records due to group limit for #{inspect(group_key)}"
          )
        end

        # Update state and counts
        {Map.put(state, group_key, updated_groups), Map.put(counts, group_key, new_count)}
      end)

    {new_grouped_state, new_group_counts}
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

  # Transformer Security Validation

  defp validate_transformer_arity!(transformer, stream_id) do
    if is_function(transformer) do
      case :erlang.fun_info(transformer, :arity) do
        {:arity, 1} ->
          :ok

        {:arity, arity} ->
          raise ArgumentError, """
          Invalid transformer function for stream #{stream_id}.
          Expected arity-1 function (fn record -> ... end), got arity-#{arity}.

          The transformer must accept exactly one argument (the record map).

          Example:
            transformer = fn record -> Map.put(record, :processed, true) end
          """
      end
    else
      raise ArgumentError, """
      Invalid transformer for stream #{stream_id}.
      Transformer must be a function, got: #{inspect(transformer)}
      """
    end
  end
end
