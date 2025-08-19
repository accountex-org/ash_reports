defmodule AshReports.PdfRenderer.TempFileCleanup do
  @moduledoc """
  Temporary File Cleanup - Periodic cleanup service for PDF generation temporary files.

  This GenServer provides automatic cleanup of temporary files created during
  PDF generation, preventing disk space accumulation and maintaining system hygiene.

  ## Features

  - **Periodic Cleanup**: Automatically removes old temporary files
  - **Pattern-Based**: Configurable file patterns for cleanup
  - **Age-Based Removal**: Only removes files older than specified threshold
  - **Safe Operation**: Carefully validates files before removal

  ## Configuration

      config :ash_reports,
        pdf_temp_cleanup_interval: 3_600_000,  # 1 hour
        temp_file_patterns: [
          "ash_reports_*.html",
          "ash_reports_*.pdf"
        ],
        max_file_age_seconds: 7200  # 2 hours

  """

  use GenServer
  require Logger

  defstruct config: %{}, cleanup_timer: nil, stats: %{}

  ## Public API

  @doc """
  Starts the Temporary File Cleanup service.
  """
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Triggers immediate cleanup of temporary files.
  """
  @spec cleanup_now() :: :ok
  def cleanup_now do
    GenServer.cast(__MODULE__, :cleanup_now)
  end

  @doc """
  Gets cleanup statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Updates cleanup configuration.
  """
  @spec update_config(map()) :: :ok
  def update_config(new_config) do
    GenServer.cast(__MODULE__, {:update_config, new_config})
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(config) do
    state = %__MODULE__{
      config: normalize_config(config),
      cleanup_timer: schedule_next_cleanup(config),
      stats: init_stats()
    }

    Logger.info("Temporary File Cleanup service started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl GenServer
  def handle_cast(:cleanup_now, state) do
    updated_stats = perform_cleanup(state.config, state.stats)
    updated_state = %{state | stats: updated_stats}
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:update_config, new_config}, state) do
    # Cancel current timer and reschedule with new config
    if state.cleanup_timer do
      Process.cancel_timer(state.cleanup_timer)
    end

    normalized_config = normalize_config(new_config)
    new_timer = schedule_next_cleanup(normalized_config)

    updated_state = %{state | config: normalized_config, cleanup_timer: new_timer}

    Logger.info("Temporary File Cleanup configuration updated")
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_info(:cleanup_timer, state) do
    updated_stats = perform_cleanup(state.config, state.stats)
    new_timer = schedule_next_cleanup(state.config)

    updated_state = %{state | stats: updated_stats, cleanup_timer: new_timer}

    {:noreply, updated_state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    if state.cleanup_timer do
      Process.cancel_timer(state.cleanup_timer)
    end

    Logger.info("Temporary File Cleanup service shutting down")
    :ok
  end

  ## Private Functions

  defp normalize_config(config) do
    %{
      interval: config[:interval] || 3_600_000,
      temp_dir_patterns: config[:temp_dir_patterns] || ["ash_reports_*.html"],
      max_age_seconds: config[:max_age_seconds] || 7200,
      temp_dir: config[:temp_dir] || System.tmp_dir()
    }
  end

  defp schedule_next_cleanup(config) do
    interval = config[:interval] || 3_600_000
    Process.send_after(self(), :cleanup_timer, interval)
  end

  defp init_stats do
    %{
      total_runs: 0,
      total_files_removed: 0,
      total_bytes_freed: 0,
      last_run_at: nil,
      last_run_files_removed: 0,
      last_run_bytes_freed: 0,
      errors: []
    }
  end

  defp perform_cleanup(config, current_stats) do
    start_time = System.monotonic_time(:microsecond)

    Logger.debug("Starting temporary file cleanup")

    cleanup_results =
      config.temp_dir_patterns
      |> Enum.map(fn pattern ->
        cleanup_pattern(config.temp_dir, pattern, config.max_age_seconds)
      end)
      |> Enum.reduce(%{files_removed: 0, bytes_freed: 0, errors: []}, fn result, acc ->
        %{
          files_removed: acc.files_removed + result.files_removed,
          bytes_freed: acc.bytes_freed + result.bytes_freed,
          errors: acc.errors ++ result.errors
        }
      end)

    duration_us = System.monotonic_time(:microsecond) - start_time

    updated_stats = %{
      total_runs: current_stats.total_runs + 1,
      total_files_removed: current_stats.total_files_removed + cleanup_results.files_removed,
      total_bytes_freed: current_stats.total_bytes_freed + cleanup_results.bytes_freed,
      last_run_at: System.os_time(:second),
      last_run_files_removed: cleanup_results.files_removed,
      last_run_bytes_freed: cleanup_results.bytes_freed,
      last_run_duration_us: duration_us,
      # Keep last 10 errors
      errors: Enum.take(cleanup_results.errors, 10)
    }

    if cleanup_results.files_removed > 0 do
      Logger.info("""
      Temporary file cleanup completed:
      - Files removed: #{cleanup_results.files_removed}
      - Bytes freed: #{format_bytes(cleanup_results.bytes_freed)}
      - Duration: #{format_duration(duration_us)}
      """)
    else
      Logger.debug("Temporary file cleanup completed: no files to remove")
    end

    if length(cleanup_results.errors) > 0 do
      Logger.warning(
        "Temporary file cleanup encountered #{length(cleanup_results.errors)} errors"
      )
    end

    updated_stats
  end

  defp cleanup_pattern(temp_dir, pattern, max_age_seconds) do
    full_pattern = Path.join(temp_dir, pattern)
    current_time = System.os_time(:second)

    try do
      files = Path.wildcard(full_pattern)

      results =
        Enum.reduce(files, %{files_removed: 0, bytes_freed: 0, errors: []}, fn file_path, acc ->
          case should_remove_file?(file_path, current_time, max_age_seconds) do
            {:yes, file_size} ->
              case File.rm(file_path) do
                :ok ->
                  %{
                    acc
                    | files_removed: acc.files_removed + 1,
                      bytes_freed: acc.bytes_freed + file_size
                  }

                {:error, reason} ->
                  error = "Failed to remove #{file_path}: #{inspect(reason)}"
                  %{acc | errors: [error | acc.errors]}
              end

            :no ->
              acc

            {:error, reason} ->
              error = "Failed to check #{file_path}: #{inspect(reason)}"
              %{acc | errors: [error | acc.errors]}
          end
        end)

      results
    rescue
      error ->
        %{
          files_removed: 0,
          bytes_freed: 0,
          errors: ["Pattern #{pattern} error: #{inspect(error)}"]
        }
    end
  end

  defp should_remove_file?(file_path, current_time, max_age_seconds) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime, size: size}} ->
        file_age_seconds = current_time - :calendar.datetime_to_gregorian_seconds(mtime)

        if file_age_seconds > max_age_seconds and safe_to_remove?(file_path) do
          {:yes, size}
        else
          :no
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp safe_to_remove?(file_path) do
    # Safety checks to ensure we only remove our temporary files
    filename = Path.basename(file_path)

    # Must match our naming pattern
    # Must be in temp directory
    # Must have safe extensions
    String.starts_with?(filename, "ash_reports_") and
      String.starts_with?(file_path, System.tmp_dir()) and
      (String.ends_with?(filename, ".html") or
         String.ends_with?(filename, ".pdf") or
         String.ends_with?(filename, ".tmp"))
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"

  defp format_duration(duration_us) when duration_us < 1000, do: "#{duration_us} μs"

  defp format_duration(duration_us) when duration_us < 1_000_000,
    do: "#{Float.round(duration_us / 1000, 1)} ms"

  defp format_duration(duration_us), do: "#{Float.round(duration_us / 1_000_000, 1)} s"
end
