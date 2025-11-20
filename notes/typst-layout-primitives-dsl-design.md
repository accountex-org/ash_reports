# Typst Layout Primitives DSL Design Proposal

**Date**: 2025-11-20
**Status**: Proposal
**Author**: Claude Code

---

## 1. Overview

This document proposes integrating Typst's layout primitives (grid, table, stack, row) into the AshReports DSL. The goal is to provide powerful, declarative layout capabilities that map directly to Typst's rendering model while maintaining an ergonomic Elixir DSL.

### Objectives

- Provide full access to Typst's layout capabilities through an Elixir DSL
- Maintain semantic distinction between presentational (grid) and data (table) layouts
- Support multi-format rendering (Typst/PDF, HTML, JSON)
- Clean-slate implementation (no backward compatibility with legacy column-based syntax)

---

## 2. Key Design Principles

### 2.1 Semantic Distinction

- **`table`**: For data presentation with accessibility semantics (detail bands, data grids)
- **`grid`**: For presentational layout without data semantics (title bands, dashboards)
- **`stack`**: For sequential arrangement of elements (vertical or horizontal flow)
- **`row`**: Explicit row containers within grid/table for clarity and row-level properties

### 2.2 Integration Strategy

Layout primitives nest **inside bands** as the layout mechanism, replacing the current string-based column definition:

```elixir
# Current approach
band :detail do
  columns "(150pt, 100pt, 80pt)"  # String-based
  field :name, column: 0
end

# New approach
band :detail do
  table do
    columns ["150pt", "100pt", "80pt"]
    row do
      cell do
        field :name
      end
    end
  end
end
```

---

## 3. DSL Entity Definitions

### 3.1 Grid Entity

Grid is for presentational 2D layout without semantic meaning.

```elixir
grid do
  # Track Sizing
  columns [auto(), fr(1), "100pt", "20%"]  # Array of track sizes
  rows auto()                              # auto, array, or integer count

  # Spacing
  gutter "10pt"                    # All gutters
  column_gutter "5pt"              # Override column gaps
  row_gutter "15pt"                # Override row gaps

  # Cell Defaults
  align :center                    # :left, :center, :right, :top, :bottom
  inset "5pt"                      # Cell padding
  fill "#ffffff"                   # Background color
  stroke :none                     # No borders by default (grid is presentational)

  # Content
  cell do ... end                  # Cells flow row-major
  row do ... end                   # Explicit rows
  hline y: 1, stroke: "1pt"        # Horizontal line after row 1
  vline x: 2                       # Vertical line after column 2
end
```

**Track Size Types:**
- `auto()` - Size to content
- `fr(n)` - Fractional unit (n shares of remaining space)
- `"100pt"` - Fixed length (pt, mm, cm, in)
- `"20%"` - Percentage of available space
- Integer - Shorthand for N auto columns: `columns 3`

### 3.2 Table Entity

Table is for semantic data presentation with accessibility support.

```elixir
table do
  # Track Sizing (same as grid)
  columns ["150pt", fr(1), "100pt", "80pt"]
  rows auto()

  # Spacing
  gutter "0pt"
  column_gutter "0pt"
  row_gutter "0pt"

  # Cell Defaults
  align :left
  inset "5pt"                      # Default: 0% + 5pt (Typst default)
  fill :none
  stroke "1pt"                     # Default: 1pt + black (tables have borders)

  # Semantic Sections
  header repeat: true do           # Repeats on each page
    cell do ... end
  end

  footer repeat: true do           # Appears at bottom of each page
    cell do ... end
  end

  # Data Rows
  row do
    cell do ... end
  end

  # Line Control
  hline y: 0, stroke: "2pt", position: :bottom
  vline x: 1, start: 0, end_row: 3
end
```

### 3.3 Stack Entity

Stack arranges content sequentially in one direction.

```elixir
stack do
  # Direction
  dir :ttb                         # :ttb (top-to-bottom, default)
                                   # :btt (bottom-to-top)
                                   # :ltr (left-to-right)
                                   # :rtl (right-to-left)

  # Spacing between items
  spacing "10pt"

  # Children - any content elements
  grid do ... end
  table do ... end
  label do ... end
  box do ... end
end
```

### 3.4 Row Entity

Explicit row container for clarity and row-level properties.

