# Ash Reports Implementation Plan

## Overview

This implementation plan is organized into 6 phases, with each phase building upon the previous one. Each section within a phase includes unit testing, and each phase concludes with integration testing to ensure all components work together correctly.

## Phase 1: Core Foundation and DSL Framework

**Duration: 3-4 weeks**  
**Goal: Establish the foundational Spark DSL extensions and basic report structure**

### 1.1 Spark DSL Foundation

#### Implementation Tasks:
- [ ] 1.1.1 Create `Ash.Report` extension module
- [ ] 1.1.2 Define core DSL schema for reports
- [ ] 1.1.3 Implement basic section definitions
- [ ] 1.1.4 Create DSL entity modules for Band, Element, Variable

#### Code Structure:
```elixir
# lib/ash/report.ex
defmodule Ash.Report do
  use Spark.Dsl.Extension,
    sections: @sections,
    transformers: []
end

# lib/ash/report/dsl.ex
defmodule Ash.Report.Dsl do
  # Core DSL definitions
end
```

#### Testing:
```elixir
# test/ash/report/dsl_test.exs
defmodule Ash.Report.DslTest do
  use ExUnit.Case

  test "accepts valid report definition" do
    assert {:ok, _} = 
      Spark.Dsl.parse("""
      report :test_report do
        title "Test Report"
        driving_resource TestResource
      end
      """, Ash.Report)
  end

  test "rejects invalid report definition" do
    assert {:error, _} = 
      Spark.Dsl.parse("""
      report :test_report do
        # Missing required fields
      end
      """, Ash.Report)
  end
end
```

### 1.2 Band Hierarchy Implementation

#### Implementation Tasks:
- [ ] 1.2.1 Create Band entity with type validation
- [ ] 1.2.2 Implement band ordering logic
- [ ] 1.2.3 Add band nesting support for groups
- [ ] 1.2.4 Create band validation transformer

#### Code Structure:
```elixir
# lib/ash/report/band.ex
defmodule Ash.Report.Band do
  use Spark.Dsl.Entity
  
  defstruct [:type, :group_level, :detail_number, ...]
end

# lib/ash/report/transformers/validate_bands.ex
defmodule Ash.Report.Transformers.ValidateBands do
  use Spark.Dsl.Transformer
  
  def transform(dsl_state) do
    # Validate band hierarchy
  end
end
```

#### Testing:
```elixir
# test/ash/report/band_test.exs
defmodule Ash.Report.BandTest do
  use ExUnit.Case

  describe "band hierarchy validation" do
    test "validates correct band order" do
      bands = [
        %Band{type: :title},
        %Band{type: :page_header},
        %Band{type: :detail},
        %Band{type: :summary}
      ]
      
      assert :ok = Ash.Report.Band.validate_hierarchy(bands)
    end

    test "rejects invalid band order" do
      bands = [
        %Band{type: :summary},
        %Band{type: :title}
      ]
      
      assert {:error, _} = Ash.Report.Band.validate_hierarchy(bands)
    end
  end
end
```

### 1.3 Element System

#### Implementation Tasks:
- [ ] 1.3.1 Create Element entity types (field, label, expression, etc.)
- [ ] 1.3.2 Implement position and style schemas
- [ ] 1.3.3 Add element validation
- [ ] 1.3.4 Create element renderer interface

#### Testing:
```elixir
# test/ash/report/element_test.exs
defmodule Ash.Report.ElementTest do
  use ExUnit.Case

  test "creates field element with valid path" do
    element = %Element{
      type: :field,
      source: [:customer, :name],
      position: [x: 10, y: 20]
    }
    
    assert :ok = Element.validate(element)
  end

  test "validates expression elements" do
    element = %Element{
      type: :expression,
      source: expr(total * 0.1),
      format: [number: [precision: 2]]
    }
    
    assert :ok = Element.validate(element)
  end
end
```

### 1.4 Basic Report Registry

#### Implementation Tasks:
- [ ] 1.4.1 Create report storage mechanism
- [ ] 1.4.2 Implement report lookup functions
- [ ] 1.4.3 Add report compilation logic
- [ ] 1.4.4 Create basic report metadata

#### Testing:
```elixir
# test/ash/report/registry_test.exs
defmodule Ash.Report.RegistryTest do
  use ExUnit.Case

  test "registers and retrieves reports" do
    report = %Report{name: :test_report, title: "Test"}
    
    :ok = Registry.register(report)
    assert {:ok, ^report} = Registry.get(:test_report)
  end
end
```

### Phase 1 Integration Tests

