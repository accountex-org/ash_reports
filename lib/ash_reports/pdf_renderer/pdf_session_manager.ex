defmodule AshReports.PdfRenderer.PdfSessionManager do
  @moduledoc """
  PDF Session Manager - Tracks and manages active PDF generation sessions.

  This GenServer manages active PDF generation sessions, providing cleanup
  coordination, resource tracking, and session lifecycle management for
  the PDF renderer components.

  ## Features

  - **Session Tracking**: Monitors active PDF generation sessions
  - **Resource Management**: Tracks temporary files and process resources
  - **Automatic Cleanup**: Cleans up abandoned sessions and resources
  - **Performance Monitoring**: Tracks PDF generation performance metrics

  ## Usage

      # Start a new PDF session
      {:ok, session_id} = PdfSessionManager.start_session(context)
      
      # Register resources for cleanup
      :ok = PdfSessionManager.register_temp_file(session_id, "/tmp/report.html")
      
      # Complete and cleanup session
      :ok = PdfSessionManager.complete_session(session_id)

  """

  use GenServer
  require Logger

  # 5 minutes
  @cleanup_interval 300_000
  # 1 hour
  @session_timeout 3_600_000

  defstruct sessions: %{}, metrics: %{}, cleanup_timer: nil

  ## Public API

  @doc """
  Starts the PDF Session Manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts a new PDF generation session.
  """
  @spec start_session(map()) :: {:ok, String.t()} | {:error, term()}
  def start_session(context) do
    GenServer.call(__MODULE__, {:start_session, context})
  end

  @doc """
  Registers a temporary file for cleanup with a session.
  """
  @spec register_temp_file(String.t(), String.t()) :: :ok | {:error, term()}
  def register_temp_file(session_id, file_path) do
    GenServer.cast(__MODULE__, {:register_temp_file, session_id, file_path})
  end

  @doc """
  Registers a process for cleanup with a session.
  """
  @spec register_process(String.t(), pid()) :: :ok | {:error, term()}
  def register_process(session_id, pid) do
    GenServer.cast(__MODULE__, {:register_process, session_id, pid})
  end

  @doc """
  Updates session status.
  """
  @spec update_session_status(String.t(), atom()) :: :ok | {:error, term()}
  def update_session_status(session_id, status) do
    GenServer.cast(__MODULE__, {:update_session_status, session_id, status})
  end

  @doc """
  Completes a PDF generation session and triggers cleanup.
  """
  @spec complete_session(String.t()) :: :ok | {:error, term()}
  def complete_session(session_id) do
    GenServer.call(__MODULE__, {:complete_session, session_id})
  end

  @doc """
  Gets status of all active sessions.
  """
  @spec get_session_status() :: map()
  def get_session_status do
    GenServer.call(__MODULE__, :get_session_status)
  end

  @doc """
  Gets performance metrics for PDF generation.
  """
  @spec get_metrics() :: map()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Forces cleanup of abandoned sessions.
  """
  @spec cleanup_abandoned_sessions() :: :ok
  def cleanup_abandoned_sessions do
    GenServer.cast(__MODULE__, :cleanup_abandoned_sessions)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{
      cleanup_timer: schedule_cleanup()
    }

    Logger.info("PDF Session Manager started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:start_session, context}, _from, state) do
    session_id = generate_session_id()

    session = %{
      id: session_id,
      context: context,
      status: :active,
      start_time: System.monotonic_time(:microsecond),
      temp_files: [],
      processes: [],
      last_activity: System.monotonic_time(:microsecond)
    }

    updated_sessions = Map.put(state.sessions, session_id, session)
    updated_state = %{state | sessions: updated_sessions}

    Logger.debug("Started PDF session: #{session_id}")
    {:reply, {:ok, session_id}, updated_state}
  end

  @impl GenServer
  def handle_call({:complete_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        # Perform cleanup
        cleanup_session_resources(session)

        # Update metrics
        duration = System.monotonic_time(:microsecond) - session.start_time
        updated_metrics = update_completion_metrics(state.metrics, duration)

        # Remove session
        updated_sessions = Map.delete(state.sessions, session_id)
        updated_state = %{state | sessions: updated_sessions, metrics: updated_metrics}

        Logger.debug("Completed PDF session: #{session_id}")
        {:reply, :ok, updated_state}
    end
  end

  @impl GenServer
  def handle_call(:get_session_status, _from, state) do
    status = %{
      active_sessions: map_size(state.sessions),
      sessions:
        Enum.map(state.sessions, fn {id, session} ->
          %{
            id: id,
            status: session.status,
            start_time: session.start_time,
            temp_files: length(session.temp_files),
            processes: length(session.processes)
          }
        end)
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl GenServer
  def handle_cast({:register_temp_file, session_id, file_path}, state) do
    updated_sessions =
      update_in(state.sessions, [session_id, :temp_files], fn files ->
        if files, do: [file_path | files], else: [file_path]
      end)

    updated_state = %{state | sessions: updated_sessions}
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:register_process, session_id, pid}, state) do
    updated_sessions =
      update_in(state.sessions, [session_id, :processes], fn processes ->
        if processes, do: [pid | processes], else: [pid]
      end)

    updated_state = %{state | sessions: updated_sessions}
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:update_session_status, session_id, status}, state) do
    updated_sessions =
      update_in(state.sessions, [session_id], fn session ->
        if session do
          %{session | status: status, last_activity: System.monotonic_time(:microsecond)}
        else
          session
        end
      end)

    updated_state = %{state | sessions: updated_sessions}
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast(:cleanup_abandoned_sessions, state) do
    current_time = System.monotonic_time(:microsecond)

    {abandoned, active} =
      Enum.split_with(state.sessions, fn {_id, session} ->
        current_time - session.last_activity > @session_timeout * 1000
      end)

    # Cleanup abandoned sessions
    Enum.each(abandoned, fn {_id, session} ->
      cleanup_session_resources(session)
      Logger.warning("Cleaned up abandoned PDF session: #{session.id}")
    end)

    active_sessions = Map.new(active)
    updated_state = %{state | sessions: active_sessions}

    if length(abandoned) > 0 do
      Logger.info("Cleaned up #{length(abandoned)} abandoned PDF sessions")
    end

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_info(:cleanup_timer, state) do
    # Perform periodic cleanup
    send(self(), {:cleanup_abandoned_sessions})

    updated_state = %{state | cleanup_timer: schedule_cleanup()}
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_info({:cleanup_abandoned_sessions}, state) do
    handle_cast(:cleanup_abandoned_sessions, state)
  end

  @impl GenServer
  def terminate(_reason, state) do
    # Cleanup all active sessions
    Enum.each(state.sessions, fn {_id, session} ->
      cleanup_session_resources(session)
    end)

    Logger.info("PDF Session Manager shutting down")
    :ok
  end

  ## Private Functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_timer, @cleanup_interval)
  end

  defp cleanup_session_resources(session) do
    # Cleanup temporary files
    Enum.each(session.temp_files, fn file_path ->
      case File.rm(file_path) do
        :ok ->
          :ok

        {:error, _reason} ->
          Logger.debug("Could not remove temp file: #{file_path}")
      end
    end)

    # Cleanup processes if needed
    Enum.each(session.processes, fn pid ->
      if Process.alive?(pid) do
        Process.exit(pid, :shutdown)
      end
    end)
  end

  defp update_completion_metrics(metrics, duration_us) do
    current_metrics =
      metrics ||
        %{
          total_sessions: 0,
          total_duration_us: 0,
          average_duration_us: 0,
          max_duration_us: 0,
          min_duration_us: nil
        }

    new_total = current_metrics.total_sessions + 1
    new_total_duration = current_metrics.total_duration_us + duration_us
    new_average = div(new_total_duration, new_total)
    new_max = max(current_metrics.max_duration_us, duration_us)

    new_min =
      if current_metrics.min_duration_us,
        do: min(current_metrics.min_duration_us, duration_us),
        else: duration_us

    %{
      total_sessions: new_total,
      total_duration_us: new_total_duration,
      average_duration_us: new_average,
      max_duration_us: new_max,
      min_duration_us: new_min
    }
  end
end