```elixir
row do
  # Row-specific properties
  height "30pt"                    # Fixed height (optional)
  fill "#f0f0f0"                   # Row background
  stroke "1pt"                     # Row border
  align :center                    # Default alignment for cells in row
  inset "5pt"                      # Default inset for cells

  # Cells
  cell do ... end
  cell do ... end
end
```

### 3.5 Cell Entity

Individual cell with spanning and positioning options.

```elixir
cell do
  # Spanning
  colspan 2                        # Span multiple columns
  rowspan 3                        # Span multiple rows

  # Explicit Positioning (optional, overrides flow)
  x 0                              # Column index (0-based)
  y 1                              # Row index (0-based)

  # Cell-specific overrides
  align :right
  fill "#e0e0e0"
  stroke "0.5pt"
  inset "10pt"
  breakable false                  # Prevent page breaks within cell

  # Content - labels, fields, nested layouts
  label do ... end
  field do ... end
  stack do ... end                 # Nested layout
end
```

---

## 4. Content Elements

### 4.1 Label

```elixir
label do
  text "Report Title"              # Or: text "[variable_name]" for interpolation

  # Styling
  style do
    font_size 24
    font_weight :bold
    color "#2F5597"
    font_family "Arial"
  end
end

# Short form
label text: "Customer Name", style: [font_size: 12]
```

### 4.2 Field

```elixir
field do
  source :total_amount             # Attribute or calculation name

  # Formatting
  format :currency                 # :currency, :number, :date, :datetime, :percent
  decimal_places 2

  # Styling (optional, inherits from cell/table)
  style do
    font_weight :bold
  end
end

# Short form
field source: :name
field source: :amount, format: :currency, decimal_places: 2
```

---

## 5. Property Type Specifications

### 5.1 Track Size Types

```elixir
@type track_size ::
  :auto |                              # Auto-size to content
  {:auto, keyword()} |                 # auto with options
  {:fr, pos_integer()} |               # Fractional unit
  String.t() |                         # "100pt", "2cm", "20%"
  pos_integer()                        # Shorthand for N auto columns

# Helper functions for DSL
defmodule AshReports.Layout.Track do
  def auto(), do: :auto
  def fr(n), do: {:fr, n}
end
```

### 5.2 Length Type

```elixir
@type length :: String.t()  # "10pt", "1cm", "0.5in", "20%", "1em"

# Supported units:
# pt - points (1/72 inch)
# mm - millimeters
# cm - centimeters
# in - inches
# % - percentage of parent
# em - relative to font size
# fr - fractional (for track sizing only)
```

### 5.3 Alignment Type

```elixir
@type alignment ::
  :left | :center | :right |           # Horizontal
  :top | :middle | :bottom |           # Vertical
  {:horizontal, :left | :center | :right} |
  {:vertical, :top | :middle | :bottom} |
  {horizontal_align, vertical_align}   # Combined
```

### 5.4 Color/Fill Type

```elixir
@type color ::
  String.t() |                         # "#ffffff", "rgb(255,255,255)"
  atom() |                             # :none, :transparent
  {:gradient, gradient_spec}           # Gradient definition

@type fill ::
  color() |
  (x :: integer(), y :: integer() -> color())  # Function for conditional fill
```

### 5.5 Stroke Type

```elixir
@type stroke ::
  :none |
  String.t() |                         # "1pt" (uses default color)
  {String.t(), color()} |              # {"1pt", "#000000"}
  stroke_spec()

@type stroke_spec :: [
  width: String.t(),
  color: color(),
  dash: :solid | :dashed | :dotted | [pattern]
]
```

### 5.6 Direction Type (for Stack)

```elixir
@type direction ::
  :ttb |    # Top to bottom (default)
  :btt |    # Bottom to top
  :ltr |    # Left to right
  :rtl      # Right to left
```

---

## 6. Cell/Content Placement Model

### 6.1 Automatic Flow (Row-Major Order)

By default, cells populate in row-major order:

```elixir
grid do
  columns 3  # 3 columns

  # These cells fill positions: (0,0), (1,0), (2,0), (0,1), (1,1)...
  cell do ... end  # (0, 0)
  cell do ... end  # (1, 0)
  cell do ... end  # (2, 0)
  cell do ... end  # (0, 1)
end
```

### 6.2 Explicit Row Containers

Using `row` provides clearer structure and row-level properties:

```elixir
table do
  columns 3

  row fill: "#f0f0f0" do
    cell do ... end  # (0, 0)
    cell do ... end  # (1, 0)
    cell do ... end  # (2, 0)
  end

  row do
    cell do ... end  # (0, 1)
    cell do ... end  # (1, 1)
    cell do ... end  # (2, 1)
  end
end
```

### 6.3 Explicit Positioning

Override automatic flow with `x` and `y`:

```elixir
grid do
  columns 4
  rows 3

  # Explicit position
  cell x: 0, y: 0 do
    label text: "Top Left"
  end

  cell x: 3, y: 2 do
    label text: "Bottom Right"
  end

  # Spanning cell
  cell x: 1, y: 1, colspan: 2, rowspan: 2 do
    label text: "Large Center Cell"
  end
end
```

### 6.4 Spanning Behavior

When a cell spans multiple columns/rows:
- Takes up space in the grid
- Automatic flow skips occupied positions
- Content is centered by default within the spanned area

```elixir
table do
  columns 4

  row do
    cell colspan: 2 do
      label text: "Spans columns 0-1"
    end
    cell do
      label text: "Column 2"
    end
    cell do
      label text: "Column 3"
    end
  end
end
```

### 6.5 Nested Layouts

Cells can contain nested layout structures:

```elixir
grid do
  columns 2

  cell do
    # Nested vertical stack inside cell
    stack dir: :ttb, spacing: "5pt" do
      label text: "Title"
      field source: :value
      label text: "Footer"
    end
  end

  cell do
    # Nested grid inside cell
    grid do
      columns 2
      cell do ... end
      cell do ... end
    end
  end
end
```

### 6.6 Header/Footer Repeat Behavior

For tables spanning multiple pages:

```elixir
table do
  columns ["100pt", fr(1), "80pt"]

  # Header repeats on each page
  header repeat: true do
    cell do
      label text: "Column A"
    end
    cell do
      label text: "Column B"
    end
    cell do
      label text: "Column C"
    end
  end

  # Multiple header levels (cascading)
  header repeat: true, level: 1 do
    cell colspan: 3 do
      label text: "Section Title"
    end
  end

  # Footer appears at bottom of each page
  footer repeat: true do
    cell colspan: 3, align: :center do
      label text: "Page [page_number] of [total_pages]"
    end
  end
end
```

---

## 7. Complete Example: Invoice Report