```elixir
# test/integration/phase1_test.exs
defmodule Ash.Report.Phase1IntegrationTest do
  use ExUnit.Case

  defmodule TestDomain do
    use Ash.Domain,
      extensions: [Ash.Report]

    reports do
      report :basic_report do
        title "Basic Integration Test Report"
        driving_resource TestResource
        
        bands do
          band :title do
            elements do
              label "Test Report", position: [x: :center, y: 10]
            end
          end
          
          band :detail do
            elements do
              field :name, position: [x: 10, y: 5]
              field :value, position: [x: 100, y: 5]
            end
          end
        end
      end
    end
  end

  test "complete DSL compilation and registration" do
    assert {:ok, domain} = Ash.Domain.Info.reports(TestDomain)
    assert length(domain.reports) == 1
    
    report = hd(domain.reports)
    assert report.name == :basic_report
    assert length(report.bands) == 2
  end
end
```

## Phase 2: Data Integration and Query System

**Duration: 3-4 weeks**  
**Goal: Integrate with Ash Query system and implement data fetching**

### 2.1 Query Builder

#### Implementation Tasks:
- [ ] 2.1.1 Create query builder for report scope
- [ ] 2.1.2 Implement parameter substitution
- [ ] 2.1.3 Add query validation
- [ ] 2.1.4 Create query optimization logic

#### Code Structure:
```elixir
# lib/ash/report/query_builder.ex
defmodule Ash.Report.QueryBuilder do
  def build_query(report, params) do
    report.driving_resource
    |> apply_scope(report.scope, params)
    |> apply_sorting(report.sorting)
    |> apply_loading(report.required_loads)
  end
end
```

#### Testing:
```elixir
# test/ash/report/query_builder_test.exs
defmodule Ash.Report.QueryBuilderTest do
  use ExUnit.Case

  test "builds query with parameters" do
    report = %Report{
      driving_resource: Order,
      scope: fn params ->
        Order |> Ash.Query.filter(date >= ^params.start_date)
      end
    }
    
    query = QueryBuilder.build_query(report, %{start_date: ~D[2024-01-01]})
    
    assert %Ash.Query{resource: Order} = query
    assert query.filter != nil
  end
end
```

### 2.2 Variable System Implementation

#### Implementation Tasks:
- [ ] 2.2.1 Create variable storage and state management
- [ ] 2.2.2 Implement reset logic for different scopes
- [ ] 2.2.3 Add variable calculation engine
- [ ] 2.2.4 Create variable dependency resolver

#### Testing:
```elixir
# test/ash/report/variable_test.exs
defmodule Ash.Report.VariableTest do
  use ExUnit.Case

  describe "variable calculations" do
    test "calculates sum variable" do
      variable = %Variable{
        name: :total,
        type: :sum,
        expression: expr(amount),
        reset_on: :report
      }
      
      state = VariableState.new([variable])
      state = VariableState.update(state, :total, %{amount: 100})
      state = VariableState.update(state, :total, %{amount: 50})
      
      assert VariableState.get_value(state, :total) == 150
    end

    test "resets on group change" do
      variable = %Variable{
        name: :group_total,
        type: :sum,
        expression: expr(amount),
        reset_on: :group,
        reset_group: 1
      }
      
      state = VariableState.new([variable])
      state = VariableState.update(state, :group_total, %{amount: 100})
      state = VariableState.reset_group(state, 1)
      
      assert VariableState.get_value(state, :group_total) == 0
    end
  end
end
```

### 2.3 Group Processing Engine

#### Implementation Tasks:
- [ ] 2.3.1 Implement group break detection
- [ ] 2.3.2 Create group value tracking
- [ ] 2.3.3 Add multi-level group support
- [ ] 2.3.4 Implement group sorting

#### Testing:
```elixir
# test/ash/report/group_processor_test.exs
defmodule Ash.Report.GroupProcessorTest do
  use ExUnit.Case

  test "detects group breaks" do
    processor = GroupProcessor.new([
      %Group{field: :category, level: 1},
      %Group{field: :subcategory, level: 2}
    ])
    
    current = %{category: "A", subcategory: "X"}
    next = %{category: "A", subcategory: "Y"}
    
    assert {:break, 2} = GroupProcessor.check_break(processor, current, next)
  end
end
```

### 2.4 Data Loader

#### Implementation Tasks:
- [ ] 2.4.1 Create data fetching orchestrator
- [ ] 2.4.2 Implement relationship loading
- [ ] 2.4.3 Add data transformation pipeline
- [ ] 2.4.4 Create streaming support for large datasets

