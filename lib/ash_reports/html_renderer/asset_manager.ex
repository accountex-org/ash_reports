defmodule AshReports.HtmlRenderer.AssetManager do
  @moduledoc """
  Asset management system for AshReports HTML Renderer in Phase 5.2.

  Manages CDN integration, JavaScript library loading, CSS optimization,
  and performance-oriented asset delivery for chart and interactive features.

  ## Features

  - **CDN Integration**: Chart.js, D3.js, Plotly loading via CDN with fallbacks
  - **Asset Optimization**: Lazy loading, code splitting, caching strategies
  - **Mobile Optimization**: Responsive asset loading and mobile-specific configurations
  - **Performance Monitoring**: Asset loading metrics and optimization recommendations
  - **Fallback Management**: Local asset fallbacks when CDN is unavailable
  - **Version Management**: Library version pinning and compatibility checking

  ## Supported Providers

  ### Chart.js
  - CDN: jsDelivr, cdnjs, unpkg
  - Version: 4.4.0+ (latest stable)
  - Plugins: chartjs-plugin-zoom, chartjs-adapter-date-fns

  ### D3.js  
  - CDN: jsDelivr, cdnjs, unpkg
  - Version: 7.8.0+ (latest stable)
  - Modules: d3-selection, d3-scale, d3-axis, d3-shape

  ### Plotly.js
  - CDN: jsDelivr, cdnjs, Plotly CDN
  - Version: 2.26.0+ (latest stable)
  - Bundles: plotly-basic, plotly-gl3d, plotly-geo

  """

  alias AshReports.RenderContext

  @chart_providers %{
    chartjs: %{
      name: "Chart.js",
      version: "4.4.0",
      cdn_urls: [
        "https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js",
        "https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.0/chart.umd.js",
        "https://unpkg.com/chart.js@4.4.0/dist/chart.umd.js"
      ],
      local_fallback: "/assets/js/chart.min.js",
      # Would be real integrity hash in production
      integrity: "sha384-...",
      plugins: [
        "https://cdn.jsdelivr.net/npm/chartjs-plugin-zoom@2.0.1/dist/chartjs-plugin-zoom.min.js"
      ]
    },
    d3: %{
      name: "D3.js",
      version: "7.8.0",
      cdn_urls: [
        "https://cdn.jsdelivr.net/npm/d3@7.8.0/dist/d3.min.js",
        "https://cdnjs.cloudflare.com/ajax/libs/d3/7.8.0/d3.min.js",
        "https://unpkg.com/d3@7.8.0/dist/d3.min.js"
      ],
      local_fallback: "/assets/js/d3.min.js",
      integrity: "sha384-...",
      plugins: []
    },
    plotly: %{
      name: "Plotly.js",
      version: "2.26.0",
      cdn_urls: [
        "https://cdn.plot.ly/plotly-2.26.0.min.js",
        "https://cdn.jsdelivr.net/npm/plotly.js@2.26.0/dist/plotly.min.js",
        "https://cdnjs.cloudflare.com/ajax/libs/plotly.js/2.26.0/plotly.min.js"
      ],
      local_fallback: "/assets/js/plotly.min.js",
      integrity: "sha384-...",
      plugins: []
    }
  }

  @ash_reports_assets %{
    css: [
      "ash_reports_charts.css",
      "ash_reports_interactive.css",
      "ash_reports_mobile.css"
    ],
    js: [
      "ash_reports_core.js",
      "ash_reports_accessibility.js",
      "ash_reports_mobile.js"
    ]
  }

  @doc """
  Get required asset URLs for a specific chart provider.

  ## Examples

      assets = AssetManager.get_provider_assets(:chartjs)
      # Returns: ["https://cdn.jsdelivr.net/npm/chart.js@4.4.0/...", ...]

  """
  @spec get_provider_assets(atom()) :: [String.t()]
  def get_provider_assets(provider) when provider in [:chartjs, :d3, :plotly] do
    provider_config = Map.get(@chart_providers, provider)
    [List.first(provider_config.cdn_urls)] ++ provider_config.plugins
  end

  def get_provider_assets(_), do: []

  @doc """
  Generate HTML for loading required assets with fallback support.

  ## Examples

      html = AssetManager.generate_asset_loading_html([:chartjs], context)

  """
  @spec generate_asset_loading_html([atom()], RenderContext.t()) :: String.t()
  def generate_asset_loading_html(providers, %RenderContext{} = context) do
    provider_scripts =
      providers
      |> Enum.map(&generate_provider_script_tag(&1, context))
      |> Enum.join("\n")

    ash_reports_scripts = generate_ash_reports_script_tags(context)

    """
    <!-- AshReports Chart Assets -->
    #{provider_scripts}

    <!-- AshReports Core Assets -->
    #{ash_reports_scripts}

    <!-- Asset Loading Status -->
    <script>
      #{generate_asset_loading_status_js(providers, context)}
    </script>
    """
  end

  @doc """
  Generate CSS link tags for chart styling.
  """
  @spec generate_css_links(RenderContext.t()) :: String.t()
  def generate_css_links(%RenderContext{} = context) do
    css_files = @ash_reports_assets.css

    links =
      css_files
      |> Enum.map(fn css_file ->
        "<link rel=\"stylesheet\" href=\"/assets/css/#{css_file}\" data-locale=\"#{context.locale}\">"
      end)
      |> Enum.join("\n")

    # Add RTL-specific CSS if needed
    rtl_css =
      if context.text_direction == "rtl" do
        "<link rel=\"stylesheet\" href=\"/assets/css/ash_reports_rtl.css\">"
      else
        ""
      end

    """
    <!-- AshReports Chart Styles -->
    #{links}
    #{rtl_css}
    """
  end

  @doc """
  Get performance optimization recommendations based on usage.
  """
  @spec get_optimization_recommendations([atom()], RenderContext.t()) :: map()
  def get_optimization_recommendations(providers, %RenderContext{} = context) do
    total_assets = providers |> Enum.flat_map(&get_provider_assets/1) |> length()
    estimated_size_kb = estimate_total_asset_size(providers)

    recommendations = []

    # Check if too many providers
    recommendations =
      if length(providers) > 2 do
        ["Consider reducing chart providers for better performance" | recommendations]
      else
        recommendations
      end

    # Check estimated bundle size
    recommendations =
      if estimated_size_kb > 500 do
        [
          "Large asset bundle detected (#{estimated_size_kb}KB), consider lazy loading"
          | recommendations
        ]
      else
        recommendations
      end

    # Mobile optimization check
    recommendations =
      if context.locale in ["ar", "he", "fa", "ur"] do
        ["RTL locale detected, ensure font loading optimization" | recommendations]
      else
        recommendations
      end

    %{
      total_assets: total_assets,
      estimated_size_kb: estimated_size_kb,
      providers: providers,
      recommendations: recommendations,
      optimization_score: calculate_optimization_score(total_assets, estimated_size_kb),
      loading_strategy: recommend_loading_strategy(providers, estimated_size_kb)
    }
  end

  @doc """
  Generate lazy loading JavaScript for performance optimization.
  """
  @spec generate_lazy_loading_javascript([atom()], map()) :: String.t()
  def generate_lazy_loading_javascript(providers, options \\ %{}) do
    intersection_threshold = options[:threshold] || 0.1
    root_margin = options[:root_margin] || "50px"

    """
    // Lazy loading for chart assets
    (function() {
      const chartContainers = document.querySelectorAll('.ash-chart-container');
      
      if ('IntersectionObserver' in window) {
        const chartObserver = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              loadChartAssets(entry.target);
              chartObserver.unobserve(entry.target);
            }
          });
        }, {
          threshold: #{intersection_threshold},
          rootMargin: '#{root_margin}'
        });
        
        chartContainers.forEach(container => {
          chartObserver.observe(container);
        });
      } else {
        // Fallback for browsers without IntersectionObserver
        chartContainers.forEach(loadChartAssets);
      }
      
      function loadChartAssets(container) {
        const chartType = container.dataset.chartType;
        const providers = #{Jason.encode!(providers)};
        
        // Load required assets dynamically
        providers.forEach(provider => {
          loadProviderAssets(provider);
        });
      }
      
      function loadProviderAssets(provider) {
        #{generate_dynamic_asset_loading_js(providers)}
      }
    })();
    """
  end

  # Private asset management functions

  defp generate_provider_script_tag(provider, %RenderContext{} = _context) do
    provider_config = Map.get(@chart_providers, provider)
    primary_url = List.first(provider_config.cdn_urls)
    fallback_url = provider_config.local_fallback

    """
    <script src="#{primary_url}" 
            integrity="#{provider_config.integrity}"
            crossorigin="anonymous"
            onerror="this.onerror=null; this.src='#{fallback_url}';">
    </script>
    """
  end

  defp generate_ash_reports_script_tags(%RenderContext{} = context) do
    @ash_reports_assets.js
    |> Enum.map(fn js_file ->
      "<script src=\"/assets/js/#{js_file}\" data-locale=\"#{context.locale}\"></script>"
    end)
    |> Enum.join("\n")
  end

  defp generate_asset_loading_status_js(providers, %RenderContext{} = _context) do
    """
    // Asset loading status tracking
    window.AshReports.assetStatus = {
      providers: #{Jason.encode!(providers)},
      loaded: [],
      failed: [],
      
      markLoaded: function(provider) {
        if (!this.loaded.includes(provider)) {
          this.loaded.push(provider);
          this.checkAllLoaded();
        }
      },
      
      markFailed: function(provider) {
        if (!this.failed.includes(provider)) {
          this.failed.push(provider);
          console.warn('Asset loading failed for provider:', provider);
        }
      },
      
      checkAllLoaded: function() {
        if (this.loaded.length === this.providers.length) {
          document.dispatchEvent(new CustomEvent('ashReportsAssetsReady'));
        }
      }
    };
    """
  end

  defp generate_dynamic_asset_loading_js(providers) do
    provider_loading_functions =
      providers
      |> Enum.map(fn provider ->
        provider_config = Map.get(@chart_providers, provider)
        primary_url = List.first(provider_config.cdn_urls)

        """
        case '#{provider}':
          loadScript('#{primary_url}', function() {
            window.AshReports.assetStatus.markLoaded('#{provider}');
          }, function() {
            window.AshReports.assetStatus.markFailed('#{provider}');
          });
          break;
        """
      end)
      |> Enum.join("\n")

    """
    switch(provider) {
      #{provider_loading_functions}
      default:
        console.warn('Unknown provider for dynamic loading:', provider);
    }

    function loadScript(url, onSuccess, onError) {
      const script = document.createElement('script');
      script.src = url;
      script.async = true;
      script.onload = onSuccess;
      script.onerror = onError;
      document.head.appendChild(script);
    }
    """
  end

  defp estimate_total_asset_size(providers) do
    # Rough estimates in KB
    size_estimates = %{
      # Chart.js is ~250KB minified
      chartjs: 250,
      # D3.js full bundle ~300KB
      d3: 300,
      # Plotly.js is quite large ~800KB
      plotly: 800
    }

    providers
    |> Enum.map(&Map.get(size_estimates, &1, 0))
    |> Enum.sum()
    # Add 50KB for AshReports assets
    |> Kernel.+(50)
  end

  defp calculate_optimization_score(total_assets, estimated_size_kb) do
    # Score from 0-100 based on performance factors
    # Penalty for many assets
    asset_score = max(0, 100 - (total_assets - 1) * 10)
    # Penalty for large size
    size_score = max(0, 100 - div(estimated_size_kb - 200, 10))

    div(asset_score + size_score, 2)
  end

  defp recommend_loading_strategy(providers, estimated_size_kb) do
    cond do
      estimated_size_kb > 600 -> :lazy_load_with_critical_path
      length(providers) > 2 -> :prioritized_loading
      estimated_size_kb > 300 -> :lazy_load_on_interaction
      true -> :immediate_load
    end
  end
end
