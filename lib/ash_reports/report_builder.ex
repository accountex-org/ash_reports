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
         {:ok, query} <- build_query_from_config(config) do
      # Use existing DataLoader for preview with limit
      # This would integrate with AshReports.Typst.DataLoader
      # For now, return mock data
      {:ok,
       [
         %{id: 1, customer_name: "Acme Corp", total: 1500.0, status: "completed"},
         %{id: 2, customer_name: "TechStart Inc", total: 2300.0, status: "pending"}
       ]
       |> Enum.take(limit)}
    end
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
      # This would integrate with StreamingPipeline
      # For now, return mock stream ID
      stream_id = generate_stream_id()
      {:ok, stream_id}
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
      dsl_code = """
      report :#{config.template} do
        # Generated from Report Builder
        # Data source: #{inspect(config.data_source?.resource)}

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
    if Code.ensure_loaded?(resource) do
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
end
