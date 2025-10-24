# Stage 2 - Section 2.1: GenStage Infrastructure Setup

**Feature**: Section 2.1 of Stage 2 - GenStage Streaming Pipeline for Large Datasets
**Status**: 📋 Planned
**Priority**: High (Foundation for memory-efficient large dataset processing)
**Dependencies**:
  - Stage 1 Section 1.1 (Typst Runtime) ✅ COMPLETED
  - Stage 1 Section 1.2 (DSL Generator) ✅ COMPLETED
  - Stage 1 Section 1.3 (Data Integration) ✅ COMPLETED
**Target Completion**: 1-2 weeks
**Branch**: `feature/genstage-infrastructure`

---

## 📋 Executive Summary

Section 2.1 implements the foundational GenStage infrastructure that enables memory-efficient streaming of large datasets (10K+ records) for both full report generation and D3 chart data aggregation. This infrastructure serves as the critical bottleneck solution for processing massive datasets while maintaining constant memory usage.

### Problem Statement

The current implementation in `AshReports.Typst.DataLoader` has a placeholder for streaming functionality:

```elixir
defp create_streaming_pipeline(_domain, _report, _params, _opts) do
  # Implementation will be added in streaming pipeline task
  {:error, :streaming_not_implemented}
end
```

This limits AshReports to in-memory processing, which becomes problematic for:
- Reports with 100K+ records (memory exhaustion)
- D3 chart data aggregation from 1M+ records down to 500 chart points
- Real-time streaming updates with incremental data loading
- Concurrent multi-user report generation scenarios

### Solution Overview

Implement a production-grade GenStage infrastructure with:
- **Producer-Consumer Architecture**: Demand-driven query execution with backpressure
- **Dynamic Supervision**: Concurrent stream management with health monitoring
- **Stream Registry**: Track and manage active pipelines
- **Resource Management**: Memory limits, circuit breakers, graceful degradation

### Key Benefits

- **Constant Memory Usage**: Process unlimited records with <1.5x baseline memory
- **Horizontal Scalability**: Linear scaling with multiple CPU cores
- **High Throughput**: Target 1000+ records/second on standard hardware
- **Production Ready**: Health monitoring, restart strategies, telemetry

---

## 🎯 Architecture Design

### System Context

The GenStage infrastructure fits into the larger AshReports architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                    AshReports Application                        │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │            AshReports.Supervisor                            │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │      Existing Components                              │  │ │
│  │  │  • PdfSessionManager                                  │  │ │
│  │  │  • TempFileCleanup                                    │  │ │
│  │  │  • ChromicPDF (conditional)                           │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │      NEW: StreamingSupervisor                         │  │ │
│  │  │  ┌────────────────────────────────────────────────┐  │  │ │
│  │  │  │  StreamingPipeline.Supervisor                  │  │  │ │
│  │  │  │    • StreamRegistry (ETS)                      │  │  │ │
│  │  │  │    • HealthMonitor (GenServer)                 │  │  │ │
│  │  │  │    • PipelineSupervisor (DynamicSupervisor)    │  │  │ │
│  │  │  └────────────────────────────────────────────────┘  │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Producer-Consumer Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                  Streaming Pipeline Flow                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Client Request                                                   │
│       ↓                                                           │
│  DataLoader.stream_for_typst/4                                   │
│       ↓                                                           │
│  StreamingPipeline.start_pipeline/3                              │
│       ↓                                                           │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Producer Stage                                          │    │
│  │  • Query Ash resources in chunks (500-1000 records)     │    │
│  │  • Handle demand from consumers                         │    │
│  │  • Implement backpressure                               │    │
│  │  • Manage query pagination                              │    │
│  └─────────────────────────────────────────────────────────┘    │
│       ↓ (events: chunks of Ash structs)                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  ProducerConsumer Stage                                  │    │
│  │  • Convert Ash structs to Typst format                   │    │
│  │  • Apply type conversions (DataProcessor)                │    │
│  │  • Calculate variables and groups                        │    │
│  │  • Handle relationships                                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│       ↓ (events: Typst-compatible maps)                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Consumer / Stream Output                                │    │
│  │  • Aggregate for D3 charts (optional)                    │    │
│  │  • Stream to Typst compiler                              │    │
│  │  • Track progress and memory                             │    │
│  │  • Emit telemetry events                                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│       ↓                                                           │
│  Enumerable Stream → Client (Report/Chart)                       │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

#### 1. StreamingPipeline (Core Module)
**Location**: `lib/ash_reports/typst/streaming_pipeline.ex`
**Responsibility**: Main API and pipeline coordination

```elixir
defmodule AshReports.Typst.StreamingPipeline do
  @moduledoc """
  Memory-efficient streaming pipeline for large dataset processing.

  Provides GenStage-based producer-consumer architecture with:
  - Demand-driven query execution
  - Backpressure management
  - Memory monitoring and circuit breakers
  - Progress tracking and telemetry
  """

  @doc """
  Starts a new streaming pipeline for a report.

  Returns a stream that can be consumed for incremental processing.
  The pipeline is automatically registered and monitored.
  """
  @spec start_pipeline(domain :: module(), report :: Report.t(), opts :: keyword()) ::
    {:ok, stream_id :: String.t(), stream :: Enumerable.t()} | {:error, term()}

  @doc """
  Cancels an active streaming pipeline.
  """
  @spec cancel_pipeline(stream_id :: String.t()) :: :ok | {:error, :not_found}

  @doc """
  Gets the status of a streaming pipeline.
  """
  @spec get_status(stream_id :: String.t()) ::
    {:ok, %{status: atom(), progress: float(), memory: integer()}} | {:error, :not_found}
end
```

#### 2. StreamingPipeline.Producer
**Location**: `lib/ash_reports/typst/streaming_pipeline/producer.ex`
**Responsibility**: Query execution and data production