```elixir
report :invoice_details do
  description "Detailed invoice report with line items"

  parameter :start_date, :date
  parameter :end_date, :date

  base_filter expr(
    invoice_date >= ^arg(:start_date) and
    invoice_date <= ^arg(:end_date)
  )

  group :customer do
    level 1
    expression expr(customer_id)
  end

  variable :invoice_total do
    type :sum
    expression expr(total_amount)
    reset_on :group
  end

  variable :grand_total do
    type :sum
    expression expr(total_amount)
    reset_on :report
  end

  # Title Band
  band :report_title do
    type :title

    grid do
      columns [fr(1)]
      rows auto()
      align :center

      cell do
        label text: "Invoice Report", style: [font_size: 28, font_weight: :bold]
      end

      cell do
        label text: "[start_date] to [end_date]", style: [font_size: 14, color: "#666"]
      end
    end
  end

  # Group Header
  band :customer_header do
    type :group_header
    group_level 1

    grid do
      columns [fr(1), "100pt"]
      fill "#e8f4fc"
      inset "10pt"

      row do
        cell do
          label text: "Customer: [group_value]", style: [font_size: 16, font_weight: :bold]
        end
        cell align: :right do
          label text: "[record_count] invoices"
        end
      end
    end
  end

  # Column Headers
  band :column_headers do
    type :column_header

    table do
      columns ["120pt", fr(1), "80pt", "100pt", "100pt"]
      stroke "1pt"
      fill "#f5f5f5"

      header repeat: true do
        cell do
          label text: "Invoice #", style: [font_weight: :bold]
        end
        cell do
          label text: "Description", style: [font_weight: :bold]
        end
        cell align: :center do
          label text: "Qty", style: [font_weight: :bold]
        end
        cell align: :right do
          label text: "Unit Price", style: [font_weight: :bold]
        end
        cell align: :right do
          label text: "Amount", style: [font_weight: :bold]
        end
      end
    end
  end

  # Detail Band
  band :invoice_detail do
    type :detail

    table do
      columns ["120pt", fr(1), "80pt", "100pt", "100pt"]
      stroke "0.5pt"
      fill fn _x, y -> if rem(y, 2) == 0, do: "#fafafa" end

      row do
        cell do
          field source: :invoice_number
        end
        cell do
          field source: :description
        end
        cell align: :center do
          field source: :quantity
        end
        cell align: :right do
          field source: :unit_price, format: :currency
        end
        cell align: :right do
          field source: :line_total, format: :currency
        end
      end
    end
  end

  # Group Footer
  band :customer_footer do
    type :group_footer
    group_level 1

    table do
      columns ["120pt", fr(1), "80pt", "100pt", "100pt"]
      stroke :none

      row fill: "#f0f0f0" do
        cell colspan: 4, align: :right do
          label text: "Customer Total:", style: [font_weight: :bold]
        end
        cell align: :right do
          field source: :invoice_total, format: :currency, style: [font_weight: :bold]
        end
      end
    end
  end

  # Report Summary
  band :report_summary do
    type :summary

    stack dir: :ttb, spacing: "20pt" do
      # Summary statistics
      grid do
        columns [fr(1), fr(1), fr(1)]
        gutter "15pt"

        cell do
          stack dir: :ttb, spacing: "5pt" do
            label text: "Total Invoices", style: [font_size: 12, color: "#666"]
            field source: :record_count, style: [font_size: 24, font_weight: :bold]
          end
        end

        cell do
          stack dir: :ttb, spacing: "5pt" do
            label text: "Total Customers", style: [font_size: 12, color: "#666"]
            field source: :group_count, style: [font_size: 24, font_weight: :bold]
          end
        end

        cell do
          stack dir: :ttb, spacing: "5pt" do
            label text: "Grand Total", style: [font_size: 12, color: "#666"]
            field source: :grand_total, format: :currency,
                  style: [font_size: 24, font_weight: :bold, color: "#2e7d32"]
          end
        end
      end

      # Grand total table
      table do
        columns [fr(1), "150pt"]
        stroke "2pt"
        fill "#e8f5e9"
        inset "15pt"

        row do
          cell align: :right do
            label text: "GRAND TOTAL:", style: [font_size: 18, font_weight: :bold]
          end
          cell align: :right do
            field source: :grand_total, format: :currency,
                  style: [font_size: 18, font_weight: :bold]
          end
        end
      end
    end
  end
end
```

---

## 8. Renderer Integration Strategy

### 8.1 Multi-Format Rendering Architecture

The layout DSL needs to render to multiple formats, each with different capabilities:

```
DSL Definition
      │
      ▼
┌─────────────────┐
│  DSL Parser     │  (Spark.Dsl)
│  & Transformer  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Layout IR      │  (Intermediate Representation)
│  (Normalized)   │
└────────┬────────┘
         │
    ┌────┼────┬────────┐
    ▼    ▼    ▼        ▼
  Typst  HTML  JSON   HEEX
  Render Render Render Render
    │    │     │       │
    ▼    ▼     ▼       ▼
   PDF  HTML  JSON   LiveView
```

### 8.2 Intermediate Representation (IR)

The DSL transforms into a normalized IR that all renderers consume:

```elixir
defmodule AshReports.Layout.IR do
  @type t :: %__MODULE__{
    type: :grid | :table | :stack,
    properties: map(),
    children: [cell_ir() | row_ir() | content_ir()],
    lines: [line_ir()]
  }

  @type cell_ir :: %{
    type: :cell,
    position: {x :: integer(), y :: integer()},
    span: {colspan :: integer(), rowspan :: integer()},
    properties: map(),
    content: [content_ir()]
  }

  @type content_ir ::
    {:label, text :: String.t(), style :: map()} |
    {:field, source :: atom(), format :: atom(), style :: map()} |
    {:layout, t()}  # Nested layout
end
```

### 8.3 Typst Renderer

Generates `.typ` markup for PDF output:

```elixir
defmodule AshReports.Renderer.Typst do
  def render_layout(%{type: :grid} = layout, data) do
    """
    #grid(
      columns: #{render_columns(layout.properties.columns)},
      rows: #{render_rows(layout.properties.rows)},
      gutter: #{render_length(layout.properties.gutter)},
      align: #{render_align(layout.properties.align)},
      inset: #{render_length(layout.properties.inset)},
      fill: #{render_fill(layout.properties.fill)},
      stroke: #{render_stroke(layout.properties.stroke)},
      #{render_children(layout.children, data)}
    )
    """
  end

  def render_layout(%{type: :table} = layout, data) do
    """
    #table(
      columns: #{render_columns(layout.properties.columns)},
      rows: #{render_rows(layout.properties.rows)},
      gutter: #{render_length(layout.properties.gutter)},
      align: #{render_align(layout.properties.align)},
      inset: #{render_length(layout.properties.inset)},
      fill: #{render_fill(layout.properties.fill)},
      stroke: #{render_stroke(layout.properties.stroke)},
      #{render_header(layout, data)}
      #{render_children(layout.children, data)}
      #{render_footer(layout, data)}
    )
    """
  end

  def render_layout(%{type: :stack} = layout, data) do
    """
    #stack(
      dir: #{render_direction(layout.properties.dir)},
      spacing: #{render_length(layout.properties.spacing)},
      #{render_stack_children(layout.children, data)}
    )
    """
  end

  defp render_cell(cell, data) do
    props = [
      cell.span.colspan > 1 && "colspan: #{cell.span.colspan}",
      cell.span.rowspan > 1 && "rowspan: #{cell.span.rowspan}",
      cell.properties[:align] && "align: #{render_align(cell.properties.align)}",
      cell.properties[:fill] && "fill: #{render_color(cell.properties.fill)}",
      cell.properties[:inset] && "inset: #{render_length(cell.properties.inset)}"
    ] |> Enum.filter(& &1) |> Enum.join(", ")

    if props == "" do
      "[#{render_content(cell.content, data)}]"
    else
      "grid.cell(#{props})[#{render_content(cell.content, data)}]"
    end
  end

  defp render_content([{:label, text, style}], data) do
    interpolated = interpolate_variables(text, data)
    styled_text(interpolated, style)
  end

  defp render_content([{:field, source, format, style}], data) do
    value = get_field_value(data, source)
    formatted = format_value(value, format)
    styled_text(formatted, style)
  end
end
```

### 8.4 HTML Renderer

Generates HTML/CSS for web display:

```elixir
defmodule AshReports.Renderer.Html do
  def render_layout(%{type: :grid} = layout, data) do
    style = grid_css_style(layout.properties)

    ~E"""
    <div class="ash-grid" style="<%= style %>">
      <%= for child <- layout.children do %>
        <%= render_child(child, data) %>
      <% end %>
    </div>
    """
  end

  def render_layout(%{type: :table} = layout, data) do
    ~E"""
    <table class="ash-table" style="<%= table_css_style(layout.properties) %>">
      <%= if layout.header do %>
        <thead>
          <%= render_header_rows(layout.header, data) %>
        </thead>
      <% end %>
      <tbody>
        <%= for row <- layout.children do %>
          <%= render_table_row(row, data) %>
        <% end %>
      </tbody>
      <%= if layout.footer do %>
        <tfoot>
          <%= render_footer_rows(layout.footer, data) %>
        </tfoot>
      <% end %>
    </table>
    """
  end

  def render_layout(%{type: :stack} = layout, data) do
    direction = if layout.properties.dir in [:ltr, :rtl], do: "row", else: "column"

    ~E"""
    <div class="ash-stack" style="display: flex; flex-direction: <%= direction %>; gap: <%= layout.properties.spacing %>;">
      <%= for child <- layout.children do %>
        <%= render_child(child, data) %>
      <% end %>
    </div>
    """
  end

  defp grid_css_style(props) do
    """
    display: grid;
    grid-template-columns: #{columns_to_css(props.columns)};
    gap: #{props.gutter};
    align-items: #{align_to_css(props.align)};
    """
  end

  defp columns_to_css(columns) when is_list(columns) do
    Enum.map(columns, fn
      :auto -> "auto"
      {:fr, n} -> "#{n}fr"
      size when is_binary(size) -> size
    end)
    |> Enum.join(" ")
  end
end
```

### 8.5 JSON Renderer

For client-side rendering or API responses:

```elixir
defmodule AshReports.Renderer.Json do
  def render_layout(layout, data) do
    %{
      type: layout.type,
      properties: serialize_properties(layout.properties),
      children: Enum.map(layout.children, &render_child(&1, data))
    }
  end

  defp render_child(%{type: :cell} = cell, data) do
    %{
      type: :cell,
      position: %{x: elem(cell.position, 0), y: elem(cell.position, 1)},
      colspan: cell.span.colspan,
      rowspan: cell.span.rowspan,
      properties: serialize_properties(cell.properties),
      content: render_content(cell.content, data)
    }
  end
end
```

### 8.6 Conditional Fill Functions

Both Typst and HTML renderers need to handle conditional fill:

```elixir
# DSL definition with function-based fill
table do
  fill fn x, y ->
    cond do
      y == 0 -> "#e0e0e0"           # Header row
      rem(y, 2) == 0 -> "#fafafa"   # Even rows
      true -> "#ffffff"              # Odd rows
    end
  end
end

# Typst renderer generates Typst function syntax
defp render_fill({:fn, _, _} = func) do
  "(x, y) => {
    #{compile_fill_function(func)}
  }"
end

# HTML renderer applies styles per-cell
defp apply_cell_fill(cell, fill_fn, x, y) do
  color = fill_fn.(x, y)
  "background-color: #{color};"
end
```

### 8.7 Variable Interpolation

Handle `[variable_name]` substitution in labels:

```elixir
defmodule AshReports.Renderer.Interpolation do
  @variable_pattern ~r/\[([a-z_][a-z0-9_]*)\]/

  def interpolate(text, variables) do
    Regex.replace(@variable_pattern, text, fn _, var_name ->
      case Map.get(variables, String.to_atom(var_name)) do
        nil -> "[#{var_name}]"  # Keep original if not found
        value -> to_string(value)
      end
    end)
  end
end
```

---

## 9. Spark DSL Implementation

### 9.1 Section Definitions

```elixir
defmodule AshReports.Dsl.Layout do
  @grid_schema [
    columns: [
      type: {:or, [:integer, {:list, :any}]},
      required: true,
      doc: "Column track sizes"
    ],
    rows: [
      type: {:or, [:atom, :integer, {:list, :any}]},
      default: :auto,
      doc: "Row track sizes"
    ],
    gutter: [
      type: :string,
      default: "0pt",
      doc: "Gap between all cells"
    ],
    column_gutter: [
      type: :string,
      doc: "Gap between columns (overrides gutter)"
    ],
    row_gutter: [
      type: :string,
      doc: "Gap between rows (overrides gutter)"
    ],
    align: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      default: :left,
      doc: "Default cell alignment"
    ],
    inset: [
      type: :string,
      default: "0pt",
      doc: "Cell padding"
    ],
    fill: [
      type: {:or, [:string, :atom, {:fun, 2}]},
      doc: "Cell background"
    ],
    stroke: [
      type: {:or, [:string, :atom, {:list, :any}]},
      default: :none,
      doc: "Cell borders"
    ]
  ]

  @table_schema @grid_schema
  |> Keyword.put(:stroke, type: {:or, [:string, :atom, {:list, :any}]}, default: "1pt")
  |> Keyword.put(:inset, default: "5pt")

  @stack_schema [
    dir: [
      type: {:in, [:ttb, :btt, :ltr, :rtl]},
      default: :ttb,
      doc: "Stack direction"
    ],
    spacing: [
      type: :string,
      default: "0pt",
      doc: "Space between items"
    ]
  ]

  @cell_schema [
    colspan: [type: :pos_integer, default: 1],
    rowspan: [type: :pos_integer, default: 1],
    x: [type: :non_neg_integer],
    y: [type: :non_neg_integer],
    align: [type: {:or, [:atom, {:tuple, [:atom, :atom]}]}],
    fill: [type: {:or, [:string, :atom]}],
    stroke: [type: {:or, [:string, :atom, {:list, :any}]}],
    inset: [type: :string],
    breakable: [type: :boolean, default: true]
  ]

  @row_schema [
    height: [type: :string],
    fill: [type: {:or, [:string, :atom]}],
    stroke: [type: {:or, [:string, :atom, {:list, :any}]}],
    align: [type: {:or, [:atom, {:tuple, [:atom, :atom]}]}],
    inset: [type: :string]
  ]
end
```

### 9.2 Entity Definitions

