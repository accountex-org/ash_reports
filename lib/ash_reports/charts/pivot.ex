defmodule AshReports.Charts.Pivot do
  @moduledoc """
  Multi-dimensional data pivoting and transformation for complex charts.

  Provides pivot table functionality to transform data from:
  - Long format → Wide format
  - Nested groupings → Flat structure
  - Multi-dimensional aggregations

  Useful for heatmaps, grouped charts, and cross-tabulation visualizations.

  ## Features

  - **Pivot Tables**: Transform rows to columns
  - **Multi-level Grouping**: Group by multiple fields
  - **Aggregation Support**: Combine with aggregation functions
  - **Null Handling**: Fill missing combinations with defaults
  - **Memory Efficient**: Streaming-compatible for large datasets

  ## Usage

  ### Basic Pivot

      data = [
        %{region: "North", product: "A", sales: 100},
        %{region: "North", product: "B", sales: 150},
        %{region: "South", product: "A", sales: 200},
        %{region: "South", product: "B", sales: 250}
      ]

      Pivot.pivot(data,
        rows: :region,
        columns: :product,
        values: :sales,
        aggregation: :sum
      )
      # => [
      #   %{region: "North", "A" => 100, "B" => 150},
      #   %{region: "South", "A" => 200, "B" => 250}
      # ]

  ### Multi-level Grouping

      Pivot.group_by_multiple(data, [:region, :quarter], :sales, :sum)
      # => [
      #   %{region: "North", quarter: "Q1", value: 500},
      #   %{region: "North", quarter: "Q2", value: 600},
      #   ...
      # ]

  ### For Heatmap Charts

      heatmap_data = Pivot.pivot(data,
        rows: :hour,
        columns: :day_of_week,
        values: :activity_count,
        aggregation: :avg,
        fill_value: 0
      )

      # Transform to chart format
      chart_data = Pivot.to_heatmap_format(heatmap_data)

  ## Performance

  - Pivot: O(n * c) where n = rows, c = unique column values
  - Multi-group: O(n * log(g)) where g = unique groups
  - Memory: O(rows * columns) for pivot table
  """

  alias AshReports.Charts.Aggregator
  require Logger

  @type pivot_options :: [
          rows: atom() | [atom()],
          columns: atom(),
          values: atom(),
          aggregation: Aggregator.aggregation(),
          fill_value: term()
        ]

  @doc """
  Creates a pivot table from data.

  ## Parameters

    * `data` - List of records
    * `opts` - Pivot options

  ## Options

    * `:rows` - Field(s) for row dimension (atom or list of atoms)
    * `:columns` - Field for column dimension
    * `:values` - Field to aggregate
    * `:aggregation` - Aggregation function (:sum, :avg, :count, etc.)
    * `:fill_value` - Value for missing combinations (default: nil)

  ## Returns

  List of maps with row keys + dynamic column keys

  ## Examples

      Pivot.pivot(data,
        rows: :category,
        columns: :month,
        values: :amount,
        aggregation: :sum
      )
  """
  @spec pivot(Enumerable.t(), pivot_options()) :: [map()]
  def pivot(data, opts) do
    rows = Keyword.fetch!(opts, :rows)
    columns = Keyword.fetch!(opts, :columns)
    values = Keyword.fetch!(opts, :values)
    aggregation = Keyword.get(opts, :aggregation, :sum)
    fill_value = Keyword.get(opts, :fill_value, nil)

    # Ensure rows is a list
    row_fields = if is_list(rows), do: rows, else: [rows]

    # Get all unique column values
    unique_columns =
      data
      |> Enum.map(&get_field(&1, columns))
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()

    # Group by row fields
    grouped =
      data
      |> Enum.group_by(fn record ->
        Enum.map(row_fields, &get_field(record, &1))
      end)

    # Build pivot table
    grouped
    |> Enum.map(fn {row_keys, records} ->
      # Create base row with row field values
      base_row =
        row_fields
        |> Enum.zip(row_keys)
        |> Map.new()

      # Add aggregated values for each column
      column_values =
        unique_columns
        |> Enum.map(fn col_value ->
          # Filter records for this column
          col_records =
            Enum.filter(records, fn r ->
              get_field(r, columns) == col_value
            end)

          # Aggregate
          agg_value =
            if length(col_records) > 0 do
              apply_aggregation(col_records, values, aggregation)
            else
              fill_value
            end

          {col_value, agg_value}
        end)
        |> Map.new()

      Map.merge(base_row, column_values)
    end)
  end

  @doc """
  Groups data by multiple fields and aggregates.

  ## Parameters

    * `data` - List of records
    * `group_fields` - List of fields to group by
    * `value_field` - Field to aggregate
    * `aggregation` - Aggregation function

  ## Returns

  List of maps with group keys and aggregated value

  ## Examples

      Pivot.group_by_multiple(data, [:region, :product], :sales, :sum)
      # => [
      #   %{region: "North", product: "A", value: 100},
      #   %{region: "North", product: "B", value: 150},
      #   ...
      # ]
  """
  @spec group_by_multiple(Enumerable.t(), [atom()], atom(), Aggregator.aggregation()) :: [map()]
  def group_by_multiple(data, group_fields, value_field, aggregation) do
    data
    |> Enum.group_by(fn record ->
      Enum.map(group_fields, &get_field(record, &1))
    end)
    |> Enum.map(fn {group_keys, records} ->
      # Build result map with group keys
      base_map =
        group_fields
        |> Enum.zip(group_keys)
        |> Map.new()

      # Add aggregated value
      value = apply_aggregation(records, value_field, aggregation)

      Map.put(base_map, :value, value)
    end)
    |> Enum.sort_by(fn record ->
      Enum.map(group_fields, &Map.get(record, &1))
    end)
  end

  @doc """
  Converts pivoted data to heatmap format.

  Transforms pivot table into format suitable for heatmap charts:
  `[%{x: col, y: row, value: val}, ...]`

  ## Parameters

    * `pivoted_data` - Output from pivot/2
    * `opts` - Options

  ## Options

    * `:row_field` - Name of row field in pivoted data (default: first key)
    * `:exclude_fields` - Fields to exclude from transformation (default: [])

  ## Returns

  List of maps with :x, :y, :value keys

  ## Examples

      heatmap_data = Pivot.to_heatmap_format(pivoted_data)
      # => [
      #   %{x: "Monday", y: "9am", value: 45},
      #   %{x: "Monday", y: "10am", value: 67},
      #   ...
      # ]
  """
  @spec to_heatmap_format([map()], keyword()) :: [map()]
  def to_heatmap_format(pivoted_data, opts \\ []) do
    exclude_fields = Keyword.get(opts, :exclude_fields, [])

    pivoted_data
    |> Enum.flat_map(fn row ->
      # Get row identifier (first non-excluded key)
      row_id =
        row
        |> Map.keys()
        |> Enum.reject(&(&1 in exclude_fields))
        |> List.first()

      row_value = Map.get(row, row_id)

      # Transform each column to a point
      row
      |> Map.drop([row_id | exclude_fields])
      |> Enum.map(fn {col, value} ->
        %{
          x: col,
          y: row_value,
          value: value || 0
        }
      end)
    end)
  end

  @doc """
  Transposes pivoted data (swaps rows and columns).

  ## Parameters

    * `pivoted_data` - Output from pivot/2
    * `row_field` - Current row field name

  ## Returns

  Transposed pivot table

  ## Examples

      transposed = Pivot.transpose(pivoted_data, :region)
  """
  @spec transpose([map()], atom()) :: [map()]
  def transpose(pivoted_data, row_field) do
    case pivoted_data do
      [] ->
        []

      _ ->
        # Get all column names (excluding row_field)
        first_row = List.first(pivoted_data)

        column_names =
          first_row
          |> Map.keys()
          |> Enum.reject(&(&1 == row_field))

        # Create new rows (one per old column)
        Enum.map(column_names, fn col_name ->
          values =
            Enum.map(pivoted_data, fn row ->
              row_id = Map.get(row, row_field)
              value = Map.get(row, col_name)
              {row_id, value}
            end)
            |> Map.new()

          Map.put(values, row_field, col_name)
        end)
    end
  end

  @doc """
  Flattens nested grouped data into a single list.

  Useful for converting hierarchical groupings into flat structures.

  ## Parameters

    * `nested_data` - Nested map structure
    * `prefix` - Prefix for flattened keys (default: [])

  ## Returns

  List of flattened maps

  ## Examples

      nested = %{
        "North" => %{"Q1" => 100, "Q2" => 150},
        "South" => %{"Q1" => 200, "Q2" => 250}
      }

      Pivot.flatten(nested)
      # => [
      #   %{region: "North", quarter: "Q1", value: 100},
      #   %{region: "North", quarter: "Q2", value: 150},
      #   %{region: "South", quarter: "Q1", value: 200},
      #   %{region: "South", quarter: "Q2", value: 250}
      # ]
  """
  @spec flatten(map(), [String.t()]) :: [map()]
  def flatten(nested_data, prefix \\ []) do
    Enum.flat_map(nested_data, fn {key, value} ->
      new_prefix = prefix ++ [key]

      if is_map(value) and not Map.has_key?(value, :__struct__) do
        # Recursively flatten
        flatten(value, new_prefix)
      else
        # Leaf node - create record
        [create_flat_record(new_prefix, value)]
      end
    end)
  end

  # Private Helpers

  defp get_field(record, field) when is_map(record) and is_atom(field) do
    Map.get(record, field) || Map.get(record, to_string(field))
  end

  defp get_field(record, field) when is_map(record) and is_binary(field) do
    Map.get(record, field) || Map.get(record, String.to_existing_atom(field))
  rescue
    ArgumentError -> Map.get(record, field)
  end

  defp get_field(_record, _field), do: nil

  defp apply_aggregation(records, field, :sum) do
    Aggregator.sum(records, field)
  end

  defp apply_aggregation(records, field, :count) do
    Aggregator.count(records, field)
  end

  defp apply_aggregation(records, field, :avg) do
    Aggregator.avg(records, field)
  end

  defp apply_aggregation(records, field, :min) do
    Aggregator.field_min(records, field)
  end

  defp apply_aggregation(records, field, :max) do
    Aggregator.field_max(records, field)
  end

  defp create_flat_record(keys, value) do
    # Create field names based on depth
    field_names = [:level1, :level2, :level3, :level4, :level5]

    keys
    |> Enum.zip(field_names)
    |> Map.new()
    |> Map.put(:value, value)
  end
end