```elixir
defmodule AshReports.Typst.StreamingPipeline.Producer do
  use GenStage

  @moduledoc """
  Producer stage that executes Ash queries in chunks with demand-driven backpressure.

  Features:
  - Chunked query execution (configurable size: 500-1000 records)
  - Intelligent preloading for relationships
  - Query pagination with offset/limit
  - Memory monitoring and circuit breakers
  - Automatic error recovery
  """

  # State: %{
  #   domain: module(),
  #   report: Report.t(),
  #   query: Ash.Query.t(),
  #   offset: integer(),
  #   chunk_size: integer(),
  #   total_records: integer() | nil,
  #   memory_limit: integer(),
  #   telemetry_ref: reference()
  # }
end
```

#### 3. StreamingPipeline.ProducerConsumer
**Location**: `lib/ash_reports/typst/streaming_pipeline/producer_consumer.ex`
**Responsibility**: Data transformation pipeline

```elixir
defmodule AshReports.Typst.StreamingPipeline.ProducerConsumer do
  use GenStage

  @moduledoc """
  ProducerConsumer stage that transforms Ash structs to Typst-compatible format.

  Integrates with:
  - AshReports.Typst.DataProcessor for type conversion
  - Variable calculation and scope management
  - Group processing and aggregation
  - Relationship flattening
  """

  # State: %{
  #   report: Report.t(),
  #   processor_opts: keyword(),
  #   buffer: [map()],
  #   variables: %{},
  #   groups: %{}
  # }
end
```

#### 4. StreamingPipeline.Supervisor
**Location**: `lib/ash_reports/typst/streaming_pipeline/supervisor.ex`
**Responsibility**: Supervise all streaming components

```elixir
defmodule AshReports.Typst.StreamingPipeline.Supervisor do
  use Supervisor

  @moduledoc """
  Top-level supervisor for streaming infrastructure.

  Supervises:
  - StreamRegistry (ETS-based registry)
  - HealthMonitor (GenServer for monitoring)
  - PipelineSupervisor (DynamicSupervisor for pipelines)
  """

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [
      # ETS-based registry for tracking active streams
      {AshReports.Typst.StreamingPipeline.Registry, []},

      # Health monitoring and telemetry
      {AshReports.Typst.StreamingPipeline.HealthMonitor, []},

      # Dynamic supervisor for individual pipelines
      {DynamicSupervisor,
        name: AshReports.Typst.StreamingPipeline.PipelineSupervisor,
        strategy: :one_for_one,
        max_restarts: 10,
        max_seconds: 60
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

#### 5. StreamRegistry
**Location**: `lib/ash_reports/typst/streaming_pipeline/registry.ex`
**Responsibility**: Track active pipelines

```elixir
defmodule AshReports.Typst.StreamingPipeline.Registry do
  use GenServer

  @moduledoc """
  ETS-based registry for tracking active streaming pipelines.

  Stores:
  - stream_id → %{producer_pid, consumer_pid, status, started_at, metadata}
  - Monitors all registered processes
  - Automatic cleanup on process termination
  - Query capabilities for management
  """

  # ETS Table Schema:
  # {:stream, stream_id, %{
  #   producer_pid: pid(),
  #   consumer_pid: pid(),
  #   status: :running | :paused | :completed | :failed,
  #   started_at: DateTime.t(),
  #   records_processed: integer(),
  #   memory_usage: integer(),
  #   telemetry_ref: reference()
  # }}
end
```

#### 6. HealthMonitor
**Location**: `lib/ash_reports/typst/streaming_pipeline/health_monitor.ex`
**Responsibility**: Health monitoring and metrics

```elixir
defmodule AshReports.Typst.StreamingPipeline.HealthMonitor do
  use GenServer

  @moduledoc """
  Monitors health of streaming pipelines and emits telemetry.

  Features:
  - Periodic health checks (every 1 second)
  - Memory usage monitoring with circuit breakers
  - Throughput tracking (records/second)
  - Automatic intervention for unhealthy pipelines
  - Telemetry event emission
  """

  # Telemetry Events:
  # [:ash_reports, :streaming, :pipeline, :start]
  # [:ash_reports, :streaming, :pipeline, :stop]
  # [:ash_reports, :streaming, :pipeline, :exception]
  # [:ash_reports, :streaming, :health_check]
  # [:ash_reports, :streaming, :memory_warning]
  # [:ash_reports, :streaming, :throughput]
end
```

---

## 🔧 Technical Implementation Details

### 1. GenStage Configuration

#### Producer Configuration
```elixir
# lib/ash_reports/typst/streaming_pipeline/producer.ex

def init(opts) do
  state = %{
    domain: Keyword.fetch!(opts, :domain),
    report: Keyword.fetch!(opts, :report),
    query: Keyword.fetch!(opts, :query),
    offset: 0,
    chunk_size: Keyword.get(opts, :chunk_size, 500),
    total_records: nil,
    memory_limit: Keyword.get(opts, :memory_limit, 500_000_000), # 500MB
    records_produced: 0,
    started_at: DateTime.utc_now()
  }

  # Emit start telemetry
  :telemetry.execute(
    [:ash_reports, :streaming, :pipeline, :start],
    %{time: System.system_time()},
    %{report: state.report.name}
  )

  {:producer, state}
end

def handle_demand(demand, state) when demand > 0 do
  # Check memory before processing
  if memory_ok?(state) do
    # Execute chunked query
    case execute_chunk_query(state) do
      {:ok, records, new_state} ->
        {:noreply, records, new_state}

      {:error, reason} ->
        # Emit error telemetry
        :telemetry.execute(
          [:ash_reports, :streaming, :pipeline, :exception],
          %{duration: elapsed(state.started_at)},
          %{reason: reason}
        )
        {:stop, {:error, reason}, state}
    end
  else
    # Circuit breaker: pause production
    {:noreply, [], state}
  end
end

defp execute_chunk_query(state) do
  query =
    state.query
    |> Ash.Query.limit(state.chunk_size)
    |> Ash.Query.offset(state.offset)

  case Ash.read(query, domain: state.domain) do
    {:ok, records} when records == [] ->
      # End of stream
      {:ok, [], %{state | offset: :done}}

    {:ok, records} ->
      new_offset = state.offset + length(records)
      new_state = %{state |
        offset: new_offset,
        records_produced: state.records_produced + length(records)
      }
      {:ok, records, new_state}

    {:error, reason} ->
      {:error, reason}
  end
end

