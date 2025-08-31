defmodule AshReports.FormatterFactory do
  @moduledoc """
  Factory for creating and configuring formatter instances.

  This module implements the Factory pattern to provide a clean interface for
  creating formatters with specific configurations, reducing complexity in
  the main formatting logic and improving testability.

  ## Design Benefits

  - **Configuration Management**: Centralized formatter configuration
  - **Testability**: Easy to mock and test different formatter configurations
  - **Flexibility**: Support for different formatter types and options
  - **Caching**: Efficient reuse of formatter configurations

  ## Usage

      # Create a basic formatter
      formatter = FormatterFactory.create(:default)

      # Create a locale-specific formatter
      formatter = FormatterFactory.create(:locale_aware, locale: "fr")

      # Create a custom formatter with specific options
      formatter = FormatterFactory.create(:custom, [
        currency: :EUR,
        precision: 3,
        date_format: :long
      ])

  """

  alias AshReports.{FormatSpecification, Formatter}

  @typedoc "Formatter configuration"
  @type formatter_config :: %{
          type: formatter_type(),
          locale: String.t(),
          options: keyword(),
          specifications: [FormatSpecification.format_spec()]
        }

  @typedoc "Formatter type"
  @type formatter_type ::
          :default
          | :locale_aware
          | :currency_focused
          | :scientific
          | :custom

  @doc """
  Creates a formatter configuration for the specified type.

  ## Parameters

  - `type` - The type of formatter to create
  - `options` - Additional configuration options

  ## Examples

      iex> config = AshReports.FormatterFactory.create(:default)
      iex> config.type
      :default

      iex> config = AshReports.FormatterFactory.create(:locale_aware, locale: "fr")
      iex> config.locale
      "fr"

  """
  @spec create(formatter_type(), keyword()) :: formatter_config()
  def create(type, options \\ [])

  def create(:default, options) do
    %{
      type: :default,
      locale: Keyword.get(options, :locale, "en"),
      options: default_options() |> Keyword.merge(options),
      specifications: []
    }
  end

  def create(:locale_aware, options) do
    %{
      type: :locale_aware,
      locale: Keyword.get(options, :locale, "en"),
      options: locale_aware_options() |> Keyword.merge(options),
      specifications: []
    }
  end

  def create(:currency_focused, options) do
    %{
      type: :currency_focused,
      locale: Keyword.get(options, :locale, "en"),
      options: currency_options() |> Keyword.merge(options),
      specifications: [create_currency_specifications()]
    }
  end

  def create(:scientific, options) do
    %{
      type: :scientific,
      locale: Keyword.get(options, :locale, "en"),
      options: scientific_options() |> Keyword.merge(options),
      specifications: [create_scientific_specifications()]
    }
  end

  def create(:custom, options) do
    %{
      type: :custom,
      locale: Keyword.get(options, :locale, "en"),
      options: options,
      specifications: Keyword.get(options, :specifications, [])
    }
  end

  @doc """
  Applies a formatter configuration to format a value.

  ## Examples

      config = FormatterFactory.create(:currency_focused, currency: :EUR)
      {:ok, formatted} = FormatterFactory.format_with_config(1234.56, config)

  """
  @spec format_with_config(term(), formatter_config()) ::
          {:ok, String.t()} | {:error, term()}
  def format_with_config(value, config) do
    # Apply specifications first if available
    case apply_specifications(value, config.specifications, config) do
      {:ok, _result} = success -> success
      {:error, _} -> apply_standard_formatting(value, config)
    end
  end

  @doc """
  Registers a custom formatter configuration for reuse.

  ## Examples

      config = FormatterFactory.create(:custom, currency: :EUR, precision: 3)
      FormatterFactory.register(:euro_formatter, config)

  """
  @spec register(atom(), formatter_config()) :: :ok
  def register(name, config) when is_atom(name) do
    # In a real implementation, this would use a registry
    # For now, store in process dictionary
    Process.put({:formatter_config, name}, config)
    :ok
  end

  @doc """
  Gets a registered formatter configuration.

  ## Examples

      config = FormatterFactory.get(:euro_formatter)

  """
  @spec get(atom()) :: {:ok, formatter_config()} | {:error, :not_found}
  def get(name) when is_atom(name) do
    case Process.get({:formatter_config, name}) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  # Private helper functions

  defp default_options do
    [
      precision: 2,
      format: :decimal,
      type: :auto
    ]
  end

  defp locale_aware_options do
    [
      precision: 2,
      format: :decimal,
      type: :auto,
      locale_fallback: "en",
      direction_aware: true
    ]
  end

  defp currency_options do
    [
      currency: :USD,
      format: :standard,
      type: :currency,
      symbol_position: :prefix
    ]
  end

  defp scientific_options do
    [
      format: :scientific,
      type: :number,
      precision: 3,
      notation: :scientific
    ]
  end

  defp create_currency_specifications do
    FormatSpecification.new(:currency_default,
      pattern: "¤ #,##0.00",
      type: :currency,
      locale_aware: true
    )
  end

  defp create_scientific_specifications do
    FormatSpecification.new(:scientific_default,
      pattern: "#.###E0",
      type: :number,
      locale_aware: false
    )
  end

  defp apply_specifications(_value, [], _config), do: {:error, :no_specifications}

  defp apply_specifications(value, [spec | _rest], config) do
    Formatter.format_with_spec(value, spec, config.locale, config.options)
  end

  defp apply_standard_formatting(value, config) do
    Formatter.format_value(value, config.options |> Keyword.put(:locale, config.locale))
  end
end
