# Phase 6.3: Multi-Renderer Chart Completion - Technical Planning Document

## 1. Technical Analysis

### 1.1 Current Renderer Status Assessment

Based on comprehensive codebase analysis, the current chart integration status across all AshReports renderers:

#### **HTML Renderer: ✅ COMPLETE** 
- **Status**: Full chart integration with Phase 5.2 implementation
- **Features**: Chart.js/D3.js/Plotly support, asset management, JavaScript generation
- **Files**: `HtmlRenderer.AssetManager`, `HtmlRenderer.ChartIntegrator`, `HtmlRenderer.JavaScriptGenerator`
- **Implementation**: 400+ lines of chart-specific code with comprehensive asset loading

#### **HEEX Renderer: ✅ COMPLETE**
- **Status**: Phase 6.2 LiveView integration with interactive charts complete
- **Features**: LiveView chart components, real-time updates, Phoenix hooks integration
- **Files**: `HeexRenderer` with Phase 6.2 chart component generation (lines 518-700)
- **Implementation**: LiveView chart components with `AshReports.LiveView.ChartLiveComponent`

#### **PDF Renderer: ❌ NO CHART INTEGRATION**
- **Status**: Basic PDF generation without chart support
- **Gap**: No chart rendering capabilities for static PDF reports
- **Current**: Only reuses HTML renderer without chart-to-PDF conversion
- **Missing**: Server-side chart image generation, PDF chart embedding

#### **JSON Renderer: ❌ LIMITED CHART SUPPORT**
- **Status**: Basic JSON structure without chart metadata
- **Gap**: No chart configuration export or API endpoints for chart data
- **Current**: Standard JSON serialization without chart awareness
- **Missing**: Chart metadata serialization, interactive chart APIs

### 1.2 Architecture Analysis

Current renderer architecture shows:
- **HTML + HEEX**: Full chart ecosystem with interactive capabilities
- **PDF + JSON**: Static renderers without chart integration
- **Missing Components**: Server-side chart image generation, chart metadata APIs

### 1.3 Integration Points

The existing chart infrastructure provides:
- **ChartEngine**: Complete chart generation with statistical analysis (Phase 5.1)
- **ChartIntegrator**: HTML-specific integration patterns
- **AssetManager**: Chart library asset management system
- **ChartHooks**: LiveView integration for interactive charts

## 2. Problem Definition

### 2.1 Multi-Renderer Chart Gap Analysis

Phase 6.2 successfully delivered interactive charts for HEEX/LiveView, but created a significant **disparity** across renderers:

#### **PDF Renderer Limitations**
- **No Static Chart Images**: PDF reports cannot include visual charts
- **Missing Chart Conversion**: No HTML-to-image pipeline for PDF embedding
- **Limited Business Value**: PDF reports lack visual data representation
- **Export Incompatibility**: LiveView charts cannot be preserved in PDF exports

#### **JSON Renderer API Gaps**
- **No Chart Metadata**: JSON exports lose all chart configuration information
- **Missing API Endpoints**: No structured chart data for external integrations
- **Limited Analytics Integration**: Third-party tools cannot access chart definitions
- **Incomplete Data Export**: Chart interactions and filters not serialized

### 2.2 Enterprise Use Case Requirements

Enterprise customers require **format consistency**:
- **Executive PDF Reports**: Static charts for board presentations and compliance
- **API Data Integration**: Chart configurations for business intelligence tools
- **Multi-Format Exports**: Preserve chart data across all output formats
- **Embedded Analytics**: Third-party applications need chart metadata access

### 2.3 Technical Debt and Scalability Issues

Current architecture creates:
- **Renderer Inconsistency**: Feature disparity across output formats
- **Development Overhead**: Chart features must be implemented per renderer
- **Maintenance Complexity**: Chart updates require multiple renderer modifications
- **Testing Burden**: Chart functionality testing across multiple formats

## 3. Solution Architecture

### 3.1 Universal Chart Integration System

Design a **renderer-agnostic chart integration** that extends chart capabilities to all renderers:

```
Phase 6.3 Multi-Renderer Chart Architecture
┌─────────────────────────────────────────────────────────────┐
│                    Chart Integration Core                    │
├─────────────────────────────────────────────────────────────┤
│  ChartEngine (Phase 5.1) - Statistical Analysis            │
│  ChartDataProcessor - Universal data preparation            │
│  ChartConfigSerializer - Cross-renderer configuration       │
└─────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
        ┌───────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐
        │ HTML/HEEX    │ │ PDF        │ │ JSON       │
        │ Interactive  │ │ Static     │ │ API        │
        │ Charts ✅    │ │ Images ❌  │ │ Data ❌    │
        └──────────────┘ └────────────┘ └────────────┘
                                │               │
                    ┌───────────▼─────────┐    │
                    │ ServerSideRenderer  │    │
                    │ - Headless browser  │    │
                    │ - Chart to PNG/SVG  │    │
                    │ - PDF embedding     │    │
                    └─────────────────────┘    │
                                              │
                                    ┌─────────▼─────────┐
                                    │ ChartAPIGenerator │
                                    │ - Metadata export │
                                    │ - Interactive APIs│
                                    │ - Data endpoints  │
                                    └───────────────────┘
```