defp memory_ok?(state) do
  current_memory = :erlang.memory(:total)
  current_memory < state.memory_limit
end
```

#### ProducerConsumer Configuration
```elixir
# lib/ash_reports/typst/streaming_pipeline/producer_consumer.ex

def init(opts) do
  state = %{
    report: Keyword.fetch!(opts, :report),
    processor_opts: Keyword.get(opts, :processor_opts, []),
    buffer: [],
    variables: %{},
    groups: %{}
  }

  # Subscribe to producer with specific subscription options
  {:producer_consumer, state, subscribe_to: [
    {Keyword.fetch!(opts, :producer_pid),
     max_demand: 1000,
     min_demand: 500
    }
  ]}
end

def handle_events(events, _from, state) do
  # Transform Ash structs to Typst format
  case transform_batch(events, state) do
    {:ok, transformed_events, new_state} ->
      {:noreply, transformed_events, new_state}

    {:error, reason} ->
      {:stop, {:error, reason}, state}
  end
end

defp transform_batch(events, state) do
  # Use DataProcessor for conversion
  case AshReports.Typst.DataProcessor.convert_records(events, state.processor_opts) do
    {:ok, converted} ->
      # Calculate variables if needed
      variables = calculate_incremental_variables(converted, state.variables, state.report)

      new_state = %{state | variables: variables}
      {:ok, converted, new_state}

    {:error, reason} ->
      {:error, {:transformation_failed, reason}}
  end
end
```

### 2. Stream Registry Implementation

```elixir
# lib/ash_reports/typst/streaming_pipeline/registry.ex

