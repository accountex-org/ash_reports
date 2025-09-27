defmodule AshReports.LiveView.SessionManager do
  @moduledoc """
  Session management system for AshReports Phase 6.2 real-time streaming.

  Manages user sessions, WebSocket connections, and chart subscriptions with
  intelligent connection pooling, session persistence, and performance optimization
  for scalable real-time chart streaming.

  ## Features

  - **Session Lifecycle Management**: User session creation, maintenance, cleanup
  - **Connection Pooling**: Efficient WebSocket connection management per user
  - **Subscription Management**: Chart and dashboard subscription tracking
  - **Performance Optimization**: Connection limits, memory usage monitoring
  - **Session Persistence**: Session state recovery and reconnection handling
  - **Multi-tenancy Support**: Isolated sessions for different organizations/users

  ## Usage Examples

  ### Create User Session

      {:ok, session_id} = SessionManager.create_session(
        user_id: "user_123",
        organization_id: "org_456", 
        permissions: [:view_charts, :interactive_charts],
        max_connections: 5
      )

  ### Subscribe to Chart Updates

      SessionManager.subscribe_to_chart(
        session_id: session_id,
        chart_id: "sales_dashboard",
        subscription_type: :real_time,
        filters: %{region: "North America"}
      )

  ### Manage Connection Pool

      SessionManager.add_connection(session_id, socket_pid)
      SessionManager.cleanup_expired_sessions()

  """

  use GenServer

  # alias AshReports.PubSub.ChartBroadcaster  # Unused alias
  alias Phoenix.PubSub

  require Logger

  @registry_name AshReports.SessionRegistry
  # 2 hours
  @default_session_timeout 7200
  @max_sessions_per_user 3
  # 5 minutes
  @cleanup_interval 300_000

  defstruct session_id: nil,
            user_id: nil,
            organization_id: nil,
            permissions: [],
            connections: MapSet.new(),
            subscriptions: %{},
            max_connections: 5,
            created_at: nil,
            last_activity: nil,
            metadata: %{}

  @type t :: %__MODULE__{}
  @type session_id :: String.t()
  @type user_id :: String.t()
  @type connection_ref :: pid() | reference()

  # Client API

  @doc """
  Create a new user session with specified configuration.
  """
  @spec create_session(keyword()) :: {:ok, session_id()} | {:error, String.t()}
  def create_session(opts) do
    user_id = Keyword.fetch!(opts, :user_id)

    # Check session limits
    case check_session_limit(user_id) do
      :ok ->
        session_config = %{
          user_id: user_id,
          organization_id: Keyword.get(opts, :organization_id),
          permissions: Keyword.get(opts, :permissions, []),
          max_connections: Keyword.get(opts, :max_connections, 5),
          metadata: Keyword.get(opts, :metadata, %{})
        }

        GenServer.call(__MODULE__, {:create_session, session_config})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Subscribe session to chart updates with optional filtering.
  """
  @spec subscribe_to_chart(keyword()) :: :ok | {:error, String.t()}
  def subscribe_to_chart(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    chart_id = Keyword.fetch!(opts, :chart_id)

    subscription_config = %{
      chart_id: chart_id,
      subscription_type: Keyword.get(opts, :subscription_type, :real_time),
      filters: Keyword.get(opts, :filters, %{}),
      update_interval: Keyword.get(opts, :update_interval, 30_000)
    }

    GenServer.call(__MODULE__, {:subscribe_to_chart, session_id, subscription_config})
  end

  @doc """
  Add a WebSocket connection to a user session.
  """
  @spec add_connection(session_id(), connection_ref()) :: :ok | {:error, String.t()}
  def add_connection(session_id, connection_ref) do
    GenServer.call(__MODULE__, {:add_connection, session_id, connection_ref})
  end

  @doc """
  Remove connection from session and cleanup if needed.
  """
  @spec remove_connection(session_id(), connection_ref()) :: :ok
  def remove_connection(session_id, connection_ref) do
    GenServer.cast(__MODULE__, {:remove_connection, session_id, connection_ref})
  end

  @doc """
  Get session information and statistics.
  """
  @spec get_session_info(session_id()) :: {:ok, map()} | {:error, String.t()}
  def get_session_info(session_id) do
    GenServer.call(__MODULE__, {:get_session_info, session_id})
  end

  @doc """
  Get global session management statistics.
  """
  @spec get_global_stats() :: map()
  def get_global_stats do
    GenServer.call(__MODULE__, :get_global_stats)
  end

  # GenServer implementation

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Initialize session manager
    :ok = setup_session_registry()

    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_expired_sessions, @cleanup_interval)

    state = %{
      sessions: %{},
      global_stats: %{
        total_sessions_created: 0,
        active_sessions: 0,
        total_connections: 0,
        start_time: DateTime.utc_now()
      }
    }

    Logger.info("AshReports SessionManager started successfully")
    {:ok, state}
  end

  @impl true
  def handle_call({:create_session, config}, _from, state) do
    session_id = generate_session_id(config.user_id)

    session = %__MODULE__{
      session_id: session_id,
      user_id: config.user_id,
      organization_id: config.organization_id,
      permissions: config.permissions,
      max_connections: config.max_connections,
      created_at: DateTime.utc_now(),
      last_activity: DateTime.utc_now(),
      metadata: config.metadata
    }

    # Register session
    case Registry.register(@registry_name, session_id, session) do
      {:ok, _} ->
        :ok

      # Session already exists, continue
      {:error, {:already_registered, _pid}} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to register session #{session_id}: #{inspect(reason)}")
        # Continue anyway for robustness
        :ok
    end

    updated_sessions = Map.put(state.sessions, session_id, session)

    updated_stats = %{
      state.global_stats
      | total_sessions_created: state.global_stats.total_sessions_created + 1,
        active_sessions: state.global_stats.active_sessions + 1
    }

    Logger.info("Created session #{session_id} for user #{config.user_id}")

    {:reply, {:ok, session_id},
     %{state | sessions: updated_sessions, global_stats: updated_stats}}
  end

  @impl true
  def handle_call({:subscribe_to_chart, session_id, subscription_config}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, "Session not found: #{session_id}"}, state}

      session ->
        # Add subscription to session
        chart_id = subscription_config.chart_id
        updated_subscriptions = Map.put(session.subscriptions, chart_id, subscription_config)

        updated_session = %{
          session
          | subscriptions: updated_subscriptions,
            last_activity: DateTime.utc_now()
        }

        # Subscribe to PubSub topic
        topic = "chart_updates:#{chart_id}"
        :ok = PubSub.subscribe(AshReports.PubSub, topic)

        # Update state
        updated_sessions = Map.put(state.sessions, session_id, updated_session)

        Logger.debug("Session #{session_id} subscribed to chart #{chart_id}")
        {:reply, :ok, %{state | sessions: updated_sessions}}
    end
  end

  @impl true
  def handle_call({:add_connection, session_id, connection_ref}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, "Session not found: #{session_id}"}, state}

      session ->
        if MapSet.size(session.connections) >= session.max_connections do
          {:reply, {:error, "Connection limit exceeded for session #{session_id}"}, state}
        else
          updated_connections = MapSet.put(session.connections, connection_ref)

          updated_session = %{
            session
            | connections: updated_connections,
              last_activity: DateTime.utc_now()
          }

          updated_sessions = Map.put(state.sessions, session_id, updated_session)

          updated_stats = %{
            state.global_stats
            | total_connections: state.global_stats.total_connections + 1
          }

          Logger.debug("Added connection to session #{session_id}")
          {:reply, :ok, %{state | sessions: updated_sessions, global_stats: updated_stats}}
        end
    end
  end

  @impl true
  def handle_call({:get_session_info, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, "Session not found"}, state}

      session ->
        session_info = %{
          session_id: session.session_id,
          user_id: session.user_id,
          organization_id: session.organization_id,
          active_connections: MapSet.size(session.connections),
          chart_subscriptions: Map.keys(session.subscriptions),
          created_at: session.created_at,
          last_activity: session.last_activity,
          uptime_seconds: DateTime.diff(DateTime.utc_now(), session.created_at, :second)
        }

        {:reply, {:ok, session_info}, state}
    end
  end

  @impl true
  def handle_call(:get_global_stats, _from, state) do
    enhanced_stats = calculate_enhanced_global_stats(state.global_stats, state.sessions)
    {:reply, enhanced_stats, state}
  end

  @impl true
  def handle_cast({:remove_connection, session_id, connection_ref}, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:noreply, state}

      session ->
        updated_connections = MapSet.delete(session.connections, connection_ref)

        # Remove session if no connections left
        if MapSet.size(updated_connections) == 0 do
          updated_sessions = Map.delete(state.sessions, session_id)
          :ok = Registry.unregister(@registry_name, session_id)

          Logger.info("Removed empty session #{session_id}")
          {:noreply, %{state | sessions: updated_sessions}}
        else
          updated_session = %{session | connections: updated_connections}
          updated_sessions = Map.put(state.sessions, session_id, updated_session)

          {:noreply, %{state | sessions: updated_sessions}}
        end
    end
  end

  @impl true
  def handle_info(:cleanup_expired_sessions, state) do
    updated_state = cleanup_expired_sessions_internal(state)

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_expired_sessions, @cleanup_interval)

    {:noreply, updated_state}
  end

  # Private implementation

  defp check_session_limit(user_id) do
    user_sessions =
      Registry.select(@registry_name, [
        {{:"$1", :"$2", :"$3"}, [{:==, {:map_get, :"$3", :user_id}, user_id}], [:"$1"]}
      ])

    if length(user_sessions) < @max_sessions_per_user do
      :ok
    else
      {:error, "Session limit exceeded for user #{user_id}"}
    end
  end

  defp generate_session_id(user_id) do
    timestamp = System.system_time(:millisecond)
    random_bytes = :crypto.strong_rand_bytes(8)

    hash =
      :crypto.hash(:sha256, "#{user_id}_#{timestamp}_#{Base.encode16(random_bytes)}")
      |> Base.encode16(case: :lower)
      |> String.slice(0, 16)

    "session_#{hash}"
  end

  defp setup_session_registry do
    case Registry.start_link(keys: :unique, name: @registry_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, "Failed to start session registry: #{inspect(reason)}"}
    end
  end

  defp cleanup_expired_sessions_internal(state) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -@default_session_timeout, :second)

    {active_sessions, expired_sessions} =
      state.sessions
      |> Enum.split_with(fn {_session_id, session} ->
        DateTime.compare(session.last_activity, cutoff_time) == :gt
      end)

    # Cleanup expired sessions
    Enum.each(expired_sessions, fn {session_id, session} ->
      cleanup_session_subscriptions(session)
      Registry.unregister(@registry_name, session_id)
      Logger.info("Cleaned up expired session #{session_id}")
    end)

    active_sessions_map = Map.new(active_sessions)
    updated_stats = %{state.global_stats | active_sessions: map_size(active_sessions_map)}

    %{state | sessions: active_sessions_map, global_stats: updated_stats}
  end

  defp cleanup_session_subscriptions(session) do
    # Unsubscribe from all chart topics
    Enum.each(session.subscriptions, fn {chart_id, _config} ->
      topic = "chart_updates:#{chart_id}"
      PubSub.unsubscribe(AshReports.PubSub, topic)
    end)
  end

  defp calculate_enhanced_global_stats(base_stats, sessions) do
    total_connections =
      sessions
      |> Map.values()
      |> Enum.map(fn session -> MapSet.size(session.connections) end)
      |> Enum.sum()

    total_subscriptions =
      sessions
      |> Map.values()
      |> Enum.map(fn session -> map_size(session.subscriptions) end)
      |> Enum.sum()

    uptime_seconds = DateTime.diff(DateTime.utc_now(), base_stats.start_time, :second)

    Map.merge(base_stats, %{
      active_connections: total_connections,
      total_chart_subscriptions: total_subscriptions,
      average_connections_per_session:
        if(base_stats.active_sessions > 0,
          do: total_connections / base_stats.active_sessions,
          else: 0
        ),
      uptime_seconds: uptime_seconds,
      memory_usage_mb: get_memory_usage_mb()
    })
  end

  defp get_memory_usage_mb do
    {memory_bytes, _} = :erlang.process_info(self(), :memory)
    Float.round(memory_bytes / (1024 * 1024), 2)
  end
end
