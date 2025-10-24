# Stage 3, Section 3.3.2: DSL Chart Element - Feature Planning Document

## 1. Problem Statement

### What problem does DSL chart element solve?

Currently, AshReports supports 7 element types in the Report DSL (field, label, expression, aggregate, line, box, image), but there is no native way to embed charts directly in report definitions. While the infrastructure exists for chart generation (Stage 3.1-3.2) and chart embedding (Stage 3.3.1), report authors must manually integrate charts through custom code rather than declarative DSL.

**Current workflow** (manual integration):
```elixir
# 1. Generate chart in custom code
{:ok, svg} = Charts.generate(:bar, data, config)

# 2. Manually embed in Typst template
{:ok, typst} = ChartEmbedder.embed(svg, opts)

# 3. Inject into report template generation
```

**Desired workflow** (DSL-driven):
```elixir
reports do
  report :sales_report do
    bands do
      band :header do
        type :page_header
        elements do
          chart :sales_by_region do
            chart_type :bar
            data_source expr(query_results.sales)
            config width: 600, height: 400, title: "Sales by Region"
            visible expr(show_charts)
            caption "Q1 Sales Performance"
          end
        end
      end
    end
  end
end
```

### Impact on report creation workflow

1. **Declarative chart embedding** - Charts become first-class DSL elements alongside field, label, image
2. **Data binding from report queries** - Charts automatically consume data from report's driving_resource query
3. **Variable-driven configuration** - Chart properties can be set dynamically from report variables/parameters
4. **Conditional rendering** - Charts show/hide based on data availability or conditional expressions
5. **Consistent element API** - Charts follow same pattern as other elements (position, style, conditional)

### Why is this needed now?

Stage 3.3.1 (ChartEmbedder) provides the technical foundation for SVG-to-Typst conversion, but without DSL integration, chart usage remains ad-hoc and procedural. This section completes the visualization layer by making charts a native, declarative part of report definitions.

**Dependencies satisfied**:
- Stage 3.1: Chart generation infrastructure (Charts module, Registry, Renderer, Cache)
- Stage 3.2: Data processing (DataExtractor, Aggregator, TimeSeries, Pivot, Statistics)
- Stage 3.3.1: Typst embedding (ChartEmbedder with SVG encoding, layouts, captions)

**Blocks downstream work**:
- Stage 3.3.3: Performance optimization requires understanding chart usage patterns in DSL
- Stage 4: LiveView integration needs DSL chart configuration for interactive editing

---

## 2. Solution Overview

### High-level approach to DSL integration

**Core Strategy**: Extend the existing element entity system in `lib/ash_reports/dsl.ex` with a new `chart` element entity, following the same patterns as existing elements (field, image, label, etc.).

**Key Design Principles**:
1. **Consistency** - Chart elements follow same schema structure as other elements (name, position, style, conditional)
2. **Data-driven** - Charts pull data from report query results via `data_source` expressions
3. **Declarative configuration** - All chart options configurable via DSL (chart_type, dimensions, colors, etc.)
4. **Variable integration** - Chart properties can reference report variables/parameters
5. **Conditional rendering** - Charts respect `conditional` and `visible` expressions

### Key design decisions

#### 1. Element Entity Structure

Add `chart_element_entity()` to DSL with schema:
- **name** (required) - Element identifier
- **chart_type** (required) - :bar, :line, :pie, :area, :scatter
- **data_source** (required) - Ash expression to extract chart data from report query
- **config** (optional) - Chart.Config map (width, height, colors, legend, etc.)
- **position** (optional) - Standard element positioning
- **style** (optional) - Standard element styling
- **conditional** (optional) - Expression for show/hide logic
- **caption** (optional) - Text caption below chart
- **title** (optional) - Text title above chart
- **encoding** (optional) - :base64 (default) or :file for large charts

#### 2. Data Binding Mechanism

**Problem**: How to map report query results to chart data format?

**Solution**: Use Ash expressions with smart field extraction:

```elixir
# Option A: Direct field mapping (simple bar chart)
chart :sales_by_category do
  chart_type :bar
  data_source expr(records)  # Expects records to have category/value fields
  # Auto-detects: %{category: string, value: number}
end

# Option B: Explicit field mapping
chart :revenue_trend do
  chart_type :line
  data_source expr(records)
  data_mapping %{
    x_field: :date,
    y_field: :revenue
  }
end

# Option C: Custom transformation expression
chart :top_products do
  chart_type :pie
  data_source expr(records |> Enum.take(10) |> Enum.map(&{&1.name, &1.total}))
end
```

**Implementation**: DSLGenerator extracts `data_source` expression, evaluates against report data, and passes to Chart generation.

#### 3. Variable Support for Dynamic Configuration

Charts can reference report variables and parameters:

```elixir
parameters do
  parameter :chart_width, :integer, default: 800
  parameter :show_legend, :boolean, default: true
end

variables do
  variable :chart_theme do
    type :custom
    expression expr(if total_sales > 100000, do: :vibrant, else: :minimal)
  end
end

bands do
  band :header do
    elements do
      chart :sales_chart do
        chart_type :bar
        data_source expr(records)
        config %{
          width: expr(param(:chart_width)),
          height: 400,
          show_legend: expr(param(:show_legend)),
          theme_name: expr(var(:chart_theme))
        }
      end
    end
  end
end
```