```elixir
defmodule AshReports.Dsl.Sections do
  use Spark.Dsl.Extension

  @cell %Spark.Dsl.Entity{
    name: :cell,
    describe: "A cell within a grid, table, or row",
    schema: @cell_schema,
    entities: [
      labels: [@label_entity],
      fields: [@field_entity],
      layouts: [@grid_entity, @table_entity, @stack_entity]
    ]
  }

  @row %Spark.Dsl.Entity{
    name: :row,
    describe: "A row within a grid or table",
    schema: @row_schema,
    entities: [cells: [@cell]]
  }

  @header %Spark.Dsl.Entity{
    name: :header,
    describe: "Table header section",
    schema: [
      repeat: [type: :boolean, default: true],
      level: [type: :pos_integer, default: 1]
    ],
    entities: [cells: [@cell], rows: [@row]]
  }

  @footer %Spark.Dsl.Entity{
    name: :footer,
    describe: "Table footer section",
    schema: [repeat: [type: :boolean, default: true]],
    entities: [cells: [@cell], rows: [@row]]
  }

  @hline %Spark.Dsl.Entity{
    name: :hline,
    describe: "Horizontal line",
    schema: [
      y: [type: :non_neg_integer, required: true],
      start: [type: :non_neg_integer, default: 0],
      end_col: [type: :non_neg_integer],
      stroke: [type: :string, default: "1pt"],
      position: [type: {:in, [:top, :bottom]}, default: :bottom]
    ]
  }

  @vline %Spark.Dsl.Entity{
    name: :vline,
    describe: "Vertical line",
    schema: [
      x: [type: :non_neg_integer, required: true],
      start: [type: :non_neg_integer, default: 0],
      end_row: [type: :non_neg_integer],
      stroke: [type: :string, default: "1pt"],
      position: [type: {:in, [:left, :right]}, default: :right]
    ]
  }

  @grid %Spark.Dsl.Entity{
    name: :grid,
    describe: "Grid layout container",
    schema: @grid_schema,
    entities: [
      cells: [@cell],
      rows: [@row],
      hlines: [@hline],
      vlines: [@vline]
    ]
  }

  @table %Spark.Dsl.Entity{
    name: :table,
    describe: "Table layout container with semantic structure",
    schema: @table_schema,
    entities: [
      headers: [@header],
      cells: [@cell],
      rows: [@row],
      footers: [@footer],
      hlines: [@hline],
      vlines: [@vline]
    ]
  }

  @stack %Spark.Dsl.Entity{
    name: :stack,
    describe: "Stack layout container",
    schema: @stack_schema,
    entities: [
      cells: [@cell],
      grids: [@grid],
      tables: [@table],
      stacks: [@stack],
      labels: [@label_entity],
      fields: [@field_entity]
    ]
  }
end
```

---

## 10. Demo App Migration Plan

Since this is a greenfield implementation with no backward compatibility, all existing reports in the demo app must be rewritten using the new DSL. Below is the migration plan for each report.

### 10.1 Reports to Migrate

Based on the demo app's domain.ex, the following reports need to be rewritten:

| Report | Current Location | Migration Complexity |
|--------|-----------------|---------------------|
| `customer_summary` | `domain.ex` | Medium - Multiple groups, variables |
| `product_inventory` | `domain.ex` | Low - Simple tabular data |
| `invoice_details` | `domain.ex` | High - Line items, multiple groups |
| `financial_summary` | `domain.ex` | Medium - Aggregations, summary bands |

### 10.2 Migration Tasks

#### Phase 1: Core Infrastructure
1. Remove legacy `columns` string support from DSL
2. Remove `column` property from field/label entities
3. Implement new grid, table, stack, row, cell entities
4. Update DSL verifiers to require new layout syntax

#### Phase 2: Report Migrations

**Task: Migrate customer_summary report**
- Convert column headers to table with header section
- Convert detail band to table with row template
- Convert group headers/footers to grid layouts
- Update variable references to new field syntax

**Task: Migrate product_inventory report**
- Convert to simple table layout
- Add header section with repeat
- Style inventory levels with conditional fill

**Task: Migrate invoice_details report**
- Convert to nested table structure
- Handle line item grouping
- Add page-repeating headers
- Implement group totals in footers

**Task: Migrate financial_summary report**
- Convert summary statistics to grid layout
- Use stack for vertical arrangement
- Style totals with emphasis

