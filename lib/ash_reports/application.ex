defmodule AshReports.Application do
  @moduledoc """
  AshReports Application - Supervisor for runtime services.

  This application module provides supervision for runtime services needed by
  AshReports, including streaming pipeline infrastructure and chart generation.

  ## Services Supervised

  - **Typst StreamingPipeline**: Manages large dataset processing with GenStage
  - **Chart Registry**: Tracks active chart instances
  - **Chart Cache**: Caches chart data for performance
  - **Performance Monitor**: Monitors system performance metrics

  ## Usage

  This application is automatically started when AshReports is used. It can also
  be started manually:

      {:ok, pid} = AshReports.Application.start(:normal, [])

  """

  use Application

  alias AshReports.Typst.StreamingPipeline
  alias AshReports.Charts.{Registry, Cache, PerformanceMonitor}

  @doc """
  Starts the AshReports application supervisor.

  Starts supervision tree with streaming pipeline, chart infrastructure, and other services.
  """
  def start(_type, _args) do
    children = build_supervision_tree()

    opts = [strategy: :one_for_one, name: AshReports.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Builds the supervision tree for AshReports runtime services.

  Includes streaming pipeline, chart infrastructure, and test endpoint when applicable.
  """
  def build_supervision_tree do
    base_children = [
      # StreamingPipeline infrastructure for large dataset processing
      {StreamingPipeline.Supervisor, []},

      # Chart generation infrastructure (Stage 3)
      {Registry, []},
      {Cache, []},
      {PerformanceMonitor, []}
    ]

    # Add test endpoint in test environment for phoenix_test compatibility
    if Mix.env() == :test do
      [AshReports.TestEndpoint | base_children]
    else
      base_children
    end
  end

end