### 3.2 PDF Chart Integration Strategy

#### **Server-Side Chart Rendering**
- **Technology**: Puppeteer/ChromicPDF headless browser rendering
- **Process**: HTML chart → Headless render → PNG/SVG → PDF embed
- **Quality**: High-DPI image generation for professional print quality
- **Performance**: Background processing with image caching

#### **PDF Chart Pipeline**
```elixir
defmodule AshReports.PdfRenderer.ChartProcessor do
  def render_charts_for_pdf(context) do
    context
    |> extract_chart_configs()
    |> render_charts_as_images()
    |> embed_images_in_pdf()
  end

  defp render_charts_as_images(chart_configs) do
    chart_configs
    |> Enum.map(&render_single_chart_image/1)
    |> handle_rendering_results()
  end

  defp render_single_chart_image(chart_config) do
    chart_config
    |> generate_html_chart()
    |> capture_with_headless_browser()
    |> optimize_for_pdf()
  end
end
```

### 3.3 JSON API Enhancement Strategy

#### **Chart Metadata Serialization**
- **Configuration Export**: Complete chart definitions in JSON structure
- **Interactive State**: Filters, selections, and user interactions
- **Data Endpoints**: RESTful APIs for chart data access
- **Schema Validation**: Structured chart metadata with versioning

#### **JSON Chart API Structure**
```json
{
  "report": {...},
  "charts": {
    "configurations": [
      {
        "id": "sales_chart_001",
        "type": "bar",
        "provider": "chartjs",
        "title": "Monthly Sales Trends",
        "data_source": "sales_data",
        "interactive": true,
        "config": {...},
        "api_endpoints": {
          "data": "/api/charts/sales_chart_001/data",
          "update": "/api/charts/sales_chart_001/update",
          "export": "/api/charts/sales_chart_001/export"
        }
      }
    ],
    "interactions": {
      "filters": {...},
      "selections": {...},
      "drill_downs": {...}
    }
  },
  "data": {...}
}
```

### 3.4 Embedded Analytics Support

#### **Third-Party Integration APIs**
- **Chart Configuration APIs**: Access to chart definitions for BI tools
- **Live Data Endpoints**: Real-time chart data for external dashboards
- **Embedding Code Generation**: iFrame and widget code for web integration
- **Authentication Integration**: Secure access to chart data and configurations

## 4. Implementation Plan

### 4.1 Week 1-2: Universal Chart Infrastructure

#### **Week 1: Chart Data Pipeline Enhancement**

**Day 1-2: ChartDataProcessor Universal Module**
```elixir
# lib/ash_reports/chart_engine/chart_data_processor.ex
defmodule AshReports.ChartEngine.ChartDataProcessor do
  @moduledoc """
  Universal chart data processing for all renderers.
  Prepares chart data for HTML, PDF, and JSON outputs.
  """

  def process_for_renderer(chart_config, context, renderer_type) do
    chart_config
    |> prepare_base_data(context)
    |> apply_renderer_optimizations(renderer_type)
    |> validate_output_compatibility(renderer_type)
  end

  defp apply_renderer_optimizations(data, :pdf) do
    data
    |> optimize_for_static_rendering()
    |> prepare_for_image_generation()
  end

  defp apply_renderer_optimizations(data, :json) do
    data
    |> serialize_interactive_state()
    |> prepare_api_metadata()
  end

  defp apply_renderer_optimizations(data, _), do: data
end
```

**Day 3-4: ChartConfigSerializer Module**
```elixir
# lib/ash_reports/chart_engine/chart_config_serializer.ex
defmodule AshReports.ChartEngine.ChartConfigSerializer do
  @moduledoc """
  Serializes chart configurations for cross-renderer compatibility.
  """

  def serialize_for_pdf(chart_config, context) do
    %{
      static_image_config: build_static_config(chart_config),
      image_dimensions: calculate_pdf_dimensions(chart_config, context),
      render_options: build_headless_options(chart_config)
    }
  end

  def serialize_for_json(chart_config, context) do
    %{
      configuration: sanitize_for_json(chart_config),
      api_endpoints: generate_api_endpoints(chart_config),
      interactive_state: extract_interactive_state(chart_config),
      metadata: build_chart_metadata(chart_config, context)
    }
  end
end
```

**Day 5: Integration Testing**
- Test universal chart data processing across all renderer types
- Validate configuration serialization for PDF and JSON outputs
- Performance testing for data processing pipeline

#### **Week 2: Server-Side Chart Rendering Infrastructure**

**Day 1-3: PDF Server-Side Renderer**
```elixir
# lib/ash_reports/pdf_renderer/server_side_chart_renderer.ex
defmodule AshReports.PdfRenderer.ServerSideChartRenderer do
  @moduledoc """
  Renders charts as images for PDF embedding using headless browser.
  """

  alias AshReports.HtmlRenderer

  def render_chart_as_image(chart_config, context, opts \\ []) do
    with {:ok, html_chart} <- generate_html_chart(chart_config, context),
         {:ok, image_binary} <- capture_chart_image(html_chart, opts),
         {:ok, optimized_image} <- optimize_for_pdf(image_binary, opts) do
      {:ok, %{
        image_data: optimized_image,
        dimensions: extract_dimensions(optimized_image),
        format: opts[:format] || :png
      }}
    end
  end

  defp generate_html_chart(chart_config, context) do
    # Reuse existing HTML chart generation
    chart_context = prepare_chart_context(chart_config, context)
    HtmlRenderer.ChartIntegrator.render_chart(chart_config, chart_context)
  end

  defp capture_chart_image(html_content, opts) do
    ChromicPDF.Template.source_and_options(
      content: wrap_chart_html(html_content),
      print_to_pdf: false,
      capture_screenshot: %{
        format: opts[:format] || :png,
        quality: opts[:quality] || 90,
        full_page: false,
        clip: calculate_chart_bounds(html_content)
      }
    )
    |> ChromicPDF.print_to_binary()
  end
end
```

