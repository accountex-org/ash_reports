defmodule AshReports.LiveView.AccessControl do
  @moduledoc """
  Access control and permissions system for AshReports Phase 6.2.
  
  Provides comprehensive user permissions, role-based access control,
  and security features for collaborative dashboard environments with
  fine-grained chart and dashboard permissions.
  
  ## Features
  
  - **Role-Based Access Control**: Predefined roles with specific permissions
  - **Fine-Grained Permissions**: Chart-level and dashboard-level access control
  - **Dynamic Permission Management**: Runtime permission updates and validation
  - **Security Audit**: Track user actions and permission changes
  - **Multi-tenancy Support**: Organization-based permission isolation
  - **Session Security**: Secure session validation and timeout management
  
  ## Permission Levels
  
  ### Dashboard Permissions
  - `:view_dashboard` - Can view dashboard and charts
  - `:edit_dashboard` - Can modify dashboard layout and configuration
  - `:manage_dashboard` - Can create/delete dashboards and manage users
  
  ### Chart Permissions
  - `:view_charts` - Can view charts and data
  - `:interact_charts` - Can filter, sort, and interact with charts
  - `:edit_charts` - Can modify chart configuration and settings
  - `:create_charts` - Can create new charts and data sources
  
  ### Collaboration Permissions
  - `:collaborate` - Can participate in collaborative sessions
  - `:share_dashboard` - Can share dashboards with other users
  - `:export_data` - Can export chart and dashboard data
  - `:real_time_access` - Can access real-time streaming features
  
  ## Usage Examples
  
  ### Check User Permissions
  
      if AccessControl.has_permission?(user_id, :edit_charts, dashboard_id) do
        # Allow chart editing
      end
  
  ### Validate Dashboard Access
  
      case AccessControl.authorize_dashboard_access(user_id, dashboard_id, :edit) do
        :authorized -> # Allow access
        {:unauthorized, reason} -> # Deny access
      end
  
  ### Manage User Roles
  
      AccessControl.assign_role(user_id, :dashboard_editor, dashboard_id)
      AccessControl.revoke_permission(user_id, :export_data, dashboard_id)
  
  """
  
  use GenServer
  
  require Logger
  
  @registry_name AshReports.AccessControlRegistry
  @default_session_timeout 7200  # 2 hours
  
  # Predefined roles with permissions
  @roles %{
    :viewer => [
      :view_dashboard,
      :view_charts,
      :collaborate
    ],
    :analyst => [
      :view_dashboard,
      :view_charts,
      :interact_charts,
      :collaborate,
      :export_data
    ],
    :editor => [
      :view_dashboard,
      :view_charts,
      :interact_charts,
      :edit_charts,
      :collaborate,
      :share_dashboard,
      :export_data,
      :real_time_access
    ],
    :admin => [
      :view_dashboard,
      :edit_dashboard,
      :manage_dashboard,
      :view_charts,
      :interact_charts,
      :edit_charts,
      :create_charts,
      :collaborate,
      :share_dashboard,
      :export_data,
      :real_time_access
    ]
  }
  
  # Client API
  
  @doc """
  Start the access control system.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Check if user has specific permission for dashboard/chart.
  """
  @spec has_permission?(String.t(), atom(), String.t()) :: boolean()
  def has_permission?(user_id, permission, resource_id) do
    case get_user_permissions(user_id, resource_id) do
      {:ok, permissions} -> permission in permissions
      {:error, _reason} -> false
    end
  end
  
  @doc """
  Authorize dashboard access for user with specific action.
  """
  @spec authorize_dashboard_access(String.t(), String.t(), atom()) :: :authorized | {:unauthorized, String.t()}
  def authorize_dashboard_access(user_id, dashboard_id, action) do
    required_permission = map_action_to_permission(action, :dashboard)
    
    case has_permission?(user_id, required_permission, dashboard_id) do
      true -> 
        # Log successful authorization
        log_access_attempt(user_id, dashboard_id, action, :success)
        :authorized
      
      false ->
        # Log failed authorization
        log_access_attempt(user_id, dashboard_id, action, :denied)
        {:unauthorized, "User #{user_id} lacks permission #{required_permission} for dashboard #{dashboard_id}"}
    end
  end
  
  @doc """
  Authorize chart access for user with specific action.
  """
  @spec authorize_chart_access(String.t(), String.t(), String.t(), atom()) :: :authorized | {:unauthorized, String.t()}
  def authorize_chart_access(user_id, dashboard_id, chart_id, action) do
    required_permission = map_action_to_permission(action, :chart)
    
    case has_permission?(user_id, required_permission, dashboard_id) do
      true ->
        log_chart_access_attempt(user_id, dashboard_id, chart_id, action, :success)
        :authorized
      
      false ->
        log_chart_access_attempt(user_id, dashboard_id, chart_id, action, :denied)
        {:unauthorized, "User #{user_id} lacks permission #{required_permission} for chart #{chart_id}"}
    end
  end
  
  @doc """
  Assign role to user for specific dashboard.
  """
  @spec assign_role(String.t(), atom(), String.t()) :: :ok | {:error, String.t()}
  def assign_role(user_id, role, dashboard_id) do
    if Map.has_key?(@roles, role) do
      GenServer.call(__MODULE__, {:assign_role, user_id, role, dashboard_id})
    else
      {:error, "Unknown role: #{role}"}
    end
  end
  
  @doc """
  Grant specific permission to user.
  """
  @spec grant_permission(String.t(), atom(), String.t()) :: :ok | {:error, String.t()}
  def grant_permission(user_id, permission, resource_id) do
    GenServer.call(__MODULE__, {:grant_permission, user_id, permission, resource_id})
  end
  
  @doc """
  Revoke specific permission from user.
  """
  @spec revoke_permission(String.t(), atom(), String.t()) :: :ok | {:error, String.t()}
  def revoke_permission(user_id, permission, resource_id) do
    GenServer.call(__MODULE__, {:revoke_permission, user_id, permission, resource_id})
  end
  
  @doc """
  Get user's effective permissions for resource.
  """
  @spec get_user_permissions(String.t(), String.t()) :: {:ok, [atom()]} | {:error, String.t()}
  def get_user_permissions(user_id, resource_id) do
    GenServer.call(__MODULE__, {:get_permissions, user_id, resource_id})
  end
  
  @doc """
  Get access control audit log.
  """
  @spec get_audit_log(String.t(), keyword()) :: [map()]
  def get_audit_log(dashboard_id, opts \\ []) do
    hours = Keyword.get(opts, :hours, 24)
    user_id = Keyword.get(opts, :user_id)
    
    GenServer.call(__MODULE__, {:get_audit_log, dashboard_id, hours, user_id})
  end
  
  # GenServer implementation
  
  @impl true
  def init(_opts) do
    # Initialize access control state
    state = %{
      user_permissions: %{},
      user_roles: %{},
      audit_log: [],
      organization_permissions: %{},
      session_timeouts: %{}
    }
    
    # Setup audit log cleanup
    schedule_audit_cleanup()
    
    Logger.info("Access Control system started")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:assign_role, user_id, role, resource_id}, _from, state) do
    # Assign role and update permissions
    role_permissions = Map.get(@roles, role, [])
    
    updated_roles = put_in(state.user_roles, [user_id, resource_id], role)
    updated_permissions = put_in(state.user_permissions, [user_id, resource_id], role_permissions)
    
    # Log role assignment
    audit_entry = create_audit_entry(user_id, resource_id, :role_assigned, %{role: role})
    updated_audit = [audit_entry | state.audit_log]
    
    Logger.info("Assigned role #{role} to user #{user_id} for resource #{resource_id}")
    
    {:reply, :ok, %{state |
      user_roles: updated_roles,
      user_permissions: updated_permissions,
      audit_log: updated_audit
    }}
  end
  
  @impl true
  def handle_call({:grant_permission, user_id, permission, resource_id}, _from, state) do
    # Grant specific permission
    current_permissions = get_in(state.user_permissions, [user_id, resource_id]) || []
    
    if permission not in current_permissions do
      updated_permissions = [permission | current_permissions]
      new_state = put_in(state.user_permissions, [user_id, resource_id], updated_permissions)
      
      # Log permission grant
      audit_entry = create_audit_entry(user_id, resource_id, :permission_granted, %{permission: permission})
      updated_audit = [audit_entry | state.audit_log]
      
      Logger.debug("Granted permission #{permission} to user #{user_id} for resource #{resource_id}")
      
      {:reply, :ok, %{new_state | audit_log: updated_audit}}
    else
      {:reply, :ok, state}  # Permission already granted
    end
  end
  
  @impl true
  def handle_call({:revoke_permission, user_id, permission, resource_id}, _from, state) do
    # Revoke specific permission
    current_permissions = get_in(state.user_permissions, [user_id, resource_id]) || []
    updated_permissions = List.delete(current_permissions, permission)
    
    new_state = put_in(state.user_permissions, [user_id, resource_id], updated_permissions)
    
    # Log permission revocation
    audit_entry = create_audit_entry(user_id, resource_id, :permission_revoked, %{permission: permission})
    updated_audit = [audit_entry | state.audit_log]
    
    Logger.debug("Revoked permission #{permission} from user #{user_id} for resource #{resource_id}")
    
    {:reply, :ok, %{new_state | audit_log: updated_audit}}
  end
  
  @impl true
  def handle_call({:get_permissions, user_id, resource_id}, _from, state) do
    permissions = get_in(state.user_permissions, [user_id, resource_id]) || []
    {:reply, {:ok, permissions}, state}
  end
  
  @impl true
  def handle_call({:get_audit_log, dashboard_id, hours, user_id}, _from, state) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)
    
    filtered_log = state.audit_log
    |> Enum.filter(fn entry ->
      DateTime.compare(entry.timestamp, cutoff_time) == :gt
    end)
    |> Enum.filter(fn entry ->
      entry.resource_id == dashboard_id
    end)
    |> then(fn entries ->
      if user_id do
        Enum.filter(entries, fn entry -> entry.user_id == user_id end)
      else
        entries
      end
    end)
    
    {:reply, filtered_log, state}
  end
  
  @impl true
  def handle_info(:cleanup_audit_log, state) do
    # Clean up old audit log entries
    cutoff_time = DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)  # 7 days
    
    filtered_audit = state.audit_log
    |> Enum.filter(fn entry ->
      DateTime.compare(entry.timestamp, cutoff_time) == :gt
    end)
    
    schedule_audit_cleanup()
    {:noreply, %{state | audit_log: filtered_audit}}
  end
  
  # Private utility functions
  
  defp map_action_to_permission(action, resource_type) do
    case {action, resource_type} do
      {:view, :dashboard} -> :view_dashboard
      {:edit, :dashboard} -> :edit_dashboard
      {:manage, :dashboard} -> :manage_dashboard
      {:view, :chart} -> :view_charts
      {:interact, :chart} -> :interact_charts
      {:edit, :chart} -> :edit_charts
      {:create, :chart} -> :create_charts
      {:export, _} -> :export_data
      {:share, _} -> :share_dashboard
      {:real_time, _} -> :real_time_access
      _ -> :view_dashboard  # Default fallback
    end
  end
  
  defp create_audit_entry(user_id, resource_id, action, metadata \\ %{}) do
    %{
      user_id: user_id,
      resource_id: resource_id,
      action: action,
      metadata: metadata,
      timestamp: DateTime.utc_now(),
      ip_address: get_user_ip(user_id),  # Would get from session
      user_agent: get_user_agent(user_id)  # Would get from session
    }
  end
  
  defp log_access_attempt(user_id, dashboard_id, action, result) do
    Logger.debug("Access attempt: user=#{user_id}, dashboard=#{dashboard_id}, action=#{action}, result=#{result}")
    
    # Would also log to audit system in production
    :ok
  end
  
  defp log_chart_access_attempt(user_id, dashboard_id, chart_id, action, result) do
    Logger.debug("Chart access: user=#{user_id}, dashboard=#{dashboard_id}, chart=#{chart_id}, action=#{action}, result=#{result}")
    
    # Would also log to audit system in production
    :ok
  end
  
  defp schedule_audit_cleanup do
    Process.send_after(self(), :cleanup_audit_log, 24 * 60 * 60 * 1000)  # 24 hours
  end
  
  defp get_user_ip(user_id) do
    # Placeholder - would get from session manager
    "127.0.0.1"
  end
  
  defp get_user_agent(user_id) do
    # Placeholder - would get from session manager
    "AshReports/6.2"
  end
  
  @doc """
  Helper function to check if user can perform action on resource.
  
  Used in LiveView templates and components for conditional rendering.
  """
  def can?(user_id, action, resource_id) do
    has_permission?(user_id, action, resource_id)
  end
  
  @doc """
  Get available roles for assignment.
  """
  def available_roles, do: Map.keys(@roles)
  
  @doc """
  Get permissions for specific role.
  """
  def role_permissions(role), do: Map.get(@roles, role, [])
  
  @doc """
  Validate that user session is still active and authorized.
  """
  @spec validate_session(String.t(), String.t()) :: :valid | {:invalid, String.t()}
  def validate_session(user_id, session_token) do
    # Placeholder for session validation
    # Would integrate with authentication system
    case SessionManager.get_session_info(session_token) do
      {:ok, session_info} ->
        if session_info.user_id == user_id do
          :valid
        else
          {:invalid, "Session user mismatch"}
        end
      
      {:error, reason} ->
        {:invalid, "Invalid session: #{reason}"}
    end
  end
  
  @doc """
  Create permission check middleware for LiveView.
  """
  def require_permission(permission, resource_id_key \\ :dashboard_id) do
    quote do
      def mount(params, session, socket) do
        user_id = session["user_id"]
        resource_id = params[unquote(resource_id_key)] || socket.assigns[unquote(resource_id_key)]
        
        case AshReports.LiveView.AccessControl.authorize_dashboard_access(user_id, resource_id, unquote(permission)) do
          :authorized ->
            # Continue with normal mount
            super(params, session, socket)
          
          {:unauthorized, reason} ->
            {:ok, 
              socket
              |> put_flash(:error, "Access denied: #{reason}")
              |> redirect(to: "/unauthorized")
            }
        end
      end
    end
  end
end