# Stage 3, Section 3.3.1: SVG Embedding System - Planning Document

**Feature Branch**: `feature/stage3-section3.3.1-svg-embedding-system`
**Status**: Planning
**Date**: 2025-10-03
**Dependencies**:
- Section 3.1 (Chart Infrastructure) - COMPLETED
- Section 3.2.1 (Data Transformation Pipeline) - COMPLETED
- Section 3.2.2 (Chart Type Implementations) - COMPLETED
- Section 3.2.3 (Dynamic Configuration) - COMPLETED
- Stage 1 (Typst Integration) - COMPLETED

---

## 1. Problem Statement

### What Problem Does SVG Embedding Solve?

Currently, AshReports has a complete chart generation system that produces SVG output:
- Charts module generates SVG via Contex (bar, line, pie, area, scatter)
- Data transformation pipeline extracts and aggregates data
- Theme system provides styling and layout options

However, **there is no mechanism to embed these charts into Typst PDF reports**. The charts exist in isolation and cannot be included in the final report documents.

### Impact on Report Workflow

Without SVG embedding:
1. **Manual Process**: Users must generate charts separately and manually insert them
2. **No Automation**: Cannot programmatically include charts in reports
3. **Limited Layout Control**: No multi-chart page layouts or positioning
4. **Missing Integration**: Charts and report data are disconnected

### Why This Is Needed Now

This section represents the **critical integration point** between:
- Stage 3's chart generation system (Sections 3.1, 3.2.x)
- Stage 1's Typst PDF generation (DSLGenerator, BinaryWrapper)

Without this integration, charts remain isolated and cannot fulfill the core requirement: **generating comprehensive PDF reports with embedded visualizations**.

### Current State Analysis

**What We Have**:
- `AshReports.Charts.generate(:bar, data, config)` → returns SVG string
- `AshReports.Typst.DSLGenerator.generate_template(report)` → returns Typst template string
- `AshReports.Typst.BinaryWrapper.compile(template)` → returns PDF binary

**What's Missing**:
- No mechanism to embed SVG into Typst templates
- No chart positioning or layout system in templates
- No caption/title support for charts
- No multi-chart page layout capabilities
- No integration between Charts and Typst modules

---

## 2. Solution Overview

### High-Level Approach

Create a `ChartEmbedder` module that bridges the chart generation system and Typst template generation:

```
Chart Data → Charts.generate(:bar, data, config) → SVG string
                                                       ↓
                                          ChartEmbedder.embed(svg, opts)
                                                       ↓
                                    Typst #image() with base64 encoding
                                                       ↓
                                    DSLGenerator injects into template
                                                       ↓
                                       BinaryWrapper.compile() → PDF
```

### Key Design Decisions

#### 1. SVG Encoding Strategy: Base64 vs File Paths

**Decision**: Use **base64 encoding** as the primary strategy with file path fallback.

**Rationale**:
- **Base64 Advantages**:
  - No file system dependencies
  - Works in all environments (containers, serverless)
  - Atomic template generation (single string)
  - No cleanup required
  - Thread-safe (no file conflicts)

- **Base64 Disadvantages**:
  - ~33% size increase for large SVGs
  - Template size grows with embedded charts

- **File Path Fallback**: Use for very large SVGs (>1MB) to avoid template bloat

**Implementation**:
```elixir
# Primary: Base64 encoding
svg_data = Base.encode64(svg_string)
typst_code = "#image.decode(\"#{svg_data}\", format: \"svg\")"

# Fallback: File path (for large charts)
path = write_temp_svg(svg_string)
typst_code = "#image(\"#{path}\")"
```

#### 2. Typst Image Function Syntax

Typst provides two ways to embed images:

**Option A: Base64 inline** (chosen for primary approach)
```typst
#image.decode("data:image/svg+xml;base64,PHN2ZyB...", format: "svg")
```

**Option B: File path** (fallback for large charts)
```typst
#image("path/to/chart.svg")
```

**Decision**: Use Option A (base64) as primary, Option B as fallback for >1MB SVGs.

#### 3. Layout System Design

Implement two layout modes:

**Grid Layout**: Fixed grid with cells
```typst
#grid(
  columns: (1fr, 1fr),
  gutter: 10pt,
  [#image.decode("chart1", format: "svg")],
  [#image.decode("chart2", format: "svg")]
)
```

**Flow Layout**: Stacking with configurable spacing
```typst
#v(20pt)
#image.decode("chart1", format: "svg")
#v(20pt)
#image.decode("chart2", format: "svg")
```

**Decision**: Support both, default to flow layout for simplicity.

#### 4. Integration Points

**With DSLGenerator**:
- Add `chart` element support to band processing
- Generate Typst image code from chart elements
- Maintain existing band architecture

**With StreamingPipeline**:
- Chart data extracted via existing pipeline
- Aggregations computed during streaming
- SVG generated after data collection

**With Existing Charts Module**:
- No changes to Charts.generate/3 API
- ChartEmbedder calls Charts.generate internally
- Maintains separation of concerns

---

## 3. Technical Details

### Module Structure

#### Primary Module: `AshReports.Typst.ChartEmbedder`