#### Testing:
```elixir
# test/ash/report/data_loader_test.exs
defmodule Ash.Report.DataLoaderTest do
  use ExUnit.Case

  test "loads data with relationships" do
    report = build_test_report()
    params = %{start_date: ~D[2024-01-01]}
    
    {:ok, data} = DataLoader.load(report, params)
    
    assert length(data) > 0
    assert Ash.Resource.loaded?(hd(data), :customer)
  end
end
```

### Phase 2 Integration Tests

```elixir
# test/integration/phase2_test.exs
defmodule Ash.Report.Phase2IntegrationTest do
  use ExUnit.Case

  setup do
    # Create test data
    {:ok, customer} = Customer.create(%{name: "Test Customer"})
    {:ok, _} = Order.create(%{
      customer_id: customer.id,
      amount: 100,
      category: "Electronics",
      date: ~D[2024-01-15]
    })
    {:ok, _} = Order.create(%{
      customer_id: customer.id,
      amount: 200,
      category: "Electronics",
      date: ~D[2024-01-20]
    })
    
    :ok
  end

  test "processes report with groups and variables" do
    report = TestDomain.get_report!(:grouped_report)
    params = %{start_date: ~D[2024-01-01], end_date: ~D[2024-01-31]}
    
    {:ok, result} = Ash.Report.Engine.process(report, params)
    
    assert result.groups["Electronics"] == %{
      records: 2,
      total: 300
    }
    
    assert result.variables.grand_total == 300
  end
end
```

## Phase 3: Rendering Engine and Output Formats

**Duration: 4-5 weeks**  
**Goal: Implement the rendering abstraction and multiple output formats**

### 3.1 Renderer Interface

#### Implementation Tasks:
- [ ] 3.1.1 Create renderer behavior
- [ ] 3.1.2 Implement render context
- [ ] 3.1.3 Add layout calculation engine
- [ ] 3.1.4 Create render pipeline

#### Code Structure:
```elixir
# lib/ash/report/renderer.ex
defmodule Ash.Report.Renderer do
  @callback render(report :: Report.t(), data :: term(), opts :: keyword()) ::
              {:ok, binary()} | {:error, term()}
              
  defmacro __using__(_) do
    quote do
      @behaviour Ash.Report.Renderer
      
      def render(report, data, opts) do
        context = build_render_context(report, data, opts)
        do_render(context)
      end
    end
  end
end
```

#### Testing:
```elixir
# test/ash/report/renderer_test.exs
defmodule Ash.Report.RendererTest do
  use ExUnit.Case

  defmodule TestRenderer do
    use Ash.Report.Renderer
    
    def do_render(context) do
      {:ok, "test output"}
    end
  end

  test "renderer behavior implementation" do
    report = build_test_report()
    data = []
    
    assert {:ok, "test output"} = TestRenderer.render(report, data, [])
  end
end
```

### 3.2 HTML Renderer

#### Implementation Tasks:
- [ ] 3.2.1 Create HTML template system
- [ ] 3.2.2 Implement CSS styling
- [ ] 3.2.3 Add responsive layout support
- [ ] 3.2.4 Create HTML element builders

#### Testing:
```elixir
# test/ash/report/renderer/html_test.exs
defmodule Ash.Report.Renderer.HTMLTest do
  use ExUnit.Case

  test "renders valid HTML structure" do
    report = build_simple_report()
    data = [%{name: "Test", value: 100}]
    
    {:ok, html} = Ash.Report.Renderer.HTML.render(report, data, [])
    
    assert html =~ ~r/<div class="ash-report"/
    assert html =~ ~r/<div class="ash-report-band-title"/
    assert html =~ "Test"
  end

  test "applies custom styles" do
    element = %Element{
      type: :label,
      content: "Test",
      style: [color: "red", font_size: "14px"]
    }
    
    html = Ash.Report.Renderer.HTML.render_element(element)
    assert html =~ ~r/style="color: red; font-size: 14px"/
  end
end
```

### 3.3 HEEX Renderer

#### Implementation Tasks:
- [ ] 3.3.1 Create Phoenix component integration
- [ ] 3.3.2 Implement live view support
- [ ] 3.3.3 Add interactive elements
- [ ] 3.3.4 Create component library

#### Testing:
```elixir
# test/ash/report/renderer/heex_test.exs
defmodule Ash.Report.Renderer.HEEXTest do
  use ExUnit.Case
  import Phoenix.LiveViewTest

  test "renders as Phoenix component" do
    report = build_test_report()
    data = build_test_data()
    
    html = render_component(&Ash.Report.Renderer.HEEX.report/1, 
      report: report,
      data: data
    )
    
    assert html =~ "ash-report"
    assert html =~ "Test Report"
  end
end
```

### 3.4 PDF Renderer