**Implementation**: Config values containing `expr()` are evaluated at render time with access to parameters, variables, and current record context.

#### 4. Conditional Rendering

Charts support two types of conditionals:

```elixir
# A. Conditional element visibility (standard for all elements)
chart :sales_by_region do
  chart_type :bar
  data_source expr(records)
  conditional expr(param(:include_charts) == true)
end

# B. Data-driven conditional (minimum data points)
chart :trend_chart do
  chart_type :line
  data_source expr(records)
  config %{
    min_data_points: 3  # Won't render if <3 datapoints
  }
end
```

**Implementation**:
- `conditional` is evaluated by DSLGenerator before chart generation
- `min_data_points` is enforced by Charts module (already implemented in Stage 3.2.3)

### Integration points with existing system

1. **DSL Layer** (`lib/ash_reports/dsl.ex`)
   - Add `chart_element_entity()` to band entity's elements list
   - Define `chart_element_schema()` with all configuration options
   - Register `AshReports.Element.Chart` as target module

2. **Element Module** (`lib/ash_reports/element/chart.ex` - NEW)
   - Create `AshReports.Element.Chart` struct with all schema fields
   - Implement `new/2` constructor following element pattern
   - Add helper functions for data extraction and config building

3. **DSLGenerator** (`lib/ash_reports/typst/dsl_generator.ex`)
   - Add `"Chart" ->` case to `generate_element/2`
   - Implement `generate_chart_element/2` function
   - Extract data from report context using `data_source` expression
   - Evaluate dynamic config expressions (variables, parameters)
   - Call `Charts.generate/3` → `ChartEmbedder.embed/2`
   - Return Typst code for embedding in template

4. **Data Flow**:
   ```
   Report DSL (chart element)
        ↓
   AshReports.Element.Chart struct
        ↓
   DSLGenerator.generate_element/2
        ↓
   Evaluate data_source expr → chart data list
   Evaluate config exprs → Charts.Config
        ↓
   Charts.generate(:bar, data, config)
        ↓
   ChartEmbedder.embed(svg, opts)
        ↓
   Typst #image.decode(...) code
        ↓
   Inserted into band template
   ```

---

## 3. Agent Consultations Performed

### Research Phase

**Codebase Analysis Completed**:
1. **Report DSL structure** - Studied `lib/ash_reports/dsl.ex` (769 lines)
   - Understood entity/schema pattern for elements
   - Reviewed existing 7 element types (field, label, expression, aggregate, line, box, image)
   - Identified extension points in `band_entity()` entities list

2. **Element implementations** - Reviewed `lib/ash_reports/element/`
   - `field.ex`, `image.ex` - Pattern for struct creation, position/style handling
   - All elements follow same pattern: defstruct, type field, new/2 constructor

3. **DSLGenerator logic** - Analyzed `lib/ash_reports/typst/dsl_generator.ex` (512 lines)
   - `generate_element/2` - Main dispatch function for element types
   - Element-specific generators: `generate_field_element/2`, `generate_image_element/2`, etc.
   - Expression evaluation: `convert_expression_to_typst/2` for Ash.Expr handling

4. **Chart infrastructure** - Verified Stage 3 completion:
   - `Charts` module - Public API for chart generation (210 lines)
   - `ChartEmbedder` module - SVG-to-Typst conversion (289 lines)
   - 5 chart types implemented: bar, line, pie, area, scatter
   - Theme system, caching, telemetry all operational

5. **Band system** - Reviewed `lib/ash_reports/band.ex`
   - Elements stored in `elements` list
   - Band types: title, page_header, detail, group_header, etc.
   - Recursive band structure support

6. **Variable system** - Studied `lib/ash_reports/variable.ex`
   - Variable types: sum, count, average, min, max, custom
   - Reset scopes: detail, group, page, report
   - Variables can be referenced in expressions via `expr(var(:variable_name))`

### Key Insights

1. **Pattern consistency**: All elements follow identical structure - this simplifies chart element implementation
2. **Expression evaluation**: Ash.Expr is used throughout for dynamic values - chart config can leverage this
3. **DSLGenerator extensibility**: Adding new element type requires:
   - New case in `generate_element/2`
   - New `generate_chart_element/2` function
   - Integration with existing conversion logic
4. **ChartEmbedder ready**: Section 3.3.1 provides complete embedding API, no modifications needed
5. **Data binding precedent**: Field elements use `source` for data binding - chart elements should use similar `data_source` pattern

---

## 4. Technical Details

### DSL Syntax Design

#### Basic Chart Element

```elixir
chart :chart_name do
  chart_type :bar | :line | :pie | :area | :scatter
  data_source expr(expression_to_get_data)

  # Optional configuration
  config %{
    width: 600,
    height: 400,
    title: "Chart Title",
    colors: ["#FF6B6B", "#4ECDC4"],
    show_legend: true,
    legend_position: :right,
    theme_name: :default | :corporate | :minimal | :vibrant
  }

  # Standard element properties
  position x: 0, y: 0, width: 100, height: 50
  style [...]
  conditional expr(boolean_expression)

  # Chart-specific presentation
  caption "Chart caption text"
  title "Chart title text"
  encoding :base64 | :file
end
```

#### Complete Example in Report DSL

