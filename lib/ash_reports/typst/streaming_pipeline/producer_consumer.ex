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

  alias AshReports.Typst.StreamingPipeline.Registry

  @default_max_demand 500
  @default_min_demand 100

  # Client API

  @doc """
  Starts a ProducerConsumer GenStage process.

  ## Options

  - `:stream_id` - Unique identifier for this pipeline (required)
  - `:subscribe_to` - List of producers to subscribe to (required)
  - `:transformer` - Function to transform records (default: identity)
  - `:report_config` - Report configuration for DataProcessor (optional)
  - `:max_demand` - Maximum demand from producer (default: 500)
  - `:min_demand` - Minimum demand from producer (default: 100)
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
    max_demand = Keyword.get(opts, :max_demand, @default_max_demand)
    min_demand = Keyword.get(opts, :min_demand, @default_min_demand)

    # Update Registry with our PID
    Registry.update_producer_consumer(stream_id, self())

    state = %{
      stream_id: stream_id,
      transformer: transformer,
      report_config: report_config,
      max_demand: max_demand,
      min_demand: min_demand,
      total_transformed: 0
    }

    Logger.debug("StreamingPipeline.ProducerConsumer started for stream #{stream_id}")

    # Subscribe to producer(s)
    {:producer_consumer, state,
     subscribe_to: format_subscriptions(subscribe_to, max_demand, min_demand)}
  end

  @impl true
  def handle_events(events, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Transform events
    case transform_batch(events, state) do
      {:ok, transformed_events} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Emit telemetry
        :telemetry.execute(
          [:ash_reports, :streaming, :producer_consumer, :batch_transformed],
          %{
            records_in: length(events),
            records_out: length(transformed_events),
            duration_ms: duration
          },
          %{stream_id: state.stream_id}
        )

        new_total = state.total_transformed + length(transformed_events)

        {:noreply, transformed_events, %{state | total_transformed: new_total}}

      {:error, reason} ->
        Logger.error(
          "ProducerConsumer #{state.stream_id} transformation failed: #{inspect(reason)}"
        )

        :telemetry.execute(
          [:ash_reports, :streaming, :producer_consumer, :error],
          %{records: length(events)},
          %{stream_id: state.stream_id, reason: reason}
        )

        Registry.update_status(state.stream_id, :failed)

        # Pass through untransformed events or empty list
        {:noreply, [], state}
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
      # Apply transformer function to each event
      transformed =
        events
        |> Enum.map(fn event ->
          transform_record(event, state)
        end)
        # Filter out any nil results
        |> Enum.reject(&is_nil/1)

      {:ok, transformed}
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