#### Implementation Tasks:
- [ ] 3.4.1 Integrate PDF generation library (ChromicPDF/wkhtmltopdf)
- [ ] 3.4.2 Implement page layout management
- [ ] 3.4.3 Add page breaking logic
- [ ] 3.4.4 Create PDF-specific formatting

#### Testing:
```elixir
# test/ash/report/renderer/pdf_test.exs
defmodule Ash.Report.Renderer.PDFTest do
  use ExUnit.Case

  test "generates valid PDF" do
    report = build_test_report()
    data = build_test_data()
    
    {:ok, pdf_binary} = Ash.Report.Renderer.PDF.render(report, data, [])
    
    assert is_binary(pdf_binary)
    assert byte_size(pdf_binary) > 1000
    assert String.starts_with?(pdf_binary, "%PDF")
  end

  test "handles page breaks correctly" do
    report = build_report_with_many_records()
    data = build_large_dataset()
    
    {:ok, pdf} = Ash.Report.Renderer.PDF.render(report, data, [])
    
    # Verify page headers appear on each page
    assert count_occurrences(pdf, "Page Header") > 1
  end
end
```

### 3.5 JSON Renderer

#### Implementation Tasks:
- [ ] 3.5.1 Create JSON structure definition
- [ ] 3.5.2 Implement data serialization
- [ ] 3.5.3 Add metadata inclusion
- [ ] 3.5.4 Create JSON schema validation

#### Testing:
```elixir
# test/ash/report/renderer/json_test.exs
defmodule Ash.Report.Renderer.JSONTest do
  use ExUnit.Case

  test "renders valid JSON structure" do
    report = build_test_report()
    data = build_test_data()
    
    {:ok, json_string} = Ash.Report.Renderer.JSON.render(report, data, [])
    {:ok, decoded} = Jason.decode(json_string)
    
    assert decoded["report"]["name"] == "test_report"
    assert decoded["metadata"]["generated_at"]
    assert is_list(decoded["data"])
  end
end
```

### Phase 3 Integration Tests

```elixir
# test/integration/phase3_test.exs
defmodule Ash.Report.Phase3IntegrationTest do
  use ExUnit.Case

  test "renders same report in multiple formats" do
    report = create_test_report()
    data = create_test_data()
    
    {:ok, html} = Ash.Report.render(report, data, format: :html)
    {:ok, pdf} = Ash.Report.render(report, data, format: :pdf)
    {:ok, json} = Ash.Report.render(report, data, format: :json)
    
    assert is_binary(html) and String.contains?(html, "<html>")
    assert is_binary(pdf) and String.starts_with?(pdf, "%PDF")
    assert is_binary(json) and match?({:ok, _}, Jason.decode(json))
  end

  test "maintains data consistency across formats" do
    report = create_summary_report()
    data = create_financial_data()
    
    {:ok, html} = Ash.Report.render(report, data, format: :html)
    {:ok, json_string} = Ash.Report.render(report, data, format: :json)
    {:ok, json} = Jason.decode(json_string)
    
    # Extract total from HTML
    html_total = extract_total_from_html(html)
    json_total = json["summary"]["total"]
    
    assert html_total == json_total
  end
end
```

## Phase 4: Internationalization and Formatting

**Duration: 2-3 weeks**  
**Goal: Integrate CLDR for comprehensive internationalization**

### 4.1 CLDR Integration

#### Implementation Tasks:
- [ ] 4.1.1 Set up ex_cldr configuration
- [ ] 4.1.2 Create formatter module
- [ ] 4.1.3 Implement locale detection
- [ ] 4.1.4 Add locale fallback logic

#### Code Structure:
```elixir
# lib/ash/report/cldr.ex
defmodule Ash.Report.Cldr do
  use Cldr,
    locales: ["en", "es", "fr", "de", "ja"],
    default_locale: "en",
    providers: [Cldr.Number, Cldr.DateTime, Cldr.Unit, Cldr.Currency]
end
```

#### Testing:
```elixir
# test/ash/report/cldr_test.exs
defmodule Ash.Report.CldrTest do
  use ExUnit.Case

  test "formats numbers for different locales" do
    assert "1,234.56" = Ash.Report.Formatter.format_number(1234.56, locale: "en")
    assert "1.234,56" = Ash.Report.Formatter.format_number(1234.56, locale: "de")
    assert "1 234,56" = Ash.Report.Formatter.format_number(1234.56, locale: "fr")
  end
end
```

### 4.2 Format Specifications

#### Implementation Tasks:
- [ ] 4.2.1 Create format specification DSL
- [ ] 4.2.2 Implement format parsers
- [ ] 4.2.3 Add custom format support
- [ ] 4.2.4 Create format validation

