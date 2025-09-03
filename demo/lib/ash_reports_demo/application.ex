defmodule AshReportsDemo.Application do
  @moduledoc """
  OTP Application for AshReports Demo.
  
  Manages the lifecycle of the demo application including ETS data layer,
  data generation services, and report processing capabilities.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # ETS Data Layer for Demo
      {AshReportsDemo.EtsDataLayer, []},
      
      # Data Generation Service
      {AshReportsDemo.DataGenerator, []},
      
      # PubSub for real-time features if needed
      {Phoenix.PubSub, name: AshReportsDemo.PubSub}
    ]

    opts = [strategy: :one_for_one, name: AshReportsDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end