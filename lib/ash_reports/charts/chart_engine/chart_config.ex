defmodule AshReports.ChartEngine.ChartConfig do
  @moduledoc """
  Configuration structure for chart generation in AshReports.

  Defines the chart type, data, styling options, and behavioral configuration
  for generating server-side SVG charts using Contex across all renderers.
  """

  @type chart_type :: :line | :bar | :pie | :area | :scatter | :histogram | :boxplot | :heatmap
  @type interaction_type :: :none | :hover | :click | :drill_down | :filter | :zoom

  defstruct [
    # Core configuration
    type: :bar,
    title: nil,
    subtitle: nil,

    # Data configuration
    data: [],
    labels: [],
    datasets: [],

    # Visual styling
    colors: [],
    theme: :default,
    width: nil,
    height: nil,

    # Interactivity
    interactive: false,
    interactions: [:hover],
    real_time: false,
    update_interval: nil,

    # Localization
    locale_aware: true,
    rtl_support: true,

    # Export options
    exportable: true,
    export_formats: [:png, :svg, :pdf, :csv],

    # Performance
    animation: true,
    lazy_loading: false,
    cache_enabled: true,

    # Advanced options
    options: %{},
    custom_css: nil,

    # AI and automation
    auto_type_selection: false,
    confidence: 1.0,
    reasoning: nil,

    # Metadata
    created_at: nil,
    updated_at: nil
  ]

  @type t :: %__MODULE__{
          type: chart_type(),
          title: String.t() | nil,
          subtitle: String.t() | nil,
          data: list() | map(),
          labels: list(),
          datasets: list(),
          colors: list(),
          theme: atom(),
          width: integer() | nil,
          height: integer() | nil,
          interactive: boolean(),
          interactions: [interaction_type()],
          real_time: boolean(),
          update_interval: integer() | nil,
          locale_aware: boolean(),
          rtl_support: boolean(),
          exportable: boolean(),
          export_formats: [atom()],
          animation: boolean(),
          lazy_loading: boolean(),
          cache_enabled: boolean(),
          options: map(),
          custom_css: String.t() | nil,
          auto_type_selection: boolean(),
          confidence: float(),
          reasoning: String.t() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Create a new ChartConfig with default values.

  ## Examples

      config = ChartConfig.new(:line, chart_data)
      config = ChartConfig.new(:pie, chart_data, title: "Sales Distribution")

  """
  @spec new(chart_type(), list() | map(), keyword()) :: t()
  def new(type, data, opts \\ []) do
    %__MODULE__{
      type: type,
      data: data,
      created_at: DateTime.utc_now()
    }
    |> struct!(opts)
  end

  @doc """
  Create a configuration for an interactive chart.

  ## Examples

      config = ChartConfig.interactive(:bar, sales_data, 
        interactions: [:hover, :click, :drill_down],
        real_time: true,
        update_interval: 30_000
      )

  """
  @spec interactive(chart_type(), list() | map(), keyword()) :: t()
  def interactive(type, data, opts \\ []) do
    default_interactive_opts = [
      interactive: true,
      interactions: [:hover, :click],
      animation: true,
      exportable: true
    ]

    new(type, data, Keyword.merge(default_interactive_opts, opts))
  end

  @doc """
  Create a configuration for real-time updating charts.

  ## Examples

      config = ChartConfig.real_time(:line, stream_data,
        update_interval: 5000,
        max_data_points: 100
      )

  """
  @spec real_time(chart_type(), list() | map(), keyword()) :: t()
  def real_time(type, data, opts \\ []) do
    default_realtime_opts = [
      real_time: true,
      interactive: true,
      # Disable for performance
      animation: false,
      cache_enabled: false,
      # 10 seconds default
      update_interval: 10_000
    ]

    new(type, data, Keyword.merge(default_realtime_opts, opts))
  end

  @doc """
  Validate chart configuration and ensure all required fields are present.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{} = config) do
    with :ok <- validate_chart_type(config.type),
         :ok <- validate_data_presence(config.data),
         :ok <- validate_interactions(config.interactions),
         :ok <- validate_real_time_config(config) do
      {:ok, config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Validation functions

  defp validate_chart_type(type)
       when type in [:line, :bar, :pie, :area, :scatter, :histogram, :boxplot, :heatmap] do
    :ok
  end

  defp validate_chart_type(type) do
    {:error, "Invalid chart type: #{type}"}
  end

  defp validate_data_presence(data) when data in [nil, []],
    do: {:error, "Chart data cannot be empty"}

  defp validate_data_presence(_data), do: :ok

  defp validate_interactions(interactions) when is_list(interactions) do
    valid_interactions = [:none, :hover, :click, :drill_down, :filter, :zoom]
    invalid = interactions -- valid_interactions

    case invalid do
      [] -> :ok
      invalid -> {:error, "Invalid interactions: #{Enum.join(invalid, ", ")}"}
    end
  end

  defp validate_interactions(_), do: {:error, "Interactions must be a list"}

  defp validate_real_time_config(%{real_time: true, update_interval: nil}) do
    {:error, "Real-time charts must specify update_interval"}
  end

  defp validate_real_time_config(%{real_time: true, update_interval: interval})
       when interval < 1000 do
    {:error, "Update interval must be at least 1000ms"}
  end

  defp validate_real_time_config(_), do: :ok
end