#### Testing:
```elixir
# test/ash/report/format_spec_test.exs
defmodule Ash.Report.FormatSpecTest do
  use ExUnit.Case

  test "parses currency format" do
    spec = [currency: :USD]
    assert {:ok, formatter} = FormatSpec.parse(spec)
    
    assert "$1,234.56" = formatter.(1234.56, locale: "en")
  end

  test "parses date format" do
    spec = [date: :medium]
    assert {:ok, formatter} = FormatSpec.parse(spec)
    
    date = ~D[2024-01-15]
    assert "Jan 15, 2024" = formatter.(date, locale: "en")
    assert "15 janv. 2024" = formatter.(date, locale: "fr")
  end
end
```

### 4.3 Locale-aware Rendering

#### Implementation Tasks:
- [ ] 4.3.1 Update renderers for locale support
- [ ] 4.3.2 Implement RTL support for applicable locales
- [ ] 4.3.3 Add locale-specific styling
- [ ] 4.3.4 Create translation system for labels

#### Testing:
```elixir
# test/ash/report/locale_rendering_test.exs
defmodule Ash.Report.LocaleRenderingTest do
  use ExUnit.Case

  test "renders report in different locales" do
    report = build_financial_report()
    data = build_test_data()
    
    {:ok, en_html} = Ash.Report.render(report, data, format: :html, locale: "en")
    {:ok, de_html} = Ash.Report.render(report, data, format: :html, locale: "de")
    
    assert en_html =~ "$1,234.56"
    assert de_html =~ "1.234,56 $"
  end
end
```

### Phase 4 Integration Tests

```elixir
# test/integration/phase4_test.exs
defmodule Ash.Report.Phase4IntegrationTest do
  use ExUnit.Case

  test "complete internationalized report" do
    report = create_international_report()
    data = create_multi_currency_data()
    
    locales = ["en", "de", "fr", "ja"]
    
    results = for locale <- locales do
      {:ok, html} = Ash.Report.render(report, data, 
        format: :html, 
        locale: locale
      )
      {locale, html}
    end
    
    # Verify each locale has different formatting
    assert Enum.all?(results, fn {locale, html} ->
      String.contains?(html, expected_format_for_locale(locale))
    end)
  end
end
```

## Phase 5: Server Infrastructure

**Duration: 3-4 weeks**  
**Goal: Implement report server and MCP server**

### 5.1 Report Server

#### Implementation Tasks:
- [ ] 5.1.1 Create GenServer for report management
- [ ] 5.1.2 Implement job queue
- [ ] 5.1.3 Add caching layer
- [ ] 5.1.4 Create monitoring and metrics

#### Code Structure:
```elixir
# lib/ash/report/server.ex
defmodule Ash.Report.Server do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  # Implementation...
end
```

#### Testing:
```elixir
# test/ash/report/server_test.exs
defmodule Ash.Report.ServerTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = Ash.Report.Server.start_link(reports_domain: TestDomain)
    {:ok, server: pid}
  end

  test "runs report synchronously", %{server: _server} do
    {:ok, result} = Ash.Report.Server.run_report(:test_report, %{})
    
    assert result.report == :test_report
    assert result.content
  end

  test "runs report asynchronously" do
    {:ok, job_id} = Ash.Report.Server.run_report_async(:test_report, %{})
    
    assert is_binary(job_id)
    
    # Wait for completion
    assert eventually(fn ->
      {:ok, :completed} == Ash.Report.Server.get_status(job_id)
    end)
  end
end
```

### 5.2 Caching System

#### Implementation Tasks:
- [ ] 5.2.1 Implement ETS-based cache
- [ ] 5.2.2 Add cache key generation
- [ ] 5.2.3 Create TTL management
- [ ] 5.2.4 Implement cache invalidation

#### Testing:
```elixir
# test/ash/report/cache_test.exs
defmodule Ash.Report.CacheTest do
  use ExUnit.Case

  test "caches report results" do
    report = :test_report
    params = %{date: ~D[2024-01-01]}
    
    # First call - miss
    assert :miss = Cache.get(report, params)
    
    result = %{content: "test"}
    :ok = Cache.put(report, params, result, ttl: 1000)
    
    # Second call - hit
    assert {:hit, ^result} = Cache.get(report, params)
  end

  test "respects TTL" do
    Cache.put(:test, %{}, "data", ttl: 100)
    assert {:hit, "data"} = Cache.get(:test, %{})
    
    Process.sleep(150)
    assert :miss = Cache.get(:test, %{})
  end
end
```

### 5.3 MCP Server Implementation