```elixir
defmodule MyApp.Reports do
  use Ash.Domain,
    extensions: [AshReports.Domain]

  reports do
    report :quarterly_sales do
      title "Quarterly Sales Report"
      driving_resource MyApp.Sales

      parameters do
        parameter :quarter, :integer, required: true
        parameter :chart_width, :integer, default: 800
        parameter :show_charts, :boolean, default: true
      end

      variables do
        variable :total_sales do
          type :sum
          expression expr(amount)
          reset_on :report
        end
      end

      bands do
        # Title band with static label
        band :title do
          type :title
          elements do
            label :report_title do
              text "Quarterly Sales Report"
            end
          end
        end

        # Header band with chart
        band :header do
          type :page_header
          elements do
            chart :sales_by_region do
              chart_type :bar
              data_source expr(
                records
                |> Enum.group_by(& &1.region)
                |> Enum.map(fn {region, sales} ->
                  %{category: region, value: Enum.sum(Enum.map(sales, & &1.amount))}
                end)
              )

              config %{
                width: expr(param(:chart_width)),
                height: 400,
                title: "Sales by Region",
                colors: ["#FF6B6B", "#4ECDC4", "#45B7D1"],
                show_legend: true,
                theme_name: :corporate
              }

              caption "Total sales aggregated by region"
              conditional expr(param(:show_charts))
            end

            chart :monthly_trend do
              chart_type :line
              data_source expr(
                records
                |> Enum.group_by(& &1.month)
                |> Enum.map(fn {month, sales} ->
                  %{x: month, y: Enum.sum(Enum.map(sales, & &1.amount))}
                end)
                |> Enum.sort_by(& &1.x)
              )

              config %{
                width: 600,
                height: 300,
                title: "Monthly Sales Trend",
                show_grid: true
              }

              title "Sales Trend Analysis"
              conditional expr(var(:total_sales) > 10000)
            end
          end
        end

        # Detail band with data fields
        band :detail do
          type :detail
          elements do
            field :customer do
              source expr(customer_name)
            end
            field :amount do
              source expr(amount)
              format :currency
            end
          end
        end

        # Footer band with summary chart
        band :footer do
          type :summary
          elements do
            chart :top_products do
              chart_type :pie
              data_source expr(
                records
                |> Enum.group_by(& &1.product)
                |> Enum.map(fn {product, sales} ->
                  %{category: product, value: Enum.sum(Enum.map(sales, & &1.amount))}
                end)
                |> Enum.sort_by(& &1.value, :desc)
                |> Enum.take(5)
              )

              config %{
                width: 500,
                height: 500,
                title: "Top 5 Products"
              }

              caption "Based on total sales volume"
            end
          end
        end
      end
    end
  end
end
```

### Element Structure and Configuration

#### Chart Element Struct (`lib/ash_reports/element/chart.ex`)

```elixir
defmodule AshReports.Element.Chart do
  @moduledoc """
  A chart visualization element that generates and embeds SVG charts in reports.

  Supports bar, line, pie, area, and scatter charts with full data binding from
  report query results and dynamic configuration via variables/parameters.
  """

  defstruct [
    :name,
    :chart_type,
    :data_source,
    :config,
    :data_mapping,
    :caption,
    :title,
    :encoding,
    :position,
    :style,
    :conditional,
    type: :chart
  ]

  @type chart_type :: :bar | :line | :pie | :area | :scatter
  @type encoding :: :base64 | :file

  @type t :: %__MODULE__{
    name: atom(),
    type: :chart,
    chart_type: chart_type(),
    data_source: Ash.Expr.t(),
    config: map() | Ash.Expr.t(),
    data_mapping: map() | nil,
    caption: String.t() | Ash.Expr.t() | nil,
    title: String.t() | Ash.Expr.t() | nil,
    encoding: encoding(),
    position: AshReports.Element.position(),
    style: AshReports.Element.style(),
    conditional: Ash.Expr.t() | nil
  }

  @doc """
  Creates a new Chart element with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name, type: :chart]
      |> Keyword.merge(opts)
      |> Keyword.put_new(:encoding, :base64)
      |> Keyword.put_new(:config, %{})
      |> process_options()
    )
  end

  defp process_options(opts) do
    opts
    |> Keyword.update(:position, %{}, &AshReports.Element.keyword_to_map/1)
    |> Keyword.update(:style, %{}, &AshReports.Element.keyword_to_map/1)
    |> Keyword.update(:config, %{}, &ensure_map/1)
  end

  defp ensure_map(val) when is_map(val), do: val
  defp ensure_map(val) when is_list(val), do: Map.new(val)
  defp ensure_map(val), do: val
end
```

#### DSL Schema Extension (`lib/ash_reports/dsl.ex`)

Add to `band_entity()` entities list:

```elixir
entities: [
  elements: [
    label_element_entity(),
    field_element_entity(),
    expression_element_entity(),
    aggregate_element_entity(),
    line_element_entity(),
    box_element_entity(),
    image_element_entity(),
    chart_element_entity()  # NEW
  ]
]
```

Define chart element entity:

```elixir
defp chart_element_entity do
  %Entity{
    name: :chart,
    describe: """
    A chart visualization element that generates and embeds SVG charts.

    Supports bar, line, pie, area, and scatter charts with data binding from
    report query results and dynamic configuration.
    """,
    examples: [
      """
      chart :sales_by_region do
        chart_type :bar
        data_source expr(records |> Enum.group_by(&(&1.region)))
        config %{
          width: 600,
          height: 400,
          title: "Sales by Region"
        }
        caption "Q1 Sales Performance"
      end
      """
    ],
    target: AshReports.Element.Chart,
    args: [:name],
    schema: chart_element_schema()
  }
end

defp chart_element_schema do
  base_element_schema() ++
    [
      chart_type: [
        type: {:in, [:bar, :line, :pie, :area, :scatter]},
        required: true,
        doc: "The type of chart to generate."
      ],
      data_source: [
        type: :any,
        required: true,
        doc: "Ash expression that extracts and transforms data for the chart. Should evaluate to a list of maps with appropriate fields for the chart type."
      ],
      config: [
        type: {:or, [:map, :any]},
        default: %{},
        doc: "Chart configuration map. Can include width, height, colors, legend settings, theme, etc. Values can be expressions for dynamic configuration."
      ],
      data_mapping: [
        type: :map,
        doc: "Optional field mapping for chart data. E.g., %{x_field: :date, y_field: :revenue} for line charts."
      ],
      caption: [
        type: {:or, [:string, :any]},
        doc: "Caption text displayed below the chart. Can be an expression for dynamic captions."
      ],
      title: [
        type: {:or, [:string, :any]},
        doc: "Title text displayed above the chart. Can be an expression for dynamic titles."
      ],
      encoding: [
        type: {:in, [:base64, :file]},
        default: :base64,
        doc: "SVG encoding strategy. :base64 (default) embeds directly, :file writes to temp file for large charts."
      ]
    ]
end
```

### Data Binding Mechanism

#### Data Source Evaluation Flow

```elixir
# In DSLGenerator.generate_chart_element/2

def generate_chart_element(%{chart_type: chart_type, data_source: data_source} = chart, context) do
  # Step 1: Evaluate data_source expression to get chart data
  chart_data = case evaluate_data_source(data_source, context) do
    {:ok, data} when is_list(data) -> data
    {:ok, other} ->
      Logger.warning("Chart #{chart.name}: data_source must return a list, got: #{inspect(other)}")
      []
    {:error, reason} ->
      Logger.error("Chart #{chart.name}: data_source evaluation failed: #{inspect(reason)}")
      []
  end

  # Step 2: Apply data mapping if specified
  mapped_data = if chart.data_mapping do
    apply_data_mapping(chart_data, chart.data_mapping, chart_type)
  else
    chart_data
  end

  # Step 3: Build chart config by evaluating expressions in config map
  chart_config = build_chart_config(chart.config, context)

  # Step 4: Generate chart SVG
  case Charts.generate(chart_type, mapped_data, chart_config) do
    {:ok, svg} ->
      # Step 5: Embed chart in Typst with caption/title
      embed_opts = build_embed_opts(chart, context)

      case ChartEmbedder.embed(svg, embed_opts) do
        {:ok, typst_code} -> typst_code
        {:error, reason} ->
          Logger.error("Chart #{chart.name}: embedding failed: #{inspect(reason)}")
          "// Chart embedding failed: #{inspect(reason)}"
      end

    {:error, reason} ->
      Logger.error("Chart #{chart.name}: generation failed: #{inspect(reason)}")
      "// Chart generation failed: #{inspect(reason)}"
  end
end

defp evaluate_data_source(data_source_expr, context) do
  # Evaluate Ash.Expr against report context
  # Context includes: records, variables, parameters, current_record, etc.
  try do
    # Use Ash expression evaluation
    result = eval_ash_expression(data_source_expr, context)
    {:ok, result}
  rescue
    e -> {:error, e}
  end
end

defp apply_data_mapping(data, mapping, chart_type) do
  # Transform data based on mapping and chart type requirements
  case chart_type do
    :bar ->
      # Expects: %{category: string, value: number}
      Enum.map(data, fn item ->
        %{
          category: get_in(item, [mapping[:category_field] || :category]),
          value: get_in(item, [mapping[:value_field] || :value])
        }
      end)

    :line ->
      # Expects: %{x: number, y: number} or %{date: Date.t(), value: number}
      Enum.map(data, fn item ->
        %{
          x: get_in(item, [mapping[:x_field] || :x]),
          y: get_in(item, [mapping[:y_field] || :y])
        }
      end)

    :pie ->
      # Expects: %{category: string, value: number}
      Enum.map(data, fn item ->
        %{
          category: get_in(item, [mapping[:category_field] || :category]),
          value: get_in(item, [mapping[:value_field] || :value])
        }
      end)

    _ -> data
  end
end

defp build_chart_config(config_map, context) do
  # Evaluate expressions in config map
  Enum.reduce(config_map, %{}, fn {key, value}, acc ->
    evaluated_value = case value do
      # Ash expression - evaluate with context
      {:expr, _} -> eval_ash_expression(value, context)

      # Static value
      _ -> value
    end

    Map.put(acc, key, evaluated_value)
  end)
  |> then(&struct(AshReports.Charts.Config, &1))
end

defp build_embed_opts(chart, context) do
  [
    width: get_from_config(chart.config, :width) || "100%",
    height: get_from_config(chart.config, :height),
    caption: evaluate_if_expr(chart.caption, context),
    title: evaluate_if_expr(chart.title, context),
    encoding: chart.encoding || :base64
  ]
  |> Enum.reject(fn {_k, v} -> is_nil(v) end)
end
```

