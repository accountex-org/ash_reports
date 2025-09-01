defmodule AshReports.InteractiveEngine.PivotProcessor do
  @moduledoc """
  Pivot table and cross-tabulation processor for AshReports interactive data operations.
  
  Provides advanced pivot table generation with multiple aggregation functions,
  subtotals, grand totals, and locale-aware formatting.
  """
  
  alias AshReports.RenderContext
  
  @type aggregation_function :: :sum | :count | :average | :min | :max | :median | :std_dev
  
  @doc """
  Generate a pivot table from data with specified configuration.
  
  ## Examples
  
      config = %{
        rows: [:region, :category],
        columns: [:quarter, :year], 
        values: [:revenue, :profit],
        aggregation: :sum,
        show_subtotals: true,
        show_grand_total: true
      }
      
      pivot = PivotProcessor.generate_pivot_table(data, config, context)
  
  """
  @spec generate_pivot_table(list(), map(), RenderContext.t()) :: map()
  def generate_pivot_table(data, config, %RenderContext{} = context) when is_list(data) and is_map(config) do
    row_fields = List.wrap(config.rows || [])
    column_fields = List.wrap(config.columns || [])
    value_fields = List.wrap(config.values || [])
    aggregation = config.aggregation || :sum
    
    # Extract unique row and column values
    row_values = extract_unique_combinations(data, row_fields)
    column_values = extract_unique_combinations(data, column_fields)
    
    # Build pivot table structure
    pivot_data = build_pivot_matrix(data, row_values, column_values, row_fields, column_fields, value_fields, aggregation)
    
    # Calculate subtotals and grand totals if requested
    pivot_with_totals = if config.show_subtotals or config.show_grand_total do
      add_totals(pivot_data, row_values, column_values, config, context)
    else
      pivot_data
    end
    
    %{
      rows: row_values,
      columns: column_values,
      data: pivot_with_totals,
      metadata: %{
        row_count: length(row_values),
        column_count: length(column_values),
        aggregation_function: aggregation,
        locale: context.locale,
        generated_at: DateTime.utc_now()
      }
    }
  end
  
  @doc """
  Create a cross-tabulation analysis between two categorical fields.
  
  ## Examples
  
      # Analyze relationship between region and status
      crosstab = PivotProcessor.cross_tabulation(data, :region, :status, context)
  
  """
  @spec cross_tabulation(list(), atom(), atom(), RenderContext.t()) :: map()
  def cross_tabulation(data, row_field, column_field, %RenderContext{} = context) do
    config = %{
      rows: [row_field],
      columns: [column_field],
      values: [:count],
      aggregation: :count,
      show_subtotals: true,
      show_grand_total: true
    }
    
    generate_pivot_table(data, config, context)
  end
  
  @doc """
  Generate frequency distribution for a categorical field.
  """
  @spec frequency_distribution(list(), atom(), RenderContext.t()) :: map()
  def frequency_distribution(data, field, %RenderContext{} = context) do
    frequencies = data
    |> Enum.group_by(&Map.get(&1, field))
    |> Enum.map(fn {value, items} ->
      %{
        value: value,
        count: length(items),
        percentage: length(items) / length(data) * 100
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
    
    %{
      field: field,
      frequencies: frequencies,
      total_count: length(data),
      unique_values: length(frequencies),
      metadata: %{
        locale: context.locale,
        generated_at: DateTime.utc_now()
      }
    }
  end
  
  # Private implementation functions
  
  defp extract_unique_combinations(data, fields) when is_list(fields) and length(fields) > 0 do
    data
    |> Enum.map(fn item ->
      Enum.map(fields, &Map.get(item, &1))
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end
  defp extract_unique_combinations(_data, []), do: [[]]
  
  defp build_pivot_matrix(data, row_values, column_values, row_fields, column_fields, value_fields, aggregation) do
    row_values
    |> Enum.map(fn row_combination ->
      column_data = column_values
      |> Enum.map(fn column_combination ->
        # Find matching records for this row/column intersection
        matching_records = data
        |> Enum.filter(fn item ->
          row_match = row_fields
          |> Enum.zip(row_combination)
          |> Enum.all?(fn {field, expected_value} ->
            Map.get(item, field) == expected_value
          end)
          
          column_match = column_fields
          |> Enum.zip(column_combination)
          |> Enum.all?(fn {field, expected_value} ->
            Map.get(item, field) == expected_value
          end)
          
          row_match and column_match
        end)
        
        # Calculate aggregated values for each value field
        aggregated_values = value_fields
        |> Enum.map(fn value_field ->
          values = Enum.map(matching_records, &Map.get(&1, value_field)) |> Enum.filter(&is_number/1)
          {value_field, apply_aggregation(values, aggregation)}
        end)
        |> Map.new()
        
        %{
          row: row_combination,
          column: column_combination,
          values: aggregated_values,
          record_count: length(matching_records)
        }
      end)
      
      %{row: row_combination, columns: column_data}
    end)
  end
  
  defp apply_aggregation([], _aggregation), do: 0
  defp apply_aggregation(values, aggregation) when is_list(values) do
    case aggregation do
      :sum -> Enum.sum(values)
      :count -> length(values)
      :average -> Enum.sum(values) / length(values)
      :min -> Enum.min(values)
      :max -> Enum.max(values)
      :median -> calculate_median(values)
      :std_dev -> calculate_std_deviation(values)
    end
  end
  
  defp add_totals(pivot_data, row_values, column_values, config, %RenderContext{} = context) do
    pivot_with_subtotals = if config.show_subtotals do
      add_row_subtotals(pivot_data, config)
    else
      pivot_data
    end
    
    if config.show_grand_total do
      add_grand_total(pivot_with_subtotals, config, context)
    else
      pivot_with_subtotals
    end
  end
  
  defp add_row_subtotals(pivot_data, config) do
    # Add subtotals for each row
    Enum.map(pivot_data, fn row_data ->
      subtotal_values = row_data.columns
      |> Enum.reduce(%{}, fn column_data, acc ->
        Enum.reduce(column_data.values, acc, fn {field, value}, field_acc ->
          Map.update(field_acc, field, value, &(&1 + value))
        end)
      end)
      
      subtotal_column = %{
        row: row_data.row,
        column: ["SUBTOTAL"],
        values: subtotal_values,
        record_count: Enum.sum(row_data.columns, & &1.record_count)
      }
      
      %{row_data | columns: row_data.columns ++ [subtotal_column]}
    end)
  end
  
  defp add_grand_total(pivot_data, config, %RenderContext{} = context) do
    # Calculate grand total across all cells
    grand_total_values = pivot_data
    |> Enum.flat_map(& &1.columns)
    |> Enum.reduce(%{}, fn column_data, acc ->
      Enum.reduce(column_data.values, acc, fn {field, value}, field_acc ->
        Map.update(field_acc, field, value, &(&1 + value))
      end)
    end)
    
    grand_total_row = %{
      row: ["GRAND TOTAL"],
      columns: [%{
        row: ["GRAND TOTAL"],
        column: ["TOTAL"],
        values: grand_total_values,
        record_count: calculate_total_record_count(pivot_data)
      }]
    }
    
    pivot_data ++ [grand_total_row]
  end
  
  defp calculate_total_record_count(pivot_data) do
    pivot_data
    |> Enum.flat_map(& &1.columns)
    |> Enum.map(& &1.record_count)
    |> Enum.sum()
  end
  
  defp calculate_median([]), do: 0
  defp calculate_median(values) when is_list(values) do
    sorted = Enum.sort(values)
    count = length(sorted)
    
    case rem(count, 2) do
      0 ->
        mid1 = Enum.at(sorted, div(count, 2) - 1)
        mid2 = Enum.at(sorted, div(count, 2))
        (mid1 + mid2) / 2
      
      1 ->
        Enum.at(sorted, div(count, 2))
    end
  end
  
  defp calculate_std_deviation([]), do: 0
  defp calculate_std_deviation(values) when is_list(values) do
    avg = Enum.sum(values) / length(values)
    variance = values
    |> Enum.map(fn val -> :math.pow(val - avg, 2) end)
    |> Enum.sum()
    |> Kernel./(length(values))
    
    :math.sqrt(variance)
  end
end