#### Implementation Tasks:
- [ ] 5.3.1 Create TCP server
- [ ] 5.3.2 Implement MCP protocol
- [ ] 5.3.3 Add authentication
- [ ] 5.3.4 Create tool registration

#### Testing:
```elixir
# test/ash/report/mcp_server_test.exs
defmodule Ash.Report.MCPServerTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = Ash.Report.MCPServer.start_link(
      port: 0,  # Random port
      allowed_reports: [:test_report]
    )
    
    {:ok, port} = Ash.Report.MCPServer.get_port(pid)
    {:ok, server: pid, port: port}
  end

  test "handles MCP initialize", %{port: port} do
    {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
    
    request = %{
      jsonrpc: "2.0",
      method: "initialize",
      params: %{},
      id: 1
    }
    
    :ok = :gen_tcp.send(socket, Jason.encode!(request))
    {:ok, response} = :gen_tcp.recv(socket, 0)
    
    {:ok, decoded} = Jason.decode(response)
    assert decoded["result"]["protocolVersion"] == "1.0.0"
  end

  test "lists available tools", %{port: port} do
    # Connect and initialize first
    socket = connect_and_initialize(port)
    
    request = %{
      jsonrpc: "2.0",
      method: "tools/list",
      params: %{},
      id: 2
    }
    
    :ok = :gen_tcp.send(socket, Jason.encode!(request))
    {:ok, response} = :gen_tcp.recv(socket, 0)
    
    {:ok, decoded} = Jason.decode(response)
    tools = decoded["result"]["tools"]
    
    assert length(tools) == 1
    assert hd(tools)["name"] == "report_test_report"
  end
end
```

### 5.4 API Documentation

#### Implementation Tasks:
- [ ] 5.4.1 Generate OpenAPI specification
- [ ] 5.4.2 Create API client examples
- [ ] 5.4.3 Add rate limiting
- [ ] 5.4.4 Implement API versioning

### Phase 5 Integration Tests

```elixir
# test/integration/phase5_test.exs
defmodule Ash.Report.Phase5IntegrationTest do
  use ExUnit.Case

  test "end-to-end report generation through server" do
    # Start servers
    {:ok, _} = start_supervised({Ash.Report.Server, reports_domain: TestDomain})
    {:ok, _} = start_supervised({Ash.Report.MCPServer, 
      port: 5555,
      allowed_reports: [:sales_report]
    })
    
    # Generate report through server
    {:ok, job_id} = Ash.Report.Server.run_report_async(:sales_report, %{
      start_date: ~D[2024-01-01],
      end_date: ~D[2024-01-31]
    })
    
    # Poll for completion
    assert eventually(fn ->
      case Ash.Report.Server.get_result(job_id) do
        {:ok, result} -> 
          assert result.content
          true
        _ -> 
          false
      end
    end, timeout: 5000)
  end

  test "MCP server integration" do
    # Setup MCP server
    {:ok, mcp} = start_supervised({Ash.Report.MCPServer, 
      port: 5556,
      allowed_reports: [:test_report]
    })
    
    # Simulate LLM request
    {:ok, socket} = :gen_tcp.connect('localhost', 5556, [:binary, active: false])
    
    # Initialize
    send_mcp_request(socket, "initialize", %{})
    
    # Call tool
    response = send_mcp_request(socket, "tools/call", %{
      name: "report_test_report",
      arguments: %{param1: "value1"}
    })
    
    assert response["result"]["content"]
  end
end
```

## Phase 6: Advanced Features and Polish

**Duration: 3-4 weeks**  
**Goal: Add advanced features and production readiness**

### 6.1 Ash.Resource.Reportable Extension

#### Implementation Tasks:
- [ ] 6.1.1 Create resource extension
- [ ] 6.1.2 Implement field exposure
- [ ] 6.1.3 Add calculated fields
- [ ] 6.1.4 Create field security

#### Testing:
```elixir
# test/ash/resource/reportable_test.exs
defmodule Ash.Resource.ReportableTest do
  use ExUnit.Case

  defmodule TestResource do
    use Ash.Resource,
      extensions: [Ash.Resource.Reportable]
    
    reportable do
      field :name, :string, label: "Customer Name"
      field :email, :string, sensitive: true
      
      calculation :full_address do
        calculate fn record, _context ->
          "#{record.address}, #{record.city}, #{record.state}"
        end
      end
    end
  end

  test "exposes reportable fields" do
    fields = Ash.Resource.Reportable.fields(TestResource)
    
    assert length(fields) == 3
    assert Enum.find(fields, & &1.name == :name)
  end

  test "respects field sensitivity" do
    email_field = Ash.Resource.Reportable.get_field(TestResource, :email)
    assert email_field.sensitive == true
  end
end
```