### Variable Support

Charts can reference report variables and parameters through expressions:

```elixir
# In report DSL:
variables do
  variable :total_revenue do
    type :sum
    expression expr(amount)
    reset_on :report
  end
end

parameters do
  parameter :chart_theme, :string, default: "corporate"
  parameter :show_legend, :boolean, default: true
end

chart :revenue_chart do
  chart_type :bar
  data_source expr(records)

  config %{
    # Reference parameter
    theme_name: expr(param(:chart_theme)),
    show_legend: expr(param(:show_legend)),

    # Reference variable in title
    title: expr("Total Revenue: $#{var(:total_revenue)}")
  }

  # Conditional rendering based on variable
  conditional expr(var(:total_revenue) > 0)
end
```

**Implementation**:
- `expr(param(:name))` and `expr(var(:name))` are standard Ash expression patterns
- DSLGenerator evaluates these expressions with access to runtime context
- Context includes: `parameters: %{...}`, `variables: %{...}`, `records: [...]`

### Conditional Rendering

Two mechanisms for conditional chart display:

#### 1. Element-level conditional (standard across all elements)

```elixir
chart :optional_chart do
  chart_type :line
  data_source expr(records)

  # Standard conditional field - evaluated before chart generation
  conditional expr(param(:include_visualizations) and length(records) > 0)
end
```

**Implementation**: DSLGenerator checks `conditional` field before calling `generate_chart_element/2`. If false, element is skipped entirely.

#### 2. Data-driven conditional (chart-specific)

```elixir
chart :trend_analysis do
  chart_type :line
  data_source expr(records)

  config %{
    # Charts module enforces minimum data points
    min_data_points: 5
  }
end
```

**Implementation**: Charts module returns `{:error, {:insufficient_data, msg}}` if data length < min_data_points. DSLGenerator catches error and either:
- Returns empty string (chart not rendered)
- Returns fallback text: "// Insufficient data for chart (minimum: 5 points)"

### File Locations and Dependencies

#### New Files to Create

1. **`lib/ash_reports/element/chart.ex`** (~80 lines)
   - Chart element struct definition
   - Constructor and helper functions
   - Documentation

#### Files to Modify

1. **`lib/ash_reports/dsl.ex`** (~50 lines added)
   - Add `chart_element_entity()` function
   - Add `chart_element_schema()` function
   - Register in band entity's elements list

2. **`lib/ash_reports/typst/dsl_generator.ex`** (~150 lines added)
   - Add `"Chart" ->` case to `generate_element/2`
   - Implement `generate_chart_element/2` function
   - Add `evaluate_data_source/2` helper
   - Add `apply_data_mapping/3` helper
   - Add `build_chart_config/2` helper
   - Add `build_embed_opts/2` helper
   - Add `evaluate_if_expr/2` helper

#### Dependencies

**Existing modules** (no changes needed):
- `AshReports.Charts` - Chart generation API
- `AshReports.Typst.ChartEmbedder` - SVG-to-Typst conversion
- `AshReports.Charts.Config` - Chart configuration struct
- `AshReports.Element` - Base element behavior

**External dependencies** (already in mix.exs):
- `spark` - DSL framework
- `ash` - Expression evaluation
- `contex` - Chart rendering

---

## 5. Success Criteria

### What defines a successful implementation?

1. **DSL Syntax Works**
   - Chart elements can be added to band definitions
   - All configuration options are accepted by DSL parser
   - No Spark DSL compilation errors

2. **Chart Rendering Functions**
   - Charts generate correct SVG output
   - Charts embed properly in Typst templates
   - Generated PDFs display charts at correct positions

3. **Data Binding Works**
   - `data_source` expressions evaluate correctly
   - Data transformation produces correct chart data format
   - All 5 chart types (bar, line, pie, area, scatter) render with bound data

4. **Variable Integration Works**
   - Chart config can reference report parameters
   - Chart config can reference report variables
   - Dynamic titles/captions evaluate correctly

5. **Conditional Rendering Works**
   - Charts respect `conditional` field
   - Charts respect `min_data_points` config
   - Hidden charts don't cause rendering errors

6. **Documentation Complete**
   - DSL syntax documented with examples
   - Chart element API documented
   - Integration guide for report authors

### How will we verify it works?

#### Unit Tests

1. **Element Creation** (`test/ash_reports/element/chart_test.exs`)
   ```elixir
   test "creates chart element with required fields"
   test "sets default encoding to :base64"
   test "converts config keyword list to map"
   test "validates chart_type is valid"
   ```

2. **DSL Parsing** (`test/ash_reports/dsl_test.exs`)
   ```elixir
   test "parses chart element in band"
   test "validates required chart_type field"
   test "accepts all chart configuration options"
   test "allows Ash expressions in data_source"
   test "allows expressions in config values"
   ```

3. **Chart Element Generation** (`test/ash_reports/typst/dsl_generator_test.exs`)
   ```elixir
   test "generates Typst code for bar chart"
   test "generates Typst code for line chart"
   test "generates Typst code for pie chart"
   test "evaluates data_source expression"
   test "applies data mapping correctly"
   test "builds chart config from expressions"
   test "includes caption in output"
   test "includes title in output"
   test "respects encoding option"
   ```