**Day 4-5: Chart Image Cache System**
```elixir
# lib/ash_reports/pdf_renderer/chart_image_cache.ex
defmodule AshReports.PdfRenderer.ChartImageCache do
  @moduledoc """
  Caches rendered chart images for performance optimization.
  """

  use GenServer

  def get_or_render_chart_image(chart_config, context, opts) do
    cache_key = generate_cache_key(chart_config, context)
    
    case get_cached_image(cache_key) do
      {:ok, cached_image} -> {:ok, cached_image}
      {:error, :not_found} -> render_and_cache_image(cache_key, chart_config, context, opts)
    end
  end

  defp generate_cache_key(chart_config, context) do
    content_hash = :crypto.hash(:sha256, inspect({chart_config, context.records}))
    Base.encode16(content_hash, case: :lower)
  end

  defp render_and_cache_image(cache_key, chart_config, context, opts) do
    case ServerSideChartRenderer.render_chart_as_image(chart_config, context, opts) do
      {:ok, image_result} ->
        cache_image(cache_key, image_result)
        {:ok, image_result}
      error -> error
    end
  end
end
```

### 4.2 Week 3-4: PDF Chart Integration

#### **Week 3: PDF Renderer Enhancement**

**Day 1-2: Enhanced PDF Renderer with Chart Support**
```elixir
# Enhanced lib/ash_reports/pdf_renderer.ex
defmodule AshReports.PdfRenderer do
  # ... existing code ...

  defp generate_print_optimized_html(%RenderContext{} = context) do
    with {:ok, base_html_result} <- generate_base_html(context),
         {:ok, chart_images} <- render_charts_as_images(context),
         {:ok, print_css} <- PrintOptimizer.generate_print_css(context),
         {:ok, page_layout} <- PageManager.setup_page_layout(context),
         {:ok, optimized_html} <- 
           TemplateAdapter.optimize_for_pdf_with_charts(
             base_html_result.content,
             chart_images,
             print_css,
             page_layout,
             context
           ) do
      {:ok, optimized_html}
    end
  end

  defp render_charts_as_images(%RenderContext{} = context) do
    chart_configs = extract_chart_configs_from_context(context)
    
    case chart_configs do
      [] -> {:ok, []}
      configs -> 
        configs
        |> Enum.map(&render_single_chart_image(&1, context))
        |> collect_chart_images()
    end
  end

  defp render_single_chart_image(chart_config, context) do
    AshReports.PdfRenderer.ServerSideChartRenderer.render_chart_as_image(
      chart_config, 
      context,
      format: :png,
      quality: 95,
      width: 800,
      height: 600
    )
  end
end
```

**Day 3-4: PDF Template Adapter for Charts**
```elixir
# lib/ash_reports/pdf_renderer/template_adapter.ex - Enhanced
defmodule AshReports.PdfRenderer.TemplateAdapter do
  def optimize_for_pdf_with_charts(html_content, chart_images, print_css, page_layout, context) do
    html_content
    |> embed_chart_images(chart_images)
    |> apply_chart_positioning(page_layout)
    |> optimize_chart_print_styles(print_css)
    |> finalize_pdf_template(context)
  end

  defp embed_chart_images(html_content, chart_images) do
    chart_images
    |> Enum.reduce(html_content, fn {chart_id, image_data}, html ->
      image_element = create_pdf_image_element(chart_id, image_data)
      String.replace(html, chart_placeholder(chart_id), image_element)
    end)
  end

  defp create_pdf_image_element(chart_id, image_data) do
    base64_data = Base.encode64(image_data.image_data)
    
    """
    <div class="pdf-chart-container" id="#{chart_id}_pdf">
      <img src="data:image/png;base64,#{base64_data}" 
           class="pdf-chart-image"
           style="width: #{image_data.dimensions.width}px; height: #{image_data.dimensions.height}px; max-width: 100%;" 
           alt="Chart: #{chart_id}" />
    </div>
    """
  end

  defp chart_placeholder(chart_id), do: "<!-- CHART_PLACEHOLDER_#{chart_id} -->"
end
```

**Day 5: PDF Chart Integration Testing**
- Test complete PDF generation with embedded chart images
- Validate chart quality and positioning in PDF output
- Performance testing for chart image generation and caching

#### **Week 4: PDF Chart Optimization and Quality Assurance**

