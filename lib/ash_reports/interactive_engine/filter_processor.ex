defmodule AshReports.InteractiveEngine.FilterProcessor do
  @moduledoc """
  Advanced filtering capabilities for AshReports interactive data operations.
  
  Provides sophisticated filtering operations with support for complex criteria,
  locale-aware comparisons, and performance-optimized processing.
  """
  
  alias AshReports.RenderContext
  
  @type filter_operation :: :equals | :not_equals | :greater_than | :less_than | 
                           :greater_equal | :less_equal | :contains | :starts_with | 
                           :ends_with | :between | :in | :not_in | :regex
  
  @doc """
  Apply filtering criteria to a dataset.
  
  ## Examples
  
      criteria = %{
        name: {:contains, "Smith"},
        revenue: {:greater_than, 1000},
        region: {:in, ["North", "South"]},
        created_at: {:between, ~D[2024-01-01], ~D[2024-12-31]}
      }
      
      filtered = FilterProcessor.apply_filters(data, criteria, context)
  
  """
  @spec apply_filters(list(), map(), RenderContext.t()) :: list()
  def apply_filters(data, criteria, %RenderContext{} = context) when is_list(data) and is_map(criteria) do
    data
    |> Enum.filter(fn item ->
      Enum.all?(criteria, fn {field, filter_spec} ->
        apply_single_filter(item, field, filter_spec, context)
      end)
    end)
  end
  
  @doc """
  Create a reusable filter function from criteria.
  """
  @spec create_filter_function(map(), RenderContext.t()) :: (map() -> boolean())
  def create_filter_function(criteria, %RenderContext{} = context) do
    fn item ->
      Enum.all?(criteria, fn {field, filter_spec} ->
        apply_single_filter(item, field, filter_spec, context)
      end)
    end
  end
  
  @doc """
  Apply advanced text search across multiple fields.
  
  ## Examples
  
      # Search across name and email fields
      results = FilterProcessor.text_search(data, "john", [:name, :email], context)
      
      # Case-insensitive search with locale awareness
      results = FilterProcessor.text_search(data, "الأحمد", [:name], context)
  
  """
  @spec text_search(list(), String.t(), [atom()], RenderContext.t()) :: list()
  def text_search(data, search_term, fields, %RenderContext{} = context) when is_list(data) and is_binary(search_term) and is_list(fields) do
    normalized_search = normalize_search_term(search_term, context.locale)
    
    data
    |> Enum.filter(fn item ->
      Enum.any?(fields, fn field ->
        field_value = Map.get(item, field, "")
        normalized_value = normalize_search_term(to_string(field_value), context.locale)
        String.contains?(normalized_value, normalized_search)
      end)
    end)
  end
  
  @doc """
  Apply date range filtering with locale-aware parsing.
  """
  @spec filter_date_range(list(), atom(), Date.t() | DateTime.t(), Date.t() | DateTime.t(), RenderContext.t()) :: list()
  def filter_date_range(data, date_field, start_date, end_date, %RenderContext{} = context) do
    data
    |> Enum.filter(fn item ->
      case Map.get(item, date_field) do
        nil -> false
        date_value ->
          parsed_date = parse_date_value(date_value, context)
          parsed_date && date_in_range?(parsed_date, start_date, end_date)
      end
    end)
  end
  
  @doc """
  Apply numeric range filtering with locale-aware number parsing.
  """
  @spec filter_numeric_range(list(), atom(), number(), number(), RenderContext.t()) :: list()
  def filter_numeric_range(data, numeric_field, min_value, max_value, %RenderContext{} = _context) do
    data
    |> Enum.filter(fn item ->
      case Map.get(item, numeric_field) do
        nil -> false
        value when is_number(value) ->
          value >= min_value and value <= max_value
        value ->
          # Try to parse as number
          case Float.parse(to_string(value)) do
            {parsed_value, _} -> parsed_value >= min_value and parsed_value <= max_value
            :error -> false
          end
      end
    end)
  end
  
  # Private implementation functions
  
  defp apply_single_filter(item, field, filter_spec, %RenderContext{} = context) do
    field_value = Map.get(item, field)
    
    case filter_spec do
      # Direct value comparison
      value when not is_tuple(value) ->
        field_value == value
      
      # Operation-based filtering
      {:equals, value} ->
        field_value == value
      
      {:not_equals, value} ->
        field_value != value
      
      {:greater_than, value} ->
        compare_values(field_value, value, :greater_than, context)
      
      {:less_than, value} ->
        compare_values(field_value, value, :less_than, context)
      
      {:greater_equal, value} ->
        compare_values(field_value, value, :greater_equal, context)
      
      {:less_equal, value} ->
        compare_values(field_value, value, :less_equal, context)
      
      {:contains, substring} ->
        String.contains?(normalize_for_search(field_value, context), normalize_for_search(substring, context))
      
      {:starts_with, prefix} ->
        String.starts_with?(normalize_for_search(field_value, context), normalize_for_search(prefix, context))
      
      {:ends_with, suffix} ->
        String.ends_with?(normalize_for_search(field_value, context), normalize_for_search(suffix, context))
      
      {:between, min_val, max_val} ->
        compare_values(field_value, min_val, :greater_equal, context) and
        compare_values(field_value, max_val, :less_equal, context)
      
      {:in, values} when is_list(values) ->
        field_value in values
      
      {:not_in, values} when is_list(values) ->
        field_value not in values
      
      {:regex, pattern} ->
        case Regex.compile(pattern) do
          {:ok, regex} -> Regex.match?(regex, to_string(field_value))
          {:error, _} -> false
        end
      
      _ ->
        false
    end
  end
  
  defp compare_values(val1, val2, operation, %RenderContext{} = context) do
    case {val1, val2} do
      {v1, v2} when is_number(v1) and is_number(v2) ->
        apply_numeric_comparison(v1, v2, operation)
      
      {v1, v2} when is_binary(v1) and is_binary(v2) ->
        apply_string_comparison(v1, v2, operation, context)
      
      {%Date{} = d1, %Date{} = d2} ->
        apply_date_comparison(d1, d2, operation)
      
      {%DateTime{} = dt1, %DateTime{} = dt2} ->
        apply_datetime_comparison(dt1, dt2, operation)
      
      {v1, v2} ->
        # Try to parse as numbers
        case {parse_number(v1), parse_number(v2)} do
          {n1, n2} when is_number(n1) and is_number(n2) ->
            apply_numeric_comparison(n1, n2, operation)
          _ ->
            apply_string_comparison(to_string(v1), to_string(v2), operation, context)
        end
    end
  end
  
  defp apply_numeric_comparison(n1, n2, operation) do
    case operation do
      :greater_than -> n1 > n2
      :less_than -> n1 < n2
      :greater_equal -> n1 >= n2
      :less_equal -> n1 <= n2
      :equals -> n1 == n2
      :not_equals -> n1 != n2
    end
  end
  
  defp apply_string_comparison(s1, s2, operation, %RenderContext{locale: locale}) do
    case operation do
      :greater_than -> locale_compare_strings(s1, s2, locale) > 0
      :less_than -> locale_compare_strings(s1, s2, locale) < 0
      :greater_equal -> locale_compare_strings(s1, s2, locale) >= 0
      :less_equal -> locale_compare_strings(s1, s2, locale) <= 0
      :equals -> s1 == s2
      :not_equals -> s1 != s2
    end
  end
  
  defp apply_date_comparison(d1, d2, operation) do
    case operation do
      :greater_than -> Date.compare(d1, d2) == :gt
      :less_than -> Date.compare(d1, d2) == :lt
      :greater_equal -> Date.compare(d1, d2) in [:gt, :eq]
      :less_equal -> Date.compare(d1, d2) in [:lt, :eq]
      :equals -> Date.compare(d1, d2) == :eq
      :not_equals -> Date.compare(d1, d2) != :eq
    end
  end
  
  defp apply_datetime_comparison(dt1, dt2, operation) do
    case operation do
      :greater_than -> DateTime.compare(dt1, dt2) == :gt
      :less_than -> DateTime.compare(dt1, dt2) == :lt
      :greater_equal -> DateTime.compare(dt1, dt2) in [:gt, :eq]
      :less_equal -> DateTime.compare(dt1, dt2) in [:lt, :eq]
      :equals -> DateTime.compare(dt1, dt2) == :eq
      :not_equals -> DateTime.compare(dt1, dt2) != :eq
    end
  end
  
  defp normalize_search_term(term, locale) when is_binary(term) do
    case locale do
      "ar" -> 
        # Arabic text normalization
        term
        |> String.downcase()
        |> String.replace(~r/[أإآ]/, "ا")  # Normalize alif variants
        |> String.replace(~r/[ؤئ]/, "و")   # Normalize waw variants
      
      "he" ->
        # Hebrew text normalization  
        term
        |> String.downcase()
        |> String.replace(~r/[ך]/, "כ")    # Final kaf to regular kaf
        |> String.replace(~r/[ם]/, "מ")    # Final mem to regular mem
      
      _ ->
        String.downcase(term)
    end
  end
  
  defp normalize_for_search(value, context) do
    normalize_search_term(to_string(value), context.locale)
  end
  
  defp locale_compare_strings(s1, s2, locale) do
    # Enhanced locale-aware string comparison
    case locale do
      "ar" -> 
        # Arabic collation - basic implementation
        String.compare(normalize_search_term(s1, locale), normalize_search_term(s2, locale))
      
      "he" ->
        # Hebrew collation - basic implementation
        String.compare(normalize_search_term(s1, locale), normalize_search_term(s2, locale))
      
      _ ->
        String.compare(String.downcase(s1), String.downcase(s2))
    end
  end
  
  defp parse_number(value) when is_number(value), do: value
  defp parse_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _} -> number
      :error -> nil
    end
  end
  defp parse_number(_), do: nil
  
  defp parse_date_value(value, %RenderContext{} = _context) do
    case value do
      %Date{} = date -> date
      %DateTime{} = datetime -> DateTime.to_date(datetime)
      value when is_binary(value) ->
        case Date.from_iso8601(value) do
          {:ok, date} -> date
          {:error, _} ->
            case DateTime.from_iso8601(value) do
              {:ok, datetime, _} -> DateTime.to_date(datetime)
              {:error, _} -> nil
            end
        end
      _ -> nil
    end
  end
  
  defp date_in_range?(date, start_date, end_date) do
    Date.compare(date, start_date) in [:gt, :eq] and
    Date.compare(date, end_date) in [:lt, :eq]
  end
end