#### Integration Tests

1. **End-to-End Chart Rendering** (`test/ash_reports/integration/chart_element_test.exs`)
   ```elixir
   test "renders complete report with chart element"
   test "chart displays in correct band position"
   test "multiple charts in same report"
   test "chart data from report query results"
   ```

2. **Variable Integration** (`test/ash_reports/integration/chart_variables_test.exs`)
   ```elixir
   test "chart config references parameter"
   test "chart config references variable"
   test "dynamic chart title from variable"
   test "conditional chart based on variable value"
   ```

3. **Conditional Rendering** (`test/ash_reports/integration/chart_conditionals_test.exs`)
   ```elixir
   test "chart hidden when conditional is false"
   test "chart not rendered when min_data_points not met"
   test "chart shown when data available"
   ```

#### Visual Verification

1. **Test Report Generation**
   - Create test report with charts in multiple bands
   - Generate PDF and manually verify:
     - Charts appear in correct positions
     - Charts have correct dimensions
     - Captions and titles display properly
     - Legend and labels are readable

2. **Visual Regression Tests** (using existing infrastructure from Stage 1.4.1)
   ```elixir
   test "chart element matches baseline rendering"
   test "multi-chart layout matches baseline"
   ```

### Example Use Cases

#### Use Case 1: Sales Report with Regional Bar Chart

```elixir
reports do
  report :monthly_sales do
    driving_resource Sales

    bands do
      band :header do
        type :page_header
        elements do
          chart :sales_by_region do
            chart_type :bar
            data_source expr(
              records
              |> Enum.group_by(& &1.region)
              |> Enum.map(fn {region, sales} ->
                %{category: region, value: Enum.sum(Enum.map(sales, & &1.amount))}
              end)
            )

            config %{
              width: 700,
              height: 400,
              title: "Sales by Region",
              colors: ["#FF6B6B", "#4ECDC4", "#45B7D1"],
              show_legend: true
            }

            caption "Regional sales breakdown for current period"
          end
        end
      end
    end
  end
end
```

**Expected Result**: PDF with bar chart in page header showing sales totals by region with legend and caption.

#### Use Case 2: Time-Series Line Chart with Variable-Based Conditional

```elixir
reports do
  report :revenue_trend do
    driving_resource Revenue

    variables do
      variable :total_revenue do
        type :sum
        expression expr(amount)
        reset_on :report
      end
    end

    bands do
      band :summary do
        type :summary
        elements do
          chart :trend_chart do
            chart_type :line
            data_source expr(
              records
              |> Enum.group_by(&Date.beginning_of_month(&1.date))
              |> Enum.map(fn {month, revenues} ->
                %{date: month, value: Enum.sum(Enum.map(revenues, & &1.amount))}
              end)
              |> Enum.sort_by(& &1.date)
            )

            config %{
              width: 800,
              height: 300,
              show_grid: true,
              theme_name: :corporate
            }

            title expr("Revenue Trend - Total: $#{var(:total_revenue)}")

            # Only show if we have meaningful revenue
            conditional expr(var(:total_revenue) > 1000)
          end
        end
      end
    end
  end
end
```

**Expected Result**: PDF with line chart in summary band showing monthly revenue trend, with dynamic title including total. Chart only appears if total revenue exceeds $1000.

#### Use Case 3: Multi-Chart Dashboard with Parameter Control

```elixir
reports do
  report :executive_dashboard do
    driving_resource Orders

    parameters do
      parameter :chart_size, :string, default: "large"
      parameter :theme, :string, default: "corporate"
    end

    bands do
      band :dashboard do
        type :title
        elements do
          chart :orders_by_status do
            chart_type :pie
            data_source expr(
              records
              |> Enum.group_by(& &1.status)
              |> Enum.map(fn {status, orders} ->
                %{category: status, value: length(orders)}
              end)
            )

            config %{
              width: expr(if param(:chart_size) == "large", do: 600, else: 400),
              height: expr(if param(:chart_size) == "large", do: 600, else: 400),
              theme_name: expr(String.to_atom(param(:theme)))
            }

            caption "Order Distribution by Status"
          end

          chart :top_customers do
            chart_type :bar
            data_source expr(
              records
              |> Enum.group_by(& &1.customer_id)
              |> Enum.map(fn {customer_id, orders} ->
                %{category: customer_id, value: length(orders)}
              end)
              |> Enum.sort_by(& &1.value, :desc)
              |> Enum.take(10)
            )

            config %{
              width: expr(if param(:chart_size) == "large", do: 700, else: 500),
              height: 400,
              theme_name: expr(String.to_atom(param(:theme)))
            }

            caption "Top 10 Customers by Order Volume"
          end
        end
      end
    end
  end
end
```

**Expected Result**: PDF with two charts (pie and bar) in title band, with dimensions and theme controlled by parameters.

---

## 6. Implementation Plan

### Logical Steps (Testable Chunks)

#### Step 1: Chart Element Struct (2-3 hours)
**Goal**: Create base Chart element struct and constructor

**Tasks**:
1. Create `lib/ash_reports/element/chart.ex`
2. Define struct with all fields (name, chart_type, data_source, config, etc.)
3. Implement `new/2` constructor following element pattern
4. Add type specs and documentation
5. Write unit tests for element creation

