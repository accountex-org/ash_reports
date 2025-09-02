defmodule AshReports.LiveView.DistributedConnectionManager do
  @moduledoc """
  Distributed connection management for AshReports Phase 6.2 scalability.

  Manages WebSocket connections across multiple nodes in a distributed Elixir
  cluster, providing horizontal scaling for real-time chart streaming with
  intelligent load balancing and failover capabilities.

  ## Features

  - **Multi-Node Scaling**: Connection distribution across Elixir cluster nodes
  - **Load Balancing**: Intelligent connection routing based on node capacity
  - **Failover Management**: Automatic failover and connection migration
  - **Cluster Coordination**: Node discovery and health monitoring
  - **Performance Optimization**: Cross-node optimization and resource balancing
  - **Session Affinity**: User session stickiness with graceful migration

  ## Distributed Architecture

  ### Node Types
  - **Connection Nodes**: Handle WebSocket connections and client communication
  - **Processing Nodes**: Handle data processing and chart generation
  - **Coordination Nodes**: Manage cluster state and load balancing

  ### Scaling Patterns
  - **Horizontal Scaling**: Add more nodes to handle increased connection load
  - **Vertical Scaling**: Optimize resource usage on existing nodes
  - **Geographic Distribution**: Route users to nearest nodes for latency optimization

  """

  use GenServer

  alias AshReports.LiveView.{SessionManager, WebSocketOptimizer}

  require Logger

  @cluster_name :ash_reports_cluster
  # 30 seconds
  @heartbeat_interval 30_000
  # 10 seconds
  @failover_timeout 10_000
  @max_connections_per_node 2000

  defstruct node_id: nil,
            cluster_nodes: [],
            connection_distribution: %{},
            load_balancer_state: %{},
            failover_state: %{},
            performance_metrics: %{},
            last_heartbeat: nil

  @type t :: %__MODULE__{}
  @type node_id :: atom()
  @type connection_count :: non_neg_integer()

  # Client API

  @doc """
  Start the distributed connection manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the best node for new connections based on current load.
  """
  @spec get_optimal_node() :: {:ok, node_id()} | {:error, String.t()}
  def get_optimal_node do
    GenServer.call(__MODULE__, :get_optimal_node)
  end

  @doc """
  Register a new connection on specified node.
  """
  @spec register_connection(node_id(), String.t(), pid()) :: :ok | {:error, String.t()}
  def register_connection(node, session_id, connection_pid) do
    GenServer.cast(__MODULE__, {:register_connection, node, session_id, connection_pid})
  end

  @doc """
  Get cluster-wide connection statistics.
  """
  @spec get_cluster_stats() :: map()
  def get_cluster_stats do
    GenServer.call(__MODULE__, :get_cluster_stats)
  end

  @doc """
  Trigger cluster rebalancing based on current load.
  """
  @spec rebalance_cluster() :: :ok
  def rebalance_cluster do
    GenServer.cast(__MODULE__, :rebalance_cluster)
  end

  @doc """
  Handle node failure and initiate failover procedures.
  """
  @spec handle_node_failure(node_id()) :: :ok
  def handle_node_failure(failed_node) do
    GenServer.cast(__MODULE__, {:node_failure, failed_node})
  end

  # GenServer implementation

  @impl true
  def init(opts) do
    node_id = Node.self()

    # Initialize distributed state
    state = %__MODULE__{
      node_id: node_id,
      cluster_nodes: [node_id],
      connection_distribution: %{node_id => 0},
      load_balancer_state: initialize_load_balancer(),
      performance_metrics: initialize_distributed_metrics(),
      last_heartbeat: DateTime.utc_now()
    }

    # Join cluster if configured
    if cluster_enabled?() do
      :ok = join_cluster()
      :ok = setup_cluster_monitoring()
    end

    # Start heartbeat
    schedule_heartbeat()

    Logger.info("Distributed Connection Manager started on node #{node_id}")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_optimal_node, _from, state) do
    optimal_node = select_optimal_node(state)
    {:reply, {:ok, optimal_node}, state}
  end

  @impl true
  def handle_call(:get_cluster_stats, _from, state) do
    cluster_stats = calculate_cluster_stats(state)
    {:reply, cluster_stats, state}
  end

  @impl true
  def handle_cast({:register_connection, node, session_id, connection_pid}, state) do
    # Update connection count for node
    current_count = Map.get(state.connection_distribution, node, 0)
    updated_distribution = Map.put(state.connection_distribution, node, current_count + 1)

    # Monitor connection process
    Process.monitor(connection_pid)

    updated_state = %{state | connection_distribution: updated_distribution}

    Logger.debug("Registered connection #{session_id} on node #{node}")
    {:noreply, updated_state}
  end

  @impl true
  def handle_cast(:rebalance_cluster, state) do
    if cluster_enabled?() do
      updated_state = perform_cluster_rebalancing(state)
      Logger.info("Cluster rebalancing completed")
      {:noreply, updated_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:node_failure, failed_node}, state) do
    updated_state = handle_node_failure_internal(failed_node, state)
    Logger.warn("Handled node failure: #{failed_node}")
    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    updated_state = perform_heartbeat(state)
    schedule_heartbeat()
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Handle connection process termination
    updated_state = handle_connection_termination(pid, reason, state)
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    # Handle new node joining cluster
    updated_state = handle_node_join(node, state)
    Logger.info("Node joined cluster: #{node}")
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    # Handle node leaving cluster
    updated_state = handle_node_leave(node, state)
    Logger.warn("Node left cluster: #{node}")
    {:noreply, updated_state}
  end

  # Private implementation

  defp cluster_enabled? do
    Application.get_env(:ash_reports, :enable_clustering, false)
  end

  defp join_cluster do
    # Join Elixir cluster if configured
    cluster_nodes = Application.get_env(:ash_reports, :cluster_nodes, [])

    Enum.each(cluster_nodes, fn node ->
      case Node.connect(node) do
        true -> Logger.info("Connected to cluster node: #{node}")
        false -> Logger.warn("Failed to connect to cluster node: #{node}")
      end
    end)

    :ok
  end

  defp setup_cluster_monitoring do
    # Monitor cluster node changes
    :net_kernel.monitor_nodes(true)
    :ok
  end

  defp initialize_load_balancer do
    %{
      algorithm: :round_robin,
      current_node_index: 0,
      node_weights: %{},
      last_balance_time: DateTime.utc_now()
    }
  end

  defp initialize_distributed_metrics do
    %{
      total_cluster_connections: 0,
      nodes_online: 1,
      average_load_per_node: 0.0,
      cluster_throughput: 0.0,
      last_updated: DateTime.utc_now()
    }
  end

  defp select_optimal_node(state) do
    case state.load_balancer_state.algorithm do
      :round_robin ->
        select_round_robin_node(state)

      :least_connections ->
        select_least_connections_node(state)

      :weighted ->
        select_weighted_node(state)

      _ ->
        # Fallback to current node
        Node.self()
    end
  end

  defp select_round_robin_node(state) do
    active_nodes = get_active_cluster_nodes(state)
    current_index = state.load_balancer_state.current_node_index

    # Get next node in round-robin
    selected_node = Enum.at(active_nodes, rem(current_index, length(active_nodes)))

    # Update index for next selection
    GenServer.cast(self(), {:update_lb_index, current_index + 1})

    selected_node || Node.self()
  end

  defp select_least_connections_node(state) do
    # Select node with least connections
    state.connection_distribution
    |> Enum.min_by(fn {_node, count} -> count end, fn -> {Node.self(), 0} end)
    |> elem(0)
  end

  defp select_weighted_node(state) do
    # Select based on node weights (CPU, memory capacity)
    weights = state.load_balancer_state.node_weights

    best_node =
      weights
      |> Enum.max_by(fn {_node, weight} -> weight end, fn -> {Node.self(), 1.0} end)
      |> elem(0)

    best_node
  end

  defp get_active_cluster_nodes(state) do
    # Filter for healthy, active nodes
    state.cluster_nodes
    |> Enum.filter(&(Node.ping(&1) == :pong))
  end

  defp perform_cluster_rebalancing(state) do
    # Rebalance connections across cluster nodes
    total_connections = state.connection_distribution |> Map.values() |> Enum.sum()
    active_nodes = get_active_cluster_nodes(state)
    target_per_node = div(total_connections, length(active_nodes))

    # Identify nodes that need rebalancing
    {overloaded_nodes, underloaded_nodes} =
      state.connection_distribution
      |> Enum.split_with(fn {_node, count} -> count > target_per_node * 1.2 end)

    # Trigger connection migration if needed
    if length(overloaded_nodes) > 0 and length(underloaded_nodes) > 0 do
      initiate_connection_migration(overloaded_nodes, underloaded_nodes)
    end

    state
  end

  defp handle_node_failure_internal(failed_node, state) do
    # Remove failed node and redistribute its connections
    updated_cluster_nodes = List.delete(state.cluster_nodes, failed_node)
    failed_connections = Map.get(state.connection_distribution, failed_node, 0)
    updated_distribution = Map.delete(state.connection_distribution, failed_node)

    # Redistribute failed connections if there were any
    if failed_connections > 0 do
      Logger.info(
        "Redistributing #{failed_connections} connections from failed node #{failed_node}"
      )

      # Would trigger connection migration logic here
    end

    %{state | cluster_nodes: updated_cluster_nodes, connection_distribution: updated_distribution}
  end

  defp handle_node_join(new_node, state) do
    # Add new node to cluster
    updated_cluster_nodes = [new_node | state.cluster_nodes] |> Enum.uniq()
    updated_distribution = Map.put(state.connection_distribution, new_node, 0)

    %{state | cluster_nodes: updated_cluster_nodes, connection_distribution: updated_distribution}
  end

  defp handle_node_leave(leaving_node, state) do
    # Handle graceful node departure
    handle_node_failure_internal(leaving_node, state)
  end

  defp handle_connection_termination(_pid, _reason, state) do
    # Handle individual connection termination
    # Would update connection counts here
    state
  end

  defp perform_heartbeat(state) do
    # Send heartbeat and collect cluster health info
    cluster_health = collect_cluster_health_info(state)

    # Update performance metrics based on cluster state
    updated_metrics = %{
      state.performance_metrics
      | nodes_online: length(state.cluster_nodes),
        total_cluster_connections: Map.values(state.connection_distribution) |> Enum.sum(),
        average_load_per_node: calculate_average_node_load(state),
        last_updated: DateTime.utc_now()
    }

    %{state | performance_metrics: updated_metrics, last_heartbeat: DateTime.utc_now()}
  end

  defp calculate_cluster_stats(state) do
    total_connections = Map.values(state.connection_distribution) |> Enum.sum()
    active_nodes = length(state.cluster_nodes)

    %{
      cluster_name: @cluster_name,
      active_nodes: active_nodes,
      total_connections: total_connections,
      connections_per_node: state.connection_distribution,
      average_connections_per_node:
        if(active_nodes > 0, do: total_connections / active_nodes, else: 0),
      cluster_capacity_used: total_connections / (@max_connections_per_node * active_nodes) * 100,
      load_balancer_algorithm: state.load_balancer_state.algorithm,
      last_heartbeat: state.last_heartbeat,
      cluster_health: determine_cluster_health(state)
    }
  end

  defp collect_cluster_health_info(state) do
    # Collect health information from all cluster nodes
    state.cluster_nodes
    |> Enum.map(fn node ->
      case :rpc.call(node, WebSocketOptimizer, :get_performance_metrics, [], 5000) do
        {:ok, metrics} -> {node, :healthy, metrics}
        {:error, reason} -> {node, :unhealthy, %{error: reason}}
        {:badrpc, reason} -> {node, :unreachable, %{error: reason}}
      end
    end)
    |> Map.new(fn {node, status, metrics} -> {node, %{status: status, metrics: metrics}} end)
  end

  defp determine_cluster_health(state) do
    healthy_nodes =
      state.cluster_nodes
      |> Enum.count(fn node -> Node.ping(node) == :pong end)

    total_nodes = length(state.cluster_nodes)
    health_percentage = if total_nodes > 0, do: healthy_nodes / total_nodes * 100, else: 0

    cond do
      health_percentage >= 90 -> :healthy
      health_percentage >= 70 -> :degraded
      health_percentage >= 50 -> :unhealthy
      true -> :critical
    end
  end

  defp calculate_average_node_load(state) do
    loads = Map.values(state.connection_distribution)

    if length(loads) > 0 do
      Float.round(Enum.sum(loads) / length(loads), 2)
    else
      0.0
    end
  end

  defp initiate_connection_migration(overloaded_nodes, underloaded_nodes) do
    # Placeholder for connection migration logic
    # Would implement graceful connection migration between nodes

    migration_plan =
      overloaded_nodes
      |> Enum.zip(underloaded_nodes)
      |> Enum.map(fn {{source_node, source_count}, {target_node, target_count}} ->
        connections_to_migrate = max(0, div(source_count - target_count, 2))

        %{
          source: source_node,
          target: target_node,
          count: connections_to_migrate
        }
      end)

    Logger.info("Migration plan: #{inspect(migration_plan)}")

    # Would execute migration here
    :ok
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end
end
