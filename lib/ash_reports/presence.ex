defmodule AshReports.Presence do
  @moduledoc """
  Phoenix Presence integration for AshReports LiveView features.

  Provides real-time presence tracking for dashboard collaboration,
  multi-user editing, and collaborative filtering features.
  """

  use Phoenix.Presence,
    otp_app: :ash_reports,
    pubsub_server: AshReports.PubSub

  @doc """
  Tracks a user's presence on a dashboard.
  """
  def track_dashboard_user(socket, dashboard_id, user_info) do
    track(socket, "dashboard:#{dashboard_id}", user_info.user_id, %{
      name: user_info.name,
      joined_at: DateTime.utc_now(),
      locale: user_info.locale
    })
  end

  @doc """
  Lists all users currently present on a dashboard.
  """
  def list_dashboard_users(dashboard_id) do
    list("dashboard:#{dashboard_id}")
  end

  @doc """
  Gets the count of users on a dashboard.
  """
  def dashboard_user_count(dashboard_id) do
    "dashboard:#{dashboard_id}"
    |> list()
    |> map_size()
  end
end
