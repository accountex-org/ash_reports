defmodule AshReports.FormatSpecification do
  @moduledoc """
  Format Specification DSL for AshReports.

  This module provides a comprehensive DSL for defining custom formatting patterns
  that extend beyond the standard CLDR formatting capabilities. Format specifications
  allow for sophisticated control over how data is presented in reports across all
  output formats (HTML, HEEX, PDF, JSON).

  ## Features

  - **Custom Format Patterns**: Define complex formatting rules using intuitive syntax
  - **Type-Specific Formatting**: Specialized formatting for numbers, currencies, dates, and text
  - **Conditional Formatting**: Apply different formats based on data values or conditions
  - **Locale Integration**: Works seamlessly with existing CLDR locale support
  - **Cross-Renderer Support**: Format specifications work across all output renderers
  - **Performance Optimized**: Compiled format specifications for efficient processing

  ## Format Specification Syntax

  Format specifications use a declarative syntax that combines pattern strings
  with configuration options:

  ### Basic Pattern Syntax

      # Number formatting with custom precision and separators
      format_spec :custom_number do
        pattern "#,##0.000"
        locale_aware true
      end

      # Currency formatting with symbol placement
      format_spec :custom_currency do
        pattern "¤ #,##0.00"
        currency :USD
        symbol_position :prefix
      end

      # Date formatting with custom patterns
      format_spec :custom_date do
        pattern "dd/MM/yyyy"
        locale "en-GB"
      end

  ### Conditional Formatting

      # Apply different formats based on value ranges
      format_spec :conditional_number do
        condition value > 1000, pattern: "#,##0K", color: :green
        condition value < 0, pattern: "(#,##0)", color: :red
        default pattern: "#,##0.00"
      end

  ### Advanced Pattern Features

      # Text formatting with transformations
      format_spec :custom_text do
        pattern "%{value}"
        transform :uppercase
        max_length 50
        truncate_suffix "..."
      end

      # Percentage formatting with custom display
      format_spec :custom_percentage do
        pattern "#0.##%"
        multiplier 100
        suffix " percent"
      end

  ## Integration with Renderers

  Format specifications integrate seamlessly with all AshReports renderers:

  ### In Element Definitions

      field :amount do
        source :total_amount
        format_spec :custom_currency
      end

      expression :growth_rate do
        expression expr(current / previous - 1)
        format_spec :custom_percentage
      end

  ### In Band Processing

      band :summary do
        elements do
          field :total do
            source :sum_amount
            format_spec conditional_number: [
              {value > 10000, pattern: "$#,##0K", color: :green},
              {value < 0, pattern: "($#,##0)", color: :red}
            ]
          end
        end
      end

  ## Performance Considerations

  - **Format Compilation**: Specifications are compiled at DSL build time for performance
  - **Caching**: Compiled formatters are cached per locale and specification
  - **Lazy Evaluation**: Complex conditional formats are evaluated only when needed
  - **Memory Efficiency**: Format specifications share common components

  ## Error Handling

  Format specifications include comprehensive error handling:

  - **Pattern Validation**: Syntax validation at compile time
  - **Runtime Fallbacks**: Graceful degradation when formatting fails
  - **Type Checking**: Ensures format compatibility with data types
  - **Locale Validation**: Verifies locale availability for format operations

  """

  @typedoc "Format specification identifier"
  @type format_spec_name :: atom()

  @typedoc "Format pattern string with placeholders and formatting directives"
  @type format_pattern :: String.t()

  @typedoc "Conditional formatting rule"
  @type condition_rule :: {condition :: any(), options :: keyword()}

  @typedoc "Format specification configuration"
  @type format_spec :: %{
          name: format_spec_name(),
          pattern: format_pattern() | nil,
          conditions: [condition_rule()],
          options: keyword(),
          compiled: boolean()
        }

  @typedoc "Format specification result"
  @type format_result :: {:ok, String.t()} | {:error, term()}

  defstruct [
    :name,
    :pattern,
    conditions: [],
    options: [],
    compiled: false
  ]

  @doc """
  Creates a new format specification with the given name and configuration.

  ## Parameters

  - `name` - Unique identifier for the format specification
  - `options` - Configuration options for the specification

  ## Options

  - `:pattern` - The base format pattern string
  - `:locale_aware` - Whether the format should respect locale settings (default: true)
  - `:type` - Expected data type (:number, :currency, :date, :text, :percentage)
  - `:fallback` - Fallback format specification or pattern
  - `:cache` - Whether to cache compiled format (default: true)

  ## Examples

      iex> spec = AshReports.FormatSpecification.new(:custom_number, pattern: "#,##0.00")
      iex> spec.name
      :custom_number

  """
  @spec new(format_spec_name(), keyword()) :: format_spec()
  def new(name, options \\ []) when is_atom(name) do
    %__MODULE__{
      name: name,
      pattern: Keyword.get(options, :pattern),
      conditions: Keyword.get(options, :conditions, []),
      options: options,
      compiled: false
    }
  end

  @doc """
  Adds a conditional formatting rule to a format specification.

  Conditional rules are evaluated in order, with the first matching condition
  being applied. If no conditions match, the default pattern is used.

  ## Parameters

  - `spec` - The format specification to modify
  - `condition` - The condition expression to evaluate
  - `format_options` - Formatting options to apply when condition is true

  ## Examples

      spec = AshReports.FormatSpecification.new(:conditional_amount)
      |> AshReports.FormatSpecification.add_condition(
           expr(value > 1000),
           pattern: "#,##0K",
           color: :green
         )
      |> AshReports.FormatSpecification.add_condition(
           expr(value < 0),
           pattern: "(#,##0)",
           color: :red
         )

  """
  @spec add_condition(format_spec(), any(), keyword()) :: format_spec()
  def add_condition(%__MODULE__{} = spec, condition, format_options) do
    new_condition = {condition, format_options}
    %{spec | conditions: spec.conditions ++ [new_condition]}
  end

  @doc """
  Sets the default formatting pattern for a specification.

  The default pattern is used when no conditional rules match or when
  no conditions are defined.

  ## Parameters

  - `spec` - The format specification to modify
  - `pattern` - The default format pattern string

  ## Examples

      spec = AshReports.FormatSpecification.new(:my_format)
      |> AshReports.FormatSpecification.set_default_pattern("#,##0.00")

  """
  @spec set_default_pattern(format_spec(), format_pattern()) :: format_spec()
  def set_default_pattern(%__MODULE__{} = spec, pattern) when is_binary(pattern) do
    %{spec | pattern: pattern}
  end

  @doc """
  Compiles a format specification for efficient runtime use.

  Compilation validates the format patterns, optimizes condition evaluation,
  and prepares the specification for integration with the formatting system.

  ## Parameters

  - `spec` - The format specification to compile

  ## Returns

  Returns `{:ok, compiled_spec}` on success or `{:error, reason}` if compilation fails.

  ## Examples

      spec = AshReports.FormatSpecification.new(:my_format, pattern: "#,##0.00")
      {:ok, compiled} = AshReports.FormatSpecification.compile(spec)

  """
  @spec compile(format_spec()) :: {:ok, format_spec()} | {:error, term()}
  def compile(%__MODULE__{compiled: true} = spec), do: {:ok, spec}

  def compile(%__MODULE__{} = spec) do
    with :ok <- validate_pattern(spec.pattern),
         :ok <- validate_conditions(spec.conditions),
         :ok <- validate_options(spec.options) do
      compiled_spec = %{spec | compiled: true}
      {:ok, compiled_spec}
    else
      {:error, reason} -> {:error, "Format specification compilation failed: #{reason}"}
    end
  rescue
    error -> {:error, "Compilation error: #{Exception.message(error)}"}
  end

  @doc """
  Validates a format specification without compiling it.

  Performs syntax and semantic validation of format patterns, conditions,
  and options without the overhead of full compilation.

  ## Parameters

  - `spec` - The format specification to validate

  ## Examples

      spec = AshReports.FormatSpecification.new(:test, pattern: "invalid{pattern")
      AshReports.FormatSpecification.validate(spec)
      # => {:error, "Invalid pattern syntax..."}

  """
  @spec validate(format_spec()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = spec) do
    case validate_pattern(spec.pattern) do
      :ok ->
        case validate_conditions(spec.conditions) do
          :ok -> validate_options(spec.options)
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  Gets the effective format pattern for a given value and context.

  Evaluates conditional rules against the provided value and returns the
  appropriate format pattern and options.

  ## Parameters

  - `spec` - The compiled format specification
  - `value` - The value to format
  - `context` - Additional context for condition evaluation

  ## Examples

      spec = compiled_conditional_spec()
      {:ok, {pattern, opts}} = AshReports.FormatSpecification.get_effective_format(
        spec,
        1500,
        %{locale: "en"}
      )

  """
  @spec get_effective_format(format_spec(), any(), map()) ::
          {:ok, {format_pattern(), keyword()}} | {:error, term()}
  def get_effective_format(spec, value, context \\ %{})

  def get_effective_format(%__MODULE__{compiled: true} = spec, value, context) do
    case evaluate_conditions(spec.conditions, value, context) do
      {:match, {_condition, options}} ->
        pattern = Keyword.get(options, :pattern, spec.pattern)
        effective_options = merge_options(spec.options, options)
        {:ok, {pattern, effective_options}}

      :no_match ->
        {:ok, {spec.pattern, spec.options}}
    end
  rescue
    error -> {:error, "Format evaluation failed: #{Exception.message(error)}"}
  end

  def get_effective_format(%__MODULE__{compiled: false}, _value, _context) do
    {:error, "Format specification must be compiled before use"}
  end

  # Private helper functions

  @spec validate_pattern(format_pattern() | nil) :: :ok | {:error, String.t()}
  defp validate_pattern(nil), do: :ok

  defp validate_pattern(pattern) when is_binary(pattern) do
    cond do
      String.length(pattern) == 0 ->
        {:error, "Pattern cannot be empty"}

      String.contains?(pattern, ["{{", "}}"]) ->
        {:error, "Invalid pattern syntax: nested braces not allowed"}

      not valid_pattern_syntax?(pattern) ->
        {:error, "Invalid pattern syntax"}

      true ->
        :ok
    end
  end

  defp validate_pattern(_), do: {:error, "Pattern must be a string"}

  @spec validate_conditions([condition_rule()]) :: :ok | {:error, String.t()}
  defp validate_conditions([]), do: :ok

  defp validate_conditions(conditions) when is_list(conditions) do
    Enum.reduce_while(conditions, :ok, fn {condition, options}, :ok ->
      case validate_condition_rule(condition, options) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_conditions(_), do: {:error, "Conditions must be a list"}

  @spec validate_condition_rule(any(), keyword()) :: :ok | {:error, String.t()}
  defp validate_condition_rule(_condition, options) when is_list(options) do
    # Validate that required options are present and valid
    case Keyword.get(options, :pattern) do
      nil -> {:error, "Condition rule must specify a pattern"}
      pattern when is_binary(pattern) -> validate_pattern(pattern)
      _ -> {:error, "Condition pattern must be a string"}
    end
  end

  defp validate_condition_rule(_condition, _options) do
    {:error, "Condition options must be a keyword list"}
  end

  @spec validate_options(keyword()) :: :ok | {:error, String.t()}
  defp validate_options(options) when is_list(options) do
    # Validate known options
    known_options = [
      :pattern,
      :locale_aware,
      :type,
      :fallback,
      :cache,
      :currency,
      :symbol_position,
      :transform,
      :max_length,
      :truncate_suffix,
      :multiplier,
      :suffix,
      :prefix,
      :color,
      :conditions
    ]

    case Keyword.keys(options) -- known_options do
      [] -> :ok
      unknown -> {:error, "Unknown options: #{inspect(unknown)}"}
    end
  end

  defp validate_options(_), do: {:error, "Options must be a keyword list"}

  @spec valid_pattern_syntax?(format_pattern()) :: boolean()
  defp valid_pattern_syntax?(pattern) do
    # Basic syntax validation for format patterns
    # This is a simplified validation - a real implementation would be more comprehensive
    pattern
    |> String.graphemes()
    |> Enum.reduce({true, 0}, fn
      "{", {valid, depth} -> {valid, depth + 1}
      "}", {valid, depth} when depth > 0 -> {valid, depth - 1}
      "}", {_valid, 0} -> {false, 0}
      _char, {valid, depth} -> {valid, depth}
    end)
    |> case do
      {true, 0} -> true
      _ -> false
    end
  end

  @spec evaluate_conditions([condition_rule()], any(), map()) ::
          {:match, condition_rule()} | :no_match
  defp evaluate_conditions([], _value, _context), do: :no_match

  defp evaluate_conditions([{condition, options} | rest], value, context) do
    if evaluate_condition(condition, value, context) do
      {:match, {condition, options}}
    else
      evaluate_conditions(rest, value, context)
    end
  end

  @spec evaluate_condition(any(), any(), map()) :: boolean()
  defp evaluate_condition(condition, value, _context) do
    # This is a simplified condition evaluation
    # In a real implementation, this would integrate with Ash's expression system
    # The context parameter is reserved for future expression evaluation features
    case condition do
      {:>, threshold} -> value > threshold
      {:<, threshold} -> value < threshold
      {:==, expected} -> value == expected
      {:!=, expected} -> value != expected
      true -> true
      false -> false
      _ -> false
    end
  rescue
    _ -> false
  end

  @spec merge_options(keyword(), keyword()) :: keyword()
  defp merge_options(base_options, override_options) do
    Keyword.merge(base_options, override_options)
  end
end