**Day 1-2: Chart Print Optimization**
```elixir
# lib/ash_reports/pdf_renderer/print_optimizer.ex - Chart Enhancement
defmodule AshReports.PdfRenderer.PrintOptimizer do
  def generate_chart_print_css(context) do
    """
    /* PDF Chart Styles */
    .pdf-chart-container {
      page-break-inside: avoid;
      margin: 10px 0;
      text-align: center;
    }

    .pdf-chart-image {
      max-width: 100%;
      height: auto;
      border: 1px solid #ddd;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    /* Print-specific chart optimizations */
    @media print {
      .pdf-chart-container {
        break-inside: avoid;
        -webkit-break-inside: avoid;
      }
      
      .pdf-chart-image {
        -webkit-print-color-adjust: exact;
        color-adjust: exact;
      }
    }

    /* High-DPI print support */
    @media print and (min-resolution: 300dpi) {
      .pdf-chart-image {
        image-rendering: -webkit-optimize-contrast;
        image-rendering: crisp-edges;
      }
    }
    """
  end
end
```

**Day 3-4: Advanced PDF Chart Features**
- Chart page break handling
- Multi-page chart support for large datasets
- Chart legends and axis label optimization for print
- Color profile optimization for PDF output

**Day 5: PDF Integration Quality Assurance**
- Comprehensive testing of PDF charts across different chart types
- Print quality validation
- Performance optimization and memory usage testing

### 4.3 Week 5-6: JSON API Enhancement

#### **Week 5: JSON Renderer Chart Integration**

**Day 1-2: Enhanced JSON Renderer**
```elixir
# Enhanced lib/ash_reports/json_renderer.ex
defmodule AshReports.JsonRenderer do
  # ... existing code ...

  defp build_json_structure(%RenderContext{} = context, serialized_data) do
    with {:ok, base_structure} <- StructureBuilder.build_report_structure(context, serialized_data),
         {:ok, chart_metadata} <- build_chart_metadata_structure(context),
         {:ok, chart_apis} <- generate_chart_api_structure(context) do
      enhanced_structure = base_structure
      |> Map.put(:charts, chart_metadata)
      |> Map.put(:chart_apis, chart_apis)
      |> add_interactive_chart_state(context)
      
      {:ok, enhanced_structure}
    end
  end

  defp build_chart_metadata_structure(%RenderContext{} = context) do
    chart_configs = extract_chart_configs_from_context(context)
    
    chart_metadata = %{
      count: length(chart_configs),
      configurations: Enum.map(chart_configs, &serialize_chart_config(&1, context)),
      interactive_features: extract_interactive_features(chart_configs),
      data_sources: extract_chart_data_sources(chart_configs)
    }
    
    {:ok, chart_metadata}
  end

  defp serialize_chart_config(chart_config, context) do
    ChartConfigSerializer.serialize_for_json(chart_config, context)
  end

  defp generate_chart_api_structure(%RenderContext{} = context) do
    chart_configs = extract_chart_configs_from_context(context)
    
    api_structure = %{
      base_url: build_api_base_url(context),
      endpoints: build_chart_endpoints(chart_configs),
      authentication: build_auth_requirements(context),
      rate_limiting: build_rate_limit_info()
    }
    
    {:ok, api_structure}
  end
end
```

**Day 3-4: Chart API Endpoint Generation**
```elixir
# lib/ash_reports/json_renderer/chart_api_generator.ex
defmodule AshReports.JsonRenderer.ChartApiGenerator do
  @moduledoc """
  Generates RESTful API endpoints for chart data access.
  """

  def generate_chart_endpoints(chart_configs, context) do
    chart_configs
    |> Enum.map(&build_chart_api_spec(&1, context))
    |> Enum.reduce(%{}, fn spec, acc ->
      Map.merge(acc, spec)
    end)
  end

  defp build_chart_api_spec(chart_config, context) do
    chart_id = chart_config.id || generate_chart_id(chart_config)
    base_path = "/api/charts/#{chart_id}"
    
    %{
      chart_id => %{
        data: %{
          url: "#{base_path}/data",
          method: "GET",
          description: "Get chart data",
          parameters: build_data_parameters(chart_config),
          response_schema: build_data_response_schema(chart_config)
        },
        config: %{
          url: "#{base_path}/config",
          method: "GET", 
          description: "Get chart configuration",
          response_schema: build_config_response_schema(chart_config)
        },
        update: %{
          url: "#{base_path}/data",
          method: "POST",
          description: "Update chart data",
          body_schema: build_update_body_schema(chart_config),
          response_schema: build_update_response_schema()
        },
        export: %{
          url: "#{base_path}/export",
          method: "GET",
          description: "Export chart in various formats",
          parameters: [
            %{name: "format", type: "string", enum: ["png", "svg", "pdf", "json"]},
            %{name: "width", type: "integer", default: 800},
            %{name: "height", type: "integer", default: 600}
          ]
        }
      }
    }
  end

  defp build_data_parameters(chart_config) do
    base_params = [
      %{name: "limit", type: "integer", default: 100, max: 1000},
      %{name: "offset", type: "integer", default: 0},
      %{name: "format", type: "string", enum: ["json", "csv"], default: "json"}
    ]

    if chart_config.interactive do
      interactive_params = [
        %{name: "filters", type: "object", description: "Chart filters"},
        %{name: "sort", type: "string", description: "Sort configuration"},
        %{name: "group_by", type: "string", description: "Grouping field"}
      ]
      base_params ++ interactive_params
    else
      base_params
    end
  end
end
```