### 6.2 Performance Optimization

#### Implementation Tasks:
- [ ] 6.2.1 Implement query optimization
- [ ] 6.2.2 Add connection pooling
- [ ] 6.2.3 Create streaming for large datasets
- [ ] 6.2.4 Implement parallel processing

#### Testing:
```elixir
# test/ash/report/performance_test.exs
defmodule Ash.Report.PerformanceTest do
  use ExUnit.Case

  @tag :performance
  test "handles large datasets efficiently" do
    # Create 10,000 records
    create_large_dataset(10_000)
    
    report = create_test_report()
    
    {time, {:ok, _result}} = :timer.tc(fn ->
      Ash.Report.run(report, %{}, streaming: true)
    end)
    
    # Should complete in under 5 seconds
    assert time < 5_000_000
  end

  @tag :performance
  test "uses streaming for memory efficiency" do
    create_large_dataset(50_000)
    
    report = create_test_report()
    
    # Monitor memory usage
    before_memory = :erlang.memory(:total)
    
    {:ok, stream} = Ash.Report.stream(report, %{}, chunk_size: 1000)
    
    # Process stream
    Enum.each(stream, fn _chunk ->
      # Verify memory doesn't grow significantly
      current_memory = :erlang.memory(:total)
      assert current_memory < before_memory * 1.5
    end)
  end
end
```

### 6.3 Security Enhancements

#### Implementation Tasks:
- [ ] 6.3.1 Implement row-level security
- [ ] 6.3.2 Add audit logging
- [ ] 6.3.3 Create permission caching
- [ ] 6.3.4 Implement data masking

#### Testing:
```elixir
# test/ash/report/security_test.exs
defmodule Ash.Report.SecurityTest do
  use ExUnit.Case

  test "enforces report permissions" do
    user_without_permission = %User{permissions: []}
    user_with_permission = %User{permissions: [:view_financial_reports]}
    
    report = %Report{permissions: [:view_financial_reports]}
    
    assert {:error, :unauthorized} = 
      Ash.Report.authorize(report, user_without_permission)
      
    assert :ok = 
      Ash.Report.authorize(report, user_with_permission)
  end

  test "applies data masking" do
    report = create_report_with_sensitive_fields()
    data = create_sensitive_data()
    
    {:ok, result} = Ash.Report.run(report, %{}, 
      actor: %User{permissions: [:view_masked_data]}
    )
    
    # Verify sensitive fields are masked
    assert result.data |> hd() |> Map.get(:ssn) == "XXX-XX-1234"
  end
end
```

### 6.4 Monitoring and Observability

#### Implementation Tasks:
- [ ] 6.4.1 Add telemetry events
- [ ] 6.4.2 Create health checks
- [ ] 6.4.3 Implement error tracking
- [ ] 6.4.4 Add performance metrics

#### Testing:
```elixir
# test/ash/report/telemetry_test.exs
defmodule Ash.Report.TelemetryTest do
  use ExUnit.Case

  test "emits telemetry events" do
    self = self()
    
    handler = fn event, measurements, metadata, _config ->
      send(self, {:telemetry, event, measurements, metadata})
    end
    
    :telemetry.attach(
      "test-handler",
      [:ash, :report, :run, :stop],
      handler,
      nil
    )
    
    Ash.Report.run(:test_report, %{})
    
    assert_receive {:telemetry, [:ash, :report, :run, :stop], measurements, metadata}
    assert measurements.duration > 0
    assert metadata.report == :test_report
  end
end
```

### Phase 6 Integration Tests

```elixir
# test/integration/phase6_test.exs
defmodule Ash.Report.Phase6IntegrationTest do
  use ExUnit.Case

  test "complete production scenario" do
    # Setup monitoring
    attach_telemetry_handler()
    
    # Create test data with relationships
    {:ok, customer} = create_customer()
    {:ok, orders} = create_orders_for_customer(customer, 100)
    
    # Define report with all features
    report = create_comprehensive_report()
    
    # Run report with security context
    actor = %User{
      permissions: [:view_reports, :view_financial_data],
      locale: "de-DE"
    }
    
    {:ok, result} = Ash.Report.Server.run_report(:comprehensive_report, 
      %{customer_id: customer.id},
      actor: actor,
      format: :pdf,
      locale: actor.locale
    )
    
    # Verify result
    assert byte_size(result.content) > 10_000
    assert result.metadata.locale == "de-DE"
    assert result.metadata.record_count == 100
    
    # Verify telemetry
    assert_receive {:telemetry, [:ash, :report, :run, :stop], _, _}
    
    # Verify caching
    {:ok, cached} = Ash.Report.Server.run_report(:comprehensive_report,
      %{customer_id: customer.id},
      actor: actor,
      format: :pdf,
      locale: actor.locale
    )
    
    assert cached.metadata.cache_hit == true
  end

  test "stress test with concurrent reports" do
    # Create shared test data
    setup_stress_test_data()
    
    # Run 50 concurrent reports
    tasks = for i <- 1..50 do
      Task.async(fn ->
        Ash.Report.Server.run_report(:stress_test_report, %{
          iteration: i,
          date_range: random_date_range()
        })
      end)
    end
    
    # All should complete successfully
    results = Task.await_many(tasks, 30_000)
    
    assert Enum.all?(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    # Verify server is still responsive
    assert {:ok, _} = Ash.Report.Server.run_report(:simple_report, %{})
  end
end
```

