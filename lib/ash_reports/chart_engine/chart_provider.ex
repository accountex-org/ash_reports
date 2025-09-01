defmodule AshReports.ChartEngine.ChartProvider do
  @moduledoc """
  Behavior for chart providers in AshReports Phase 5.1.

  Defines the interface that all chart providers (Chart.js, D3.js, Plotly)
  must implement to integrate with the ChartEngine system.
  """

  alias AshReports.RenderContext

  @type chart_result :: {:ok, map()} | {:error, String.t()}

  @doc """
  Generate a chart from the provided specification and render context.

  ## Parameters

  - `chart_spec`: Chart specification containing type, data, and options
  - `context`: RenderContext with locale, RTL, and rendering configuration

  ## Returns

  - `{:ok, chart_output}`: Successful chart generation with provider-specific output
  - `{:error, reason}`: Chart generation failed with error description
  """
  @callback generate(chart_spec :: map(), context :: RenderContext.t()) :: chart_result()

  @doc """
  List chart types supported by this provider.

  ## Returns

  List of atoms representing supported chart types:
  - `:line` - Line charts for trends and time series
  - `:bar` - Bar charts for categorical comparisons  
  - `:pie` - Pie charts for proportional data
  - `:area` - Area charts for cumulative data
  - `:scatter` - Scatter plots for correlation analysis
  - `:histogram` - Histograms for frequency distribution
  - `:boxplot` - Box plots for statistical summaries
  - `:heatmap` - Heatmaps for density visualization
  """
  @callback supported_chart_types() :: [atom()]

  @doc """
  Describe features supported by this provider.

  ## Returns

  Map containing capability flags:
  - `interactive`: Boolean - supports user interaction
  - `real_time`: Boolean - supports real-time data updates
  - `responsive`: Boolean - responsive design support
  - `animations`: Boolean - supports chart animations
  - `exports`: List - supported export formats [:png, :svg, :pdf]
  - `accessibility`: Boolean - accessibility features support
  - `rtl_support`: Boolean - RTL language support
  - `mobile_optimized`: Boolean - mobile device optimization
  """
  @callback supported_features() :: map()

  @doc """
  Describe performance characteristics of this provider.

  ## Returns

  Map containing performance information:
  - `startup_time`: String - "fast" | "medium" | "slow"
  - `memory_usage`: String - "low" | "medium" | "high"  
  - `render_performance`: String - "excellent" | "good" | "acceptable"
  - `bundle_size`: String - "small" | "medium" | "large"
  - `mobile_performance`: String - "excellent" | "good" | "poor"
  """
  @callback performance_characteristics() :: map()

  @doc """
  Get the CDN URLs or asset requirements for this provider.

  ## Returns

  Map containing asset information:
  - `css_urls`: List of CSS file URLs
  - `js_urls`: List of JavaScript file URLs
  - `fonts`: List of font requirements
  - `version`: Provider library version
  """
  @callback get_asset_requirements() :: map()

  @optional_callbacks [get_asset_requirements: 0]

  @doc """
  Validate that a chart specification is compatible with this provider.
  """
  @spec validate_chart_spec(module(), map()) :: :ok | {:error, String.t()}
  def validate_chart_spec(provider_module, chart_spec) do
    supported_types = provider_module.supported_chart_types()
    chart_type = chart_spec[:type]

    cond do
      chart_type == nil ->
        {:error, "Chart type must be specified"}

      chart_type not in supported_types ->
        {:error,
         "Chart type #{chart_type} not supported by #{provider_module}. Supported: #{Enum.join(supported_types, ", ")}"}

      true ->
        :ok
    end
  end

  @doc """
  Get default options for a specific chart type and provider.
  """
  @spec get_default_options(atom(), atom()) :: map()
  def get_default_options(chart_type, provider) do
    case {chart_type, provider} do
      {:line, :chartjs} ->
        %{
          elements: %{line: %{tension: 0.4}},
          plugins: %{legend: %{display: true}},
          scales: %{y: %{beginAtZero: true}}
        }

      {:bar, :chartjs} ->
        %{
          plugins: %{legend: %{display: false}},
          scales: %{y: %{beginAtZero: true}}
        }

      {:pie, :chartjs} ->
        %{
          plugins: %{
            legend: %{position: "right"},
            tooltip: %{enabled: true}
          }
        }

      {:scatter, :chartjs} ->
        %{
          plugins: %{legend: %{display: true}},
          scales: %{
            x: %{type: "linear", position: "bottom"},
            y: %{beginAtZero: true}
          }
        }

      {_, :d3} ->
        %{
          margin: %{top: 20, right: 20, bottom: 30, left: 40},
          transition_duration: 750
        }

      {_, :plotly} ->
        %{
          displayModeBar: true,
          responsive: true,
          modeBarButtonsToRemove: ["pan2d", "lasso2d"]
        }

      _ ->
        %{}
    end
  end

  @doc """
  Check if a provider supports real-time updates.
  """
  @spec supports_real_time?(module()) :: boolean()
  def supports_real_time?(provider_module) do
    features = provider_module.supported_features()
    Map.get(features, :real_time, false)
  end

  @doc """
  Check if a provider supports interactive features.
  """
  @spec supports_interactivity?(module()) :: boolean()
  def supports_interactivity?(provider_module) do
    features = provider_module.supported_features()
    Map.get(features, :interactive, false)
  end

  @doc """
  Check if a provider supports RTL languages.
  """
  @spec supports_rtl?(module()) :: boolean()
  def supports_rtl?(provider_module) do
    features = provider_module.supported_features()
    Map.get(features, :rtl_support, false)
  end
end