**Day 5: JSON API Testing and Validation**
- Test chart metadata serialization
- Validate API endpoint generation
- Test JSON schema compliance for chart data

#### **Week 6: Advanced JSON Chart Features**

**Day 1-2: Interactive Chart State Serialization**
```elixir
# lib/ash_reports/json_renderer/interactive_state_serializer.ex
defmodule AshReports.JsonRenderer.InteractiveStateSerializer do
  @moduledoc """
  Serializes interactive chart state for API consumption.
  """

  def serialize_interactive_state(chart_config, context) do
    %{
      filters: serialize_chart_filters(chart_config, context),
      selections: serialize_chart_selections(chart_config, context),
      drill_downs: serialize_drill_downs(chart_config, context),
      zoom_state: serialize_zoom_state(chart_config, context),
      user_customizations: serialize_user_customizations(chart_config, context)
    }
    |> remove_empty_states()
  end

  defp serialize_chart_filters(chart_config, context) do
    case extract_active_filters(chart_config, context) do
      [] -> nil
      filters ->
        %{
          active_filters: filters,
          available_filters: extract_available_filters(chart_config),
          filter_schema: build_filter_schema(chart_config)
        }
    end
  end

  defp serialize_chart_selections(chart_config, context) do
    case extract_selections(chart_config, context) do
      [] -> nil
      selections ->
        %{
          selected_points: selections,
          selection_mode: chart_config.selection_mode || "single",
          selection_persistence: chart_config.persist_selections || false
        }
    end
  end
end
```

**Day 3-4: Chart Data Export APIs**
```elixir
# lib/ash_reports/json_renderer/chart_export_handler.ex
defmodule AshReports.JsonRenderer.ChartExportHandler do
  @moduledoc """
  Handles chart data export in various formats through API endpoints.
  """

  def handle_chart_export(chart_id, export_format, params, context) do
    with {:ok, chart_config} <- find_chart_config(chart_id, context),
         {:ok, chart_data} <- fetch_chart_data(chart_config, params, context),
         {:ok, exported_data} <- export_chart_data(chart_data, export_format, params) do
      {:ok, %{
        chart_id: chart_id,
        format: export_format,
        data: exported_data,
        metadata: build_export_metadata(chart_config, params)
      }}
    end
  end

  defp export_chart_data(chart_data, :json, _params) do
    {:ok, Jason.encode!(chart_data, pretty: true)}
  end

  defp export_chart_data(chart_data, :csv, _params) do
    case convert_to_csv(chart_data) do
      {:ok, csv_data} -> {:ok, csv_data}
      error -> error
    end
  end

  defp export_chart_data(chart_data, :png, params) do
    # Generate chart image for export
    ServerSideChartRenderer.render_chart_as_image(
      build_export_chart_config(chart_data),
      build_export_context(),
      format: :png,
      width: params[:width] || 800,
      height: params[:height] || 600
    )
  end
end
```

**Day 5: JSON Chart Integration Quality Assurance**
- Comprehensive testing of JSON chart metadata export
- API endpoint functionality testing  
- Performance testing for large chart datasets

### 4.4 Week 7-8: Integration and Quality Assurance

#### **Week 7: Cross-Renderer Integration Testing**

**Day 1-2: Multi-Renderer Chart Consistency Testing**
```elixir
# test/ash_reports/integration/multi_renderer_chart_test.exs
defmodule AshReports.Integration.MultiRendererChartTest do
  use ExUnit.Case
  
  alias AshReports.{HtmlRenderer, HeexRenderer, PdfRenderer, JsonRenderer}

  describe "chart consistency across renderers" do
    setup do
      chart_config = build_test_chart_config()
      context = build_test_context_with_charts()
      
      {:ok, chart_config: chart_config, context: context}
    end

    test "HTML renderer maintains chart functionality", %{context: context} do
      {:ok, result} = HtmlRenderer.render_with_context(context)
      
      assert result.content =~ "data-chart-id"
      assert result.content =~ "<canvas"
      assert result.metadata.charts_rendered == true
    end

    test "PDF renderer embeds chart images", %{context: context} do
      {:ok, result} = PdfRenderer.render_with_context(context)
      
      # PDF should contain embedded chart images
      assert result.metadata.chart_images_embedded == true
      assert result.metadata.charts_count > 0
      assert is_binary(result.content)
    end

    test "JSON renderer exports chart metadata", %{context: context} do
      {:ok, result} = JsonRenderer.render_with_context(context)
      
      json_data = Jason.decode!(result.content)
      
      assert Map.has_key?(json_data, "charts")
      assert json_data["charts"]["count"] > 0
      assert Map.has_key?(json_data, "chart_apis")
    end

    test "chart data consistency across renderers", %{context: context} do
      # Render same chart configuration across all renderers
      {:ok, html_result} = HtmlRenderer.render_with_context(context)
      {:ok, pdf_result} = PdfRenderer.render_with_context(context)  
      {:ok, json_result} = JsonRenderer.render_with_context(context)

      # Extract chart data from each renderer
      html_chart_data = extract_chart_data_from_html(html_result.content)
      pdf_chart_data = extract_chart_data_from_pdf(pdf_result.metadata)
      json_chart_data = extract_chart_data_from_json(json_result.content)

      # Verify data consistency
      assert charts_data_equivalent?(html_chart_data, pdf_chart_data)
      assert charts_data_equivalent?(html_chart_data, json_chart_data)
    end
  end

  describe "performance comparison across renderers" do
    test "chart rendering performance benchmarks", %{context: context} do
      # Measure rendering time for each renderer with charts
      html_time = benchmark_renderer(HtmlRenderer, context)
      pdf_time = benchmark_renderer(PdfRenderer, context)
      json_time = benchmark_renderer(JsonRenderer, context)

      # Performance assertions
      assert html_time < 1000 # < 1 second
      assert pdf_time < 5000  # < 5 seconds (includes image generation)
      assert json_time < 500  # < 500ms
    end
  end
end
```