**Tests**:
- Element creation with required fields
- Default values set correctly
- Config normalization (keyword list → map)
- Position/style processing

**Deliverable**: `AshReports.Element.Chart` module with passing tests

---

#### Step 2: DSL Schema Extension (3-4 hours)
**Goal**: Register chart element in DSL

**Tasks**:
1. Add `chart_element_entity/0` function to `dsl.ex`
2. Define `chart_element_schema/0` with all fields
3. Add chart entity to band's elements list
4. Write DSL parsing tests

**Tests**:
- Chart element parsed from DSL
- Required fields validated
- Chart type values restricted to valid types
- Expressions accepted in data_source and config

**Deliverable**: Chart elements compile in DSL without errors

---

#### Step 3: Basic Chart Generation (4-5 hours)
**Goal**: Generate Typst code for simplest chart case

**Tasks**:
1. Add `"Chart" ->` case to DSLGenerator.`generate_element/2`
2. Implement `generate_chart_element/2` for static data source
3. Implement `build_chart_config/2` for static config
4. Use ChartEmbedder to get Typst code
5. Write generator tests

**Tests**:
- Generates Typst code for bar chart with static data
- Generates Typst code for pie chart with static data
- Config passed correctly to Charts module
- ChartEmbedder called with correct options

**Deliverable**: Static charts render in generated Typst templates

---

#### Step 4: Data Source Expression Evaluation (4-5 hours)
**Goal**: Evaluate data_source expressions against report context

**Tasks**:
1. Implement `evaluate_data_source/2` function
2. Build report context with records, variables, parameters
3. Use Ash expression evaluation
4. Handle evaluation errors gracefully
5. Write expression evaluation tests

**Tests**:
- Simple field access: `expr(records)`
- Transformation: `expr(records |> Enum.map(...))`
- Grouping: `expr(records |> Enum.group_by(...))`
- Error handling for invalid expressions

**Deliverable**: Charts render with data extracted from report query results

---

#### Step 5: Data Mapping Support (3-4 hours)
**Goal**: Transform data to match chart type requirements

**Tasks**:
1. Implement `apply_data_mapping/3` function
2. Handle bar chart data format (category/value)
3. Handle line chart data format (x/y or date/value)
4. Handle pie chart data format (category/value)
5. Write data mapping tests

**Tests**:
- Bar chart data mapping
- Line chart data mapping
- Pie chart data mapping
- No mapping (data already correct format)

**Deliverable**: Charts work with various data structures through mapping

---

#### Step 6: Dynamic Config with Expressions (4-5 hours)
**Goal**: Evaluate expressions in config values

**Tasks**:
1. Update `build_chart_config/2` to detect expressions
2. Evaluate expressions with parameter/variable access
3. Handle nested expressions in config
4. Add context for param() and var() functions
5. Write dynamic config tests

**Tests**:
- Config references parameter: `width: expr(param(:chart_width))`
- Config references variable: `title: expr("Total: #{var(:total)}")`
- Multiple expressions in same config
- Fallback for evaluation errors

**Deliverable**: Charts accept dynamic configuration from DSL

---

#### Step 7: Caption and Title Support (2-3 hours)
**Goal**: Add caption/title to embedded charts

**Tasks**:
1. Implement `build_embed_opts/2` function
2. Extract caption/title from chart element
3. Evaluate if they're expressions
4. Pass to ChartEmbedder
5. Write caption/title tests

**Tests**:
- Static caption renders
- Static title renders
- Dynamic caption from expression
- Dynamic title with variable interpolation

**Deliverable**: Charts display with captions and titles in PDF

---

#### Step 8: Conditional Rendering (3-4 hours)
**Goal**: Support show/hide logic for charts

**Tasks**:
1. Check `conditional` field before chart generation
2. Handle `min_data_points` config option
3. Return empty string or fallback text when hidden
4. Write conditional tests

**Tests**:
- Chart hidden when conditional is false
- Chart shown when conditional is true
- Chart skipped when insufficient data points
- No errors when chart not rendered

**Deliverable**: Charts conditionally render based on data and expressions

---

#### Step 9: Integration Testing (4-5 hours)
**Goal**: Test complete end-to-end scenarios

**Tasks**:
1. Create test report with multiple chart types
2. Test with real Ash resources
3. Test with parameters and variables
4. Generate actual PDFs
5. Visual verification

**Tests**:
- Report with bar chart in header
- Report with line chart in summary
- Report with pie chart in detail
- Multiple charts in same report
- Chart with dynamic configuration
- Chart with conditional rendering

**Deliverable**: Complete reports with charts render correctly

---

#### Step 10: Documentation and Examples (3-4 hours)
**Goal**: Document chart element usage

**Tasks**:
1. Add moduledoc to Chart element
2. Add examples to DSL entity definition
3. Create usage guide in docs/
4. Add to main README
5. Create example report in test/support/

**Tests**:
- Documentation compiles without warnings
- Examples are syntactically correct

**Deliverable**: Comprehensive documentation for chart elements

---

### Testing Strategy for Each Step

1. **Unit Tests First** - Write tests before implementation (TDD)
2. **Incremental Integration** - Each step builds on previous, test integration points
3. **Error Handling** - Test both success and failure paths
4. **Edge Cases** - Empty data, malformed expressions, missing config
5. **Visual Verification** - Manual PDF inspection for final integration tests

### Integration Milestones