#### Phase 3: Chart Integration
- Ensure charts work within new layout containers
- Test chart embedding in grid cells

### 10.3 Files Requiring Changes

**In ash_reports library:**
- `lib/ash_reports/dsl/*.ex` - New DSL entities
- `lib/ash_reports/renderer/*.ex` - Updated renderers
- Remove any legacy column support code

**In ash_reports_demo app:**
- `lib/ash_reports_demo/domain.ex` - All report definitions (~400 lines)
- `lib/ash_reports_demo_web/live/*.ex` - Report viewers if affected
- Tests for all migrated reports

### 10.4 Estimated Scope

| Component | Files | Estimated Changes |
|-----------|-------|-------------------|
| DSL Entities | 5-8 new files | ~1500 LOC |
| Transformers | 2-3 files | ~400 LOC |
| Renderers | 3-4 files | ~800 LOC |
| Demo Reports | 1 file (domain.ex) | ~600 LOC rewrite |
| Tests | 8-12 files | ~1000 LOC |

---

## 11. Summary

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Layout container location** | Inside bands | Bands define logical sections; layouts define physical arrangement |
| **Grid vs Table** | Both primitives | Grid for presentation, Table for data semantics (accessibility) |
| **Row as explicit entity** | Yes | Clearer DSL, enables row-level properties (height, fill) |
| **Cell flow** | Row-major default | Matches Typst behavior, explicit positioning optional |
| **Property types** | Match Typst closely | `fr()`, `auto()`, length strings minimize translation |
| **Conditional fill** | Function syntax | `fn x, y -> color end` for alternating rows, highlights |
| **Header/Footer repeat** | Boolean flag | Matches Typst `table.header(repeat: true)` |
| **No backward compatibility** | Clean slate | Greenfield project allows optimal DSL design without legacy constraints |

### New DSL Entities Summary

| Entity | Purpose | Key Properties |
|--------|---------|----------------|
| `grid` | 2D presentational layout | columns, rows, gutter, align, inset, fill, stroke |
| `table` | 2D semantic data layout | Same as grid + header, footer, default stroke |
| `stack` | 1D sequential layout | dir (:ttb/:ltr/etc), spacing |
| `row` | Explicit row container | height, fill, stroke, align, inset |
| `cell` | Individual cell | colspan, rowspan, x, y, align, fill, stroke, inset, breakable |
| `header` | Table header section | repeat, level |
| `footer` | Table footer section | repeat |
| `hline` | Horizontal line | y, start, end_col, stroke, position |
| `vline` | Vertical line | x, start, end_row, stroke, position |

### Implementation Roadmap

1. **Phase 1: Core DSL Entities**
   - Define Spark DSL sections and schemas
   - Implement grid, table, stack, row, cell entities
   - Add label and field simplifications

2. **Phase 2: Intermediate Representation**
   - Design IR data structures
   - Build transformers to convert DSL to IR
   - Handle cell positioning and spanning calculations

3. **Phase 3: Typst Renderer**
   - Generate Typst markup from IR
   - Implement all property translations
   - Handle variable interpolation and formatting

4. **Phase 4: HTML Renderer**
   - Generate CSS Grid/Flexbox from IR
   - Map Typst properties to CSS equivalents
   - Support conditional styling

5. **Phase 5: Demo App Migration**
   - Rewrite customer_summary report
   - Rewrite product_inventory report
   - Rewrite invoice_details report
   - Rewrite financial_summary report
   - Update all report tests

6. **Phase 6: Advanced Features**
   - Nested layouts
   - Function-based conditional styling
   - Page break handling
   - Accessibility attributes

---

## 12. Open Questions

1. **Should we support Typst's `place` for absolute positioning within cells?**
2. **How should we handle responsive layouts for HTML output?**
3. **Should conditional fill functions be pure Elixir or support a restricted DSL?**
4. **Do we need `box` and `block` primitives from Typst?**

---

## 13. References

- [Typst Grid Documentation](https://typst.app/docs/reference/layout/grid/)
- [Typst Table Documentation](https://typst.app/docs/reference/model/table/)
- [Typst Stack Documentation](https://typst.app/docs/reference/layout/stack/)
- [Spark DSL Documentation](https://hexdocs.pm/spark/Spark.Dsl.html)