**Day 3-4: Chart Quality Validation Testing**
```elixir
# test/ash_reports/chart_quality_test.exs
defmodule AshReports.ChartQualityTest do
  use ExUnit.Case

  describe "PDF chart image quality" do
    test "chart images are high quality and properly sized" do
      chart_config = build_test_chart_config()
      context = build_test_context()
      
      {:ok, image_result} = ServerSideChartRenderer.render_chart_as_image(
        chart_config, context, width: 800, height: 600, quality: 95
      )
      
      assert image_result.dimensions.width == 800
      assert image_result.dimensions.height == 600
      assert byte_size(image_result.image_data) > 50_000 # Reasonable quality threshold
    end

    test "chart images render correctly in PDF" do
      context = build_chart_context()
      
      {:ok, pdf_result} = PdfRenderer.render_with_context(context)
      
      # PDF should be valid and contain images
      assert is_binary(pdf_result.content)
      assert byte_size(pdf_result.content) > 100_000 # PDF with images
      assert pdf_result.metadata.chart_images_embedded == true
    end
  end

  describe "JSON chart API completeness" do
    test "chart APIs include all necessary endpoints" do
      context = build_chart_context()
      
      {:ok, json_result} = JsonRenderer.render_with_context(context)
      json_data = Jason.decode!(json_result.content)
      
      chart_apis = json_data["chart_apis"]
      
      # Verify API completeness
      assert Map.has_key?(chart_apis, "endpoints")
      assert Map.has_key?(chart_apis, "authentication") 
      assert Map.has_key?(chart_apis, "rate_limiting")
      
      # Verify endpoint structure
      endpoints = chart_apis["endpoints"]
      chart_id = get_first_chart_id(endpoints)
      
      assert Map.has_key?(endpoints[chart_id], "data")
      assert Map.has_key?(endpoints[chart_id], "config")
      assert Map.has_key?(endpoints[chart_id], "update")
      assert Map.has_key?(endpoints[chart_id], "export")
    end
  end
end
```

**Day 5: Integration Performance Optimization**
- Profile chart rendering performance across all renderers
- Optimize shared chart processing pipeline
- Implement caching strategies for expensive operations

#### **Week 8: Production Readiness and Documentation**

**Day 1-2: Production Configuration and Optimization**
```elixir
# config/config.exs - Chart Integration Configuration
config :ash_reports, AshReports.ChartEngine,
  # Universal chart processing
  chart_processing: %{
    max_data_points: 10_000,
    processing_timeout: 30_000,
    cache_enabled: true,
    cache_ttl: 3600 # 1 hour
  },
  
  # PDF chart rendering
  pdf_charts: %{
    image_format: :png,
    default_width: 800,
    default_height: 600,
    quality: 95,
    background_color: "#ffffff",
    cache_images: true,
    max_cache_size_mb: 500
  },
  
  # JSON chart APIs  
  json_charts: %{
    api_base_url: "/api/charts",
    include_metadata: true,
    enable_export_apis: true,
    max_data_export_size: 100_000,
    rate_limit_requests_per_minute: 1000
  },
  
  # Server-side rendering
  headless_rendering: %{
    pool_size: 2,
    timeout: 10_000,
    viewport: %{width: 1024, height: 768},
    wait_for_selector: ".chart-loaded",
    cleanup_timeout: 5_000
  }
```

**Day 3-4: Comprehensive Documentation**

Create comprehensive documentation covering:

1. **Chart Integration Guide**: How to use charts across all renderers
2. **PDF Chart Configuration**: Settings for optimal chart image quality
3. **JSON API Reference**: Complete API endpoint documentation
4. **Performance Optimization**: Best practices for chart rendering
5. **Troubleshooting Guide**: Common issues and solutions

**Day 5: Final Quality Assurance and Release Preparation**
- Complete end-to-end testing of all chart features
- Performance validation under load
- Security review of chart APIs
- Documentation review and finalization

## 5. Testing Strategy

### 5.1 Unit Testing Coverage

#### **Chart Processing Pipeline Tests**
```elixir
# Core chart processing functionality
describe "ChartDataProcessor" do
  test "processes chart data for all renderer types"
  test "optimizes data based on renderer capabilities"
  test "handles large datasets efficiently"
  test "validates output compatibility"
end

describe "ChartConfigSerializer" do
  test "serializes configurations for PDF rendering"
  test "serializes configurations for JSON APIs"
  test "maintains configuration integrity across formats"
end
```