defmodule AshReports.Typst.StreamingPipeline.Registry do
  use GenServer

  @table_name :streaming_pipeline_registry

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    table = :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{table: table, monitors: %{}}}
  end

  @doc """
  Registers a new streaming pipeline.
  """
  def register(stream_id, producer_pid, consumer_pid, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:register, stream_id, producer_pid, consumer_pid, metadata})
  end

  @doc """
  Updates the status of a streaming pipeline.
  """
  def update_status(stream_id, status, metrics \\ %{}) do
    GenServer.cast(__MODULE__, {:update_status, stream_id, status, metrics})
  end

  @doc """
  Gets information about a streaming pipeline.
  """
  def lookup(stream_id) do
    case :ets.lookup(@table_name, stream_id) do
      [{^stream_id, info}] -> {:ok, info}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all active streaming pipelines.
  """
  def list_active do
    :ets.match_object(@table_name, {:_, %{status: :running}})
    |> Enum.map(fn {stream_id, info} -> {stream_id, info} end)
  end

  def handle_call({:register, stream_id, producer_pid, consumer_pid, metadata}, _from, state) do
    # Monitor both processes
    producer_ref = Process.monitor(producer_pid)
    consumer_ref = Process.monitor(consumer_pid)

    info = %{
      producer_pid: producer_pid,
      consumer_pid: consumer_pid,
      status: :running,
      started_at: DateTime.utc_now(),
      records_processed: 0,
      memory_usage: 0,
      metadata: metadata
    }

    :ets.insert(@table_name, {stream_id, info})

    new_monitors =
      state.monitors
      |> Map.put(producer_ref, stream_id)
      |> Map.put(consumer_ref, stream_id)

    {:reply, :ok, %{state | monitors: new_monitors}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state.monitors, ref) do
      {nil, _monitors} ->
        {:noreply, state}

      {stream_id, new_monitors} ->
        # Update status to failed or completed
        final_status = if reason == :normal, do: :completed, else: :failed
        update_stream_status(stream_id, final_status, %{exit_reason: reason})

        {:noreply, %{state | monitors: new_monitors}}
    end
  end

  defp update_stream_status(stream_id, status, metrics) do
    case :ets.lookup(@table_name, stream_id) do
      [{^stream_id, info}] ->
        updated_info =
          info
          |> Map.put(:status, status)
          |> Map.merge(metrics)

        :ets.insert(@table_name, {stream_id, updated_info})

      [] ->
        :ok
    end
  end
end
```

### 3. Health Monitoring Implementation

```elixir
# lib/ash_reports/typst/streaming_pipeline/health_monitor.ex

defmodule AshReports.Typst.StreamingPipeline.HealthMonitor do
  use GenServer

  @check_interval 1_000 # 1 second
  @memory_warning_threshold 0.8 # 80% of limit
  @memory_critical_threshold 0.95 # 95% of limit

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_health_check()
    {:ok, %{last_check: DateTime.utc_now()}}
  end

  def handle_info(:health_check, state) do
    perform_health_check()
    schedule_health_check()
    {:noreply, %{state | last_check: DateTime.utc_now()}}
  end

  defp perform_health_check do
    active_streams = AshReports.Typst.StreamingPipeline.Registry.list_active()

    Enum.each(active_streams, fn {stream_id, info} ->
      check_stream_health(stream_id, info)
    end)

    # Emit overall health telemetry
    :telemetry.execute(
      [:ash_reports, :streaming, :health_check],
      %{
        active_streams: length(active_streams),
        total_memory: :erlang.memory(:total),
        time: System.system_time()
      },
      %{}
    )
  end

  defp check_stream_health(stream_id, info) do
    # Check producer/consumer are alive
    producer_alive = Process.alive?(info.producer_pid)
    consumer_alive = Process.alive?(info.consumer_pid)

    unless producer_alive and consumer_alive do
      Logger.warning("Stream #{stream_id} has dead processes",
        producer_alive: producer_alive,
        consumer_alive: consumer_alive
      )
    end

    # Check memory usage
    check_memory_usage(stream_id, info)

    # Calculate throughput
    calculate_throughput(stream_id, info)
  end

  defp check_memory_usage(stream_id, info) do
    current_memory = :erlang.memory(:total)
    memory_limit = Application.get_env(:ash_reports, :streaming_memory_limit, 1_000_000_000)

    usage_ratio = current_memory / memory_limit

    cond do
      usage_ratio >= @memory_critical_threshold ->
        Logger.error("CRITICAL: Stream #{stream_id} memory usage at #{Float.round(usage_ratio * 100, 1)}%")

        :telemetry.execute(
          [:ash_reports, :streaming, :memory_critical],
          %{memory_usage: current_memory, memory_limit: memory_limit},
          %{stream_id: stream_id, action: :circuit_break}
        )

        # Consider killing the stream to prevent OOM
        maybe_kill_stream(stream_id, info)

      usage_ratio >= @memory_warning_threshold ->
        Logger.warning("Stream #{stream_id} memory usage at #{Float.round(usage_ratio * 100, 1)}%")

        :telemetry.execute(
          [:ash_reports, :streaming, :memory_warning],
          %{memory_usage: current_memory, memory_limit: memory_limit},
          %{stream_id: stream_id}
        )

      true ->
        :ok
    end
  end

  defp calculate_throughput(stream_id, info) do
    elapsed_seconds = DateTime.diff(DateTime.utc_now(), info.started_at)

    if elapsed_seconds > 0 do
      throughput = info.records_processed / elapsed_seconds

      :telemetry.execute(
        [:ash_reports, :streaming, :throughput],
        %{records_per_second: throughput, total_records: info.records_processed},
        %{stream_id: stream_id}
      )
    end
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @check_interval)
  end

  defp maybe_kill_stream(stream_id, info) do
    # Graceful shutdown attempt
    Process.exit(info.producer_pid, :memory_limit_exceeded)
    Process.exit(info.consumer_pid, :memory_limit_exceeded)

    AshReports.Typst.StreamingPipeline.Registry.update_status(
      stream_id,
      :killed_memory,
      %{killed_at: DateTime.utc_now()}
    )
  end
end
```

### 4. Integration with DataLoader

```elixir
# lib/ash_reports/typst/data_loader.ex (UPDATE existing function)

defp create_streaming_pipeline(domain, report, params, opts) do
  # Generate unique stream ID
  stream_id = generate_stream_id(report.name)

  # Build Ash query
  query = build_streaming_query(domain, report, params)

  # Start pipeline under supervision
  pipeline_opts = [
    stream_id: stream_id,
    domain: domain,
    report: report,
    query: query,
    chunk_size: Keyword.get(opts, :chunk_size, 500),
    memory_limit: Keyword.get(opts, :memory_limit, 500_000_000),
    processor_opts: Keyword.get(opts, :type_conversion, [])
  ]

  case AshReports.Typst.StreamingPipeline.start_pipeline(pipeline_opts) do
    {:ok, stream} ->
      Logger.info("Started streaming pipeline #{stream_id} for report #{report.name}")
      {:ok, stream}

    {:error, reason} = error ->
      Logger.error("Failed to start streaming pipeline: #{inspect(reason)}")
      error
  end
end

defp build_streaming_query(domain, report, params) do
  # Leverage existing QueryBuilder
  query = AshReports.QueryBuilder.build(report, params)

  # Add optimal preloading for relationships
  preloads = infer_preloads_from_report(report)
  Ash.Query.load(query, preloads)
end

defp infer_preloads_from_report(report) do
  # Extract relationship paths from DSL elements
  report.bands
  |> Enum.flat_map(& &1.elements)
  |> Enum.filter(&(&1.type in [:field, :expression]))
  |> Enum.flat_map(&extract_relationship_paths/1)
  |> Enum.uniq()
end

defp generate_stream_id(report_name) do
  "stream_#{report_name}_#{System.unique_integer([:positive, :monotonic])}"
end
```

---

## 📁 File Structure and Module Organization

```
lib/ash_reports/
├── application.ex                          # UPDATE: Add StreamingSupervisor
└── typst/
    ├── data_loader.ex                      # UPDATE: Implement create_streaming_pipeline/4
    ├── data_processor.ex                   # EXISTS: Use for transformations
    ├── streaming_pipeline.ex               # NEW: Main API module
    └── streaming_pipeline/
        ├── supervisor.ex                   # NEW: Supervision tree
        ├── producer.ex                     # NEW: Query execution producer
        ├── producer_consumer.ex            # NEW: Transformation stage
        ├── registry.ex                     # NEW: ETS-based stream registry
        └── health_monitor.ex               # NEW: Health monitoring GenServer

test/ash_reports/typst/
├── data_loader_test.exs                    # UPDATE: Test streaming integration
├── streaming_pipeline_test.exs             # NEW: Core pipeline tests
└── streaming_pipeline/
    ├── producer_test.exs                   # NEW: Producer unit tests
    ├── producer_consumer_test.exs          # NEW: ProducerConsumer unit tests
    ├── registry_test.exs                   # NEW: Registry tests
    ├── health_monitor_test.exs             # NEW: Health monitor tests
    └── integration_test.exs                # NEW: End-to-end streaming tests
```

### Module Count and Lines of Code Estimate

| Module | Lines of Code | Complexity |
|--------|--------------|------------|
| StreamingPipeline | 150 | Medium |
| StreamingPipeline.Supervisor | 80 | Low |
| StreamingPipeline.Producer | 300 | High |
| StreamingPipeline.ProducerConsumer | 250 | High |
| StreamingPipeline.Registry | 200 | Medium |
| StreamingPipeline.HealthMonitor | 250 | Medium |
| DataLoader (updates) | 100 | Medium |
| Application (updates) | 20 | Low |
| **Total New/Updated** | **~1,350 LOC** | |

### Test Coverage Estimate

| Test Module | Test Cases | Lines of Code |
|-------------|-----------|--------------|
| streaming_pipeline_test.exs | 15 | 250 |
| producer_test.exs | 12 | 200 |
| producer_consumer_test.exs | 10 | 180 |
| registry_test.exs | 8 | 150 |
| health_monitor_test.exs | 8 | 150 |
| integration_test.exs | 10 | 300 |
| **Total Tests** | **63** | **~1,230 LOC** |

---

## 📋 Step-by-Step Implementation Plan

### Phase 1: Foundation (Days 1-2)
**Goal**: Establish basic infrastructure and supervision tree

#### Tasks:
1. **Add Dependencies to mix.exs**
   - [ ] Add `{:gen_stage, "~> 1.3"}` dependency
   - [ ] Add `{:flow, "~> 1.2"}` dependency
   - [ ] Run `mix deps.get` and verify compilation

2. **Create Supervisor Structure**
   - [ ] Create `lib/ash_reports/typst/streaming_pipeline/supervisor.ex`
   - [ ] Implement basic supervision tree with:
     - StreamRegistry as first child
     - HealthMonitor as second child
     - DynamicSupervisor as third child
   - [ ] Write unit tests for supervisor initialization

3. **Implement StreamRegistry**
   - [ ] Create `lib/ash_reports/typst/streaming_pipeline/registry.ex`
   - [ ] Implement ETS table setup with proper concurrency options
   - [ ] Add register/4, lookup/1, update_status/3, list_active/0 functions
   - [ ] Add process monitoring with handle_info for :DOWN messages
   - [ ] Write comprehensive unit tests (8 test cases)

4. **Update Application Supervision**
   - [ ] Modify `lib/ash_reports/application.ex`
   - [ ] Add StreamingPipeline.Supervisor to supervision tree
   - [ ] Ensure proper restart strategy
   - [ ] Test application startup with new supervisor

**Deliverables**: Working supervision tree with registry, all tests passing

---

### Phase 2: Producer Implementation (Days 3-4)
**Goal**: Implement demand-driven query execution producer

#### Tasks:
1. **Create Producer Module**
   - [ ] Create `lib/ash_reports/typst/streaming_pipeline/producer.ex`
   - [ ] Implement `use GenStage` with `:producer` type
   - [ ] Add init/1 with state initialization
   - [ ] Implement handle_demand/2 for chunk query execution

2. **Query Execution Logic**
   - [ ] Implement execute_chunk_query/1 private function
   - [ ] Add Ash query building with offset/limit pagination
   - [ ] Handle end-of-stream detection (empty results)
   - [ ] Add proper error handling for query failures

3. **Memory Management**
   - [ ] Implement memory_ok?/1 circuit breaker
   - [ ] Add configurable memory limits
   - [ ] Implement backpressure on memory pressure
   - [ ] Add telemetry events for memory warnings

4. **Preloading Strategy**
   - [ ] Implement intelligent relationship preloading
   - [ ] Add preload inference from report DSL elements
   - [ ] Optimize preload depth and breadth
   - [ ] Add configuration for preload strategy

5. **Testing**
   - [ ] Write 12 unit tests for producer
   - [ ] Test demand handling
   - [ ] Test query pagination
   - [ ] Test memory circuit breakers
   - [ ] Test error recovery

**Deliverables**: Fully functional producer with memory management, all tests passing

---

### Phase 3: ProducerConsumer Implementation (Days 5-6)
**Goal**: Implement data transformation pipeline stage

#### Tasks:
1. **Create ProducerConsumer Module**
   - [ ] Create `lib/ash_reports/typst/streaming_pipeline/producer_consumer.ex`
   - [ ] Implement `use GenStage` with `:producer_consumer` type
   - [ ] Add init/1 with subscription to producer
   - [ ] Configure max_demand and min_demand

2. **Data Transformation Integration**
   - [ ] Implement handle_events/3
   - [ ] Integrate with AshReports.Typst.DataProcessor
   - [ ] Add batch transformation logic
   - [ ] Handle transformation errors gracefully

3. **Variable Calculation**
   - [ ] Implement incremental variable calculations
   - [ ] Add support for detail and group scopes
   - [ ] Maintain running aggregations
   - [ ] Optimize for streaming performance

4. **Group Processing**
   - [ ] Add streaming-aware group detection
   - [ ] Implement group break handling
   - [ ] Maintain group state across chunks
   - [ ] Emit group boundaries for consumers

5. **Testing**
   - [ ] Write 10 unit tests for producer_consumer
   - [ ] Test event transformation
   - [ ] Test integration with DataProcessor
   - [ ] Test variable calculations
   - [ ] Test group processing

**Deliverables**: Functional transformation stage, all tests passing

---

### Phase 4: Health Monitoring (Day 7)
**Goal**: Implement comprehensive health monitoring and telemetry

#### Tasks:
1. **Create HealthMonitor Module**
   - [ ] Create `lib/ash_reports/typst/streaming_pipeline/health_monitor.ex`
   - [ ] Implement GenServer with periodic health checks
   - [ ] Add process liveness checks
   - [ ] Implement memory monitoring

2. **Telemetry Integration**
   - [ ] Define telemetry event specifications
   - [ ] Implement event emission for:
     - Pipeline start/stop
     - Health checks
     - Memory warnings
     - Throughput metrics
   - [ ] Add metadata for debugging

3. **Intervention Logic**
   - [ ] Implement graceful shutdown for unhealthy streams
   - [ ] Add automatic cleanup on failures
   - [ ] Create intervention policies
   - [ ] Add configurable thresholds

4. **Testing**
   - [ ] Write 8 unit tests for health monitor
   - [ ] Test health check cycles
   - [ ] Test memory monitoring
   - [ ] Test intervention logic

**Deliverables**: Health monitoring system with telemetry, all tests passing

---

### Phase 5: Main API and Integration (Days 8-9)
**Goal**: Implement public API and integrate with DataLoader

#### Tasks:
1. **Create StreamingPipeline Module**
   - [ ] Create `lib/ash_reports/typst/streaming_pipeline.ex`
   - [ ] Implement start_pipeline/3 public API
   - [ ] Add cancel_pipeline/1 function
   - [ ] Implement get_status/1 for monitoring

2. **Pipeline Orchestration**
   - [ ] Implement pipeline startup logic
   - [ ] Start producer and producer_consumer stages
   - [ ] Register pipeline with registry
   - [ ] Return enumerable stream to caller

3. **Stream Creation**
   - [ ] Implement GenStage.stream/1 usage
   - [ ] Configure buffer and demand
   - [ ] Add stream cancellation support
   - [ ] Handle stream completion

4. **DataLoader Integration**
   - [ ] Update create_streaming_pipeline/4 in DataLoader
   - [ ] Replace {:error, :streaming_not_implemented} placeholder
   - [ ] Add query building logic
   - [ ] Implement preload inference

5. **Configuration**
   - [ ] Add application configuration options
   - [ ] Document all configuration keys
   - [ ] Add sensible defaults
   - [ ] Create configuration validation

6. **Testing**
   - [ ] Write 15 unit tests for main API
   - [ ] Test pipeline startup
   - [ ] Test stream creation
   - [ ] Test cancellation
   - [ ] Test DataLoader integration

**Deliverables**: Complete public API integrated with DataLoader, all tests passing

---

### Phase 6: Integration Testing (Day 10)
**Goal**: End-to-end integration testing with real scenarios

#### Tasks:
1. **Create Integration Test Suite**
   - [ ] Create `test/ash_reports/typst/streaming_pipeline/integration_test.exs`
   - [ ] Set up test fixtures with demo resources
   - [ ] Create test reports with varying complexity

2. **End-to-End Scenarios**
   - [ ] Test complete pipeline: query → transform → stream
   - [ ] Test with 10K record dataset
   - [ ] Test with 100K record dataset
   - [ ] Test with relationships and preloading
   - [ ] Test with grouping and variables

3. **Error Scenarios**
   - [ ] Test query failures
   - [ ] Test transformation errors
   - [ ] Test memory limit exceeded
   - [ ] Test process crashes and recovery
   - [ ] Test cancellation during streaming

4. **Performance Validation**
   - [ ] Measure memory usage (must be <1.5x baseline)
   - [ ] Measure throughput (target: 1000+ records/sec)
   - [ ] Verify constant memory regardless of dataset size
   - [ ] Test concurrent streams

**Deliverables**: 10 integration tests, all passing with performance targets met

---

### Phase 7: Documentation and Polish (Days 11-12)
**Goal**: Comprehensive documentation and code quality

#### Tasks:
1. **Module Documentation**
   - [ ] Add @moduledoc to all modules with examples
   - [ ] Document all public functions with @doc
   - [ ] Add @spec type specifications everywhere
   - [ ] Include usage examples in documentation

2. **API Documentation**
   - [ ] Document StreamingPipeline public API
   - [ ] Create usage guide with examples
   - [ ] Document configuration options
   - [ ] Add troubleshooting guide

3. **Architecture Documentation**
   - [ ] Update this planning document with actual implementation details
   - [ ] Create architecture diagrams
   - [ ] Document supervision tree
   - [ ] Add telemetry event reference

4. **Code Quality**
   - [ ] Run Credo and fix all issues (target: A+ rating)
   - [ ] Run Dialyzer and fix type issues
   - [ ] Add code comments for complex logic
   - [ ] Refactor for clarity and maintainability

5. **Testing Polish**
   - [ ] Ensure all tests have descriptive names
   - [ ] Add test documentation
   - [ ] Verify test coverage >90%
   - [ ] Clean up test helpers

**Deliverables**: Complete documentation, A+ code quality rating

---

### Phase 8: Performance Benchmarking (Days 13-14)
**Goal**: Validate performance targets and optimize

#### Tasks:
1. **Benchmark Suite**
   - [ ] Create benchee-based performance tests
   - [ ] Benchmark with varying dataset sizes (1K, 10K, 100K, 1M)
   - [ ] Benchmark with different chunk sizes (100, 500, 1000, 2000)
   - [ ] Benchmark with/without relationships
   - [ ] Benchmark concurrent streams (1, 5, 10, 20)

2. **Memory Profiling**
   - [ ] Profile memory usage with :observer
   - [ ] Verify <1.5x baseline memory constraint
   - [ ] Identify memory hotspots
   - [ ] Optimize allocations

3. **Throughput Optimization**
   - [ ] Profile throughput bottlenecks
   - [ ] Tune chunk sizes for optimal performance
   - [ ] Optimize type conversions in DataProcessor
   - [ ] Tune GenStage demand parameters

4. **Results Documentation**
   - [ ] Document benchmark results
   - [ ] Create performance comparison charts
   - [ ] Add performance tuning guide
   - [ ] Document optimal configuration

**Deliverables**: Performance validation report, optimized implementation

---

## 🧪 Testing Strategy

### Unit Testing Approach

#### Test Categories
1. **Producer Tests** (12 tests)
   - Demand handling with various demand sizes
   - Query execution and pagination
   - Memory circuit breaker activation
   - End-of-stream detection
   - Error handling and recovery
   - Telemetry event emission

2. **ProducerConsumer Tests** (10 tests)
   - Event transformation correctness
   - DataProcessor integration
   - Variable calculation accuracy
   - Group processing logic
   - Backpressure handling
   - Error propagation

3. **Registry Tests** (8 tests)
   - Stream registration
   - Process monitoring
   - Status updates
   - Lookup functionality
   - Automatic cleanup on process death
   - Concurrent access

4. **HealthMonitor Tests** (8 tests)
   - Periodic health check execution
   - Memory monitoring
   - Throughput calculation
   - Intervention logic
   - Telemetry emission
   - Process liveness checks

5. **Main API Tests** (15 tests)
   - Pipeline startup
   - Stream creation
   - Cancellation
   - Status queries
   - Error handling
   - Configuration validation

6. **Integration Tests** (10 tests)
   - End-to-end pipeline flow
   - Large dataset processing
   - Memory efficiency validation
   - Concurrent streams
   - Error recovery scenarios

**Total**: 63 unit + integration tests

### Performance Testing

#### Benchmarks to Create
```elixir
# benchmarks/streaming_pipeline_bench.exs

Benchee.run(%{
  "1K records" => fn ->
    stream_and_consume(1_000)
  end,
  "10K records" => fn ->
    stream_and_consume(10_000)
  end,
  "100K records" => fn ->
    stream_and_consume(100_000)
  end,
  "1M records" => fn ->
    stream_and_consume(1_000_000)
  end
},
  time: 30,
  memory_time: 10,
  formatters: [
    {Benchee.Formatters.HTML, file: "benchmarks/results/streaming.html"},
    Benchee.Formatters.Console
  ]
)
```

#### Performance Targets
- **Memory Usage**: <1.5x baseline regardless of dataset size
- **Throughput**: >1000 records/second on standard hardware
- **Latency**: Streaming starts within 100ms
- **Scalability**: Linear scaling with CPU cores (using Flow in future)
- **Concurrency**: Handle 10+ concurrent streams without degradation

### Load Testing

Create load tests to validate behavior under stress:
```elixir
# test/ash_reports/typst/streaming_pipeline/load_test.exs

test "handles 20 concurrent streams without memory exhaustion" do
  # Start 20 concurrent streams
  tasks = for i <- 1..20 do
    Task.async(fn ->
      {:ok, stream} = start_streaming_pipeline(report: "test_#{i}")

      Enum.reduce(stream, 0, fn _record, acc ->
        acc + 1
      end)
    end)
  end

  # Wait for all to complete
  results = Task.await_many(tasks, 300_000) # 5 min timeout

  # Verify all completed successfully
  assert length(results) == 20
  assert Enum.all?(results, & &1 > 0)

  # Verify memory stayed within bounds
  final_memory = :erlang.memory(:total)
  assert final_memory < initial_memory * 3 # Allow 3x for concurrent streams
end
```

---

## ✅ Success Criteria

### Functional Requirements
- [ ] StreamingPipeline.start_pipeline/3 successfully creates enumerable streams
- [ ] Producer executes chunked Ash queries with proper pagination
- [ ] ProducerConsumer transforms Ash structs to Typst-compatible format
- [ ] Registry tracks all active pipelines with accurate status
- [ ] HealthMonitor emits telemetry and intervenes on unhealthy streams
- [ ] Streams can be cancelled mid-processing
- [ ] Integration with DataLoader.stream_for_typst/4 works seamlessly

### Performance Requirements
- [ ] Memory usage <1.5x baseline for datasets of any size (1K to 1M records)
- [ ] Throughput >1000 records/second on standard hardware
- [ ] Stream startup latency <100ms
- [ ] Supports 10+ concurrent streams without degradation
- [ ] Linear CPU utilization scaling

### Quality Requirements
- [ ] 90%+ test coverage for all streaming modules
- [ ] All 63 unit and integration tests passing
- [ ] Credo code quality rating: A+
- [ ] Dialyzer runs with no warnings
- [ ] Comprehensive error handling for all failure modes
- [ ] Full telemetry coverage for monitoring

### Developer Experience
- [ ] Clear, comprehensive documentation with examples
- [ ] Intuitive API following Elixir/GenStage conventions
- [ ] Helpful error messages with actionable guidance
- [ ] Easy debugging with proper logging and telemetry
- [ ] Simple configuration with sensible defaults

### Production Readiness
- [ ] Supervision tree properly configured with restart strategies
- [ ] Health monitoring with automatic intervention
- [ ] Memory circuit breakers prevent OOM crashes
- [ ] Graceful degradation under load
- [ ] Telemetry integration for observability
- [ ] Documentation includes deployment considerations

---

## 🔄 Integration Points

### Upstream Dependencies
- **Stage 1.1 (Typst Runtime)**: Uses BinaryWrapper for final compilation after streaming
- **Stage 1.2 (DSL Generator)**: Consumes Typst templates that expect streaming data format
- **Stage 1.3 (Data Integration)**: Uses DataProcessor for transformation, extends DataLoader

### Downstream Consumers
- **Section 2.2 (Producer Implementation)**: Will extend basic producer with advanced features
- **Section 2.3 (Consumer Implementation)**: Will add aggregation and Flow integration
- **Stage 3 (D3 Visualization)**: Will use streaming for large dataset aggregation
- **Stage 4 (LiveView)**: Will use streaming for real-time report updates

### Cross-Cutting Concerns
- **Configuration**: Application environment variables for memory limits, chunk sizes, etc.
- **Telemetry**: Comprehensive event emission for monitoring and observability
- **Error Handling**: Consistent error patterns with AshReports conventions
- **Testing**: Reuses test support modules and helpers from existing codebase

---

## 📚 References and Resources

### Elixir/OTP Documentation
- [GenStage Guide](https://hexdocs.pm/gen_stage/GenStage.html) - Official GenStage documentation
- [Flow Documentation](https://hexdocs.pm/flow/Flow.html) - Flow for parallel processing
- [DynamicSupervisor](https://hexdocs.pm/elixir/DynamicSupervisor.html) - Dynamic process supervision
- [Registry](https://hexdocs.pm/elixir/Registry.html) - Process registry patterns

### Best Practices Articles
- [GenStage Backpressure Mechanisms](https://dev.to/dcdourado/understanding-genstage-back-pressure-mechanism-1b0i)
- [GenServer + Registry + DynamicSupervisor](https://dev.to/unnawut/genserver-registry-dynamicsupervisor-combined-4i9p)
- [Real-Time Data Processing in Elixir](https://softwarepatternslexicon.com/patterns-elixir/9/7/)

### Existing Codebase References
- `lib/ash_reports/typst/data_loader.ex` - Streaming API placeholder to implement
- `lib/ash_reports/typst/data_processor.ex` - Transformation logic to reuse
- `lib/ash_reports/application.ex` - Application supervision tree to extend
- `lib/ash_reports/data_loader.ex` - QueryBuilder patterns to follow

### Related Planning Documents
- `planning/typst_refactor_plan.md` - Overall Stage 2 context
- `notes/features/ash_resource_data_integration.md` - Stage 1.3 foundation

---

## 🚀 Post-Implementation: Next Steps

### Immediate Follow-ups (Section 2.2-2.4)
After completing Section 2.1, the foundation will be in place for:

1. **Section 2.2: Producer Implementation** - Enhance producer with:
   - Query result caching
   - Intelligent relationship preloading strategies
   - Relationship depth limits
   - Automatic fallback for small datasets

2. **Section 2.3: Consumer/Transformer Implementation** - Add:
   - Streaming aggregation functions (sum, count, avg, percentiles)
   - Time-series bucketing for D3 charts
   - Window-based aggregations
   - Custom aggregation function support
   - Flow integration for parallel processing

3. **Section 2.4: DataLoader Integration** - Complete:
   - Automatic mode selection (batch vs streaming)
   - Dataset size detection heuristics
   - Pause/resume functionality
   - Graceful shutdown on cancellation

### Future Enhancements (Stage 3+)
The GenStage infrastructure will enable:

1. **D3 Visualization (Stage 3)**: Stream 1M records → aggregate to 500 chart datapoints
2. **LiveView Integration (Stage 4)**: Real-time report updates with WebSocket streaming
3. **Distributed Processing**: Extend to multi-node clusters with Flow partitioning
4. **Advanced Caching**: Stream-aware caching for repeated report generation

---

## 📊 Risk Assessment and Mitigation

### Technical Risks

| Risk | Probability | Impact | Mitigation Strategy |
|------|------------|--------|-------------------|
| Memory leaks in long-running streams | Medium | High | Comprehensive testing with memory profiling; health monitor intervention |
| GenStage backpressure misconfiguration | Medium | Medium | Follow official patterns; extensive testing; performance benchmarking |
| Query performance degradation with large offsets | High | Medium | Implement cursor-based pagination as alternative; cache query plans |
| Process crashes causing data loss | Low | High | Supervision tree with proper restart strategies; registry cleanup |
| Telemetry overhead impacting performance | Low | Low | Async event emission; sampling for high-frequency events |

### Implementation Risks

| Risk | Probability | Impact | Mitigation Strategy |
|------|------------|--------|-------------------|
| Underestimated complexity of producer logic | Medium | Medium | Allocate extra time in Phase 2; early prototype validation |
| Integration challenges with existing DataLoader | Low | Medium | Thorough code review of existing implementation; integration tests |
| Test suite becoming too slow | Medium | Low | Use tagged tests; optimize test setup; parallel test execution |
| Documentation falling behind implementation | Medium | Low | Write docs alongside code; include in PR review checklist |

### Schedule Risks

| Risk | Probability | Impact | Mitigation Strategy |
|------|------------|--------|-------------------|
| Performance optimization taking longer than expected | Medium | High | Start benchmarking early (Phase 8); adjust targets if needed |
| Debugging streaming issues consuming time | Medium | Medium | Build debugging tools early; comprehensive logging |
| Integration testing revealing architectural issues | Low | High | Early integration testing in Phase 6; validate design with Pascal |

---

## 💡 Design Decisions and Rationale

### 1. GenStage over Custom Streaming
**Decision**: Use GenStage instead of building custom stream processing
**Rationale**:
- Battle-tested backpressure mechanism
- Elixir community best practice
- Integration with Flow for future parallel processing
- Well-documented patterns and troubleshooting

### 2. ETS-based Registry over Process Registry
**Decision**: Use ETS table for stream registry instead of Elixir's Registry
**Rationale**:
- Simpler query patterns (list all active, filter by status)
- Better performance for frequent status updates
- Easier to add custom metadata
- More control over cleanup logic

### 3. Separate HealthMonitor Process
**Decision**: Dedicated GenServer for health monitoring
**Rationale**:
- Centralized monitoring logic
- Easier to test health checks independently
- Can monitor multiple streams efficiently
- Clear separation of concerns

### 4. Producer-ProducerConsumer-Consumer Pattern
**Decision**: Three-stage pipeline instead of two-stage
**Rationale**:
- Separation of concerns (query vs transform vs output)
- Better backpressure propagation
- Easier to add aggregation stages in future
- Follows GenStage best practices

### 5. Memory Circuit Breaker in Producer
**Decision**: Check memory before executing queries
**Rationale**:
- Prevent OOM crashes
- Graceful degradation under memory pressure
- Early intervention is better than late recovery
- Configurable threshold for different environments

### 6. Telemetry over Custom Metrics
**Decision**: Use :telemetry for all metrics and events
**Rationale**:
- Standard Elixir observability pattern
- Integration with existing monitoring tools
- No performance overhead from custom metrics collection
- Comprehensive event metadata for debugging

### 7. DynamicSupervisor for Pipelines
**Decision**: Use DynamicSupervisor for starting individual pipelines
**Rationale**:
- On-demand pipeline creation
- Automatic cleanup on completion/failure
- Configurable restart strategies
- Standard OTP pattern for dynamic processes

---

## 🎓 Learning Resources for Implementation

### For Pascal (Implementation Reference)
Since Pascal is an expert programmer, these are quick reference resources:

1. **GenStage Fundamentals** (30 min read)
   - [Official GenStage Guide](https://hexdocs.pm/gen_stage/GenStage.html)
   - Focus on: Producer callbacks, demand handling, subscription options

2. **Producer-Consumer Patterns** (20 min read)
   - [GenStage Backpressure Article](https://dev.to/dcdourado/understanding-genstage-back-pressure-mechanism-1b0i)
   - Focus on: min_demand, max_demand, buffer management

3. **DynamicSupervisor + Registry Pattern** (15 min read)
   - [Combined Pattern Article](https://dev.to/unnawut/genserver-registry-dynamicsupervisor-combined-4i9p)
   - Focus on: Process monitoring, automatic cleanup

4. **Telemetry Best Practices** (10 min read)
   - [Telemetry Documentation](https://hexdocs.pm/telemetry/readme.html)
   - Focus on: Event naming, metadata conventions

### Code Examples to Study
Look at these real-world GenStage implementations:
- `deps/gen_stage/examples/` - Official examples
- Broadway source code - Production-grade GenStage usage
- Phoenix PubSub - Registry pattern implementation

---

## ✅ Definition of Done

Section 2.1 is considered complete when:

- [ ] All 8 modules implemented and passing Credo A+
- [ ] All 63 tests passing with >90% coverage
- [ ] Integration with DataLoader complete (placeholder replaced)
- [ ] Application supervision tree updated
- [ ] Performance targets validated with benchmarks:
  - Memory usage <1.5x baseline for 1M records ✓
  - Throughput >1000 records/second ✓
  - Concurrent streams (10+) working ✓
- [ ] Comprehensive documentation complete:
  - All modules have @moduledoc with examples
  - All public functions have @doc and @spec
  - Usage guide with real examples
  - Architecture diagrams
- [ ] Telemetry events documented and tested
- [ ] Error handling comprehensive and tested
- [ ] Code reviewed and approved
- [ ] This planning document updated with actual implementation details

---

**Document Version**: 1.0
**Created**: September 30, 2025
**Author**: Planning for Pascal's implementation
**Status**: Ready for Review and Implementation

**Next Action**: Review this planning document with Pascal, get confirmation to proceed with implementation.