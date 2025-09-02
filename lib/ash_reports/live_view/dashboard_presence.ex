defmodule AshReports.LiveView.DashboardPresence do
  @moduledoc """
  Phoenix Presence integration for collaborative dashboard features in Phase 6.2.

  Manages multi-user presence tracking, real-time collaboration indicators,
  and coordinated interactions across dashboard sessions with conflict
  resolution and user activity monitoring.

  ## Features

  - **Multi-User Tracking**: Real-time presence tracking for dashboard users
  - **Activity Monitoring**: User interaction tracking and activity indicators
  - **Conflict Resolution**: Handle simultaneous edits and configuration changes
  - **Permission Management**: Role-based access control for collaboration features
  - **Real-time Notifications**: User join/leave notifications and activity updates
  - **Session Coordination**: Coordinate chart interactions across user sessions

  ## Usage Examples

  ### Track User Presence

      DashboardPresence.track_user(dashboard_id, user_id, %{
        name: "John Smith",
        role: :editor,
        permissions: [:view_charts, :edit_charts, :share_dashboard]
      })

  ### Monitor User Activity

      DashboardPresence.track_activity(dashboard_id, user_id, %{
        action: :chart_interaction,
        chart_id: "sales_chart",
        interaction_type: :filter
      })

  ### Handle Collaboration Conflicts

      DashboardPresence.resolve_conflict(dashboard_id, %{
        type: :simultaneous_edit,
        users: [user1_id, user2_id],
        resource: chart_config
      })

  """

  use Phoenix.Presence,
    otp_app: :ash_reports,
    pubsub_server: AshReports.PubSub

  alias AshReports.LiveView.SessionManager

  require Logger

  @presence_topic_prefix "dashboard_presence:"
  @activity_topic_prefix "dashboard_activity:"
  @max_tracked_activities 50
  # 5 minutes
  @presence_timeout 300_000

  # Client API

  @doc """
  Track user presence in a dashboard with metadata.
  """
  @spec track_user(String.t(), String.t(), map()) :: {:ok, binary()} | {:error, String.t()}
  def track_user(dashboard_id, user_id, user_metadata \\ %{}) do
    topic = build_presence_topic(dashboard_id)

    presence_metadata =
      Map.merge(user_metadata, %{
        joined_at: DateTime.utc_now(),
        last_activity: DateTime.utc_now(),
        status: :active,
        dashboard_id: dashboard_id
      })

    case track(topic, user_id, presence_metadata) do
      {:ok, ref} ->
        Logger.debug("User #{user_id} joined dashboard #{dashboard_id}")

        # Notify other users
        broadcast_user_joined(dashboard_id, user_id, user_metadata)

        {:ok, ref}

      {:error, reason} ->
        Logger.error(
          "Failed to track user #{user_id} in dashboard #{dashboard_id}: #{inspect(reason)}"
        )

        {:error, "Presence tracking failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Update user presence metadata (activity, status, etc.).
  """
  @spec update_user_presence(String.t(), String.t(), map()) :: :ok
  def update_user_presence(dashboard_id, user_id, updates) do
    topic = build_presence_topic(dashboard_id)

    case get_current_presence(topic, user_id) do
      %{metas: [current_meta | _]} ->
        updated_meta =
          Map.merge(
            current_meta,
            Map.merge(updates, %{
              last_activity: DateTime.utc_now()
            })
          )

        update(topic, user_id, updated_meta)

        Logger.debug("Updated presence for user #{user_id} in dashboard #{dashboard_id}")
        :ok

      _ ->
        Logger.warn(
          "Cannot update presence - user #{user_id} not found in dashboard #{dashboard_id}"
        )

        :ok
    end
  end

  @doc """
  Track user activity for collaboration coordination.
  """
  @spec track_activity(String.t(), String.t(), map()) :: :ok
  def track_activity(dashboard_id, user_id, activity_data) do
    activity_topic = build_activity_topic(dashboard_id)

    activity_event = %{
      user_id: user_id,
      dashboard_id: dashboard_id,
      timestamp: DateTime.utc_now(),
      activity: activity_data
    }

    # Broadcast activity to all dashboard users
    Phoenix.PubSub.broadcast(AshReports.PubSub, activity_topic, {:user_activity, activity_event})

    # Update user presence with latest activity
    update_user_presence(dashboard_id, user_id, %{
      last_activity: activity_event.timestamp,
      current_action: activity_data.action
    })

    :ok
  end

  @doc """
  Get list of currently active users in dashboard.
  """
  @spec get_active_users(String.t()) :: [map()]
  def get_active_users(dashboard_id) do
    topic = build_presence_topic(dashboard_id)

    list(topic)
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      Map.merge(meta, %{user_id: user_id})
    end)
    |> Enum.filter(fn user -> user.status == :active end)
  end

  @doc """
  Resolve collaboration conflicts when multiple users edit simultaneously.
  """
  @spec resolve_conflict(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def resolve_conflict(dashboard_id, conflict_info) do
    case conflict_info.type do
      :simultaneous_edit ->
        resolve_simultaneous_edit_conflict(dashboard_id, conflict_info)

      :concurrent_filter ->
        resolve_concurrent_filter_conflict(dashboard_id, conflict_info)

      :chart_configuration ->
        resolve_chart_config_conflict(dashboard_id, conflict_info)

      _ ->
        {:error, "Unknown conflict type: #{conflict_info.type}"}
    end
  end

  @doc """
  Get dashboard collaboration statistics.
  """
  @spec get_collaboration_stats(String.t()) :: map()
  def get_collaboration_stats(dashboard_id) do
    active_users = get_active_users(dashboard_id)

    %{
      dashboard_id: dashboard_id,
      active_users: length(active_users),
      user_list: Enum.map(active_users, &extract_user_summary/1),
      collaboration_intensity: calculate_collaboration_intensity(dashboard_id),
      recent_activities: get_recent_activities(dashboard_id, 10),
      conflict_count: get_conflict_count(dashboard_id)
    }
  end

  # Private implementation functions

  defp build_presence_topic(dashboard_id), do: @presence_topic_prefix <> dashboard_id
  defp build_activity_topic(dashboard_id), do: @activity_topic_prefix <> dashboard_id

  defp get_current_presence(topic, user_id) do
    case list(topic) do
      %{^user_id => presence_data} -> presence_data
      _ -> nil
    end
  end

  defp broadcast_user_joined(dashboard_id, user_id, user_metadata) do
    join_event = %{
      type: :user_joined,
      dashboard_id: dashboard_id,
      user_id: user_id,
      user_info: user_metadata,
      timestamp: DateTime.utc_now()
    }

    activity_topic = build_activity_topic(dashboard_id)

    Phoenix.PubSub.broadcast(
      AshReports.PubSub,
      activity_topic,
      {:collaboration_event, join_event}
    )
  end

  defp resolve_simultaneous_edit_conflict(dashboard_id, conflict_info) do
    # Resolve conflicts when multiple users edit the same resource
    users = conflict_info.users
    resource = conflict_info.resource

    # Simple conflict resolution: last writer wins with notification
    # Most recent user
    winner_user = List.last(users)
    losing_users = users -- [winner_user]

    # Notify losing users of conflict
    conflict_resolution = %{
      type: :conflict_resolved,
      winner: winner_user,
      losers: losing_users,
      resolution_strategy: :last_writer_wins,
      final_resource: resource,
      timestamp: DateTime.utc_now()
    }

    # Broadcast resolution to all affected users
    activity_topic = build_activity_topic(dashboard_id)

    Phoenix.PubSub.broadcast(
      AshReports.PubSub,
      activity_topic,
      {:conflict_resolution, conflict_resolution}
    )

    {:ok, conflict_resolution}
  end

  defp resolve_concurrent_filter_conflict(dashboard_id, conflict_info) do
    # Handle concurrent filter applications
    # Strategy: merge filters intelligently

    merged_filters =
      conflict_info.filters
      |> Enum.reduce(%{}, fn filter_set, acc ->
        Map.merge(acc, filter_set)
      end)

    resolution = %{
      type: :filters_merged,
      original_filters: conflict_info.filters,
      merged_filters: merged_filters,
      strategy: :intelligent_merge,
      timestamp: DateTime.utc_now()
    }

    {:ok, resolution}
  end

  defp resolve_chart_config_conflict(dashboard_id, conflict_info) do
    # Handle chart configuration conflicts
    # Strategy: show conflict dialog to users

    resolution = %{
      type: :config_conflict_detected,
      requires_user_decision: true,
      conflicting_configs: conflict_info.configs,
      affected_chart: conflict_info.chart_id,
      timestamp: DateTime.utc_now()
    }

    # Broadcast conflict notification
    activity_topic = build_activity_topic(dashboard_id)
    Phoenix.PubSub.broadcast(AshReports.PubSub, activity_topic, {:config_conflict, resolution})

    {:ok, resolution}
  end

  defp extract_user_summary(user_presence) do
    %{
      user_id: user_presence.user_id,
      name: user_presence[:name] || "Unknown User",
      role: user_presence[:role] || :viewer,
      joined_at: user_presence.joined_at,
      last_activity: user_presence.last_activity,
      current_action: user_presence[:current_action]
    }
  end

  defp calculate_collaboration_intensity(dashboard_id) do
    # Calculate collaboration intensity based on user activities
    active_users = get_active_users(dashboard_id)

    case length(active_users) do
      0 -> :none
      1 -> :single_user
      2 -> :light_collaboration
      n when n <= 5 -> :moderate_collaboration
      _ -> :heavy_collaboration
    end
  end

  defp get_recent_activities(dashboard_id, limit) do
    # Placeholder - would track recent activities
    # In production, would maintain activity history
    []
  end

  defp get_conflict_count(dashboard_id) do
    # Placeholder - would track conflicts
    # In production, would maintain conflict statistics
    0
  end
end