#### **Renderer-Specific Tests**
```elixir
# PDF chart integration tests
describe "PdfRenderer Chart Integration" do
  test "renders charts as high-quality images"
  test "embeds chart images in PDF correctly"
  test "handles multiple charts in single PDF"
  test "optimizes chart positioning for print"
end

# JSON API tests  
describe "JsonRenderer Chart APIs" do
  test "exports complete chart metadata"
  test "generates valid API endpoint specifications"
  test "handles interactive chart state serialization"
  test "supports multiple export formats"
end
```

### 5.2 Integration Testing

#### **Cross-Renderer Consistency Tests**
- Chart data consistency across all renderers
- Configuration compatibility verification
- Performance comparison benchmarks
- Error handling consistency

#### **End-to-End Workflow Tests**
- Complete report generation with charts in all formats
- Chart configuration changes reflected across renderers
- Data updates propagating to all output formats
- Export functionality across renderer types

### 5.3 Performance Testing

#### **Chart Rendering Performance**
- PDF chart image generation latency (target: < 2 seconds per chart)
- JSON chart metadata export speed (target: < 100ms)
- Memory usage during chart processing (target: < 100MB per report)
- Concurrent chart rendering scalability

#### **Load Testing Scenarios**
- Multiple concurrent PDF reports with charts
- High-frequency JSON API chart data requests
- Large dataset chart processing (10,000+ data points)
- Extended operation memory stability testing

### 5.4 Quality Assurance

#### **Chart Quality Validation**
- PDF chart image visual quality verification
- Chart data accuracy across all formats
- Interactive chart state preservation in JSON
- Chart accessibility in generated outputs

#### **API Compliance Testing**
- JSON chart API specification validation
- HTTP response format consistency
- API authentication and authorization
- Rate limiting functionality verification

## 6. Quality Assurance

### 6.1 Code Quality Standards

#### **Credo Compliance Target**
- **Zero Credo Issues**: All new chart integration code must pass Credo analysis
- **Comprehensive Documentation**: All public functions documented with examples
- **Type Specifications**: Complete @spec coverage for all public functions
- **Error Handling**: Consistent error handling patterns across all modules

#### **Testing Requirements**
- **95%+ Code Coverage**: All chart integration functionality covered by tests
- **Integration Tests**: Cross-renderer chart functionality verification  
- **Performance Tests**: Chart rendering benchmarks and memory usage validation
- **Load Tests**: Concurrent chart processing validation

### 6.2 Performance Requirements

#### **PDF Chart Generation**
- **Image Quality**: High-DPI chart images (>= 300 DPI for print)
- **Generation Speed**: < 2 seconds per chart image
- **Memory Efficiency**: < 50MB memory usage per chart
- **Cache Hit Rate**: >= 80% for repeated chart configurations

#### **JSON Chart APIs**
- **Response Time**: < 100ms for chart metadata export
- **Data Export**: < 500ms for chart data export (up to 10,000 records)
- **Throughput**: >= 1000 requests per minute per chart endpoint
- **Memory Usage**: < 10MB per JSON chart serialization

### 6.3 Production Readiness Checklist

#### **Infrastructure Requirements**
- [ ] ChromicPDF/Puppeteer headless browser setup
- [ ] Chart image cache storage configuration
- [ ] API rate limiting implementation
- [ ] Chart processing error monitoring
- [ ] Performance metrics collection

#### **Security Considerations**
- [ ] Chart API authentication integration
- [ ] Chart data access authorization
- [ ] Image generation security (prevent SSRF attacks)
- [ ] API input validation and sanitization
- [ ] Chart export data privacy compliance

## 7. Future Enhancement Opportunities

### 7.1 Advanced Chart Features

#### **Enhanced PDF Chart Integration**
- **Vector Charts**: SVG chart embedding for scalable PDF graphics
- **Interactive PDF**: PDF form integration for basic chart interactions
- **Multi-Page Charts**: Large chart datasets split across PDF pages
- **Chart Annotations**: PDF annotation support for chart markup

#### **Extended JSON APIs**  
- **Real-Time Chart Data**: WebSocket APIs for live chart data streaming
- **Chart Collaboration**: Multi-user chart editing and sharing APIs
- **Chart Templates**: Reusable chart configuration API management
- **Analytics Integration**: Chart usage and interaction analytics

### 7.2 Performance and Scalability

#### **Advanced Caching Strategies**
- **Distributed Chart Cache**: Redis-based chart image and data caching
- **Smart Cache Invalidation**: Intelligent cache refresh based on data changes
- **Predictive Caching**: Pre-generate popular chart configurations
- **CDN Integration**: Chart image distribution via content delivery networks

#### **Scalability Enhancements**
- **Background Chart Processing**: Asynchronous chart generation for large reports
- **Chart Processing Queues**: Job queue system for high-volume chart rendering
- **Horizontal Scaling**: Multi-node chart processing distribution
- **Resource Optimization**: Dynamic resource allocation based on chart complexity

### 7.3 Developer Experience

#### **Enhanced Development Tools**
- **Chart Preview System**: Live preview of charts during development
- **Chart Testing Framework**: Specialized testing tools for chart functionality  
- **Chart Performance Profiler**: Detailed performance analysis for chart rendering
- **Chart Configuration Validator**: Real-time validation of chart configurations