## Final System Integration Test

```elixir
# test/integration/system_test.exs
defmodule Ash.Report.SystemTest do
  use ExUnit.Case

  @moduledoc """
  Complete system integration test covering all phases
  """

  setup_all do
    # Start all services
    start_supervised!({Ash.Report.Server, 
      reports_domain: TestApp.Reports,
      cache_ttl: :timer.minutes(5)
    })
    
    start_supervised!({Ash.Report.MCPServer,
      port: 5557,
      allowed_reports: [:customer_summary, :financial_report],
      require_authentication: true
    })
    
    # Create test data
    seed_test_database()
    
    :ok
  end

  test "complete end-to-end report generation workflow" do
    # 1. Define a complex report using DSL
    assert TestApp.Reports.get_report(:customer_summary)
    
    # 2. Run report with parameters and internationalization
    params = %{
      start_date: ~D[2024-01-01],
      end_date: ~D[2024-12-31],
      customer_type: "premium"
    }
    
    actor = %User{
      id: 1,
      permissions: [:view_customer_reports],
      locale: "fr-FR"
    }
    
    # 3. Generate in multiple formats
    formats = [:pdf, :html, :json, :heex]
    
    results = for format <- formats do
      {:ok, result} = Ash.Report.Server.run_report(:customer_summary,
        params,
        actor: actor,
        format: format,
        locale: actor.locale
      )
      {format, result}
    end
    
    # 4. Verify all formats generated correctly
    assert Enum.all?(results, fn {format, result} ->
      validate_format(format, result.content) and
      result.metadata.locale == "fr-FR"
    end)
    
    # 5. Test MCP server access
    mcp_response = call_mcp_tool("report_customer_summary", params)
    assert mcp_response["content"]
    
    # 6. Verify caching works
    {time1, {:ok, _}} = :timer.tc(fn ->
      Ash.Report.Server.run_report(:customer_summary, params, actor: actor)
    end)
    
    {time2, {:ok, result}} = :timer.tc(fn ->
      Ash.Report.Server.run_report(:customer_summary, params, actor: actor)
    end)
    
    assert result.metadata.cache_hit == true
    assert time2 < time1 / 10  # Cached should be much faster
    
    # 7. Test streaming for large dataset
    large_params = Map.put(params, :customer_type, "all")
    
    {:ok, stream} = Ash.Report.stream(:customer_summary, large_params,
      actor: actor,
      chunk_size: 100
    )
    
    chunk_count = Enum.count(stream)
    assert chunk_count > 10  # Should have multiple chunks
  end

  defp validate_format(:pdf, content), do: String.starts_with?(content, "%PDF")
  defp validate_format(:html, content), do: content =~ ~r/<html/i
  defp validate_format(:json, content), do: match?({:ok, _}, Jason.decode(content))
  defp validate_format(:heex, content), do: is_struct(content, Phoenix.LiveView.Rendered)
end
```

## Testing Strategy Summary

### Unit Test Coverage Goals
- DSL parsing and validation: 100%
- Core logic (bands, variables, groups): 95%
- Renderers: 90%
- Server components: 85%
- Integration points: 80%

### Performance Benchmarks
- Simple report (< 100 records): < 100ms
- Medium report (1,000 records): < 1 second
- Large report (10,000 records): < 10 seconds
- Streaming enabled: Memory usage < 2x baseline

### Test Automation
- Run unit tests on every commit
- Run integration tests on PR
- Run performance tests nightly
- Run system tests before release

## Deployment Checklist

### Phase Completion Criteria
Each phase is considered complete when:
1. All unit tests pass (100%)
2. Integration tests pass (100%)
3. Documentation is complete
4. Code review approved
5. Performance benchmarks met

### Production Readiness
Before deploying to production:
1. All phases complete
2. System integration test passes
3. Load testing completed
4. Security audit performed
5. Monitoring configured
6. Documentation published
7. Training materials prepared