1. **Milestone 1** (After Step 3): Static charts work
2. **Milestone 2** (After Step 5): Charts render with report data
3. **Milestone 3** (After Step 7): Charts have presentation features
4. **Milestone 4** (After Step 9): Complete feature with all options

---

## 7. Notes/Considerations

### Edge Cases

1. **Empty Data Source**
   - `data_source` evaluates to empty list `[]`
   - **Handling**: Check length before chart generation, skip chart or show "No data" placeholder

2. **Invalid Data Format**
   - Data doesn't match chart type requirements (e.g., bar chart gets line chart data)
   - **Handling**: Validate data format before passing to Charts module, log warning, skip chart

3. **Expression Evaluation Errors**
   - `data_source` expression throws exception
   - Config expression can't be evaluated
   - **Handling**: Wrap in try-rescue, log error, skip chart, continue report generation

4. **Large Data Sets**
   - 10,000+ records need aggregation for chart
   - **Handling**: Document recommendation to pre-aggregate in data_source expression

5. **Multiple Charts in Band**
   - Multiple chart elements in same band
   - **Handling**: Use ChartEmbedder.embed_grid or embed_flow for layout

6. **Chart Size Constraints**
   - Chart larger than page width/height
   - **Handling**: ChartEmbedder handles sizing, but document recommended dimensions

7. **Missing Dependencies**
   - Charts module not initialized
   - Contex not available
   - **Handling**: Add startup checks, clear error messages

### Future Improvements

1. **Advanced Data Transformations**
   - Built-in aggregation functions in DSL
   - Time-series bucketing helpers
   - Pre-built pivot functions
   - **Defer to**: Future enhancement or Stage 3.2 expansion

2. **Chart Templates**
   - Reusable chart configurations
   - Saved chart presets
   - **Defer to**: Stage 4 (LiveView) or separate feature

3. **Interactive Charts in HTML**
   - Charts in HTML output use Chart.js for interactivity
   - Different rendering path than PDF
   - **Defer to**: Separate feature after PDF charts stable

4. **Chart Data Caching**
   - Cache expensive data_source evaluations
   - Reuse chart data across pages
   - **Defer to**: Stage 3.3.3 (Performance Optimization)

5. **Custom Chart Types**
   - User-defined chart builders
   - Custom SVG generation
   - **Defer to**: Advanced feature, requires chart builder API

6. **Chart Animations (PDF)**
   - Animated chart rendering in PDF
   - **Not Feasible**: PDFs don't support animation well

7. **Multi-Page Charts**
   - Charts that span multiple pages
   - **Complex**: Requires advanced layout logic, defer

8. **Chart Annotations**
   - Reference lines, zones, labels
   - **Defer to**: Enhancement after basic charts work

### Known Limitations

1. **Expression Complexity**
   - Very complex data_source expressions may hit evaluation limits
   - **Recommendation**: Keep transformations simple, pre-aggregate in query if possible

2. **Chart Library Constraints**
   - Limited by Contex capabilities
   - Some advanced chart features not available
   - **Mitigation**: Document what's supported, provide workarounds

3. **PDF Size**
   - Many charts increase PDF file size significantly
   - Base64 embedding adds ~33% overhead
   - **Mitigation**: Use `:file` encoding for large charts, document size considerations

4. **No Real-Time Updates**
   - Charts generated at report creation time
   - Not updated dynamically
   - **Acceptable**: Reports are typically static documents

5. **Limited Styling Options**
   - Chart styling controlled by Charts.Config and themes
   - Can't override all Contex defaults
   - **Acceptable**: Provide reasonable defaults, allow theme selection

6. **Data Format Strictness**
   - Chart types expect specific data formats
   - Type mismatches cause errors
   - **Mitigation**: Validate data format, provide clear error messages

### Performance Considerations

1. **Chart Generation Time**
   - Each chart adds 10-50ms to report generation
   - Multiple charts compound
   - **Acceptable**: Most reports have 1-5 charts

2. **Memory Usage**
   - Charts consume memory during generation
   - SVG strings can be large (100KB+)
   - **Mitigation**: Stream processing for multiple charts, cache when appropriate

3. **Data Source Evaluation**
   - Complex expressions can be slow
   - Grouping/aggregation on large datasets
   - **Recommendation**: Use Stage 2 streaming for large datasets, pre-aggregate

4. **Typst Compilation**
   - More charts = more Typst code = longer compilation
   - Still faster than alternatives (18x faster than LaTeX)
   - **Acceptable**: Typst is fast enough for typical use cases

---

## Summary

This planning document provides a comprehensive roadmap for implementing Section 3.3.2: DSL Chart Element. The implementation follows AshReports' existing patterns for element definitions while integrating the complete chart infrastructure from Stage 3.1-3.2 and embedding system from Stage 3.3.1.

**Key Deliverables**:
1. New `AshReports.Element.Chart` module (~80 lines)
2. Extended DSL schema in `dsl.ex` (~50 lines)
3. Enhanced DSLGenerator with chart support (~150 lines)
4. Comprehensive test suite (50+ tests)
5. Complete documentation and examples

**Estimated Implementation Time**: 32-40 hours across 10 logical steps

**Next Steps**:
1. Review and confirm this plan
2. Begin Step 1: Chart Element Struct
3. Proceed incrementally through steps with testing at each milestone
