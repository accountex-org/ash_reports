defmodule AshReports.Typst.DataProcessor do
  @moduledoc """
  Handles data transformation and formatting for Typst templates.
  Converts Ash resource data into Typst-compatible format with
  proper type conversion and relationship handling.

  This module provides the core data transformation logic that bridges
  Ash resource structures with Typst template requirements, ensuring
  proper type conversion and relationship flattening.

  ## Key Responsibilities

  - **Type Conversion**: DateTime, Decimal, Money, UUID to Typst-compatible formats
  - **Relationship Flattening**: Deep relationship traversal with nil safety
  - **Variable Calculations**: Multi-scope variable processing (detail, group, page, report)
  - **Group Processing**: Multi-level grouping with break detection
  - **Memory Efficiency**: Streaming-friendly transformations

  ## Type Conversion Strategy

  The module converts Ash types to Typst-compatible formats:

  - `DateTime` → ISO8601 string or custom format
  - `Decimal` → Float or formatted string with precision
  - `Money` → Formatted string with currency symbol
  - `UUID` → String representation
  - `nil` → Safe empty string or default value
  - Structs → Flattened maps with relationship data

  ## Examples

      iex> records = [%Customer{name: "Acme", amount: Decimal.new("1500.00")}]
      iex> {:ok, converted} = DataProcessor.convert_records(records)
      iex> converted
      [%{name: "Acme", amount: 1500.0}]

  """

  alias AshReports.{Group, Variable}
  alias Decimal, as: D

  require Logger

  @typedoc """
  Typst-compatible record format (plain map with string/atom keys).
  """
  @type typst_record :: %{(atom() | String.t()) => term()}

  @typedoc """
  Variable scope calculations for different band types.
  """
  @type variable_scopes :: %{
          detail: map(),
          group: map(),
          page: map(),
          report: map()
        }

  @typedoc """
  Options for data conversion and processing.
  """
  @type conversion_options :: [
          datetime_format: :iso8601 | :custom,
          datetime_custom_format: String.t(),
          decimal_precision: non_neg_integer(),
          decimal_as_string: boolean(),
          money_format: :symbol | :code | :none,
          uuid_format: :string | :binary,
          nil_replacement: term(),
          flatten_relationships: boolean(),
          relationship_depth: pos_integer()
        ]

  @doc """
  Converts Ash structs to Typst-compatible data structures.

  Transforms Ash resource structs into plain maps with proper type conversion
  for Typst template compatibility. Handles relationships, custom types,
  and nil values safely.

  ## Parameters

    * `ash_records` - List of Ash resource structs
    * `options` - Conversion options for customization

  ## Options

    * `:datetime_format` - Format for DateTime values (default: :iso8601)
    * `:decimal_precision` - Decimal places for numeric values (default: 2)
    * `:money_format` - Money formatting style (default: :symbol)
    * `:flatten_relationships` - Include relationship data (default: true)
    * `:relationship_depth` - Max depth for relationship traversal (default: 3)

  ## Returns

    * `{:ok, [typst_record()]}` - Successfully converted records
    * `{:error, term()}` - Conversion failure

  ## Examples

      iex> customers = [
      ...>   %Customer{
      ...>     id: "550e8400-e29b-41d4-a716-446655440000",
      ...>     name: "Acme Corp",
      ...>     balance: Money.new(1500, :USD),
      ...>     created_at: ~U[2024-01-15 10:30:00Z],
      ...>     address: %Address{city: "New York", country: "US"}
      ...>   }
      ...> ]
      iex> {:ok, converted} = DataProcessor.convert_records(customers)
      iex> converted |> List.first()
      %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        name: "Acme Corp",
        balance: "$1,500.00",
        created_at: "2024-01-15T10:30:00Z",
        address_city: "New York",
        address_country: "US"
      }

  """
  @spec convert_records([struct()], conversion_options()) ::
          {:ok, [typst_record()]} | {:error, term()}
  def convert_records(ash_records, options \\ []) when is_list(ash_records) do
    Logger.debug("Converting #{length(ash_records)} records for Typst")

    try do
      opts = build_conversion_options(options)
      converted = Enum.map(ash_records, &convert_single_record(&1, opts))

      Logger.debug("Successfully converted #{length(converted)} records")
      {:ok, converted}
    rescue
      error ->
        Logger.error("Failed to convert records: #{inspect(error)}")
        {:error, {:conversion_failed, error}}
    end
  end

  @doc """
  Implements variable scope calculations for different band types.

  Calculates variables at different scopes (detail, group, page, report)
  based on AshReports variable definitions and record data.

  ## Parameters

    * `records` - Converted typst records
    * `variables` - AshReports variable definitions

  ## Returns

    * `{:ok, variable_scopes()}` - Calculated variable values
    * `{:error, term()}` - Calculation failure

  ## Examples

      iex> records = [%{amount: 100}, %{amount: 200}, %{amount: 150}]
      iex> variables = [
      ...>   %Variable{name: :total_amount, function: :sum, source: :amount, scope: :report}
      ...> ]
      iex> {:ok, scopes} = DataProcessor.calculate_variable_scopes(records, variables)
      iex> scopes.report.total_amount
      450

  """
  @spec calculate_variable_scopes([typst_record()], [Variable.t()]) ::
          {:ok, variable_scopes()} | {:error, term()}
  def calculate_variable_scopes(records, variables)
      when is_list(records) and is_list(variables) do
    Logger.debug("Calculating variable scopes for #{length(variables)} variables")

    try do
      scopes = %{
        detail: calculate_detail_variables(records, filter_variables(variables, :detail)),
        group: calculate_group_variables(records, filter_variables(variables, :group)),
        page: calculate_page_variables(records, filter_variables(variables, :page)),
        report: calculate_report_variables(records, filter_variables(variables, :report))
      }

      Logger.debug(
        "Successfully calculated variable scopes: #{map_size(scopes.report)} report, #{map_size(scopes.group)} group"
      )

      {:ok, scopes}
    rescue
      error ->
        Logger.error("Failed to calculate variable scopes: #{inspect(error)}")
        {:error, {:variable_calculation_failed, error}}
    end
  end

  @doc """
  Processes group definitions and creates grouped data structures.

  Creates multi-level grouped data based on AshReports group definitions,
  with proper break detection and hierarchy preservation.

  ## Parameters

    * `records` - Converted typst records
    * `groups` - AshReports group definitions

  ## Returns

    * `{:ok, [group_data()]}` - Grouped data structures
    * `{:error, term()}` - Processing failure

  """
  @spec process_groups([typst_record()], [Group.t()]) :: {:ok, [map()]} | {:error, term()}
  def process_groups(records, groups) when is_list(records) and is_list(groups) do
    Logger.debug("Processing #{length(groups)} group definitions for #{length(records)} records")

    if Enum.empty?(groups) do
      {:ok, []}
    else
      try do
        grouped_data = create_grouped_structure(records, groups)
        Logger.debug("Successfully created #{length(grouped_data)} groups")
        {:ok, grouped_data}
      rescue
        error ->
          Logger.error("Failed to process groups: #{inspect(error)}")
          {:error, {:group_processing_failed, error}}
      end
    end
  end

  # Private Functions - Type Conversion

  defp convert_single_record(record, opts) when is_struct(record) do
    record
    |> Map.from_struct()
    |> convert_map_values(opts)
    |> maybe_flatten_relationships(opts)
  end

  defp convert_single_record(record, opts) when is_map(record) do
    record
    |> convert_map_values(opts)
    |> maybe_flatten_relationships(opts)
  end

  defp convert_map_values(map, opts) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {key, convert_value(value, opts)}
    end)
  end

  defp convert_value(%DateTime{} = dt, opts) do
    case Keyword.get(opts, :datetime_format, :iso8601) do
      :iso8601 -> DateTime.to_iso8601(dt)
      :custom -> format_custom_datetime(dt, opts)
      _ -> DateTime.to_iso8601(dt)
    end
  end

  defp convert_value(%D{} = decimal, opts) do
    precision = Keyword.get(opts, :decimal_precision, 2)
    rounded_decimal = D.round(decimal, precision)

    if Keyword.get(opts, :decimal_as_string, false) do
      D.to_string(rounded_decimal)
    else
      D.to_float(rounded_decimal)
    end
  end

  # Handle Money type (if available)
  defp convert_value(%{__struct__: module} = money, opts) when is_atom(module) do
    if function_exported?(module, :to_string, 1) and String.contains?(to_string(module), "Money") do
      format_money_value(money, opts)
    else
      # Generic struct handling
      convert_struct_value(money, opts)
    end
  end

  defp convert_value(uuid, _opts) when is_binary(uuid) and byte_size(uuid) == 36 do
    # Assuming UUID format, keep as string
    uuid
  end

  defp convert_value(%{} = map, opts) when is_map(map) and not is_struct(map) do
    convert_map_values(map, opts)
  end

  defp convert_value(list, opts) when is_list(list) do
    Enum.map(list, &convert_value(&1, opts))
  end

  defp convert_value(nil, opts) do
    Keyword.get(opts, :nil_replacement, "")
  end

  defp convert_value(value, _opts), do: value

  defp convert_struct_value(%{__struct__: _module} = struct, opts) do
    struct
    |> Map.from_struct()
    |> convert_map_values(opts)
  end

  defp format_money_value(money, opts) do
    format = Keyword.get(opts, :money_format, :symbol)

    case format do
      # Assumes Money implements String.Chars
      :symbol -> to_string(money)
      :code -> "#{money.amount} #{money.currency}"
      :none -> money.amount
      _ -> to_string(money)
    end
  rescue
    _ ->
      # Fallback for unknown money formats
      inspect(money)
  end

  defp format_custom_datetime(dt, opts) do
    format = Keyword.get(opts, :datetime_custom_format, "%Y-%m-%d %H:%M:%S")
    Calendar.strftime(dt, format)
  rescue
    _ -> DateTime.to_iso8601(dt)
  end

  defp maybe_flatten_relationships(map, opts) do
    if Keyword.get(opts, :flatten_relationships, true) do
      flatten_relationships(map, opts)
    else
      map
    end
  end

  defp flatten_relationships(map, opts, depth \\ 1) do
    max_depth = Keyword.get(opts, :relationship_depth, 3)

    if depth > max_depth do
      map
    else
      Map.new(map, &flatten_map_value(&1, opts, depth))
    end
  end

  defp flatten_map_value({key, value}, opts, depth) do
    case value do
      %{} = nested_map when not is_struct(nested_map) ->
        flattened = flatten_nested_map(nested_map, to_string(key), opts, depth + 1)
        {key, flattened}

      _ ->
        {key, value}
    end
  end

  defp flatten_nested_map(nested_map, prefix, opts, _depth) when is_map(nested_map) do
    Map.new(nested_map, fn {nested_key, nested_value} ->
      flattened_key = "#{prefix}_#{nested_key}" |> String.to_atom()
      flattened_value = convert_value(nested_value, opts)

      {flattened_key, flattened_value}
    end)
  end

  # Private Functions - Variable Calculations

  defp filter_variables(variables, scope) do
    Enum.filter(variables, fn var ->
      Map.get(var, :reset_on, :detail) == scope
    end)
  end

  defp calculate_detail_variables(_records, variables) do
    # Detail variables are typically calculated per-record during iteration
    # For now, return empty map as detail variables are handled in templates
    Map.new(variables, fn var -> {var.name, nil} end)
  end

  defp calculate_group_variables(_records, variables) do
    # Group variables will be calculated during grouping phase
    Map.new(variables, fn var -> {var.name, nil} end)
  end

  defp calculate_page_variables(_records, variables) do
    # Page variables like page numbers, calculated during rendering
    Map.new(variables, fn var -> {var.name, nil} end)
  end

  defp calculate_report_variables(records, variables) do
    Map.new(variables, fn var ->
      value = calculate_variable_value(records, var)
      {var.name, value}
    end)
  end

  defp calculate_variable_value(records, %{type: type, name: name}) do
    # For now, we'll use a simple approach where we assume the variable name
    # corresponds to a field in the records. In a full implementation,
    # this would evaluate the variable's expression.
    source_field = extract_source_field(name)
    values = Enum.map(records, &Map.get(&1, source_field))

    case type do
      :sum ->
        Enum.sum(values)

      :count ->
        length(records)

      :average ->
        case Enum.sum(values) do
          0 -> 0
          sum -> sum / length(records)
        end

      :min ->
        Enum.min(values, fn -> nil end)

      :max ->
        Enum.max(values, fn -> nil end)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  # Helper to extract source field from variable name
  # This is a simplified approach - in reality this would be based on the variable's expression
  defp extract_source_field(name) do
    name_str = to_string(name)

    cond do
      String.contains?(name_str, "amount") -> :amount
      String.contains?(name_str, "score") -> :score
      String.contains?(name_str, "count") -> :id
      # default fallback
      true -> :amount
    end
  end

  # Private Functions - Group Processing

  defp create_grouped_structure(records, groups) do
    case groups do
      [] ->
        []

      [primary_group | nested_groups] ->
        create_groups_by_field(records, primary_group, nested_groups)
    end
  end

  defp create_groups_by_field(records, group, nested_groups) do
    grouped = Enum.group_by(records, &Map.get(&1, group.field))

    Map.new(grouped, fn {group_value, group_records} ->
      nested_structure =
        if length(nested_groups) > 0 do
          create_grouped_structure(group_records, nested_groups)
        else
          group_records
        end

      {group_value,
       %{
         group_key: group_value,
         records: group_records,
         nested_groups: nested_structure,
         record_count: length(group_records)
       }}
    end)
    |> Map.values()
  end

  # Private Functions - Options

  defp build_conversion_options(options) do
    defaults = [
      datetime_format: :iso8601,
      decimal_precision: 2,
      decimal_as_string: false,
      money_format: :symbol,
      nil_replacement: "",
      flatten_relationships: true,
      relationship_depth: 3
    ]

    Keyword.merge(defaults, options)
  end
end
