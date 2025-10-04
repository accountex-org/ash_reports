defmodule AshReports.ReportBuilder do
  @moduledoc """
  Business logic for interactive report building and configuration.

  This module provides high-level operations for the report builder interface,
  delegating to appropriate modules for specific functionality while maintaining
  a clean separation between UI concerns and business logic.

  ## Responsibilities

  - Report configuration validation and management
  - Template selection and configuration
  - Data source configuration from Ash resources
  - Field mapping and transformation setup
  - Report generation orchestration
  - Preview data generation

  ## Usage

      # Validate configuration
      {:ok, validated} = ReportBuilder.validate_config(config)

      # Select a template
      {:ok, config} = ReportBuilder.select_template("sales_report")

      # Configure data source
      {:ok, config} = ReportBuilder.configure_data_source(config, %{
        resource: MyApp.Sales.Order,
        filters: %{status: "completed"}
      })

      # Generate preview
      {:ok, preview_data} = ReportBuilder.generate_preview(config, limit: 100)

      # Start report generation
      {:ok, stream_id} = ReportBuilder.start_generation(config, async: true)
  """

  alias AshReports.Report

  @type config :: %{
          template: atom() | nil,
          data_source: map() | nil,
          field_mappings: map() | nil,
          visualizations: list() | nil,
          metadata: map()
        }

  @type validation_error :: {:error, term()}

  @doc """
  Validates a report configuration.

  ## Parameters

    * `config` - Report configuration map

  ## Returns

    * `{:ok, validated_config}` - Configuration is valid
    * `{:error, errors}` - Validation failed with error details

  ## Examples

      iex> ReportBuilder.validate_config(%{template: :sales_report, data_source: %{}})
      {:ok, %{template: :sales_report, data_source: %{}, ...}}

      iex> ReportBuilder.validate_config(%{})
      {:error, %{template: ["is required"]}}
  """
  @spec validate_config(config()) :: {:ok, config()} | validation_error()
  def validate_config(config) do
    errors = []

    errors =
      if is_nil(config[:template]) do
        [{:template, "is required"} | errors]
      else
        errors
      end

    if Enum.empty?(errors) do
      {:ok, Map.put_new(config, :metadata, %{})}
    else
      {:error, Map.new(errors)}
    end
  end

  @doc """
  Selects a report template and returns base configuration.

  ## Parameters

    * `template_name` - Atom or string identifying the template

  ## Returns

    * `{:ok, config}` - Template loaded successfully
    * `{:error, reason}` - Template not found or invalid

  ## Examples

      iex> ReportBuilder.select_template(:sales_report)
      {:ok, %{template: :sales_report, data_source: nil, ...}}
  """
  @spec select_template(atom() | String.t()) :: {:ok, config()} | {:error, term()}
  def select_template(template_name) when is_binary(template_name) do
    select_template(String.to_existing_atom(template_name))
  rescue
    ArgumentError -> {:error, :invalid_template_name}
  end

  def select_template(template_name) when is_atom(template_name) do
    # For now, return basic template config
    # In future, this would load from template registry
    {:ok,
     %{
       template: template_name,
       data_source: nil,
       field_mappings: %{},
       visualizations: [],
       metadata: %{created_at: DateTime.utc_now()}
     }}
  end

  @doc """
  Configures the data source for a report.

  ## Parameters

    * `config` - Current report configuration
    * `data_source_params` - Data source configuration with:
      - `:resource` - Ash resource module
      - `:filters` - Filter parameters (optional)
      - `:relationships` - Relationships to preload (optional)

  ## Returns

    * `{:ok, updated_config}` - Data source configured
    * `{:error, reason}` - Configuration failed

  ## Examples

      iex> config = %{template: :sales_report}
      iex> ReportBuilder.configure_data_source(config, %{
      ...>   resource: MyApp.Sales.Order,
      ...>   filters: %{status: "completed"}
      ...> })
      {:ok, %{template: :sales_report, data_source: %{...}}}
  """
  @spec configure_data_source(config(), map()) :: {:ok, config()} | {:error, term()}
  def configure_data_source(config, data_source_params) do
    with {:ok, resource} <- validate_resource(data_source_params[:resource]),
         {:ok, filters} <- validate_filters(data_source_params[:filters] || %{}) do
      data_source_config = %{
        resource: resource,
        filters: filters,
        relationships: data_source_params[:relationships] || []
      }

      {:ok, Map.put(config, :data_source, data_source_config)}
    end
  end

  @doc """
  Generates preview data for a report configuration.

  ## Parameters

    * `config` - Report configuration
    * `opts` - Options:
      - `:limit` - Maximum records to return (default: 100)
      - `:sample` - Use sampling for large datasets (default: true)

  ## Returns

    * `{:ok, preview_data}` - List of preview records
    * `{:error, reason}` - Preview generation failed

  ## Examples

      iex> ReportBuilder.generate_preview(config, limit: 50)
      {:ok, [%{customer_name: "...", total: 150.0}, ...]}
  """
  @spec generate_preview(config(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def generate_preview(config, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    with {:ok, _} <- validate_config(config),
         {:ok, data} <- load_preview_data(config, limit) do
      {:ok, data}
    end
  end

  defp load_preview_data(config, limit) do
    case config[:data_source] do
      nil ->
        # No data source configured, return mock data
        {:ok,
         [
           %{id: 1, name: "Sample Item 1", status: "active"},
           %{id: 2, name: "Sample Item 2", status: "pending"}
         ]
         |> Enum.take(limit)}

      %{resource: resource, filters: filters} ->
        # Load real data from Ash resource
        load_from_resource(resource, filters, limit)

      %{resource: resource} ->
        # Load without filters
        load_from_resource(resource, %{}, limit)
    end
  end

  defp load_from_resource(resource, filters, limit) do
    # Get the domain from the resource or use a provided domain option
    domain = Ash.Resource.Info.domain(resource)

    query =
      resource
      |> Ash.Query.limit(limit)
      |> apply_filters(filters)

    # Use domain-aware read if available, otherwise fallback to mock data
    read_opts = if domain, do: [domain: domain], else: []

    case Ash.read(query, read_opts) do
      {:ok, records} ->
        # Convert Ash records to maps for preview
        preview_data =
          Enum.map(records, fn record ->
            record
            |> Map.from_struct()
            |> Map.drop([:__meta__, :__metadata__, :aggregates, :calculations])
          end)

        {:ok, preview_data}

      {:error, error} ->
        {:error, {:preview_load_failed, error}}
    end
  rescue
    ArgumentError ->
      # If domain is not available, return mock data
      {:ok,
       [
         %{id: 1, name: "Sample Item 1", status: "active"},
         %{id: 2, name: "Sample Item 2", status: "pending"}
       ]
       |> Enum.take(limit)}

    error ->
      {:error, {:preview_error, error}}
  end

  defp apply_filters(query, filters) when map_size(filters) == 0, do: query

  defp apply_filters(query, filters) do
    import Ash.Expr

    Enum.reduce(filters, query, fn {field, value}, acc_query ->
      Ash.Query.filter(acc_query, expr(^ref(field) == ^value))
    end)
  end

  @doc """
  Starts report generation with progress tracking.

  ## Parameters

    * `config` - Report configuration
    * `opts` - Generation options:
      - `:async` - Generate asynchronously (default: true)
      - `:progress_callback` - Function called with progress updates
      - `:format` - Output format (:pdf, :html, etc.)

  ## Returns

    * `{:ok, stream_id}` - Generation started, stream ID for tracking
    * `{:error, reason}` - Generation failed to start

  ## Examples

      iex> ReportBuilder.start_generation(config, async: true)
      {:ok, "stream_abc123"}
  """
  @spec start_generation(config(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def start_generation(config, opts \\ []) do
    with {:ok, _} <- validate_config(config),
         {:ok, _query} <- build_query_from_config(config) do
      # Generate unique report ID
      report_id = generate_report_id()

      # Start progress tracking (if ProgressTracker is available)
      tracker_id =
        case start_progress_tracking(report_id, opts) do
          {:ok, id} -> id
          {:error, _} -> generate_stream_id()
        end

      # In MVP: simulate async report generation
      # In production: integrate with StreamingPipeline
      if Keyword.get(opts, :async, true) do
        Task.start(fn -> simulate_report_generation(tracker_id) end)
      end

      {:ok, tracker_id}
    end
  end

  @doc """
  Exports report configuration as DSL code.

  Converts the configuration map into AshReports DSL format.

  ## Parameters

    * `config` - Report configuration to export

  ## Returns

    * `{:ok, dsl_code}` - DSL code as string
    * `{:error, reason}` - Export failed

  ## Examples

      iex> ReportBuilder.export_as_dsl(config)
      {:ok, \"\"\"
      report :sales_report do
        # ... DSL code
      end
      \"\"\"}
  """
  @spec export_as_dsl(config()) :: {:ok, String.t()} | {:error, term()}
  def export_as_dsl(config) do
    with {:ok, _} <- validate_config(config) do
      # Generate DSL code from config
      resource = get_in(config, [:data_source, :resource])

      dsl_code = """
      report :#{config.template} do
        # Generated from Report Builder
        # Data source: #{inspect(resource)}

        # Add DSL configuration here
      end
      """

      {:ok, dsl_code}
    end
  end

  # Private Functions

  defp validate_resource(nil), do: {:error, :resource_required}

  defp validate_resource(resource) when is_atom(resource) do
    # Check if module exists and is an Ash resource
    if Code.ensure_loaded?(resource) and Ash.Resource.Info.resource?(resource) do
      {:ok, resource}
    else
      {:error, :invalid_resource}
    end
  end

  defp validate_resource(_), do: {:error, :invalid_resource}

  defp validate_filters(filters) when is_map(filters), do: {:ok, filters}
  defp validate_filters(_), do: {:error, :invalid_filters}

  defp build_query_from_config(_config) do
    # This would build an Ash query from the configuration
    # For now, return success
    {:ok, :query_placeholder}
  end

  defp generate_stream_id do
    "stream_" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  defp generate_report_id do
    "report_" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  defp start_progress_tracking(report_id, opts) do
    try do
      AshReports.ReportBuilder.ProgressTracker.start_tracking(report_id,
        total_records: Keyword.get(opts, :total_records, 0)
      )
    catch
      :exit, {:noproc, _} ->
        # ProgressTracker not running (e.g., in tests)
        {:error, :tracker_not_available}
    end
  end

  # Simulates report generation with progress updates
  # In production, this would be replaced with actual StreamingPipeline integration
  defp simulate_report_generation(tracker_id) do
    # Simulate processing in steps
    total_steps = 10

    Enum.each(1..total_steps, fn step ->
      # Simulate processing time
      Process.sleep(500)

      # Update progress (silently fail if tracker not available)
      progress = round(step / total_steps * 100)

      try do
        AshReports.ReportBuilder.ProgressTracker.update_progress(tracker_id,
          progress: progress,
          processed: step * 100
        )
      catch
        :exit, {:noproc, _} -> :ok
      end
    end)

    # Mark as completed
    try do
      AshReports.ReportBuilder.ProgressTracker.complete(tracker_id)
    catch
      :exit, {:noproc, _} -> :ok
    end
  end
end
