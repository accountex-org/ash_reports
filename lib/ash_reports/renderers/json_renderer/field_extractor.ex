defmodule AshReports.JsonRenderer.FieldExtractor do
  @moduledoc """
  Extracts field sources from report band definitions.

  This module analyzes a report's band structure to determine which fields
  should be included in JSON output, ensuring the JSON matches the report
  definition rather than exposing all resource fields.
  """

  alias AshReports.{Report, Band}

  @doc """
  Extracts all field sources from a report's detail bands.

  Returns a list of field source atoms/paths that should be included in JSON output.

  ## Examples

      field_sources = FieldExtractor.extract_detail_fields(report)
      # => [:name, :customer_health_score, :customer_tier, :credit_limit]

  """
  @spec extract_detail_fields(Report.t()) :: [atom() | [atom()]]
  def extract_detail_fields(%Report{} = report) do
    report
    |> Report.get_bands_by_type(:detail)
    |> Enum.flat_map(&extract_fields_from_band/1)
    |> Enum.uniq()
  end

  @doc """
  Extracts all field sources from all bands in a report.

  Includes fields from detail, group_header, group_footer, and summary bands.
  """
  @spec extract_all_fields(Report.t()) :: [atom() | [atom()]]
  def extract_all_fields(%Report{} = report) do
    band_types = [:detail, :group_header, :group_footer, :summary, :title]

    band_types
    |> Enum.flat_map(fn type -> Report.get_bands_by_type(report, type) end)
    |> Enum.flat_map(&extract_fields_from_band/1)
    |> Enum.uniq()
  end

  @doc """
  Extracts field sources from a single band and its nested structures.
  """
  @spec extract_fields_from_band(Band.t()) :: [atom() | [atom()]]
  def extract_fields_from_band(%Band{} = band) do
    # Extract from direct elements
    direct_fields = extract_fields_from_elements(band.elements || [])

    # Extract from tables
    table_fields =
      (band.tables || [])
      |> Enum.flat_map(&extract_fields_from_table/1)

    # Extract from grids
    grid_fields =
      (band.grids || [])
      |> Enum.flat_map(&extract_fields_from_grid/1)

    # Extract from stacks
    stack_fields =
      (band.stacks || [])
      |> Enum.flat_map(&extract_fields_from_stack/1)

    # Extract from nested bands
    nested_fields =
      (band.bands || [])
      |> Enum.flat_map(&extract_fields_from_band/1)

    direct_fields ++ table_fields ++ grid_fields ++ stack_fields ++ nested_fields
  end

  @doc """
  Filters a record to only include the specified field sources.

  If field_sources is empty, returns the original record unchanged.

  ## Examples

      filtered = FieldExtractor.filter_record(record, [:name, :email])
      # => %{name: "John", email: "john@example.com"}

  """
  @spec filter_record(map(), [atom() | [atom()]]) :: map()
  def filter_record(record, []) when is_map(record) do
    # No field sources specified - return record as-is (for backwards compatibility)
    record
  end

  def filter_record(record, field_sources) when is_map(record) do
    field_sources
    |> Enum.reduce(%{}, fn source, acc ->
      value = get_field_value(record, source)

      # Include nil values too - they're valid field values
      key = field_key(source)
      Map.put(acc, key, value)
    end)
  end

  @doc """
  Filters a list of records to only include specified field sources.

  If field_sources is empty, returns the original records unchanged.
  """
  @spec filter_records([map()], [atom() | [atom()]]) :: [map()]
  def filter_records(records, []) when is_list(records) do
    # No field sources specified - return records as-is
    records
  end

  def filter_records(records, field_sources) when is_list(records) do
    Enum.map(records, &filter_record(&1, field_sources))
  end

  # Private functions

  defp extract_fields_from_elements(elements) when is_list(elements) do
    elements
    |> Enum.filter(&field_element?/1)
    |> Enum.map(&get_source/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_fields_from_table(table) do
    elements = Map.get(table, :elements) || []
    row_entities = Map.get(table, :row_entities) || []
    table_cells = Map.get(table, :table_cells) || []

    element_fields = extract_fields_from_elements(elements)

    row_fields =
      row_entities
      |> Enum.flat_map(fn row ->
        row_elements = Map.get(row, :elements) || []
        extract_fields_from_elements(row_elements)
      end)

    cell_fields =
      table_cells
      |> Enum.flat_map(fn cell ->
        cell_elements = Map.get(cell, :elements) || []
        extract_fields_from_elements(cell_elements)
      end)

    element_fields ++ row_fields ++ cell_fields
  end

  defp extract_fields_from_grid(grid) do
    elements = Map.get(grid, :elements) || []
    grid_cells = Map.get(grid, :grid_cells) || []

    element_fields = extract_fields_from_elements(elements)

    cell_fields =
      grid_cells
      |> Enum.flat_map(fn cell ->
        cell_elements = Map.get(cell, :elements) || []
        extract_fields_from_elements(cell_elements)
      end)

    element_fields ++ cell_fields
  end

  defp extract_fields_from_stack(stack) do
    elements = Map.get(stack, :elements) || []
    extract_fields_from_elements(elements)
  end

  defp field_element?(element) do
    # Check if element has a :source key (field elements)
    Map.has_key?(element, :source) and Map.get(element, :source) != nil
  end

  defp get_source(element) do
    Map.get(element, :source)
  end

  defp get_field_value(record, source) when is_atom(source) do
    # Handle struct conversion if needed
    data = if is_struct(record), do: Map.from_struct(record), else: record
    Map.get(data, source)
  end

  defp get_field_value(record, source) when is_list(source) do
    # Navigate nested path like [:customer, :name]
    data = if is_struct(record), do: Map.from_struct(record), else: record

    Enum.reduce_while(source, data, fn key, acc ->
      case acc do
        %{} = map ->
          value = Map.get(map, key)
          if is_nil(value), do: {:halt, nil}, else: {:cont, value}

        _ ->
          {:halt, nil}
      end
    end)
  end

  defp field_key(source) when is_atom(source), do: source

  defp field_key(source) when is_list(source) do
    # For nested paths, use the last element as the key
    # e.g., [:customer, :name] becomes :name
    List.last(source)
  end
end
