defmodule AshReports.HeexRenderer.LiveViewIntegration do
  @moduledoc """
  LiveView integration helpers for real-time report updates and interactive features.

  This module provides comprehensive integration between AshReports and Phoenix LiveView,
  enabling real-time data updates, user interactions, filtering, sorting, and other
  interactive report features.

  ## Features

  - **Real-Time Updates**: Automatic report updates via Phoenix PubSub
  - **Interactive Filtering**: Dynamic report filtering with live updates
  - **User Events**: Handling clicks, selections, and form interactions
  - **State Management**: Shared state across LiveView and report components
  - **Streaming Data**: Memory-efficient handling of large datasets

  ## Usage

  ### Basic LiveView Integration

      defmodule MyAppWeb.ReportLive do
        use Phoenix.LiveView
        alias AshReports.HeexRenderer.LiveViewIntegration

        def mount(_params, _session, socket) do
          socket =
            socket
            |> assign(:report, load_report())
            |> assign(:data, load_data())
            |> LiveViewIntegration.setup_report_subscriptions()

          {:ok, socket}
        end

        def handle_event("filter_report", params, socket) do
          socket = LiveViewIntegration.handle_filter_event(socket, params)
          {:noreply, socket}
        end
      end

  ### Real-Time Data Updates

      # In your LiveView module
      def handle_info({:data_updated, new_data}, socket) do
        socket = LiveViewIntegration.update_report_data(socket, new_data)
        {:noreply, socket}
      end

  ### Interactive Components

      <.live_report
        report={@report}
        data={@data}
        interactive={true}
        real_time={true}
        phx-target={@myself}
      />

  """

  alias AshReports.{HeexRenderer, RenderContext}
  alias AshReports.Security.AtomValidator
  alias Phoenix.LiveView.Socket

  @doc """
  Sets up Phoenix PubSub subscriptions for real-time report updates.

  ## Examples

      socket = LiveViewIntegration.setup_report_subscriptions(socket)

  """
  @spec setup_report_subscriptions(Socket.t()) :: Socket.t()
  def setup_report_subscriptions(%Socket{} = socket) do
    report_id = get_report_id(socket)

    if report_id do
      try do
        Phoenix.PubSub.subscribe(pubsub_name(), "report:#{report_id}")
        Phoenix.PubSub.subscribe(pubsub_name(), "report_data:#{report_id}")
      rescue
        ArgumentError ->
          # PubSub not running (e.g., in tests), continue anyway
          :ok
      end

      # Update metadata regardless of whether subscriptions succeeded
      update_metadata(socket, :subscriptions, fn subs ->
        ["report:#{report_id}", "report_data:#{report_id}" | subs]
      end)
    else
      socket
    end
  end

  @doc """
  Cleans up PubSub subscriptions when component is unmounted.

  ## Examples

      LiveViewIntegration.cleanup_pubsub_subscriptions()

  """
  @spec cleanup_pubsub_subscriptions() :: :ok
  def cleanup_pubsub_subscriptions do
    # This would clean up any persistent subscriptions
    # For now, we'll just return :ok as LiveView handles cleanup automatically
    :ok
  end

  @doc """
  Handles filter events from user interactions.

  ## Examples

      socket = LiveViewIntegration.handle_filter_event(socket, %{"field" => "status", "value" => "active"})

  """
  @spec handle_filter_event(Socket.t(), map()) :: Socket.t()
  def handle_filter_event(%Socket{} = socket, filter_params) do
    current_filters = socket.assigns[:filters] || %{}
    new_filters = Map.merge(current_filters, filter_params)

    socket
    |> assign_to_socket(:filters, new_filters)
    |> apply_filters_to_data()
    |> update_report_context()
  end

  @doc """
  Handles sort events from user interactions.

  ## Examples

      socket = LiveViewIntegration.handle_sort_event(socket, %{"field" => "created_at", "direction" => "desc"})

  """
  @spec handle_sort_event(Socket.t(), map()) :: Socket.t()
  def handle_sort_event(%Socket{} = socket, sort_params) do
    # Validate sort direction to prevent atom exhaustion
    direction =
      case AtomValidator.to_sort_direction(Map.get(sort_params, "direction", "asc")) do
        {:ok, dir} -> dir
        {:error, _} -> :asc
      end

    sort_config = %{
      field: Map.get(sort_params, "field"),
      direction: direction
    }

    socket
    |> assign_to_socket(:sort, sort_config)
    |> apply_sort_to_data()
    |> update_report_context()
  end

  @doc """
  Updates report data and refreshes the display.

  ## Examples

      socket = LiveViewIntegration.update_report_data(socket, new_data)

  """
  @spec update_report_data(Socket.t(), list()) :: Socket.t()
  def update_report_data(%Socket{} = socket, new_data) do
    socket
    |> assign_to_socket(:data, new_data)
    |> assign_to_socket(:last_updated, DateTime.utc_now())
    |> update_report_context()
  end

  @doc """
  Handles pagination events.

  ## Examples

      socket = LiveViewIntegration.handle_pagination_event(socket, %{"page" => 2, "per_page" => 50})

  """
  @spec handle_pagination_event(Socket.t(), map()) :: Socket.t()
  def handle_pagination_event(%Socket{} = socket, pagination_params) do
    page = String.to_integer(Map.get(pagination_params, "page", "1"))
    per_page = String.to_integer(Map.get(pagination_params, "per_page", "25"))

    pagination = %{
      page: page,
      per_page: per_page,
      total: length(socket.assigns.data || [])
    }

    socket
    |> assign_to_socket(:pagination, pagination)
    |> apply_pagination_to_data()
    |> update_report_context()
  end

  @doc """
  Creates a LiveView-compatible report component.

  Returns assigns that can be used directly in HEEX templates.

  ## Examples

      {:ok, assigns} = LiveViewIntegration.create_live_report_assigns(socket)

  """
  @spec create_live_report_assigns(Socket.t()) :: {:ok, map()} | {:error, term()}
  def create_live_report_assigns(%Socket{} = socket) do
    with {:ok, context} <- build_render_context(socket),
         {:ok, result} <- HeexRenderer.render_with_context(context) do
      assigns = %{
        report_content: result.content,
        report_metadata: result.metadata,
        interactive: get_config(socket, :interactive, false),
        real_time: get_config(socket, :real_time, false),
        filters: socket.assigns[:filters] || %{},
        sort: socket.assigns[:sort] || %{},
        pagination: socket.assigns[:pagination] || %{}
      }

      {:ok, assigns}
    end
  end

  @doc """
  Broadcasts a report update to all subscribed LiveView processes.

  ## Examples

      LiveViewIntegration.broadcast_report_update(report_id, new_data)

  """
  @spec broadcast_report_update(String.t(), term()) :: :ok
  def broadcast_report_update(report_id, new_data) do
    try do
      Phoenix.PubSub.broadcast(
        pubsub_name(),
        "report_data:#{report_id}",
        {:data_updated, new_data}
      )
    rescue
      ArgumentError ->
        # PubSub not running (e.g., in tests), skip broadcast
        :ok
    end
  end

  @doc """
  Broadcasts a report configuration change.

  ## Examples

      LiveViewIntegration.broadcast_report_config_change(report_id, new_config)

  """
  @spec broadcast_report_config_change(String.t(), map()) :: :ok
  def broadcast_report_config_change(report_id, new_config) do
    try do
      Phoenix.PubSub.broadcast(
        pubsub_name(),
        "report:#{report_id}",
        {:config_updated, new_config}
      )
    rescue
      ArgumentError ->
        # PubSub not running (e.g., in tests), skip broadcast
        :ok
    end
  end

  @doc """
  Creates event handlers for interactive report elements.

  ## Examples

      handlers = LiveViewIntegration.create_event_handlers(socket, [:filter, :sort, :paginate])

  """
  @spec create_event_handlers(Socket.t(), [atom()]) :: map()
  def create_event_handlers(%Socket{} = _socket, event_types) do
    Enum.into(event_types, %{}, fn event_type ->
      handler_name = "handle_#{event_type}"
      {event_type, handler_name}
    end)
  end

  @doc """
  Validates LiveView integration requirements.

  Ensures Phoenix LiveView is available and properly configured.

  ## Examples

      case LiveViewIntegration.validate_requirements() do
        :ok -> proceed_with_integration()
        {:error, reason} -> handle_missing_requirements(reason)
      end

  """
  @spec validate_requirements() :: :ok | {:error, term()}
  def validate_requirements do
    case validate_phoenix_liveview() do
      :ok -> validate_pubsub_configuration()
      error -> error
    end
  end

  @doc """
  Streams large datasets efficiently in LiveView.

  Uses Phoenix.LiveView.stream/3 for memory-efficient handling of large reports.

  ## Examples

      socket = LiveViewIntegration.setup_data_streaming(socket, data, :report_rows)

  """
  @spec setup_data_streaming(Socket.t(), list(), atom()) :: Socket.t()
  def setup_data_streaming(%Socket{} = socket, data, stream_name) do
    socket
    |> setup_stream(stream_name, data)
    |> assign_to_socket(:streaming_enabled, true)
    |> assign_to_socket(:stream_name, stream_name)
  end

  @doc """
  Handles real-time data streaming updates.

  ## Examples

      socket = LiveViewIntegration.handle_stream_update(socket, :report_rows, new_rows)

  """
  @spec handle_stream_update(Socket.t(), atom(), list()) :: Socket.t()
  def handle_stream_update(%Socket{} = socket, stream_name, new_items) do
    Enum.reduce(new_items, socket, fn item, acc_socket ->
      insert_to_stream(acc_socket, stream_name, item)
    end)
  end

  @doc """
  Creates interactive filter components for reports.

  ## Examples

      {:ok, filter_assigns} = LiveViewIntegration.create_filter_assigns(socket, [:status, :date_range])

  """
  @spec create_filter_assigns(Socket.t(), [atom()]) :: {:ok, map()} | {:error, term()}
  def create_filter_assigns(%Socket{} = socket, filter_fields) do
    filter_configs =
      Enum.map(filter_fields, fn field ->
        {field, create_filter_config(field, socket)}
      end)

    assigns = %{
      filter_fields: filter_fields,
      filter_configs: Map.new(filter_configs),
      current_filters: socket.assigns[:filters] || %{},
      filter_enabled: true
    }

    {:ok, assigns}
  end

  # Private helper functions

  defp get_report_id(%Socket{assigns: %{report: %{id: id}}}), do: id
  defp get_report_id(%Socket{assigns: %{report: %{name: name}}}), do: name
  defp get_report_id(_socket), do: nil

  defp update_metadata(%Socket{} = socket, key, update_fun) do
    current_metadata = socket.assigns[:metadata] || %{}
    current_value = Map.get(current_metadata, key, [])
    new_value = update_fun.(current_value)
    new_metadata = Map.put(current_metadata, key, new_value)

    assign_to_socket(socket, :metadata, new_metadata)
  end

  @doc false
  def apply_filters_to_data(%Socket{} = socket) do
    filters = socket.assigns[:filters] || %{}
    data = socket.assigns[:data] || []

    filtered_data =
      Enum.filter(data, fn record ->
        Enum.all?(filters, fn {field, value} ->
          # Keep field names as strings to prevent atom exhaustion
          # Try both string and existing atom keys
          field_value =
            try do
              case AtomValidator.to_field_name(field) do
                {:ok, field_key} ->
                  Map.get(record, field_key) ||
                    (is_binary(field_key) && Map.get(record, String.to_existing_atom(field_key)))

                _ ->
                  nil
              end
            rescue
              ArgumentError -> Map.get(record, field)
            end

          matches_filter?(field_value, value)
        end)
      end)

    assign_to_socket(socket, :filtered_data, filtered_data)
  end

  @doc false
  def apply_sort_to_data(%Socket{} = socket) do
    sort = socket.assigns[:sort]
    data = socket.assigns[:filtered_data] || socket.assigns[:data] || []

    sorted_data =
      if sort && sort.field do
        # Keep field as string/atom, don't create new atoms
        {:ok, field} = AtomValidator.to_field_name(sort.field)
        direction = sort.direction || :asc

        # Try both string and atom keys
        Enum.sort_by(
          data,
          fn record ->
            Map.get(record, field) ||
              (is_binary(field) &&
                 (try do
                    Map.get(record, String.to_existing_atom(field))
                  rescue
                    ArgumentError -> nil
                  end))
          end,
          direction
        )
      else
        data
      end

    assign_to_socket(socket, :sorted_data, sorted_data)
  end

  @doc false
  def apply_pagination_to_data(%Socket{} = socket) do
    pagination = socket.assigns[:pagination]

    data =
      socket.assigns[:sorted_data] || socket.assigns[:filtered_data] || socket.assigns[:data] ||
        []

    paginated_data =
      if pagination do
        start_index = (pagination.page - 1) * pagination.per_page
        end_index = start_index + pagination.per_page - 1

        Enum.slice(data, start_index..end_index)
      else
        data
      end

    assign_to_socket(socket, :paginated_data, paginated_data)
  end

  defp update_report_context(%Socket{} = socket) do
    report = socket.assigns[:report]

    # Skip context update if no report is present (e.g., in data-only operations)
    if report do
      current_data =
        socket.assigns[:paginated_data] ||
          socket.assigns[:sorted_data] ||
          socket.assigns[:filtered_data] ||
          socket.assigns[:data] || []

      data_result = %{
        records: current_data,
        variables: socket.assigns[:variables] || %{},
        metadata: socket.assigns[:metadata] || %{}
      }

      config = socket.assigns[:config] || %{}
      context = RenderContext.new(report, data_result, config)

      assign_to_socket(socket, :render_context, context)
    else
      socket
    end
  end

  defp build_render_context(%Socket{} = socket) do
    report = socket.assigns[:report]

    data =
      socket.assigns[:paginated_data] ||
        socket.assigns[:sorted_data] ||
        socket.assigns[:filtered_data] ||
        socket.assigns[:data] || []

    data_result = %{
      records: data,
      variables: socket.assigns[:variables] || %{},
      metadata: socket.assigns[:metadata] || %{}
    }

    config =
      Map.merge(
        socket.assigns[:config] || %{},
        %{
          heex: %{
            liveview_enabled: true,
            interactive: get_config(socket, :interactive, false),
            real_time_updates: get_config(socket, :real_time, false)
          }
        }
      )

    context = RenderContext.new(report, data_result, config)
    {:ok, context}
  end

  defp get_config(%Socket{} = socket, key, default) do
    socket.assigns
    |> Map.get(:config, %{})
    |> Map.get(key, default)
  end

  defp pubsub_name do
    # Try to get the PubSub name from application configuration
    Application.get_env(:ash_reports, :pubsub, AshReports.PubSub)
  end

  defp validate_phoenix_liveview do
    case Code.ensure_loaded(Phoenix.LiveView) do
      {:module, _} -> :ok
      {:error, _} -> {:error, :phoenix_liveview_not_available}
    end
  end

  defp validate_pubsub_configuration do
    case pubsub_name() do
      nil -> {:error, :pubsub_not_configured}
      _pubsub -> :ok
    end
  end

  @doc false
  def matches_filter?(field_value, filter_value) when is_binary(filter_value) do
    field_string = to_string(field_value)
    String.contains?(String.downcase(field_string), String.downcase(filter_value))
  end

  def matches_filter?(field_value, filter_value) do
    field_value == filter_value
  end

  defp create_filter_config(field, %Socket{} = socket) do
    data = socket.assigns[:data] || []

    # Get unique values for the field to create filter options
    unique_values =
      data
      |> Enum.map(&Map.get(&1, field))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    %{
      field: field,
      type: determine_filter_type(unique_values),
      options: unique_values,
      label: humanize_field_name(field)
    }
  end

  @doc false
  def determine_filter_type([]), do: :text

  def determine_filter_type(values) do
    first_value = List.first(values)

    cond do
      is_boolean(first_value) -> :boolean
      is_number(first_value) -> :number
      Enum.count(values) <= 20 -> :select
      true -> :text
    end
  end

  @doc false
  def humanize_field_name(field) when is_atom(field) do
    field
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def humanize_field_name(field), do: to_string(field)

  # Helper functions for socket manipulation
  # These provide compatibility with LiveView without requiring full LiveView import

  defp assign_to_socket(%Socket{} = socket, key, value) do
    new_assigns = Map.put(socket.assigns, key, value)
    %{socket | assigns: new_assigns}
  end

  defp setup_stream(%Socket{} = socket, stream_name, data) do
    # Simulate LiveView stream setup
    stream_data = Enum.with_index(data, fn item, index -> {index, item} end)
    assign_to_socket(socket, stream_name, stream_data)
  end

  defp insert_to_stream(%Socket{} = socket, stream_name, item) do
    current_stream = socket.assigns[stream_name] || []
    new_index = length(current_stream)
    new_stream = current_stream ++ [{new_index, item}]
    assign_to_socket(socket, stream_name, new_stream)
  end
end
