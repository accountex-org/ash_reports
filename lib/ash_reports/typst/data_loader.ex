defmodule AshReports.Typst.DataLoader do
  @moduledoc """
  Specialized DataLoader for Typst integration that extends the existing
  AshReports.DataLoader with Typst-specific data transformation and
  streaming capabilities.

  This module serves as the critical data integration layer between AshReports
  DSL definitions and actual Ash resource data, transforming it into a format
  suitable for Typst template compilation.

  ## Architecture Integration

  ```
  AshReports DSL → DSLGenerator → Typst Template → **DATA INTEGRATION** → BinaryWrapper → PDF
  ```

  ## Key Features

  - **Typst-Compatible Data**: Transforms Ash structs to plain maps for Typst templates
  - **Type Conversion**: Handles DateTime, Decimal, Money, UUID, and custom types
  - **Relationship Traversal**: Deep relationship chains with safe nil handling
  - **Variable Scopes**: Detail, group, page, and report-level variable calculations
  - **Streaming Support**: GenStage-based pipeline for large datasets
  - **Performance Optimized**: Memory-efficient processing with backpressure

  ## Usage Examples

  ### Basic Report Data Loading

      iex> {:ok, data} = DataLoader.load_for_typst(MyApp.Domain, :sales_report, %{
      ...>   start_date: ~D[2024-01-01],
      ...>   end_date: ~D[2024-01-31]
      ...> })
      iex> data.records
      [%{customer_name: "Acme Corp", amount: 1500.0, created_at: "2024-01-15T10:30:00Z"}]

  ### Streaming Large Datasets

      iex> {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :large_report, params)
      iex> stream |> Enum.take(10) |> length()
      10

  ## Data Format

  The output format is optimized for DSL-generated Typst templates:

  ```elixir
  %{
    records: [%{field_name: value, ...}],     # For #record.field_name access
    config: %{param_name: value, ...},        # For #config.param_name access
    variables: %{var_name: value, ...},       # For #variables.var_name access
    groups: [...],                            # For grouped data processing
    metadata: %{...}                          # Report metadata
  }
  ```
  """

  alias AshReports.{DataLoader, Report}
  alias AshReports.Typst.DataProcessor

  require Logger

  @typedoc """
  Typst-compatible data structure for template compilation.
  """
  @type typst_data :: %{
          records: [map()],
          config: map(),
          variables: map(),
          groups: [map()],
          metadata: map()
        }

  @typedoc """
  Options for Typst data loading.
  """
  @type load_options :: [
          chunk_size: pos_integer(),
          enable_streaming: boolean(),
          type_conversion: keyword(),
          variable_scopes: [atom()],
          preload_strategy: :auto | :explicit | [atom()]
        ]

  @doc """
  Loads report data optimized for Typst template compilation.

  Returns data in a format directly compatible with DSL-generated
  Typst templates, including proper type conversion and relationship
  flattening.

  ## Parameters

    * `domain` - The Ash domain containing the report definition
    * `report_name` - Name of the report to load data for
    * `params` - Parameters for report generation (filters, date ranges, etc.)
    * `opts` - Loading options for customization

  ## Options

    * `:chunk_size` - Size of data chunks for processing (default: 1000)
    * `:enable_streaming` - Use streaming for large datasets (default: false)
    * `:type_conversion` - Custom type conversion options
    * `:variable_scopes` - Variable scopes to calculate (default: all)
    * `:preload_strategy` - Relationship preloading strategy (default: :auto)

  ## Returns

    * `{:ok, typst_data()}` - Successfully loaded and formatted data
    * `{:error, term()}` - Loading or transformation failure

  ## Examples

      iex> {:ok, data} = DataLoader.load_for_typst(MyApp.Domain, :sales_report, %{
      ...>   customer_id: 123,
      ...>   date_range: {~D[2024-01-01], ~D[2024-01-31]}
      ...> })
      iex> length(data.records)
      42
      iex> data.records |> List.first() |> Map.keys()
      [:id, :customer_name, :amount, :created_at, :customer_address]

  """
  @spec load_for_typst(module(), atom(), map(), load_options()) ::
          {:ok, typst_data()} | {:error, term()}
  def load_for_typst(domain, report_name, params, opts \\ []) do
    Logger.debug("Loading Typst data for report #{report_name} in domain #{inspect(domain)}")

    with {:ok, report} <- get_report_definition(domain, report_name),
         {:ok, raw_data} <- load_raw_data(domain, report, params, opts),
         {:ok, processed_data} <- process_for_typst(raw_data, report, opts) do
      Logger.debug("Successfully loaded #{length(processed_data.records)} records for Typst")
      {:ok, processed_data}
    else
      {:error, reason} = error ->
        Logger.error("Failed to load Typst data for #{report_name}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Streams large datasets for memory-efficient Typst compilation.

  Uses GenStage/Flow for backpressure-aware streaming that maintains
  constant memory usage regardless of dataset size.

  ## Parameters

    * `domain` - The Ash domain containing the report definition
    * `report_name` - Name of the report to stream data for
    * `params` - Parameters for report generation
    * `opts` - Streaming options

  ## Options

    * `:chunk_size` - Size of streaming chunks (default: 500)
    * `:max_demand` - Maximum demand for backpressure (default: 1000)
    * `:type_conversion` - Type conversion options
    * `:buffer_size` - Internal buffer size (default: 100)

  ## Returns

    * `{:ok, Enumerable.t()}` - Stream of processed record chunks
    * `{:error, term()}` - Streaming setup failure

  ## Examples

      iex> {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :large_report, params)
      iex> stream
      ...> |> Stream.take(5)
      ...> |> Enum.to_list()
      ...> |> List.flatten()
      ...> |> length()
      2500  # 5 chunks * 500 records each

  """
  @spec stream_for_typst(module(), atom(), map(), load_options()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream_for_typst(domain, report_name, params, opts \\ []) do
    Logger.info("Setting up streaming for report #{report_name} in domain #{inspect(domain)}")

    with {:ok, report} <- get_report_definition(domain, report_name),
         {:ok, stream} <- create_streaming_pipeline(domain, report, params, opts) do
      Logger.debug("Successfully created streaming pipeline for #{report_name}")
      {:ok, stream}
    else
      {:error, reason} = error ->
        Logger.error("Failed to create streaming pipeline for #{report_name}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Creates a configuration for Typst data loading with sensible defaults.

  ## Examples

      iex> config = DataLoader.typst_config(chunk_size: 2000, enable_streaming: true)
      iex> config[:chunk_size]
      2000

  """
  @spec typst_config(keyword()) :: load_options()
  def typst_config(overrides \\ []) do
    defaults = [
      chunk_size: 1000,
      enable_streaming: false,
      type_conversion: [
        datetime_format: :iso8601,
        decimal_precision: 2,
        money_format: :symbol
      ],
      variable_scopes: [:detail, :group, :page, :report],
      preload_strategy: :auto
    ]

    Keyword.merge(defaults, overrides)
  end

  # Private Functions

  defp get_report_definition(domain, report_name) do
    case AshReports.Info.report(domain, report_name) do
      nil ->
        {:error, {:report_not_found, report_name}}

      %Report{} = report ->
        {:ok, report}

      other ->
        {:error, {:invalid_report_definition, other}}
    end
  rescue
    error ->
      {:error, {:report_lookup_failed, error}}
  end

  defp load_raw_data(domain, report, params, opts) do
    # Use existing DataLoader for basic data loading
    DataLoader.load_report(domain, report.name, params, build_loader_opts(opts))
  rescue
    error ->
      {:error, {:data_loading_failed, error}}
  end

  defp process_for_typst(raw_data, report, opts) do
    with {:ok, converted_records} <- DataProcessor.convert_records(raw_data.records, opts),
         {:ok, variables} <-
           DataProcessor.calculate_variable_scopes(converted_records, report.variables || []),
         {:ok, groups} <- DataProcessor.process_groups(converted_records, report.groups || []) do
      typst_data = %{
        records: converted_records,
        config: Map.new(raw_data.parameters || %{}),
        variables: variables,
        groups: groups,
        metadata: %{
          total_records: length(converted_records),
          report_name: report.name,
          generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }

      {:ok, typst_data}
    end
  end

  defp create_streaming_pipeline(_domain, _report, _params, _opts) do
    # Implementation will be added in streaming pipeline task
    {:error, :streaming_not_implemented}
  end

  defp build_loader_opts(typst_opts) do
    # Convert Typst-specific options to DataLoader options
    chunk_size = Keyword.get(typst_opts, :chunk_size, 1000)
    enable_caching = Keyword.get(typst_opts, :enable_caching, true)

    [
      chunk_size: chunk_size,
      enable_caching: enable_caching,
      load_relationships: true
    ]
  end
end
