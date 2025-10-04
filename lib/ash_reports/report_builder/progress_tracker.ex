defmodule AshReports.ReportBuilder.ProgressTracker do
  @moduledoc """
  Tracks report generation progress and provides status updates.

  This module provides a simplified progress tracking system for the report builder.
  In the MVP, it simulates progress. Future versions will integrate with the
  StreamingPipeline telemetry system for real-time progress tracking.

  ## Usage

      # Start tracking a report generation
      {:ok, tracker_id} = ProgressTracker.start_tracking(report_id, total_records: 1000)

      # Update progress
      :ok = ProgressTracker.update_progress(tracker_id, processed: 250)

      # Get current status
      {:ok, status} = ProgressTracker.get_status(tracker_id)

      # Complete tracking
      :ok = ProgressTracker.complete(tracker_id)

  ## State Structure

  The tracker maintains state in ETS with the following structure:

      %{
        tracker_id: String.t(),
        report_id: String.t(),
        status: :pending | :running | :completed | :failed | :cancelled,
        progress: 0..100,
        total_records: integer(),
        processed_records: integer(),
        started_at: DateTime.t(),
        updated_at: DateTime.t(),
        completed_at: DateTime.t() | nil,
        error: term() | nil
      }
  """

  use GenServer
  require Logger

  @table_name :report_progress_tracker
  @cleanup_interval :timer.minutes(5)

  # Client API

  @doc """
  Starts the ProgressTracker GenServer.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Starts tracking progress for a report generation task.

  ## Parameters
    - `report_id` - Unique identifier for the report
    - `opts` - Options:
      - `:total_records` - Total number of records to process (optional)
      - `:estimated_duration` - Estimated duration in seconds (optional)

  ## Returns
    - `{:ok, tracker_id}` - Tracker started successfully
    - `{:error, reason}` - Failed to start tracker
  """
  def start_tracking(report_id, opts \\ []) do
    GenServer.call(__MODULE__, {:start_tracking, report_id, opts})
  end

  @doc """
  Updates progress for a tracked report.

  ## Parameters
    - `tracker_id` - Tracker identifier
    - `updates` - Keyword list of updates:
      - `:processed` - Number of records processed
      - `:progress` - Direct progress percentage (0-100)
      - `:status` - New status atom

  ## Returns
    - `:ok` - Progress updated
    - `{:error, :not_found}` - Tracker not found
  """
  def update_progress(tracker_id, updates) do
    GenServer.call(__MODULE__, {:update_progress, tracker_id, updates})
  end

  @doc """
  Gets the current status of a tracked report.

  ## Returns
    - `{:ok, status_map}` - Current status
    - `{:error, :not_found}` - Tracker not found
  """
  def get_status(tracker_id) do
    case :ets.lookup(@table_name, tracker_id) do
      [{^tracker_id, status}] -> {:ok, status}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Marks a report generation as completed.
  """
  def complete(tracker_id) do
    GenServer.call(__MODULE__, {:complete, tracker_id})
  end

  @doc """
  Marks a report generation as failed.
  """
  def fail(tracker_id, error) do
    GenServer.call(__MODULE__, {:fail, tracker_id, error})
  end

  @doc """
  Cancels a report generation.
  """
  def cancel(tracker_id) do
    GenServer.call(__MODULE__, {:cancel, tracker_id})
  end

  @doc """
  Lists all active trackers.
  """
  def list_active do
    @table_name
    |> :ets.tab2list()
    |> Enum.filter(fn {_id, status} -> status.status in [:pending, :running] end)
    |> Enum.map(fn {_id, status} -> status end)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for storing progress state
    :ets.new(@table_name, [:named_table, :public, read_concurrency: true])

    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_old_trackers, @cleanup_interval)

    Logger.info("ProgressTracker started")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:start_tracking, report_id, opts}, _from, state) do
    tracker_id = generate_tracker_id()
    now = DateTime.utc_now()

    status = %{
      tracker_id: tracker_id,
      report_id: report_id,
      status: :pending,
      progress: 0,
      total_records: Keyword.get(opts, :total_records, 0),
      processed_records: 0,
      started_at: now,
      updated_at: now,
      completed_at: nil,
      error: nil
    }

    :ets.insert(@table_name, {tracker_id, status})

    Logger.info("Started tracking report #{report_id} with tracker #{tracker_id}")
    {:reply, {:ok, tracker_id}, state}
  end

  @impl true
  def handle_call({:update_progress, tracker_id, updates}, _from, state) do
    case :ets.lookup(@table_name, tracker_id) do
      [{^tracker_id, current_status}] ->
        updated_status =
          current_status
          |> apply_updates(updates)
          |> Map.put(:updated_at, DateTime.utc_now())

        :ets.insert(@table_name, {tracker_id, updated_status})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:complete, tracker_id}, _from, state) do
    case :ets.lookup(@table_name, tracker_id) do
      [{^tracker_id, current_status}] ->
        updated_status =
          current_status
          |> Map.put(:status, :completed)
          |> Map.put(:progress, 100)
          |> Map.put(:completed_at, DateTime.utc_now())
          |> Map.put(:updated_at, DateTime.utc_now())

        :ets.insert(@table_name, {tracker_id, updated_status})
        Logger.info("Completed tracking for #{tracker_id}")
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:fail, tracker_id, error}, _from, state) do
    case :ets.lookup(@table_name, tracker_id) do
      [{^tracker_id, current_status}] ->
        updated_status =
          current_status
          |> Map.put(:status, :failed)
          |> Map.put(:error, error)
          |> Map.put(:completed_at, DateTime.utc_now())
          |> Map.put(:updated_at, DateTime.utc_now())

        :ets.insert(@table_name, {tracker_id, updated_status})
        Logger.error("Failed tracking for #{tracker_id}: #{inspect(error)}")
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:cancel, tracker_id}, _from, state) do
    case :ets.lookup(@table_name, tracker_id) do
      [{^tracker_id, current_status}] ->
        updated_status =
          current_status
          |> Map.put(:status, :cancelled)
          |> Map.put(:completed_at, DateTime.utc_now())
          |> Map.put(:updated_at, DateTime.utc_now())

        :ets.insert(@table_name, {tracker_id, updated_status})
        Logger.info("Cancelled tracking for #{tracker_id}")
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_info(:cleanup_old_trackers, state) do
    # Remove completed/failed/cancelled trackers older than 1 hour
    cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)

    @table_name
    |> :ets.tab2list()
    |> Enum.each(fn {tracker_id, status} ->
      if status.status in [:completed, :failed, :cancelled] and
           DateTime.compare(status.updated_at, cutoff) == :lt do
        :ets.delete(@table_name, tracker_id)
        Logger.debug("Cleaned up old tracker #{tracker_id}")
      end
    end)

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_old_trackers, @cleanup_interval)
    {:noreply, state}
  end

  # Private Functions

  defp generate_tracker_id do
    "tracker_" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  defp apply_updates(status, updates) do
    status =
      if processed = Keyword.get(updates, :processed) do
        progress =
          if status.total_records > 0 do
            round(processed / status.total_records * 100)
          else
            0
          end

        status
        |> Map.put(:processed_records, processed)
        |> Map.put(:progress, progress)
        |> Map.put(:status, :running)
      else
        status
      end

    status =
      if progress = Keyword.get(updates, :progress) do
        Map.put(status, :progress, min(progress, 100))
      else
        status
      end

    if new_status = Keyword.get(updates, :status) do
      Map.put(status, :status, new_status)
    else
      status
    end
  end
end
