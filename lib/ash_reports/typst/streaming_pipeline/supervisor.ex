defmodule AshReports.Typst.StreamingPipeline.Supervisor do
  @moduledoc """
  Top-level supervisor for the streaming pipeline infrastructure.

  This supervisor manages the core components required for streaming large datasets:

  - **Registry**: ETS-based registry for tracking active pipelines
  - **HealthMonitor**: GenServer for health monitoring and telemetry
  - **PipelineSupervisor**: DynamicSupervisor for individual streaming pipelines

  ## Supervision Strategy

  Uses `:one_for_one` strategy, meaning:
  - If Registry crashes, it restarts independently
  - If HealthMonitor crashes, it restarts independently
  - If PipelineSupervisor crashes, individual pipelines are lost but the system recovers

  ## Restart Configuration

  - **Max restarts**: 10 within 60 seconds
  - **Restart**: `:permanent` for all children (always restart)
  - **Shutdown**: 5 seconds for graceful shutdown

  ## Usage

  This supervisor is automatically started as part of the AshReports application
  supervision tree. To use streaming pipelines:

      # Start a new pipeline through the StreamingPipeline API
      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(domain, report, params)

      # The PipelineSupervisor will supervise the Producer and ProducerConsumer stages
      # The Registry will track the pipeline
      # The HealthMonitor will monitor its health

  ## Architecture

      StreamingPipeline.Supervisor
      ├─ Registry (GenServer + ETS)
      ├─ HealthMonitor (GenServer)
      └─ PipelineSupervisor (DynamicSupervisor)
         ├─ Pipeline 1 (Producer → ProducerConsumer)
         ├─ Pipeline 2 (Producer → ProducerConsumer)
         └─ Pipeline N (Producer → ProducerConsumer)
  """

  use Supervisor
  require Logger

  @doc """
  Starts the StreamingPipeline supervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the PID of the PipelineSupervisor for starting new pipelines.
  """
  @spec pipeline_supervisor() :: pid() | {:error, :not_found}
  def pipeline_supervisor do
    with supervisor_pid when not is_nil(supervisor_pid) <- Process.whereis(__MODULE__),
         child_pid <- find_pipeline_supervisor_child(supervisor_pid),
         true <- is_pid(child_pid) do
      child_pid
    else
      _ -> {:error, :not_found}
    end
  end

  defp find_pipeline_supervisor_child(supervisor_pid) do
    children = Supervisor.which_children(supervisor_pid)

    case Enum.find(children, &pipeline_supervisor_child?/1) do
      {_id, pid, _type, _modules} -> pid
      _ -> nil
    end
  end

  defp pipeline_supervisor_child?({id, _pid, _type, _modules}) do
    id == AshReports.Typst.StreamingPipeline.PipelineSupervisor
  end

  @impl true
  def init(_opts) do
    children = [
      # 1. Registry: ETS-based tracking of active pipelines
      # Must start first as other components may query it
      {AshReports.Typst.StreamingPipeline.Registry, []},

      # 2. HealthMonitor: Health monitoring and telemetry
      # Depends on Registry to query pipeline status
      {AshReports.Typst.StreamingPipeline.HealthMonitor, []},

      # 3. PipelineSupervisor: Dynamic supervisor for individual pipelines
      # Each pipeline will be supervised here
      {DynamicSupervisor,
       name: AshReports.Typst.StreamingPipeline.PipelineSupervisor,
       strategy: :one_for_one,
       max_restarts: 10,
       max_seconds: 60}
    ]

    Logger.info("Starting StreamingPipeline.Supervisor")

    # Use one_for_one: each child restarts independently
    Supervisor.init(children, strategy: :one_for_one)
  end
end
