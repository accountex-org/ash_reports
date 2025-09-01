defmodule AshReports.InteractiveEngine.FilterProcessor do
  @moduledoc """
  Advanced filtering capabilities for AshReports interactive data operations.

  Provides sophisticated filtering operations with support for complex criteria,
  locale-aware comparisons, and performance-optimized processing.
  """

  alias AshReports.RenderContext

  @type filter_operation ::
          :equals
          | :not_equals
          | :greater_than
          | :less_than
          | :greater_equal
          | :less_equal
          | :contains
          | :starts_with
          | :ends_with
          | :between
          | :in
          | :not_in
          | :regex

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
  def apply_filters(data, criteria, %RenderContext{} = context)
      when is_list(data) and is_map(criteria) do
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
  def text_search(data, search_term, fields, %RenderContext{} = context)
      when is_list(data) and is_binary(search_term) and is_list(fields) do
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
  @spec filter_date_range(
          list(),
          atom(),
          Date.t() | DateTime.t(),
          Date.t() | DateTime.t(),
          RenderContext.t()
        ) :: list()
  def filter_date_range(data, date_field, start_date, end_date, %RenderContext{} = context) do
    data
    |> Enum.filter(fn item ->
      case Map.get(item, date_field) do
        nil ->
          false

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
      field_value = Map.get(item, numeric_field)
      numeric_value_in_range?(field_value, min_value, max_value)
    end)
  end

  defp numeric_value_in_range?(nil, _min, _max), do: false

  defp numeric_value_in_range?(value, min_value, max_value) when is_number(value) do
    value >= min_value and value <= max_value
  end

  defp numeric_value_in_range?(value, min_value, max_value) do
    case Float.parse(to_string(value)) do
      {parsed_value, _} -> parsed_value >= min_value and parsed_value <= max_value
      :error -> false
    end
  end

  # Private implementation functions

  defp apply_single_filter(item, field, filter_spec, %RenderContext{} = context) do
    field_value = Map.get(item, field)

    case filter_spec do
      # Direct value comparison
      value when not is_tuple(value) -> field_value == value
      # Delegate to specific filter handlers
      operation_tuple -> apply_operation_filter(field_value, operation_tuple, context)
    end
  end

  defp apply_operation_filter(field_value, operation_tuple, context) do
    {operation, value} = operation_tuple

    case operation do
      # Equality operations
      :equals ->
        field_value == value

      :not_equals ->
        field_value != value

      # Comparison operations  
      op when op in [:greater_than, :less_than, :greater_equal, :less_equal] ->
        compare_values(field_value, value, operation, context)

      # Text operations
      op when op in [:contains, :starts_with, :ends_with] ->
        apply_text_filter(field_value, operation, value, context)

      # Range and list operations
      _ ->
        apply_range_list_operation(field_value, operation_tuple, context)
    end
  end

  defp apply_comparison_operation(field_value, {operation, value}, context) do
    compare_values(field_value, value, operation, context)
  end

  defp apply_text_operation(field_value, {operation, search_value}, context) do
    apply_text_filter(field_value, operation, search_value, context)
  end

  defp apply_range_list_operation(field_value, operation_tuple, context) do
    case operation_tuple do
      {:between, min_val, max_val} -> apply_range_filter(field_value, min_val, max_val, context)
      {:in, values} when is_list(values) -> field_value in values
      {:not_in, values} when is_list(values) -> field_value not in values
      {:regex, pattern} -> apply_regex_filter(field_value, pattern)
      _ -> false
    end
  end

  defp apply_text_filter(field_value, operation, search_value, context) do
    normalized_field = normalize_for_search(field_value, context)
    normalized_search = normalize_for_search(search_value, context)

    case operation do
      :contains -> String.contains?(normalized_field, normalized_search)
      :starts_with -> String.starts_with?(normalized_field, normalized_search)
      :ends_with -> String.ends_with?(normalized_field, normalized_search)
    end
  end

  defp apply_range_filter(field_value, min_val, max_val, context) do
    compare_values(field_value, min_val, :greater_equal, context) and
      compare_values(field_value, max_val, :less_equal, context)
  end

  defp apply_regex_filter(field_value, pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} -> Regex.match?(regex, to_string(field_value))
      {:error, _} -> false
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
        handle_mixed_type_comparison(v1, v2, operation, context)
    end
  end

  defp handle_mixed_type_comparison(v1, v2, operation, context) do
    case {parse_number(v1), parse_number(v2)} do
      {n1, n2} when is_number(n1) and is_number(n2) ->
        apply_numeric_comparison(n1, n2, operation)

      _ ->
        apply_string_comparison(to_string(v1), to_string(v2), operation, context)
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
        # Normalize alif variants
        |> String.replace(~r/[أإآ]/, "ا")
        # Normalize waw variants
        |> String.replace(~r/[ؤئ]/, "و")

      "he" ->
        # Hebrew text normalization  
        term
        |> String.downcase()
        # Final kaf to regular kaf
        |> String.replace(~r/[ך]/, "כ")
        # Final mem to regular mem
        |> String.replace(~r/[ם]/, "מ")

      _ ->
        String.downcase(term)
    end
  end

  defp normalize_for_search(value, context) do
    normalize_search_term(to_string(value), context.locale)
  end

  defp locale_compare_strings(s1, s2, locale) do
    case locale do
      locale when locale in ["ar", "he"] ->
        apply_rtl_string_comparison(s1, s2, locale)

      _ ->
        apply_default_string_comparison(s1, s2)
    end
  end

  defp apply_rtl_string_comparison(s1, s2, locale) do
    normalized_s1 = normalize_search_term(s1, locale)
    normalized_s2 = normalize_search_term(s2, locale)
    compare_normalized_strings(normalized_s1, normalized_s2)
  end

  defp apply_default_string_comparison(s1, s2) do
    downcased_s1 = String.downcase(s1)
    downcased_s2 = String.downcase(s2)
    compare_normalized_strings(downcased_s1, downcased_s2)
  end

  defp compare_normalized_strings(str1, str2) do
    cond do
      str1 < str2 -> -1
      str1 > str2 -> 1
      true -> 0
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
      value when is_binary(value) -> parse_string_date(value)
      _ -> nil
    end
  end

  defp parse_string_date(string_value) do
    case Date.from_iso8601(string_value) do
      {:ok, date} -> date
      {:error, _} -> parse_string_datetime(string_value)
    end
  end

  defp parse_string_datetime(string_value) do
    case DateTime.from_iso8601(string_value) do
      {:ok, datetime, _} -> DateTime.to_date(datetime)
      {:error, _} -> nil
    end
  end

  defp date_in_range?(date, start_date, end_date) do
    Date.compare(date, start_date) in [:gt, :eq] and
      Date.compare(date, end_date) in [:lt, :eq]
  end
end