**Location**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/chart_embedder.ex`

**Responsibilities**:
1. Convert SVG string to Typst image code
2. Handle base64 encoding and file path fallback
3. Generate chart positioning and sizing code
4. Create caption and title blocks
5. Build multi-chart layouts (grid/flow)

**Public API**:
```elixir
defmodule AshReports.Typst.ChartEmbedder do
  @moduledoc """
  Embeds SVG charts into Typst templates for PDF generation.

  Provides utilities for converting chart SVG output into Typst #image()
  function calls with proper encoding, positioning, and layout.
  """

  @doc """
  Embeds a single chart SVG into Typst code.

  ## Parameters

    - `svg` - SVG string from Charts.generate/3
    - `opts` - Embedding options:
      - `:width` - Chart width (e.g., "100%", "300pt", "50mm")
      - `:height` - Chart height (optional, maintains aspect ratio if omitted)
      - `:caption` - Caption text below chart
      - `:title` - Title text above chart
      - `:position` - Position in layout (:top, :center, :bottom, :left, :right)
      - `:encoding` - :base64 (default) or :file

  ## Returns

    - `{:ok, typst_code}` - Typst code string to embed in template
    - `{:error, reason}` - Encoding or validation failed

  ## Examples

      svg = "<svg>...</svg>"
      {:ok, typst} = ChartEmbedder.embed(svg,
        width: "100%",
        caption: "Sales by Region"
      )
      # => "#image.decode(\"PHN2Zy...\", format: \"svg\", width: 100%)"
  """
  @spec embed(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def embed(svg, opts \\ [])

  @doc """
  Embeds multiple charts in a grid layout.

  ## Parameters

    - `charts` - List of {svg, opts} tuples
    - `layout_opts` - Grid configuration:
      - `:columns` - Number of columns (default: 2)
      - `:gutter` - Space between cells (default: "10pt")
      - `:column_widths` - Custom column widths (e.g., ["1fr", "2fr"])

  ## Returns

    - `{:ok, typst_code}` - Typst grid code

  ## Examples

      charts = [
        {svg1, [caption: "Chart 1"]},
        {svg2, [caption: "Chart 2"]},
        {svg3, [caption: "Chart 3"]}
      ]

      {:ok, typst} = ChartEmbedder.embed_grid(charts, columns: 2)
  """
  @spec embed_grid(list({String.t(), keyword()}), keyword()) :: {:ok, String.t()} | {:error, term()}
  def embed_grid(charts, layout_opts \\ [])

  @doc """
  Embeds multiple charts in a vertical flow layout.

  ## Parameters

    - `charts` - List of {svg, opts} tuples
    - `spacing` - Vertical spacing between charts (default: "20pt")

  ## Examples

      charts = [
        {svg1, [caption: "Q1 Results"]},
        {svg2, [caption: "Q2 Results"]}
      ]

      {:ok, typst} = ChartEmbedder.embed_flow(charts, spacing: "30pt")
  """
  @spec embed_flow(list({String.t(), keyword()}), String.t()) :: {:ok, String.t()} | {:error, term()}
  def embed_flow(charts, spacing \\ "20pt")

  @doc """
  Generates chart from data and embeds in one operation.

  ## Parameters

    - `chart_type` - Chart type atom (:bar, :line, :pie, etc.)
    - `data` - Chart data
    - `config` - Chart config (Config struct or map)
    - `embed_opts` - Embedding options (same as embed/2)

  ## Examples

      data = [%{category: "A", value: 10}, %{category: "B", value: 20}]
      config = %Config{title: "Sales", width: 600, height: 400}

      {:ok, typst} = ChartEmbedder.generate_and_embed(:bar, data, config,
        width: "100%",
        caption: "Sales by Category"
      )
  """
  @spec generate_and_embed(atom(), list(map()), Config.t() | map(), keyword()) ::
    {:ok, String.t()} | {:error, term()}
  def generate_and_embed(chart_type, data, config, embed_opts \\ [])
end
```

#### Helper Module: `AshReports.Typst.ChartEmbedder.TypstFormatter`

**Location**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/chart_embedder/typst_formatter.ex`

**Responsibilities**:
- Format Typst dimension values (pt, mm, cm, %, fr)
- Generate Typst layout code (grid, stack, align)
- Escape and sanitize strings for Typst
- Handle Typst-specific syntax

**Public API**:
```elixir
defmodule AshReports.Typst.ChartEmbedder.TypstFormatter do
  @doc """
  Formats dimension value for Typst (converts to appropriate unit).

  ## Examples

      format_dimension("100%") # => "100%"
      format_dimension(300)    # => "300pt"
      format_dimension("50mm") # => "50mm"
  """
  def format_dimension(value)

  @doc """
  Generates Typst #grid() function call.
  """
  def build_grid_layout(items, columns, gutter)

  @doc """
  Generates Typst vertical stack with spacing.
  """
  def build_flow_layout(items, spacing)

  @doc """
  Escapes string for safe inclusion in Typst template.
  """
  def escape_string(text)

  @doc """
  Wraps content with caption below.
  """
  def add_caption(content, caption_text)

  @doc """
  Wraps content with title above.
  """
  def add_title(content, title_text)
end
```

### File Structure

```
lib/ash_reports/typst/
├── chart_embedder.ex              # Main embedding module (~400 lines)
├── chart_embedder/
│   └── typst_formatter.ex         # Typst formatting helpers (~250 lines)

test/ash_reports/typst/
├── chart_embedder_test.exs        # Unit tests (~350 lines)
├── chart_embedder/
│   └── typst_formatter_test.exs   # Formatter tests (~150 lines)

test/support/
└── chart_embedding_helpers.ex     # Test utilities (~100 lines)
```

**Total**: ~1,250 lines (implementation + tests)

### Dependencies

**Existing Modules** (no changes required):
- `AshReports.Charts` - Generates SVG charts
- `AshReports.Charts.Config` - Chart configuration
- `AshReports.Typst.DSLGenerator` - Template generation
- `AshReports.Typst.BinaryWrapper` - PDF compilation

**New Dependencies**: **None** - uses only Elixir standard library

### SVG Encoding Implementation

```elixir
defmodule AshReports.Typst.ChartEmbedder do
  # Size threshold for file fallback (1MB)
  @file_fallback_threshold 1_000_000

  @doc """
  Encodes SVG for Typst embedding.

  Uses base64 encoding for small/medium SVGs (<1MB).
  Falls back to temporary file for large SVGs (≥1MB).
  """
  def encode_svg(svg) when is_binary(svg) do
    svg_size = byte_size(svg)

    if svg_size < @file_fallback_threshold do
      encode_base64(svg)
    else
      encode_file(svg)
    end
  end

  defp encode_base64(svg) do
    # Base64 encode SVG
    encoded = Base.encode64(svg)

    # Return Typst image.decode() call
    typst_code = ~s(#image.decode("#{encoded}", format: "svg"))

    {:ok, typst_code, :base64}
  end

  defp encode_file(svg) do
    # Generate unique filename
    filename = "chart_#{:crypto.strong_rand_bytes(16) |> Base.url_encode64()}.svg"

    # Write to temp directory
    temp_dir = System.tmp_dir!()
    path = Path.join(temp_dir, filename)

    case File.write(path, svg) do
      :ok ->
        # Return Typst image() call with file path
        typst_code = ~s(#image("#{path}"))
        {:ok, typst_code, {:file, path}}

      {:error, reason} ->
        {:error, {:file_write_failed, reason}}
    end
  end
end
```

### Layout System Implementation

```elixir
defmodule AshReports.Typst.ChartEmbedder do
  alias AshReports.Typst.ChartEmbedder.TypstFormatter

  @doc """
  Creates grid layout with multiple charts.
  """
  def embed_grid(charts, layout_opts \\ []) do
    columns = Keyword.get(layout_opts, :columns, 2)
    gutter = Keyword.get(layout_opts, :gutter, "10pt")

    # Embed each chart individually
    with {:ok, chart_codes} <- embed_all(charts) do
      # Build grid layout
      grid_code = TypstFormatter.build_grid_layout(chart_codes, columns, gutter)
      {:ok, grid_code}
    end
  end

  @doc """
  Creates vertical flow layout with charts stacked.
  """
  def embed_flow(charts, spacing \\ "20pt") do
    with {:ok, chart_codes} <- embed_all(charts) do
      flow_code = TypstFormatter.build_flow_layout(chart_codes, spacing)
      {:ok, flow_code}
    end
  end

  defp embed_all(charts) do
    results = Enum.map(charts, fn {svg, opts} ->
      embed(svg, opts)
    end)

    # Check if all succeeded
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      codes = Enum.map(results, fn {:ok, code} -> code end)
      {:ok, codes}
    else
      # Find first error
      {:error, reason} = Enum.find(results, &match?({:error, _}, &1))
      {:error, reason}
    end
  end
end
```

### Caption and Title Support

```elixir
defmodule AshReports.Typst.ChartEmbedder do
  def embed(svg, opts) do
    with {:ok, image_code, _encoding} <- encode_svg(svg),
         {:ok, sized_code} <- apply_sizing(image_code, opts),
         {:ok, positioned_code} <- apply_position(sized_code, opts),
         {:ok, captioned_code} <- apply_caption(positioned_code, opts),
         {:ok, final_code} <- apply_title(captioned_code, opts) do
      {:ok, final_code}
    end
  end

  defp apply_sizing(image_code, opts) do
    width = Keyword.get(opts, :width)
    height = Keyword.get(opts, :height)

    sized_code = case {width, height} do
      {nil, nil} ->
        image_code

      {w, nil} ->
        # Width only - maintain aspect ratio
        "#{image_code}(width: #{TypstFormatter.format_dimension(w)})"

      {nil, h} ->
        # Height only - maintain aspect ratio
        "#{image_code}(height: #{TypstFormatter.format_dimension(h)})"

      {w, h} ->
        # Both specified
        "#{image_code}(width: #{TypstFormatter.format_dimension(w)}, height: #{TypstFormatter.format_dimension(h)})"
    end

    {:ok, sized_code}
  end

  defp apply_caption(code, opts) do
    case Keyword.get(opts, :caption) do
      nil -> {:ok, code}
      caption -> {:ok, TypstFormatter.add_caption(code, caption)}
    end
  end

  defp apply_title(code, opts) do
    case Keyword.get(opts, :title) do
      nil -> {:ok, code}
      title -> {:ok, TypstFormatter.add_title(code, title)}
    end
  end
end
```

### TypstFormatter Implementation

```elixir
defmodule AshReports.Typst.ChartEmbedder.TypstFormatter do
  @doc """
  Formats dimension for Typst.

  Supports: pt, mm, cm, in, %, fr, auto
  """
  def format_dimension(value) when is_number(value) do
    # Default to points
    "#{value}pt"
  end

  def format_dimension(value) when is_binary(value) do
    # Already formatted (e.g., "100%", "50mm")
    value
  end

  def format_dimension(:auto), do: "auto"

  @doc """
  Builds Typst grid layout.
  """
  def build_grid_layout(items, columns, gutter) do
    # Calculate column specification
    col_spec = List.duplicate("1fr", columns) |> Enum.join(", ")

    # Format items
    formatted_items = Enum.map(items, fn item ->
      "[#{item}]"
    end) |> Enum.join(",\n  ")

    """
    #grid(
      columns: (#{col_spec}),
      gutter: #{format_dimension(gutter)},
      #{formatted_items}
    )
    """
  end

  @doc """
  Builds Typst flow layout (vertical stack).
  """
  def build_flow_layout(items, spacing) do
    items
    |> Enum.map(fn item ->
      """
      #v(#{format_dimension(spacing)})
      #{item}
      """
    end)
    |> Enum.join("\n")
  end

  @doc """
  Adds caption below content.
  """
  def add_caption(content, caption_text) do
    escaped_caption = escape_string(caption_text)

    """
    #figure(
      #{content},
      caption: [#{escaped_caption}]
    )
    """
  end

  @doc """
  Adds title above content.
  """
  def add_title(content, title_text) do
    escaped_title = escape_string(title_text)

    """
    #block[
      #text(weight: "bold", size: 12pt)[#{escaped_title}]
      #v(5pt)
      #{content}
    ]
    """
  end

  @doc """
  Escapes string for Typst templates.

  Escapes: #, [, ], {, }, $, \
  """
  def escape_string(text) when is_binary(text) do
    text
    |> String.replace("\\", "\\\\")  # Escape backslashes first
    |> String.replace("#", "\\#")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace("$", "\\$")
  end

  def escape_string(nil), do: ""
end
```

---

## 4. Integration with Existing System

### Integration with DSLGenerator

**Current State**: DSLGenerator processes report bands and elements but has no chart support.

**Changes Required**: Add chart element processing to DSLGenerator.

**Implementation**:

```elixir
# In AshReports.Typst.DSLGenerator

defp process_element(%{type: :chart} = element, context) do
  # Extract chart configuration from element
  chart_type = element.chart_type || :bar
  chart_config = build_chart_config(element)

  # Extract data binding expression
  # (data would be bound from report query in actual implementation)
  data_expr = element.data_expression

  # Generate Typst code that embeds the chart
  embed_opts = [
    width: element.width || "100%",
    height: element.height,
    caption: element.caption,
    title: element.title,
    position: element.position
  ]

  # This generates Typst code that will be evaluated with data at runtime
  """
  #{generate_chart_embedding_code(chart_type, data_expr, chart_config, embed_opts)}
  """
end

defp generate_chart_embedding_code(chart_type, data_expr, config, embed_opts) do
  # This is placeholder - actual implementation would need to:
  # 1. Evaluate data_expr against current report data
  # 2. Call Charts.generate(chart_type, data, config)
  # 3. Call ChartEmbedder.embed(svg, embed_opts)
  # 4. Inject resulting Typst code

  # For now, this demonstrates the structure
  """
  // Chart: #{chart_type}
  // Data: #{data_expr}
  // Config: #{inspect(config)}
  #{ChartEmbedder.placeholder_for_runtime_chart()}
  """
end
```

**Note**: Full DSL integration requires Section 3.3.2 (Chart DSL Element). This section focuses on the embedding mechanism only.

### Integration with StreamingPipeline

**Use Case**: Generate charts from large dataset aggregations.

**Flow**:
```
Report Data → StreamingPipeline (aggregations) → Chart Data
                                                      ↓
                                          Charts.generate(:bar, ...)
                                                      ↓
                                                   SVG string
                                                      ↓
                                          ChartEmbedder.embed(svg, ...)
                                                      ↓
                                                  Typst code
                                                      ↓
                                              DSLGenerator injects
                                                      ↓
                                                     PDF
```

**Example**:
```elixir
# 1. Stream and aggregate data
{:ok, stream_id, stream} = StreamingPipeline.start_pipeline(
  domain: MyApp.Domain,
  resource: Order,
  query: Ash.Query.filter(Order, status == :completed),
  aggregations: [:sum, :count],
  grouped_aggregations: [
    %{group_by: :region, aggregations: [:sum]}
  ]
)

# 2. Collect aggregated data
aggregated_data = Enum.to_list(stream)
# => [%{region: "North", sum: 50000}, %{region: "South", sum: 45000}, ...]

# 3. Generate chart
chart_data = Enum.map(aggregated_data, fn agg ->
  %{category: agg.region, value: agg.sum}
end)

config = %Config{title: "Sales by Region", width: 800, height: 400}
{:ok, svg} = Charts.generate(:bar, chart_data, config)

# 4. Embed in Typst
{:ok, typst_code} = ChartEmbedder.embed(svg,
  width: "100%",
  caption: "Regional Sales Performance Q4 2024"
)

# 5. Include in template (handled by DSLGenerator)
template = """
#let report(data, config) = {
  = Sales Report

  #{typst_code}
}
"""
```

### Integration with Charts Module

**No changes required** - ChartEmbedder is a consumer of Charts module.

**Relationship**:
```elixir
# ChartEmbedder calls Charts.generate/3
defmodule AshReports.Typst.ChartEmbedder do
  alias AshReports.Charts
  alias AshReports.Charts.Config

  def generate_and_embed(chart_type, data, config, embed_opts) do
    # Generate SVG using existing Charts API
    with {:ok, svg} <- Charts.generate(chart_type, data, config) do
      # Embed the resulting SVG
      embed(svg, embed_opts)
    end
  end
end
```

---

## 5. Success Criteria

### Functional Requirements

- [ ] **SVG-to-Typst Conversion**: `embed/2` function converts SVG to Typst #image() code
- [ ] **Base64 Encoding**: SVG correctly encoded to base64 and embedded inline
- [ ] **File Path Fallback**: Large SVGs (>1MB) written to temp files with path references
- [ ] **Sizing Support**: Width and height options correctly applied to Typst images
- [ ] **Caption Support**: Captions rendered below charts using Typst #figure()
- [ ] **Title Support**: Titles rendered above charts with formatting
- [ ] **Grid Layout**: Multiple charts arranged in grid with configurable columns
- [ ] **Flow Layout**: Charts stacked vertically with configurable spacing
- [ ] **Position Control**: Charts can be positioned (center, left, right)
- [ ] **Responsive Sizing**: Percentage widths (e.g., "100%") work correctly
- [ ] **Generate-and-Embed**: Single function to generate chart and embed in one call

### Quality Requirements

- [ ] **Test Coverage**: >80% coverage for ChartEmbedder and TypstFormatter
- [ ] **Integration Tests**: End-to-end tests verify SVG → Typst → PDF pipeline
- [ ] **Error Handling**: All error cases handled gracefully with descriptive messages
- [ ] **Documentation**: Complete module docs with examples
- [ ] **Performance**: Embedding <10ms overhead per chart
- [ ] **Memory Efficiency**: No memory leaks from temp file accumulation

### Technical Requirements

- [ ] **No New Dependencies**: Uses only Elixir standard library
- [ ] **Clean API**: Public functions follow Elixir conventions
- [ ] **Type Specs**: All public functions have @spec declarations
- [ ] **Telemetry**: Emits events for embedding operations
- [ ] **Backward Compatible**: No breaking changes to existing modules
- [ ] **File Cleanup**: Temporary SVG files automatically cleaned up

### Verification Methods

**How We Verify It Works**:

1. **Unit Tests**: Test each function in isolation
   ```elixir
   test "embed/2 converts SVG to base64 Typst image code" do
     svg = "<svg>...</svg>"
     {:ok, typst} = ChartEmbedder.embed(svg, width: "100%")
     assert typst =~ "#image.decode"
     assert typst =~ "width: 100%"
   end
   ```

2. **Integration Tests**: Test full pipeline
   ```elixir
   test "embedded chart compiles to PDF" do
     # Generate chart
     data = [%{category: "A", value: 10}]
     {:ok, svg} = Charts.generate(:bar, data, %Config{})

     # Embed in Typst
     {:ok, typst_chart} = ChartEmbedder.embed(svg, width: "80%")

     # Create template with embedded chart
     template = """
     #set page(paper: "a4")
     = Report with Chart

     #{typst_chart}
     """

     # Compile to PDF
     {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)

     # Verify PDF contains image
     assert is_binary(pdf)
     assert byte_size(pdf) > 1000
   end
   ```

3. **Visual Regression**: Compare PDF output with baseline
   ```elixir
   test "embedded chart renders correctly in PDF" do
     # Generate chart and embed
     {:ok, pdf} = generate_test_report_with_chart()

     # Extract text/structure from PDF
     {:ok, content} = TypstTestHelpers.extract_pdf_content(pdf)

     # Verify chart caption present
     assert content =~ "Sales by Region"
   end
   ```

4. **Performance Benchmarks**:
   ```elixir
   Benchee.run(%{
     "Single chart embed (small SVG)" => fn ->
       ChartEmbedder.embed(@small_svg, width: "100%")
     end,
     "Single chart embed (large SVG)" => fn ->
       ChartEmbedder.embed(@large_svg, width: "100%")
     end,
     "Grid layout 4 charts" => fn ->
       ChartEmbedder.embed_grid(@four_charts, columns: 2)
     end
   })
   ```

---

## 6. Implementation Plan

### Phase 1: Core Embedding (Days 1-2)

#### Step 1: Create ChartEmbedder Module Skeleton
- [ ] Create `/home/ducky/code/ash_reports/lib/ash_reports/typst/chart_embedder.ex`
- [ ] Define module structure with @moduledoc
- [ ] Add function stubs with @doc and @spec
- [ ] Create test file `/home/ducky/code/ash_reports/test/ash_reports/typst/chart_embedder_test.exs`

#### Step 2: Implement Base64 Encoding
- [ ] Implement `encode_svg/1` function
- [ ] Add base64 encoding logic
- [ ] Generate Typst `#image.decode()` code
- [ ] Write tests for base64 encoding
- [ ] Test with small, medium, large SVGs

#### Step 3: Implement File Path Fallback
- [ ] Add file size threshold constant
- [ ] Implement `encode_file/1` private function
- [ ] Generate unique filenames
- [ ] Write SVG to temp directory
- [ ] Return Typst `#image()` with file path
- [ ] Write tests for file fallback
- [ ] Test cleanup logic

#### Step 4: Implement Core `embed/2` Function
- [ ] Implement main `embed/2` function
- [ ] Add SVG validation
- [ ] Call encoding functions
- [ ] Apply sizing options
- [ ] Write comprehensive tests
- [ ] Test error cases (invalid SVG, encoding failures)

**Deliverable**: Basic SVG embedding working with base64 and file fallback.

### Phase 2: TypstFormatter and Layout (Days 3-4)

#### Step 5: Create TypstFormatter Module
- [ ] Create `/home/ducky/code/ash_reports/lib/ash_reports/typst/chart_embedder/typst_formatter.ex`
- [ ] Implement `format_dimension/1`
- [ ] Implement `escape_string/1`
- [ ] Write unit tests for formatter
- [ ] Test all dimension formats (pt, mm, cm, %, fr)
- [ ] Test string escaping edge cases

#### Step 6: Implement Caption and Title Support
- [ ] Implement `add_caption/2` in TypstFormatter
- [ ] Implement `add_title/2` in TypstFormatter
- [ ] Use Typst `#figure()` for captions
- [ ] Use Typst `#block` for titles
- [ ] Add tests for caption/title formatting
- [ ] Test with special characters in captions

#### Step 7: Implement Sizing and Positioning
- [ ] Implement `apply_sizing/2` in ChartEmbedder
- [ ] Support width-only (maintain aspect ratio)
- [ ] Support height-only (maintain aspect ratio)
- [ ] Support both width and height
- [ ] Implement `apply_position/2` (center, left, right)
- [ ] Write tests for all sizing combinations

**Deliverable**: Charts can be embedded with captions, titles, custom sizes.

### Phase 3: Multi-Chart Layouts (Days 5-6)

#### Step 8: Implement Grid Layout
- [ ] Implement `embed_grid/2` function
- [ ] Implement `build_grid_layout/3` in TypstFormatter
- [ ] Support configurable columns
- [ ] Support custom gutter spacing
- [ ] Support custom column widths
- [ ] Write tests for grid layouts
- [ ] Test with 1, 2, 3, 4+ charts

#### Step 9: Implement Flow Layout
- [ ] Implement `embed_flow/2` function
- [ ] Implement `build_flow_layout/2` in TypstFormatter
- [ ] Support configurable vertical spacing
- [ ] Write tests for flow layouts
- [ ] Test with varying spacing values

#### Step 10: Helper Function for Embedding Lists
- [ ] Implement `embed_all/1` private function
- [ ] Handle partial failures (error on first failure)
- [ ] Write tests for batch embedding
- [ ] Test error propagation

**Deliverable**: Multi-chart layouts (grid and flow) working.

### Phase 4: Integration and Testing (Days 7-8)

#### Step 11: Implement `generate_and_embed/4`
- [ ] Implement convenience function
- [ ] Call `Charts.generate/3` internally
- [ ] Pass SVG to `embed/2`
- [ ] Write integration tests
- [ ] Test with all chart types (bar, line, pie, area, scatter)

#### Step 12: Integration Testing
- [ ] Create test helper module
- [ ] Write end-to-end tests (chart → embed → Typst → PDF)
- [ ] Test grid layouts in PDFs
- [ ] Test flow layouts in PDFs
- [ ] Test responsive sizing in PDFs
- [ ] Use TypstTestHelpers for PDF validation

#### Step 13: Performance Benchmarks
- [ ] Create benchmark suite
- [ ] Benchmark single chart embedding
- [ ] Benchmark grid layout (4 charts)
- [ ] Benchmark large SVG file fallback
- [ ] Measure memory usage
- [ ] Verify <10ms overhead target

#### Step 14: Documentation and Examples
- [ ] Write comprehensive module documentation
- [ ] Add usage examples to @moduledoc
- [ ] Document all public functions
- [ ] Create example scripts in `examples/chart_embedding.exs`
- [ ] Update main README if needed

#### Step 15: Telemetry and Error Handling
- [ ] Add telemetry events for embedding operations
- [ ] Add error telemetry for failures
- [ ] Implement proper error messages
- [ ] Add logging for debugging
- [ ] Test all error paths

**Deliverable**: Complete, tested, documented ChartEmbedder system.

---

## 7. Testing Strategy

### Unit Tests

**ChartEmbedder Module** (~200 lines):
- [ ] `embed/2` with base64 encoding (small SVG)
- [ ] `embed/2` with file fallback (large SVG)
- [ ] `embed/2` with width option
- [ ] `embed/2` with height option
- [ ] `embed/2` with both width and height
- [ ] `embed/2` with caption
- [ ] `embed/2` with title
- [ ] `embed/2` with caption and title
- [ ] `embed/2` with invalid SVG
- [ ] `embed/2` with empty SVG
- [ ] `embed_grid/2` with 2 charts
- [ ] `embed_grid/2` with 4 charts (2x2)
- [ ] `embed_grid/2` with 3 charts (2 columns, asymmetric)
- [ ] `embed_grid/2` with custom gutter
- [ ] `embed_grid/2` with custom column widths
- [ ] `embed_flow/2` with 2 charts
- [ ] `embed_flow/2` with 5 charts
- [ ] `embed_flow/2` with custom spacing
- [ ] `generate_and_embed/4` with bar chart
- [ ] `generate_and_embed/4` with line chart
- [ ] `generate_and_embed/4` with invalid data
- [ ] Error handling for encoding failures
- [ ] Error handling for file write failures
- [ ] Cleanup of temporary files

**TypstFormatter Module** (~150 lines):
- [ ] `format_dimension/1` with number (default to pt)
- [ ] `format_dimension/1` with string (passthrough)
- [ ] `format_dimension/1` with :auto
- [ ] `format_dimension/1` with various units (mm, cm, in, %, fr)
- [ ] `escape_string/1` with special characters (#, [, ], {, }, $)
- [ ] `escape_string/1` with backslashes
- [ ] `escape_string/1` with nil
- [ ] `escape_string/1` with empty string
- [ ] `build_grid_layout/3` with 2 columns
- [ ] `build_grid_layout/3` with 3 columns
- [ ] `build_grid_layout/3` with custom gutter
- [ ] `build_flow_layout/2` with default spacing
- [ ] `build_flow_layout/2` with custom spacing
- [ ] `add_caption/2` with simple text
- [ ] `add_caption/2` with special characters
- [ ] `add_title/2` with simple text
- [ ] `add_title/2` with special characters
- [ ] Generated Typst code is valid syntax

**Total Unit Tests**: ~42 tests

### Integration Tests

**End-to-End Pipeline** (~100 lines):
- [ ] Single chart: generate → embed → compile → PDF
- [ ] Grid layout: 4 charts → compile → PDF
- [ ] Flow layout: 3 charts → compile → PDF
- [ ] Chart with caption → PDF (verify caption in output)
- [ ] Chart with title → PDF (verify title in output)
- [ ] Responsive sizing (100% width) → PDF
- [ ] Multiple chart types in one report → PDF
- [ ] Large SVG (file fallback) → PDF
- [ ] Error handling: invalid chart data propagates
- [ ] File cleanup after PDF generation

**Total Integration Tests**: ~10 tests

### Performance Tests

**Benchmarks** (`benchmarks/chart_embedding_benchmarks.exs`):
```elixir
defmodule ChartEmbeddingBenchmarks do
  def run do
    Benchee.run(%{
      "Single chart embed (small SVG)" => fn ->
        svg = generate_small_svg()
        ChartEmbedder.embed(svg, width: "100%")
      end,

      "Single chart embed (large SVG)" => fn ->
        svg = generate_large_svg()
        ChartEmbedder.embed(svg, width: "100%")
      end,

      "Grid layout 4 charts" => fn ->
        charts = generate_four_charts()
        ChartEmbedder.embed_grid(charts, columns: 2)
      end,

      "Flow layout 5 charts" => fn ->
        charts = generate_five_charts()
        ChartEmbedder.embed_flow(charts, spacing: "20pt")
      end,

      "Generate and embed bar chart" => fn ->
        data = generate_chart_data()
        config = %Config{width: 800, height: 400}
        ChartEmbedder.generate_and_embed(:bar, data, config)
      end,

      "Full pipeline: chart → embed → PDF" => fn ->
        data = generate_chart_data()
        {:ok, svg} = Charts.generate(:bar, data, %Config{})
        {:ok, typst} = ChartEmbedder.embed(svg, width: "80%")

        template = """
        #set page(paper: "a4")
        = Report
        #{typst}
        """

        BinaryWrapper.compile(template, format: :pdf)
      end
    },
    time: 5,
    memory_time: 2
    )
  end
end
```

**Performance Targets**:
- Single chart embed (small): <5ms
- Single chart embed (large): <20ms (includes file write)
- Grid layout (4 charts): <20ms
- Flow layout (5 charts): <15ms
- Generate and embed: <200ms (dominated by chart generation)
- Full pipeline to PDF: <1000ms (dominated by Typst compilation)

**Memory Targets**:
- Single embed: <500KB
- Grid layout (4 charts): <2MB
- No memory leaks from temp files

### Visual Regression Tests

**PDF Validation** (using TypstTestHelpers):
```elixir
test "embedded chart renders correctly in PDF" do
  # Generate test chart
  data = [
    %{category: "Q1", value: 100},
    %{category: "Q2", value: 150},
    %{category: "Q3", value: 120}
  ]

  {:ok, svg} = Charts.generate(:bar, data, %Config{title: "Quarterly Sales"})
  {:ok, typst_chart} = ChartEmbedder.embed(svg,
    width: "80%",
    caption: "Sales by Quarter"
  )

  # Create report template
  template = """
  #set page(paper: "a4")
  = Sales Report

  #{typst_chart}
  """

  # Compile to PDF
  {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)

  # Extract content
  {:ok, content} = TypstTestHelpers.extract_pdf_content(pdf)

  # Verify structure
  assert content =~ "Sales Report"
  assert content =~ "Sales by Quarter"  # Caption

  # Verify image present (PDF contains image markers)
  assert content =~ "image" or content =~ "figure"
end
```

---

## 8. Performance Characteristics

### Embedding Overhead

**Base64 Encoding**:
- Small SVG (10KB): ~1ms encoding + ~1ms string formatting = **2ms total**
- Medium SVG (100KB): ~5ms encoding + ~2ms string formatting = **7ms total**
- Large SVG (1MB): ~50ms encoding + ~5ms string formatting = **55ms total** (triggers file fallback)

**File Path Fallback** (SVGs >1MB):
- File write: ~20ms (depends on disk I/O)
- Path formatting: ~1ms
- Total: **~21ms**

**Layout Generation**:
- Grid layout (4 charts): ~3ms (string concatenation)
- Flow layout (5 charts): ~2ms (string concatenation)

**Caption/Title Formatting**:
- Add caption: ~0.5ms (string escaping + wrapping)
- Add title: ~0.5ms (string escaping + wrapping)

### Memory Usage

**Base64 Encoding**:
- Input SVG: 100KB
- Base64 output: ~133KB (+33% overhead)
- Typst string: ~150KB (includes template code)
- Temporary memory: ~300KB (input + output + intermediate)

**File Path Fallback**:
- Input SVG: 1MB
- Written to disk: 1MB
- Typst string: ~100 bytes (just file path reference)
- Temporary memory: ~1MB (during file write only)

**Grid Layout (4 charts)**:
- 4 SVGs × 100KB each = 400KB
- 4 base64 strings × 133KB = 532KB
- Grid template: ~2KB
- Total memory: ~1MB peak

### Compilation Impact on PDF Generation

**Without Charts**:
- Simple report (text only): ~100ms compilation
- Memory: ~50MB

**With Embedded Charts**:
- Report + 1 chart (base64): ~200ms compilation (+100ms)
- Report + 4 charts (grid): ~400ms compilation (+300ms)
- Memory: ~150MB (+100MB for SVG rendering)

**Bottleneck**: Typst SVG rendering (not embedding overhead).

**Optimization Opportunities**:
1. Cache compiled chart PDFs for reuse
2. Pre-render charts to PNG for faster embedding
3. Use file paths for very large SVGs
4. Lazy load charts (only generate when needed)

---

## 9. Notes and Considerations

### Edge Cases

#### 1. Very Large SVGs (>5MB)
**Problem**: Base64 encoding creates 6.6MB+ strings, may exceed Typst limits.
**Solution**: Enforce file path fallback for SVGs >1MB.
**Implementation**: Check size in `encode_svg/1` before encoding.

#### 2. SVG with External References
**Problem**: SVG may reference external images/fonts (e.g., `xlink:href`).
**Solution**:
- Warn if external references detected
- Document limitation in @moduledoc
- Future: inline external resources into SVG
**Detection**: Regex scan for `xlink:href` or `url()` references.

#### 3. Invalid SVG Syntax
**Problem**: Malformed SVG from chart generation errors.
**Solution**:
- Validate SVG has `<svg>` tags
- Check for common errors (unclosed tags)
- Return meaningful error messages
**Implementation**: Add `validate_svg/1` function.

#### 4. Typst Compilation Failures
**Problem**: Embedded chart causes Typst syntax errors.
**Solution**:
- Escape special characters in captions/titles
- Test generated Typst code with BinaryWrapper
- Log Typst error messages
**Prevention**: Comprehensive string escaping in TypstFormatter.

#### 5. Multiple Charts with Same Caption
**Problem**: Duplicate captions may confuse readers.
**Solution**:
- Document recommended caption uniqueness
- Add optional chart IDs for reference
- Future: automatic numbering (Figure 1, Figure 2, etc.)

#### 6. Chart Sizing in Different Page Layouts
**Problem**: 100% width behaves differently in multi-column layouts.
**Solution**:
- Document that percentages are relative to container
- Provide examples for common layouts
- Support absolute units (pt, mm) for predictable sizing

#### 7. Temporary File Cleanup
**Problem**: Temp SVG files accumulate on disk.
**Solution**:
- Use unique filenames (crypto random)
- Rely on OS temp directory cleanup
- Optional: implement explicit cleanup function
- Document cleanup behavior

#### 8. Concurrent Embedding
**Problem**: Multiple processes embedding charts simultaneously.
**Solution**:
- Unique filenames prevent collisions
- Base64 encoding is stateless (thread-safe)
- No shared state in ChartEmbedder module
**Safety**: Module is process-safe by design.

### Future Improvements

#### 1. Advanced Layout Options
- **Absolute positioning**: Place charts at specific coordinates
- **Overlays**: Overlay multiple charts for comparison
- **Aspect ratio enforcement**: Lock aspect ratio explicitly
- **Margin control**: Fine-tune spacing around charts

#### 2. Chart References and Cross-Referencing
- **Figure numbering**: Automatic "Figure 1.2.3" numbering
- **References**: `@fig:sales_chart` → "see Figure 1"
- **List of figures**: Generate table of figures for report

#### 3. Interactive Elements (Future)
- **Tooltips**: Hover to see data values (requires HTML output)
- **Zoom**: Click to enlarge chart
- **Filters**: Interactive legend filtering
**Note**: Requires HTML/web output, not applicable to static PDF.

#### 4. Chart Compression
- **SVG optimization**: Remove redundant attributes, minify paths
- **GZIP compression**: Compress base64 data (Typst support needed)
- **PNG fallback**: Convert to PNG for smaller file size (lose vector quality)

#### 5. Chart Variants for Different Outputs
- **PDF**: High-resolution SVG
- **Web**: Responsive SVG with viewBox
- **Print**: CMYK color conversion
- **Accessibility**: Text alternatives for screen readers

#### 6. Batch Embedding with Parallel Processing
```elixir
# Future API
charts = [
  {:bar, data1, config1},
  {:line, data2, config2},
  {:pie, data3, config3}
]

# Generate and embed all charts in parallel
{:ok, typst_codes} = ChartEmbedder.embed_batch_parallel(charts,
  max_concurrency: 4
)
```

#### 7. Template Macros for Common Layouts
```typst
// Future: Reusable chart layout macro
#let chart_row(charts) = {
  grid(
    columns: (1fr, 1fr),
    gutter: 10pt,
    ..charts
  )
}

#chart_row([
  #image.decode("chart1"),
  #image.decode("chart2")
])
```

### Known Limitations

#### 1. Typst SVG Rendering Limitations
- **Limitation**: Typst's SVG renderer may not support all SVG features
- **Impact**: Complex SVGs (gradients, filters, masks) may render incorrectly
- **Workaround**: Use simpler chart styles, test SVG compatibility
- **Status**: Depends on Typst's underlying SVG library

#### 2. No Animation Support
- **Limitation**: Typst PDFs are static, cannot embed animated SVGs
- **Impact**: Time-series animations not possible
- **Alternative**: Generate multiple frames, create flipbook effect
- **Status**: Fundamental limitation of PDF format

#### 3. File Path Portability
- **Limitation**: File paths only work if Typst can access filesystem
- **Impact**: Serverless/containerized environments may restrict file access
- **Workaround**: Prefer base64 encoding, increase size threshold
- **Status**: Environment-dependent

#### 4. Base64 Size Overhead
- **Limitation**: 33% size increase for base64-encoded SVGs
- **Impact**: Large templates, slower compilation
- **Workaround**: Use file paths for large SVGs, optimize SVG first
- **Status**: Inherent to base64 encoding

#### 5. Limited Layout Flexibility
- **Limitation**: Typst layout system is not as flexible as HTML/CSS
- **Impact**: Complex multi-chart dashboards may be difficult
- **Workaround**: Use grid layouts, pre-calculate positions
- **Status**: Depends on Typst's layout capabilities

#### 6. No JavaScript Interactivity
- **Limitation**: PDFs cannot execute JavaScript
- **Impact**: No interactive charts (hover, click, zoom)
- **Alternative**: Generate HTML reports for interactivity
- **Status**: PDF format limitation

---

## 10. Dependencies and Blockers

### Completed Dependencies

- [x] **Section 3.1**: Chart Infrastructure (Charts, Renderer, Registry, Config)
  - Provides: `Charts.generate/3` for SVG output
  - Status: COMPLETED

- [x] **Section 3.2.1**: Data Transformation Pipeline
  - Provides: Data extraction and aggregation for charts
  - Status: COMPLETED

- [x] **Section 3.2.2**: Chart Type Implementations (Area, Scatter)
  - Provides: Additional chart types to embed
  - Status: COMPLETED

- [x] **Section 3.2.3**: Dynamic Chart Configuration (Themes)
  - Provides: Styled charts for embedding
  - Status: COMPLETED

- [x] **Stage 1**: Typst Integration (DSLGenerator, BinaryWrapper)
  - Provides: Template generation and PDF compilation
  - Status: COMPLETED

### Future Dependencies (Will Use This)

- [ ] **Section 3.3.2**: Chart DSL Element
  - Will use: `ChartEmbedder` to embed charts from DSL definitions
  - Impact: Adds declarative chart embedding to reports
  - Timeline: After this section (3.3.1)

- [ ] **Section 3.3.3**: Performance Optimization
  - Will use: `ChartEmbedder` as optimization target
  - Impact: Parallel chart generation, caching, compression
  - Timeline: After Section 3.3.2

### No Blockers

This section has **no blockers** - all dependencies are completed. Implementation can begin immediately.

---

## 11. Risk Assessment

### Technical Risks

#### Risk 1: Typst SVG Compatibility Issues
**Probability**: Medium
**Impact**: High
**Description**: Typst's SVG renderer may not support all Contex-generated SVG features.
**Mitigation**:
- Test all chart types during implementation
- Create visual regression test suite
- Document known incompatibilities
- Provide fallback to PNG if needed
**Contingency**: Convert SVG to PNG for problematic charts.

#### Risk 2: Base64 Size Limits
**Probability**: Low
**Impact**: Medium
**Description**: Very large base64 strings may exceed Typst's internal limits.
**Mitigation**:
- Set conservative file fallback threshold (1MB)
- Test with large datasets (100+ data points)
- Document size recommendations
**Contingency**: Lower threshold or implement SVG compression.

#### Risk 3: File Cleanup Issues
**Probability**: Low
**Impact**: Low
**Description**: Temporary SVG files may not be cleaned up properly.
**Mitigation**:
- Use OS temp directory (automatic cleanup)
- Unique filenames prevent conflicts
- Document cleanup behavior
**Contingency**: Implement manual cleanup function.

### Integration Risks

#### Risk 4: DSLGenerator Integration Complexity
**Probability**: Low
**Impact**: Medium
**Description**: Integrating chart embedding into DSLGenerator may be complex.
**Mitigation**:
- This section focuses on embedding mechanism only
- Full integration deferred to Section 3.3.2
- Provide clear API for DSLGenerator to call
**Contingency**: Simplify integration, document manual usage.

#### Risk 5: Performance Degradation
**Probability**: Low
**Impact**: Medium
**Description**: Embedding charts may significantly slow PDF generation.
**Mitigation**:
- Set performance targets (<10ms overhead)
- Benchmark early and often
- Optimize hot paths (base64 encoding)
**Contingency**: Implement caching, lazy loading.

### Project Risks

#### Risk 6: Scope Creep
**Probability**: Medium
**Impact**: Medium
**Description**: Feature requests for advanced layouts, interactivity, etc.
**Mitigation**:
- Define clear scope (basic embedding only)
- Defer advanced features to future sections
- Document limitations upfront
**Contingency**: Create backlog for future work.

---

## 12. Implementation Checklist

### Pre-Implementation
- [ ] Review planning document with Pascal
- [ ] Confirm base64 vs file path strategy
- [ ] Confirm layout approach (grid vs flow)
- [ ] Get approval to proceed

### Phase 1: Core Embedding (Days 1-2)
- [ ] Create ChartEmbedder module skeleton
- [ ] Implement base64 encoding
- [ ] Implement file path fallback
- [ ] Implement core `embed/2` function
- [ ] Write unit tests for encoding
- [ ] Verify basic embedding works

### Phase 2: Formatting and Layout (Days 3-4)
- [ ] Create TypstFormatter module
- [ ] Implement dimension formatting
- [ ] Implement string escaping
- [ ] Implement caption support
- [ ] Implement title support
- [ ] Implement sizing and positioning
- [ ] Write unit tests for formatter

### Phase 3: Multi-Chart Layouts (Days 5-6)
- [ ] Implement grid layout
- [ ] Implement flow layout
- [ ] Implement helper functions
- [ ] Write tests for layouts
- [ ] Verify multi-chart embedding works

### Phase 4: Integration and Testing (Days 7-8)
- [ ] Implement `generate_and_embed/4`
- [ ] Write integration tests
- [ ] Write performance benchmarks
- [ ] Create documentation
- [ ] Add telemetry events
- [ ] Test all error paths

### Post-Implementation
- [ ] Run full test suite
- [ ] Run performance benchmarks
- [ ] Create summary document
- [ ] Update planning/typst_refactor_plan.md
- [ ] Ask Pascal for permission to commit

---

## 13. Usage Examples

### Example 1: Single Chart with Caption

```elixir
# Generate chart data
data = [
  %{category: "North", value: 50000},
  %{category: "South", value: 45000},
  %{category: "East", value: 38000},
  %{category: "West", value: 42000}
]

# Configure chart
config = %AshReports.Charts.Config{
  title: "Sales by Region",
  width: 800,
  height: 400,
  colors: ["#4ECDC4", "#45B7D1", "#F7B801", "#FF6B6B"]
}

# Generate SVG
{:ok, svg} = AshReports.Charts.generate(:bar, data, config)

# Embed in Typst
{:ok, typst_code} = AshReports.Typst.ChartEmbedder.embed(svg,
  width: "80%",
  caption: "Regional Sales Performance - Q4 2024"
)

# Include in template
template = """
#set page(paper: "a4")
#set text(font: "Arial", size: 11pt)

= Sales Report

#{typst_code}

The chart above shows sales performance across all regions.
"""

# Compile to PDF
{:ok, pdf} = AshReports.Typst.BinaryWrapper.compile(template, format: :pdf)
File.write!("sales_report.pdf", pdf)
```

### Example 2: Grid Layout with Multiple Charts

```elixir
alias AshReports.Charts
alias AshReports.Typst.ChartEmbedder
alias AshReports.Charts.Config

# Generate 4 different charts
{:ok, svg_bar} = Charts.generate(:bar, bar_data, %Config{title: "Sales"})
{:ok, svg_line} = Charts.generate(:line, line_data, %Config{title: "Trend"})
{:ok, svg_pie} = Charts.generate(:pie, pie_data, %Config{title: "Share"})
{:ok, svg_area} = Charts.generate(:area, area_data, %Config{title: "Growth"})

# Embed in grid
charts = [
  {svg_bar, [caption: "Total Sales"]},
  {svg_line, [caption: "Sales Trend"]},
  {svg_pie, [caption: "Market Share"]},
  {svg_area, [caption: "Cumulative Growth"]}
]

{:ok, grid_typst} = ChartEmbedder.embed_grid(charts,
  columns: 2,
  gutter: "15pt"
)

# Create report
template = """
#set page(paper: "a4", margin: 1cm)

= Dashboard

#{grid_typst}
"""

{:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
File.write!("dashboard.pdf", pdf)
```

### Example 3: Generate and Embed in One Call

```elixir
alias AshReports.Typst.ChartEmbedder
alias AshReports.Charts.Config

# One-step: generate chart and embed
{:ok, typst_code} = ChartEmbedder.generate_and_embed(
  :line,  # Chart type
  time_series_data,  # Data
  %Config{
    title: "Revenue Over Time",
    width: 800,
    height: 400,
    show_grid: true
  },
  # Embedding options
  width: "100%",
  caption: "Monthly Revenue - Last 12 Months",
  title: "Revenue Analysis"
)

# Use directly in template
template = """
#set page(paper: "a4")

= Financial Report

#{typst_code}

Revenue has shown steady growth over the past year.
"""
```

### Example 4: Flow Layout with Vertical Stacking

```elixir
# Generate multiple charts
quarterly_charts = Enum.map(["Q1", "Q2", "Q3", "Q4"], fn quarter ->
  {:ok, svg} = Charts.generate(:area, get_quarter_data(quarter),
    %Config{title: "#{quarter} Performance"}
  )
  {svg, [caption: "#{quarter} 2024 Results"]}
end)

# Stack vertically with spacing
{:ok, flow_typst} = ChartEmbedder.embed_flow(quarterly_charts,
  spacing: "25pt"
)

template = """
#set page(paper: "a4")

= Quarterly Review 2024

#{flow_typst}
"""
```

### Example 5: Responsive Sizing

```elixir
# Chart adapts to container width
{:ok, typst_responsive} = ChartEmbedder.embed(svg,
  width: "100%",  # Full container width
  caption: "This chart adapts to page width"
)

# Fixed size in millimeters
{:ok, typst_fixed} = ChartEmbedder.embed(svg,
  width: "150mm",
  height: "100mm",
  caption: "This chart is exactly 150mm × 100mm"
)

# Maintain aspect ratio
{:ok, typst_aspect} = ChartEmbedder.embed(svg,
  width: "80%",  # Width specified, height auto-calculated
  caption: "Aspect ratio preserved"
)
```

### Example 6: Integration with StreamingPipeline

```elixir
alias AshReports.Typst.{ChartEmbedder, StreamingPipeline, DataLoader}
alias AshReports.Charts

# Stream large dataset and aggregate
{:ok, stream_id, stream} = StreamingPipeline.start_pipeline(
  domain: MyApp.Reporting,
  resource: Order,
  query: Ash.Query.filter(Order, status == :completed),
  grouped_aggregations: [
    %{group_by: :region, aggregations: [:sum]}
  ]
)

# Collect aggregated data
aggregated = Enum.to_list(stream)
# => [%{region: "North", sum: 50000}, %{region: "South", sum: 45000}, ...]

# Transform to chart data
chart_data = Enum.map(aggregated, fn agg ->
  %{category: agg.region, value: agg.sum}
end)

# Generate and embed chart
{:ok, typst_chart} = ChartEmbedder.generate_and_embed(
  :bar,
  chart_data,
  %Charts.Config{
    title: "Sales by Region",
    theme_name: :corporate
  },
  width: "100%",
  caption: "Data aggregated from #{length(aggregated)} regions"
)

# Include in report
template = """
#set page(paper: "a4")

= Sales Analysis

This report analyzes #{Enum.count(stream)} orders.

#{typst_chart}
"""
```

---

## 14. Questions for Pascal

Before implementation, please confirm:

### 1. Encoding Strategy
**Question**: Is the base64-first approach with 1MB file fallback acceptable? Or should we use a different threshold/strategy?

**Context**: Base64 is simpler but adds 33% size overhead. File paths are more efficient but require filesystem access.

**Recommendation**: Base64 primary with 1MB threshold seems reasonable, but open to adjustment.

---

### 2. Layout Priority
**Question**: Should we implement both grid and flow layouts in MVP, or start with just flow (simpler)?

**Context**: Grid layout is more complex (column calculations, cell positioning). Flow layout is simpler (vertical stacking).

**Recommendation**: Implement both - grid for dashboards, flow for sequential charts. But can defer grid to v2 if needed.

---

### 3. DSLGenerator Integration Scope
**Question**: Should this section include any DSLGenerator integration, or purely focus on the embedding API?

**Context**: Planning document states DSL integration is Section 3.3.2, but we could add basic hooks now.

**Recommendation**: Keep this section focused on ChartEmbedder API only. Full DSL integration in 3.3.2.

---

### 4. File Cleanup Strategy
**Question**: Should we implement explicit cleanup functions, or rely on OS temp directory cleanup?

**Context**: Explicit cleanup is safer but adds complexity. OS cleanup is simpler but may delay.

**Recommendation**: Start with OS temp cleanup (simpler). Add explicit cleanup if needed.

---

### 5. Error Handling Philosophy
**Question**: Should `embed/2` fail fast on invalid SVG, or attempt graceful fallback (e.g., error image)?

**Context**: Fail fast is clearer for developers. Fallback prevents broken reports but hides issues.

**Recommendation**: Fail fast with descriptive errors - better developer experience.

---

### 6. Performance Targets
**Question**: Are the proposed performance targets (<10ms overhead) reasonable, or should we aim higher/lower?

**Context**:
- Single embed: <5ms (base64 encoding + string formatting)
- Grid layout (4 charts): <20ms
- Full pipeline to PDF: <1000ms (dominated by Typst)

**Recommendation**: These seem achievable. Adjust if needed based on benchmarks.

---

## 15. Next Steps

1. **Review this document** with Pascal - confirm approach and answers to questions
2. **Get approval** to proceed with implementation
3. **Create feature branch**: `feature/stage3-section3.3.1-svg-embedding-system`
4. **Implement Phase 1** (Core Embedding) - Days 1-2
5. **Implement Phase 2** (Formatting) - Days 3-4
6. **Implement Phase 3** (Layouts) - Days 5-6
7. **Implement Phase 4** (Integration) - Days 7-8
8. **Run tests and benchmarks** - verify all success criteria met
9. **Create summary document** - similar to existing Section 3.x summaries
10. **Update planning/typst_refactor_plan.md** - mark Section 3.3.1 as complete
11. **Ask for permission to commit** - per CLAUDE.md rules

---

## 16. Related Documentation

- **Planning**: `/home/ducky/code/ash_reports/planning/typst_refactor_plan.md` (Section 3.3.1)
- **Section 3.1 Summary**: `/home/ducky/code/ash_reports/notes/features/stage3_section3.1_summary.md`
- **Section 3.2.1 Summary**: `/home/ducky/code/ash_reports/notes/features/stage3_section3.2.1_summary.md`
- **Charts Module**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/charts.ex`
- **DSLGenerator**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/dsl_generator.ex`
- **BinaryWrapper**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/binary_wrapper.ex`
- **Typst Docs**: https://typst.app/docs/reference/visualize/image/
- **Typst Grid Docs**: https://typst.app/docs/reference/layout/grid/

---

## 17. Conclusion

Section 3.3.1 represents the **critical integration point** between AshReports' chart generation system and Typst PDF output. By implementing the `ChartEmbedder` module with base64 encoding, multi-chart layouts, and caption/title support, we enable:

- ✅ Programmatic chart embedding in PDF reports
- ✅ Flexible layout options (grid, flow, custom positioning)
- ✅ Professional presentation (captions, titles, responsive sizing)
- ✅ Seamless integration with existing infrastructure

**Key Achievements**:
1. **Simple API**: `embed/2`, `embed_grid/2`, `embed_flow/2`, `generate_and_embed/4`
2. **Robust Encoding**: Base64 primary with file fallback for large SVGs
3. **Flexible Layouts**: Grid and flow layouts for multi-chart reports
4. **Production Ready**: Comprehensive tests, performance benchmarks, error handling

**What This Unlocks**:
- Section 3.3.2 can build DSL chart elements on this foundation
- Section 3.3.3 can optimize chart generation and caching
- Users can create rich, data-driven PDF reports with embedded visualizations

**Ready for Review**: This planning document is ready for Pascal's review and approval to proceed.
