defmodule AshReports.RenderObserver do
  @moduledoc """
  Observer pattern implementation for render lifecycle events.

  This module provides an observer pattern for monitoring and reacting to
  render events, enabling features like progress tracking, metrics collection,
  and custom event handling.

  ## Design Benefits

  - **Observer Pattern**: Loose coupling between render operations and event handlers
  - **Event-Driven**: React to render lifecycle events
  - **Extensibility**: Easy to add new observers for different concerns
  - **Monitoring**: Built-in support for performance and progress tracking

  ## Events

  - `:render_started` - Render operation begins
  - `:render_progress` - Progress update during rendering
  - `:render_completed` - Render operation completes successfully
  - `:render_failed` - Render operation fails
  - `:format_applied` - Formatting is applied to data
  - `:data_loaded` - Data loading completes

  ## Usage

      # Register an observer
      RenderObserver.register_observer(:metrics, MetricsObserver)

      # Notify observers of an event
      RenderObserver.notify(:render_started, %{
        report: :sales_report,
        format: :pdf,
        estimated_size: 1000
      })

  """

  @typedoc "Event type"
  @type event_type ::
          :render_started
          | :render_progress
          | :render_completed
          | :render_failed
          | :format_applied
          | :data_loaded
          | :context_prepared

  @typedoc "Event data"
  @type event_data :: map()

  @typedoc "Observer module"
  @type observer_module :: module()

  @typedoc "Observer callback function"
  @type observer_callback :: (event_type(), event_data() -> :ok | {:error, term()})

  @doc """
  Registers an observer for render events.

  ## Parameters

  - `name` - Unique name for the observer
  - `observer` - Module implementing observer callbacks or callback function

  ## Examples

      # Register a module observer
      RenderObserver.register_observer(:metrics, MyMetricsObserver)

      # Register a function observer
      RenderObserver.register_observer(:logger, fn _event, _data ->
        IO.puts("Render event occurred")
      end)

  """
  @spec register_observer(atom(), observer_module() | observer_callback()) :: :ok
  def register_observer(name, observer) when is_atom(name) do
    observers = get_observers()
    updated_observers = Map.put(observers, name, observer)
    put_observers(updated_observers)
    :ok
  end

  @doc """
  Unregisters an observer.

  ## Parameters

  - `name` - Name of the observer to remove

  ## Examples

      RenderObserver.unregister_observer(:metrics)

  """
  @spec unregister_observer(atom()) :: :ok
  def unregister_observer(name) when is_atom(name) do
    observers = get_observers()
    updated_observers = Map.delete(observers, name)
    put_observers(updated_observers)
    :ok
  end

  @doc """
  Notifies all registered observers of an event.

  ## Parameters

  - `event` - The event type
  - `data` - Event data to send to observers

  ## Examples

      RenderObserver.notify(:render_started, %{
        report: :sales_report,
        start_time: System.monotonic_time()
      })

  """
  @spec notify(event_type(), event_data()) :: :ok
  def notify(event, data) when is_atom(event) and is_map(data) do
    observers = get_observers()

    Enum.each(observers, fn {_name, observer} ->
      try do
        notify_observer(observer, event, data)
      rescue
        error ->
          # Log observer errors but don't fail the main operation
          log_observer_error(observer, event, error)
      end
    end)

    :ok
  end

  @doc """
  Lists all registered observers.

  ## Examples

      observers = RenderObserver.list_observers()
      # => [:metrics, :logger, :audit]

  """
  @spec list_observers() :: [atom()]
  def list_observers do
    get_observers() |> Map.keys()
  end

  @doc """
  Creates a progress tracking observer that can be used to monitor render progress.

  ## Examples

      progress_observer = RenderObserver.create_progress_observer()
      RenderObserver.register_observer(:progress, progress_observer)

  """
  @spec create_progress_observer() :: observer_callback()
  def create_progress_observer do
    fn
      :render_started, data ->
        put_progress(:started, data)
        :ok

      :render_progress, data ->
        put_progress(:progress, data)
        :ok

      :render_completed, data ->
        put_progress(:completed, data)
        :ok

      :render_failed, data ->
        put_progress(:failed, data)
        :ok

      _event, _data ->
        :ok
    end
  end

  @doc """
  Creates a metrics collection observer for performance monitoring.

  ## Examples

      metrics_observer = RenderObserver.create_metrics_observer()
      RenderObserver.register_observer(:metrics, metrics_observer)

  """
  @spec create_metrics_observer() :: observer_callback()
  def create_metrics_observer do
    fn
      :render_started, data ->
        record_metric(:render_start_count, 1, data)
        :ok

      :render_completed, data ->
        if duration = Map.get(data, :duration) do
          record_metric(:render_duration_ms, duration, data)
        end

        record_metric(:render_success_count, 1, data)
        :ok

      :render_failed, data ->
        record_metric(:render_failure_count, 1, data)
        :ok

      :data_loaded, data ->
        if record_count = Map.get(data, :record_count) do
          record_metric(:data_records_loaded, record_count, data)
        end

        :ok

      _event, _data ->
        :ok
    end
  end

  # Private helper functions

  defp notify_observer(observer, event, data) when is_function(observer, 2) do
    observer.(event, data)
  end

  defp notify_observer(observer, event, data) when is_atom(observer) do
    if function_exported?(observer, :handle_event, 2) do
      observer.handle_event(event, data)
    else
      :ok
    end
  end

  defp get_observers do
    Process.get(:render_observers, %{})
  end

  defp put_observers(observers) do
    Process.put(:render_observers, observers)
  end

  defp log_observer_error(observer, event, error) do
    # In a real implementation, this would use proper logging
    error_data = %{
      observer: observer,
      event: event,
      error: Exception.message(error),
      timestamp: DateTime.utc_now()
    }

    current_errors = Process.get(:observer_errors, [])
    Process.put(:observer_errors, [error_data | current_errors])
  end

  defp put_progress(status, data) do
    progress_data = %{
      status: status,
      data: data,
      timestamp: DateTime.utc_now()
    }

    Process.put(:render_progress, progress_data)
  end

  defp record_metric(metric_name, value, context) do
    metric_data = %{
      name: metric_name,
      value: value,
      context: context,
      timestamp: DateTime.utc_now()
    }

    current_metrics = Process.get(:render_metrics, [])
    Process.put(:render_metrics, [metric_data | current_metrics])
  end
end