#### **Integration Ecosystem**
- **Third-Party Chart Providers**: Plugin system for additional chart libraries
- **Business Intelligence Connectors**: Direct integration with BI platforms
- **Chart Widget System**: Embeddable chart widgets for web applications
- **Mobile Chart Support**: Native mobile chart rendering capabilities

---

## 8. Implementation Success Criteria

### 8.1 Technical Achievement Targets

#### **Multi-Renderer Chart Completion**
- ✅ **HTML/HEEX Renderers**: Maintain existing interactive chart capabilities
- 🎯 **PDF Renderer**: Server-side chart image generation with high-quality embedding
- 🎯 **JSON Renderer**: Complete chart metadata export with RESTful APIs
- 🎯 **Cross-Renderer Consistency**: Identical chart data across all output formats

#### **Performance and Quality Benchmarks**
- 🎯 **PDF Chart Quality**: High-DPI images (>= 300 DPI) for professional print output
- 🎯 **JSON API Performance**: < 100ms response time for chart metadata export
- 🎯 **Memory Efficiency**: < 100MB memory usage for complex multi-chart reports  
- 🎯 **Zero Code Issues**: Perfect Credo compliance across all new chart integration code

#### **Enterprise Feature Completeness**
- 🎯 **Static PDF Charts**: Executive-quality chart images in PDF reports
- 🎯 **Chart Data APIs**: RESTful endpoints for business intelligence integration
- 🎯 **Export Capabilities**: Multi-format chart export (PNG, SVG, PDF, JSON)
- 🎯 **Embedded Analytics**: Third-party application integration support

### 8.2 Business Value Delivery

#### **Format Consistency Achievement**
- **Executive Reporting**: PDF reports with professional chart visualization
- **API Integration**: Structured chart data for external analytics platforms
- **Data Interchange**: Complete chart configuration export/import capabilities
- **Multi-Channel Publishing**: Consistent charts across web, PDF, and API formats

#### **Developer Productivity Enhancement**
- **Single Chart Definition**: Write once, render across all formats
- **Comprehensive Testing**: Automated chart functionality validation
- **Performance Monitoring**: Built-in chart rendering metrics and optimization
- **Documentation Excellence**: Complete guides and API references

---

## 9. Conclusion

Phase 6.3 represents the **completion of AshReports' multi-renderer chart ecosystem**, transforming the framework from a partially-integrated chart system into a comprehensive, enterprise-grade reporting platform with consistent chart capabilities across all output formats.

### 9.1 Strategic Technical Achievement

**Universal Chart Integration**: This phase eliminates the renderer disparity created by Phase 6.2's LiveView-focused approach, delivering **consistent chart capabilities** across HTML, HEEX, PDF, and JSON outputs through a unified processing architecture.

**Server-Side Chart Rendering**: The introduction of headless browser-based chart image generation enables **professional-quality static charts** in PDF reports, addressing the critical gap in executive reporting and compliance documentation requirements.

**API-First Chart Integration**: Enhanced JSON renderer with comprehensive chart metadata export and RESTful APIs positions AshReports as a **data integration platform**, enabling seamless connectivity with business intelligence tools and third-party applications.

### 9.2 Enterprise Readiness Validation

**Production-Grade Implementation**: The 8-week implementation plan with comprehensive testing, performance optimization, and quality assurance ensures **enterprise deployment readiness** with zero-compromise code quality standards.

**Scalability and Performance**: Advanced caching strategies, background processing capabilities, and performance benchmarking ensure the chart integration scales to **enterprise workloads** while maintaining optimal response times.

**Security and Compliance**: Authentication integration, input validation, and data privacy considerations ensure **enterprise security requirements** are met for chart APIs and image generation processes.

### 9.3 Developer Experience Excellence  

**Unified Development Model**: Single chart configuration driving consistent output across all renderers eliminates **development complexity** and reduces maintenance overhead for chart functionality.

**Comprehensive Testing Framework**: Multi-renderer chart testing infrastructure ensures **quality consistency** and provides confidence in cross-format chart behavior.

**Complete Documentation Ecosystem**: Detailed implementation guides, API references, and troubleshooting documentation enable **rapid adoption** and effective utilization of chart capabilities.

### 9.4 Future-Proof Architecture

**Extensible Chart System**: The renderer-agnostic chart processing pipeline provides a **solid foundation** for future chart providers, advanced analytics integration, and emerging output formats.

**API-Driven Integration**: RESTful chart APIs and structured metadata export enable **ecosystem growth** through third-party integrations and embedded analytics use cases.

**Performance-Optimized Foundation**: Built-in caching, background processing, and resource optimization provide **scalability headroom** for future feature expansion and increased usage demands.

---

**Phase 6.3 Final Deliverable**: A **complete multi-renderer chart integration system** that elevates AshReports from a mixed-capability framework to a **unified enterprise reporting platform** with professional chart visualization across all output formats, comprehensive API integration capabilities, and production-ready performance characteristics.

This implementation establishes AshReports as a **comprehensive business intelligence foundation** capable of serving diverse enterprise reporting requirements while maintaining the performance characteristics and code quality standards of a well-architected Elixir reporting system.