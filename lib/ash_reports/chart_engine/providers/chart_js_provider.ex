defmodule AshReports.ChartEngine.Providers.ChartJsProvider do
  @moduledoc """
  Chart.js provider for AshReports Phase 5.1 chart generation.

  Implements Chart.js integration for generating interactive charts in HTML and HEEX
  renderers, with server-side SVG generation capability for PDF outputs.
  """

  @behaviour AshReports.ChartEngine.ChartProvider

  alias AshReports.ChartEngine.{ChartConfig, ChartData}
  alias AshReports.RenderContext

  @supported_chart_types [:line, :bar, :pie, :area, :scatter, :histogram]
  @chartjs_version "4.4.0"

  @doc """
  Generate a Chart.js chart from configuration and data.
  """
  @impl true
  def generate(chart_spec, %RenderContext{} = context) do
    with {:ok, chartjs_config} <- build_chartjs_config(chart_spec, context),
         {:ok, chart_html} <- generate_chart_html(chartjs_config, context),
         {:ok, chart_js} <- generate_chart_javascript(chartjs_config, context) do
      chart_output = %{
        provider: :chartjs,
        html: chart_html,
        javascript: chart_js,
        config: chartjs_config,
        svg: generate_svg_fallback(chartjs_config, context),
        metadata: %{
          chart_id: generate_chart_id(),
          generated_at: DateTime.utc_now(),
          chart_type: chart_spec.type,
          locale: context.locale
        }
      }

      {:ok, chart_output}
    else
      {:error, reason} -> {:error, "Chart.js generation failed: #{reason}"}
    end
  end

  @impl true
  def supported_chart_types, do: @supported_chart_types

  @impl true
  def supported_features do
    %{
      interactive: true,
      real_time: true,
      responsive: true,
      animations: true,
      exports: [:png, :svg, :pdf],
      accessibility: true,
      rtl_support: true,
      mobile_optimized: true
    }
  end

  @impl true
  def performance_characteristics do
    %{
      startup_time: "fast",
      memory_usage: "low",
      render_performance: "excellent",
      bundle_size: "small",
      mobile_performance: "excellent"
    }
  end

  # Chart.js Configuration Building

  defp build_chartjs_config(chart_spec, %RenderContext{} = context) do
    base_config = %{
      type: map_chart_type(chart_spec.type),
      data: prepare_chart_data(chart_spec.data, chart_spec.type),
      options: build_chart_options(chart_spec, context)
    }

    # Apply RTL adaptations if needed
    config_with_rtl =
      if context.text_direction == "rtl" do
        apply_rtl_adaptations(base_config, context)
      else
        base_config
      end

    {:ok, config_with_rtl}
  end

  defp map_chart_type(:area), do: "line"
  defp map_chart_type(:histogram), do: "bar"
  defp map_chart_type(type), do: to_string(type)

  defp prepare_chart_data(%ChartData{} = chart_data, chart_type) do
    case chart_type do
      :pie ->
        %{
          labels: chart_data.labels,
          datasets: [
            %{
              data: Enum.map(chart_data.processed_data, & &1.y),
              backgroundColor: generate_pie_colors(length(chart_data.labels)),
              borderWidth: 1
            }
          ]
        }

      type when type in [:line, :bar, :area, :scatter] ->
        %{
          labels: chart_data.labels,
          datasets: chart_data.datasets
        }

      :histogram ->
        histogram_data = create_histogram_data(chart_data.processed_data)

        %{
          labels: histogram_data.bins,
          datasets: [
            %{
              label: "Frequency",
              data: histogram_data.frequencies,
              backgroundColor: "rgba(54, 162, 235, 0.6)",
              borderColor: "rgba(54, 162, 235, 1)",
              borderWidth: 1
            }
          ]
        }
    end
  end

  defp build_chart_options(chart_spec, %RenderContext{} = context) do
    base_options = %{
      responsive: true,
      maintainAspectRatio: false,
      locale: context.locale,
      plugins: %{
        title: %{
          display: chart_spec[:title] != nil,
          text: chart_spec[:title],
          rtl: context.text_direction == "rtl"
        },
        legend: %{
          display: true,
          rtl: context.text_direction == "rtl"
        },
        tooltip: %{
          enabled: true,
          rtl: context.text_direction == "rtl"
        }
      },
      scales: build_scales(chart_spec.type, context),
      interaction: build_interaction_options(chart_spec)
    }

    # Merge with custom options from chart spec
    Map.merge(base_options, chart_spec[:options] || %{})
  end

  defp build_scales(chart_type, %RenderContext{} = context) when chart_type != :pie do
    base_scales = %{
      x: %{
        display: true,
        reverse: context.text_direction == "rtl",
        ticks: %{
          font: %{
            family: get_font_family(context.locale)
          }
        }
      },
      y: %{
        display: true,
        position: if(context.text_direction == "rtl", do: "right", else: "left"),
        ticks: %{
          font: %{
            family: get_font_family(context.locale)
          }
        }
      }
    }

    # Apply locale-specific number formatting
    case context.locale do
      locale when locale in ["ar", "fa", "ur"] ->
        put_in(
          base_scales,
          [:y, :ticks, :callback],
          "function(value) { return value.toLocaleString('#{locale}'); }"
        )

      _ ->
        base_scales
    end
  end

  defp build_scales(:pie, _context), do: %{}

  defp build_interaction_options(%{interactive: true, interactions: interactions}) do
    %{
      intersect: false,
      mode: if(:hover in interactions, do: "index", else: "point")
    }
  end

  defp build_interaction_options(_), do: %{}

  defp apply_rtl_adaptations(config, %RenderContext{locale: locale})
       when locale in ["ar", "he", "fa", "ur"] do
    config
    |> put_in([:options, :indexAxis], if(config.type == "bar", do: "y", else: nil))
    |> put_in([:options, :plugins, :legend, :rtl], true)
    |> put_in([:options, :plugins, :title, :rtl], true)
    |> put_in([:options, :scales, :x, :reverse], true)
    |> put_in([:options, :scales, :y, :position], "right")
  end

  defp apply_rtl_adaptations(config, _context), do: config

  # HTML and JavaScript Generation

  defp generate_chart_html(chartjs_config, %RenderContext{} = context) do
    chart_id = generate_chart_id()

    html = """
    <div class="ash-chart-container" data-locale="#{context.locale}" data-rtl="#{context.text_direction == "rtl"}">
      <canvas id="#{chart_id}" 
              class="ash-chart" 
              data-chart-type="#{chartjs_config.type}"
              role="img" 
              aria-label="#{get_chart_aria_label(chartjs_config, context)}">
        <p>#{get_chart_fallback_text(chartjs_config, context)}</p>
      </canvas>
    </div>
    """

    {:ok, html}
  end

  defp generate_chart_javascript(chartjs_config, %RenderContext{} = context) do
    chart_id = extract_chart_id_from_config(chartjs_config)
    config_json = Jason.encode!(chartjs_config)

    javascript = """
    (function() {
      // Wait for Chart.js to load
      if (typeof Chart === 'undefined') {
        console.warn('Chart.js not loaded, deferring chart creation');
        document.addEventListener('DOMContentLoaded', function() {
          createChart();
        });
        return;
      }
      
      function createChart() {
        const ctx = document.getElementById('#{chart_id}');
        if (!ctx) {
          console.error('Chart canvas element not found: #{chart_id}');
          return;
        }
        
        const config = #{config_json};
        
        // Apply RTL configurations if needed
        if ('#{context.text_direction}' === 'rtl') {
          Chart.defaults.font.family = '#{get_font_family(context.locale)}';
          if (config.options.plugins) {
            config.options.plugins.legend = config.options.plugins.legend || {};
            config.options.plugins.legend.rtl = true;
          }
        }
        
        // Create the chart
        const chart = new Chart(ctx, config);
        
        // Store chart instance for potential updates
        window.ashChartsInstances = window.ashChartsInstances || {};
        window.ashChartsInstances['#{chart_id}'] = chart;
        
        // Setup real-time updates if configured
        #{generate_realtime_javascript(chartjs_config, context)}
        
        return chart;
      }
      
      createChart();
    })();
    """

    {:ok, javascript}
  end

  defp generate_realtime_javascript(%{real_time: true, update_interval: interval}, _context) do
    chart_id = generate_chart_id()

    """
    // Setup real-time updates
    setInterval(function() {
      fetch('/ash_reports/api/chart_data/#{chart_id}')
        .then(response => response.json())
        .then(data => {
          chart.data = data;
          chart.update('none'); // No animation for real-time
        })
        .catch(error => console.error('Chart update failed:', error));
    }, #{interval});
    """
  end

  defp generate_realtime_javascript(_, _), do: ""

  defp generate_svg_fallback(chartjs_config, %RenderContext{} = context) do
    # For PDF rendering, generate a simple SVG representation
    # This is a basic implementation - could be enhanced with server-side chart rendering

    case chartjs_config.type do
      "pie" -> generate_svg_pie_chart(chartjs_config, context)
      "bar" -> generate_svg_bar_chart(chartjs_config, context)
      "line" -> generate_svg_line_chart(chartjs_config, context)
      _ -> generate_svg_placeholder(chartjs_config, context)
    end
  end

  defp generate_svg_pie_chart(config, _context) do
    # Simple SVG pie chart for PDF rendering
    data_values = config.data.datasets |> List.first() |> Map.get(:data, [])
    total = Enum.sum(data_values)

    slices =
      data_values
      |> Enum.with_index()
      |> Enum.map(fn {value, idx} ->
        percentage = value / total
        start_angle = if idx == 0, do: 0, else: calculate_cumulative_angle(data_values, idx)
        end_angle = start_angle + percentage * 360

        %{
          value: value,
          percentage: percentage,
          start_angle: start_angle,
          end_angle: end_angle,
          color: get_color_for_index(idx)
        }
      end)

    svg = """
    <svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">
      <g transform="translate(200,200)">
        #{Enum.map_join(slices, "\n", &generate_pie_slice/1)}
      </g>
    </svg>
    """

    svg
  end

  defp generate_svg_bar_chart(config, _context) do
    data_values = config.data.datasets |> List.first() |> Map.get(:data, [])
    labels = config.data.labels || []

    max_value = Enum.max(data_values, fn -> 0 end)
    bar_width = 300 / length(data_values)

    bars =
      data_values
      |> Enum.with_index()
      |> Enum.map(fn {value, idx} ->
        height = value / max_value * 200
        x = idx * bar_width + 50
        y = 250 - height

        """
        <rect x="#{x}" y="#{y}" width="#{bar_width - 10}" height="#{height}" 
              fill="#{get_color_for_index(idx)}" stroke="#333" stroke-width="1"/>
        <text x="#{x + bar_width / 2}" y="270" text-anchor="middle" font-size="12">
          #{Enum.at(labels, idx, "Item #{idx + 1}")}
        </text>
        """
      end)

    svg = """
    <svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
      #{Enum.join(bars, "\n")}
    </svg>
    """

    svg
  end

  defp generate_svg_line_chart(config, context) do
    data_values = config.data.datasets |> List.first() |> Map.get(:data, [])

    if length(data_values) < 2 do
      generate_svg_placeholder(config, context)
    else
      points =
        data_values
        |> Enum.with_index()
        |> Enum.map(fn {value, idx} ->
          x = idx / (length(data_values) - 1) * 300 + 50
          y = 200 - value / Enum.max(data_values) * 150
          "#{x},#{y}"
        end)
        |> Enum.join(" ")

      svg = """
      <svg width="400" height="250" xmlns="http://www.w3.org/2000/svg">
        <polyline points="#{points}" 
                  fill="none" 
                  stroke="#{get_color_for_index(0)}" 
                  stroke-width="2"/>
        #{generate_svg_axes()}
      </svg>
      """

      svg
    end
  end

  defp generate_svg_placeholder(config, _context) do
    """
    <svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
      <rect width="400" height="300" fill="#f5f5f5" stroke="#ddd"/>
      <text x="200" y="150" text-anchor="middle" font-size="16" fill="#666">
        Chart: #{config[:title] || "Visualization"}
      </text>
      <text x="200" y="170" text-anchor="middle" font-size="12" fill="#999">
        Type: #{config.type}
      </text>
    </svg>
    """
  end

  defp generate_svg_axes do
    """
    <!-- X axis -->
    <line x1="50" y1="200" x2="350" y2="200" stroke="#333" stroke-width="1"/>
    <!-- Y axis -->
    <line x1="50" y1="50" x2="50" y2="200" stroke="#333" stroke-width="1"/>
    """
  end

  defp generate_pie_slice(%{start_angle: start_a, end_angle: end_a, color: color}) do
    # Convert angles to radians
    start_rad = start_a * :math.pi() / 180
    end_rad = end_a * :math.pi() / 180

    # Calculate arc coordinates
    x1 = 80 * :math.cos(start_rad)
    y1 = 80 * :math.sin(start_rad)
    x2 = 80 * :math.cos(end_rad)
    y2 = 80 * :math.sin(end_rad)

    large_arc = if end_a - start_a > 180, do: 1, else: 0

    """
    <path d="M 0 0 L #{x1} #{y1} A 80 80 0 #{large_arc} 1 #{x2} #{y2} Z" 
          fill="#{color}" stroke="white" stroke-width="2"/>
    """
  end

  defp create_histogram_data(processed_data) do
    # Simple histogram with 10 bins
    values = Enum.map(processed_data, & &1.y) |> Enum.filter(&is_number/1)

    case values do
      [] ->
        %{bins: [], frequencies: []}

      values ->
        min_val = Enum.min(values)
        max_val = Enum.max(values)
        bin_size = (max_val - min_val) / 10

        bins =
          for i <- 0..9 do
            bin_start = min_val + i * bin_size
            bin_end = bin_start + bin_size
            "#{Float.round(bin_start, 1)}-#{Float.round(bin_end, 1)}"
          end

        frequencies =
          for i <- 0..9 do
            bin_start = min_val + i * bin_size
            bin_end = bin_start + bin_size

            Enum.count(values, fn val ->
              val >= bin_start and val < bin_end
            end)
          end

        %{bins: bins, frequencies: frequencies}
    end
  end

  defp calculate_cumulative_angle(data_values, index) do
    data_values
    |> Enum.take(index)
    |> Enum.sum()
    |> Kernel./(Enum.sum(data_values))
    |> Kernel.*(360)
  end

  # Utility functions

  defp generate_chart_id do
    "ash_chart_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp extract_chart_id_from_config(config) do
    # Extract chart ID from the configuration or generate one
    config[:chart_id] || generate_chart_id()
  end

  defp get_chart_aria_label(config, %RenderContext{} = context) do
    chart_type = config.type
    title = config[:title] || "Chart"

    case context.locale do
      "ar" -> "#{title} - رسم بياني من نوع #{chart_type}"
      "es" -> "#{title} - Gráfico de tipo #{chart_type}"
      "fr" -> "#{title} - Graphique de type #{chart_type}"
      _ -> "#{title} - #{chart_type} chart"
    end
  end

  defp get_chart_fallback_text(_config, %RenderContext{} = context) do
    case context.locale do
      "ar" -> "المتصفح الخاص بك لا يدعم الرسوم البيانية التفاعلية"
      "es" -> "Su navegador no soporta gráficos interactivos"
      "fr" -> "Votre navigateur ne supporte pas les graphiques interactifs"
      _ -> "Your browser does not support interactive charts"
    end
  end

  defp get_font_family("ar"), do: "Arial, 'Noto Sans Arabic', sans-serif"
  defp get_font_family("he"), do: "Arial, 'Noto Sans Hebrew', sans-serif"
  defp get_font_family("fa"), do: "Tahoma, 'Noto Sans Arabic', sans-serif"
  defp get_font_family("ur"), do: "'Noto Sans Urdu', Arial, sans-serif"
  defp get_font_family("ja"), do: "'Noto Sans JP', Arial, sans-serif"
  defp get_font_family("zh"), do: "'Noto Sans SC', Arial, sans-serif"
  defp get_font_family(_), do: "Arial, sans-serif"

  defp get_color_for_index(index) do
    colors = [
      "#FF6384",
      "#36A2EB",
      "#FFCE56",
      "#4BC0C0",
      "#9966FF",
      "#FF9F40",
      "#FF6384",
      "#C9CBCF"
    ]

    Enum.at(colors, rem(index, length(colors)))
  end

  defp generate_pie_colors(count) do
    for i <- 0..(count - 1) do
      hue = (i * 360 / count) |> round()
      "hsl(#{hue}, 70%, 60%)"
    end
  end
end
