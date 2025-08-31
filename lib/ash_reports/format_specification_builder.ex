defmodule AshReports.FormatSpecificationBuilder do
  @moduledoc """
  Builder pattern for constructing complex format specifications.

  This module implements the Builder pattern to provide a fluent interface for
  creating format specifications with complex conditional logic, improving
  readability and maintainability of format definitions.

  ## Design Benefits

  - **Fluent Interface**: Chainable method calls for readable specification building
  - **Type Safety**: Compile-time validation of builder operations
  - **Composability**: Ability to combine multiple formatting rules
  - **Immutability**: Each operation returns a new builder state

  ## Usage

      # Build a complex conditional format specification
      spec = FormatSpecificationBuilder.new(:sales_amount)
      |> FormatSpecificationBuilder.add_currency_formatting(:USD)
      |> FormatSpecificationBuilder.add_condition(
           expr(value > 10000),
           pattern: "$#,##0K",
           color: :green,
           font_weight: :bold
         )
      |> FormatSpecificationBuilder.add_condition(
           expr(value < 0),
           pattern: "($#,##0)",
           color: :red
         )
      |> FormatSpecificationBuilder.set_default(pattern: "$#,##0.00")
      |> FormatSpecificationBuilder.build()

  """

  alias AshReports.FormatSpecification

  @typedoc "Builder state"
  @type builder_state :: %{
          name: atom(),
          pattern: String.t() | nil,
          conditions: [FormatSpecification.condition_rule()],
          options: keyword(),
          validations: [function()]
        }

  @typedoc "Condition expression"
  @type condition_expr :: any()

  @typedoc "Format options for conditions"
  @type condition_options :: keyword()

  defstruct [
    :name,
    :pattern,
    conditions: [],
    options: [],
    validations: []
  ]

  @doc """
  Creates a new format specification builder.

  ## Parameters

  - `name` - Unique name for the format specification

  ## Examples

      iex> builder = AshReports.FormatSpecificationBuilder.new(:my_format)
      iex> builder.name
      :my_format

  """
  @spec new(atom()) :: builder_state()
  def new(name) when is_atom(name) do
    %__MODULE__{name: name}
  end

  @doc """
  Sets the base pattern for the format specification.

  ## Parameters

  - `builder` - The builder state
  - `pattern` - The format pattern string

  ## Examples

      builder = FormatSpecificationBuilder.new(:test)
      |> FormatSpecificationBuilder.set_pattern("#,##0.00")

  """
  @spec set_pattern(builder_state(), String.t()) :: builder_state()
  def set_pattern(%__MODULE__{} = builder, pattern) when is_binary(pattern) do
    %{builder | pattern: pattern}
  end

  @doc """
  Adds currency-specific formatting configuration.

  ## Parameters

  - `builder` - The builder state
  - `currency` - The currency code

  ## Examples

      builder = FormatSpecificationBuilder.new(:price)
      |> FormatSpecificationBuilder.add_currency_formatting(:EUR)

  """
  @spec add_currency_formatting(builder_state(), atom()) :: builder_state()
  def add_currency_formatting(%__MODULE__{} = builder, currency) when is_atom(currency) do
    currency_options = [
      type: :currency,
      currency: currency,
      locale_aware: true
    ]

    %{builder | options: Keyword.merge(builder.options, currency_options)}
  end

  @doc """
  Adds percentage-specific formatting configuration.

  ## Parameters

  - `builder` - The builder state
  - `options` - Percentage formatting options

  ## Examples

      builder = FormatSpecificationBuilder.new(:growth_rate)
      |> FormatSpecificationBuilder.add_percentage_formatting(precision: 2, multiplier: 100)

  """
  @spec add_percentage_formatting(builder_state(), keyword()) :: builder_state()
  def add_percentage_formatting(%__MODULE__{} = builder, options \\ []) do
    percentage_options = [
      type: :percentage,
      precision: Keyword.get(options, :precision, 2),
      multiplier: Keyword.get(options, :multiplier, 1),
      locale_aware: true
    ]

    %{builder | options: Keyword.merge(builder.options, percentage_options)}
  end

  @doc """
  Adds date-specific formatting configuration.

  ## Parameters

  - `builder` - The builder state
  - `format_style` - The date format style (:short, :medium, :long, :full)

  ## Examples

      builder = FormatSpecificationBuilder.new(:report_date)
      |> FormatSpecificationBuilder.add_date_formatting(:long)

  """
  @spec add_date_formatting(builder_state(), atom()) :: builder_state()
  def add_date_formatting(%__MODULE__{} = builder, format_style \\ :medium) do
    date_options = [
      type: :date,
      format: format_style,
      locale_aware: true
    ]

    %{builder | options: Keyword.merge(builder.options, date_options)}
  end

  @doc """
  Adds a conditional formatting rule.

  ## Parameters

  - `builder` - The builder state
  - `condition` - The condition expression
  - `format_options` - Formatting options to apply when condition is true

  ## Examples

      builder = FormatSpecificationBuilder.new(:amount)
      |> FormatSpecificationBuilder.add_condition(
           expr(value > 1000),
           pattern: "#,##0K",
           color: :green
         )

  """
  @spec add_condition(builder_state(), condition_expr(), condition_options()) :: builder_state()
  def add_condition(%__MODULE__{} = builder, condition, format_options) do
    new_condition = {condition, format_options}
    %{builder | conditions: builder.conditions ++ [new_condition]}
  end

  @doc """
  Sets the default formatting options.

  ## Parameters

  - `builder` - The builder state
  - `default_options` - Default formatting options

  ## Examples

      builder = FormatSpecificationBuilder.new(:amount)
      |> FormatSpecificationBuilder.set_default(pattern: "#,##0.00", color: :black)

  """
  @spec set_default(builder_state(), keyword()) :: builder_state()
  def set_default(%__MODULE__{} = builder, default_options) do
    pattern = Keyword.get(default_options, :pattern)
    options = Keyword.delete(default_options, :pattern)

    builder = if pattern, do: %{builder | pattern: pattern}, else: builder
    %{builder | options: Keyword.merge(builder.options, options)}
  end

  @doc """
  Adds a validation rule to the builder.

  ## Parameters

  - `builder` - The builder state
  - `validation_fn` - Function that validates the specification

  ## Examples

      builder = FormatSpecificationBuilder.new(:amount)
      |> FormatSpecificationBuilder.add_validation(fn spec ->
           if spec.pattern, do: :ok, else: {:error, "Pattern required"}
         end)

  """
  @spec add_validation(builder_state(), function()) :: builder_state()
  def add_validation(%__MODULE__{} = builder, validation_fn) when is_function(validation_fn, 1) do
    %{builder | validations: builder.validations ++ [validation_fn]}
  end

  @doc """
  Adds locale-specific configuration.

  ## Parameters

  - `builder` - The builder state
  - `locale` - The target locale
  - `locale_options` - Locale-specific options

  ## Examples

      builder = FormatSpecificationBuilder.new(:amount)
      |> FormatSpecificationBuilder.add_locale_config("ar", text_direction: :rtl)

  """
  @spec add_locale_config(builder_state(), String.t(), keyword()) :: builder_state()
  def add_locale_config(%__MODULE__{} = builder, locale, locale_options) do
    locale_config = [
      locale: locale,
      locale_aware: true
    ]

    final_options = Keyword.merge(locale_config, locale_options)
    %{builder | options: Keyword.merge(builder.options, final_options)}
  end

  @doc """
  Builds the final format specification from the builder state.

  ## Parameters

  - `builder` - The builder state

  ## Returns

  Returns `{:ok, compiled_spec}` on success or `{:error, reason}` if validation fails.

  ## Examples

      {:ok, spec} = FormatSpecificationBuilder.new(:test)
      |> FormatSpecificationBuilder.set_pattern("#,##0.00")
      |> FormatSpecificationBuilder.build()

  """
  @spec build(builder_state()) ::
          {:ok, FormatSpecification.format_spec()} | {:error, term()}
  def build(%__MODULE__{} = builder) do
    with :ok <- run_validations(builder),
         {:ok, spec} <- create_specification(builder),
         {:ok, compiled_spec} <- FormatSpecification.compile(spec) do
      {:ok, compiled_spec}
    else
      {:error, reason} -> {:error, "Builder validation failed: #{reason}"}
    end
  end

  @doc """
  Builds the specification without compilation for testing purposes.

  ## Examples

      spec = FormatSpecificationBuilder.new(:test)
      |> FormatSpecificationBuilder.set_pattern("#,##0.00")
      |> FormatSpecificationBuilder.build_uncompiled()

  """
  @spec build_uncompiled(builder_state()) :: FormatSpecification.format_spec()
  def build_uncompiled(%__MODULE__{} = builder) do
    FormatSpecification.new(builder.name,
      pattern: builder.pattern,
      conditions: builder.conditions
    )
    |> add_options_to_spec(builder.options)
  end

  # Private helper functions

  defp run_validations(%__MODULE__{validations: []}) do
    :ok
  end

  defp run_validations(%__MODULE__{validations: validations} = builder) do
    temp_spec = build_uncompiled(builder)

    Enum.reduce_while(validations, :ok, fn validation_fn, :ok ->
      case validation_fn.(temp_spec) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp create_specification(%__MODULE__{} = builder) do
    spec =
      FormatSpecification.new(builder.name,
        pattern: builder.pattern,
        conditions: builder.conditions
      )

    final_spec = add_options_to_spec(spec, builder.options)
    {:ok, final_spec}
  end

  defp add_options_to_spec(spec, []), do: spec

  defp add_options_to_spec(spec, options) do
    %{spec | options: Keyword.merge(spec.options, options)}
  end
end
