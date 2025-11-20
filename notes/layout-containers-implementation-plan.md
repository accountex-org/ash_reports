# Layout Containers Implementation Plan

## Overview

This document outlines the complete plan for adding row, grid, table, and stack layout containers to the AshReports DSL. These containers will map directly to Typst primitives, enabling flexible multi-row/column layouts within report bands.

## Motivation

Currently, AshReports bands support a flat list of elements that render in a single horizontal row (using Typst tables). Users need the ability to:
- Organize elements into multiple rows within a single band
- Create grid layouts with explicit column/row configurations
- Use semantic tables for tabular data
- Stack elements vertically or horizontally

## Typst Primitives

### grid()
Layout-focused container for presentational purposes.
```typst
#grid(
  columns: (1fr, 1fr, 1fr),
  rows: (auto, auto),
  gutter: 5pt,
  [Cell 1], [Cell 2], [Cell 3],
  [Cell 4], [Cell 5], [Cell 6]
)
```

### table()
Semantic container for tabular data with accessibility support.
```typst
#table(
  columns: (1fr, 2fr),
  stroke: 0.5pt,
  inset: 5pt,
  [Header 1], [Header 2],
  [Data 1], [Data 2]
)
```

### stack()
Simple directional stacking of elements.
```typst
#stack(
  dir: ttb,
  spacing: 5pt,
  [Element 1],
  [Element 2],
  [Element 3]
)
```

---

## Phase 1: Struct Modules

Create struct modules in `lib/ash_reports/layout/`:

### 1.1 Row (`lib/ash_reports/layout/row.ex`)

**Status: ✅ Completed**

```elixir
defmodule AshReports.Layout.Row do
  @type t :: %__MODULE__{
    name: atom(),
    spacing: String.t() | nil,
    elements: [map()]
  }

  defstruct [
    :name,
    spacing: "5pt",
    elements: []
  ]
end
```

### 1.2 Grid (`lib/ash_reports/layout/grid.ex`)

**Status: ✅ Completed**

```elixir
defmodule AshReports.Layout.Grid do
  @type t :: %__MODULE__{
    name: atom(),
    columns: pos_integer() | String.t() | [String.t()],
    rows: pos_integer() | String.t() | [String.t()] | nil,
    gutter: String.t() | nil,
    align: atom() | [atom()] | nil,
    elements: [map()]
  }

  defstruct [
    :name,
    columns: 1,
    rows: nil,
    gutter: "5pt",
    align: nil,
    elements: []
  ]
end
```

### 1.3 TableLayout (`lib/ash_reports/layout/table_layout.ex`)

**Status: ✅ Completed**

```elixir
defmodule AshReports.Layout.TableLayout do
  @type t :: %__MODULE__{
    name: atom(),
    columns: pos_integer() | String.t() | [String.t()],
    rows: pos_integer() | String.t() | [String.t()] | nil,
    stroke: String.t() | nil,
    inset: String.t() | nil,
    align: atom() | [atom()] | nil,
    elements: [map()]
  }

  defstruct [
    :name,
    columns: 1,
    rows: nil,
    stroke: "none",
    inset: "5pt",
    align: nil,
    elements: []
  ]
end
```

### 1.4 Stack (`lib/ash_reports/layout/stack.ex`)

**Status: ✅ Completed**

```elixir
defmodule AshReports.Layout.Stack do
  @type direction :: :vertical | :horizontal | :ttb | :btt | :ltr | :rtl

  @type t :: %__MODULE__{
    name: atom(),
    direction: direction(),
    spacing: String.t() | nil,
    elements: [map()]
  }

  defstruct [
    :name,
    direction: :vertical,
    spacing: "5pt",
    elements: []
  ]
end
```

---

## Phase 2: DSL Entity Definitions

Update `lib/ash_reports/dsl.ex` to add layout container entities.

### 2.1 Add Entity Functions

Insert after `sparkline_element_entity/0` (around line 445):

```elixir
# Layout container entities

defp row_entity do
  %Entity{
    name: :row,
    describe: "A row container for organizing elements horizontally.",
    target: AshReports.Layout.Row,
    args: [:name],
    schema: [
      name: [type: :atom, required: true, doc: "The row identifier."],
      spacing: [type: :string, default: "5pt", doc: "Spacing between elements."]
    ],
    entities: [
      elements: [
        label_element_entity(),
        field_element_entity(),
        expression_element_entity(),
        aggregate_element_entity()
      ]
    ]
  }
end

defp grid_entity do
  %Entity{
    name: :grid,
    describe: "A grid layout container that maps to Typst's grid() function.",
    target: AshReports.Layout.Grid,
    args: [:name],
    schema: [
      name: [type: :atom, required: true, doc: "The grid identifier."],
      columns: [
        type: {:or, [:pos_integer, :string, {:list, :string}]},
        default: 1,
        doc: "Column specification. Integer for equal columns, string for Typst spec, or list of widths."
      ],
      rows: [
        type: {:or, [:pos_integer, :string, {:list, :string}]},
        doc: "Row specification. Integer for count, string for Typst spec, or list of heights."
      ],
      gutter: [type: :string, default: "5pt", doc: "Gap between grid cells."],
      align: [type: {:or, [:atom, {:list, :atom}]}, doc: "Alignment for grid cells."]
    ],
    entities: [
      elements: [
        label_element_entity(),
        field_element_entity(),
        expression_element_entity(),
        aggregate_element_entity()
      ]
    ]
  }
end

defp table_layout_entity do
  %Entity{
    name: :table_layout,
    describe: "A table layout container that maps to Typst's table() function.",
    target: AshReports.Layout.TableLayout,
    args: [:name],
    schema: [
      name: [type: :atom, required: true, doc: "The table identifier."],
      columns: [
        type: {:or, [:pos_integer, :string, {:list, :string}]},
        default: 1,
        doc: "Column specification."
      ],
      rows: [
        type: {:or, [:pos_integer, :string, {:list, :string}]},
        doc: "Row specification."
      ],
      stroke: [type: :string, default: "none", doc: "Stroke style for table borders."],
      inset: [type: :string, default: "5pt", doc: "Cell padding/inset."],
      align: [type: {:or, [:atom, {:list, :atom}]}, doc: "Alignment for table cells."]
    ],
    entities: [
      elements: [
        label_element_entity(),
        field_element_entity(),
        expression_element_entity(),
        aggregate_element_entity()
      ]
    ]
  }
end

defp stack_entity do
  %Entity{
    name: :stack,
    describe: "A stack layout container that maps to Typst's stack() function.",
    target: AshReports.Layout.Stack,
    args: [:name],
    schema: [
      name: [type: :atom, required: true, doc: "The stack identifier."],
      direction: [
        type: :atom,
        default: :vertical,
        doc: "Stack direction: :vertical, :horizontal, :ttb, :btt, :ltr, :rtl"
      ],
      spacing: [type: :string, default: "5pt", doc: "Spacing between stacked elements."]
    ],
    entities: [
      elements: [
        label_element_entity(),
        field_element_entity(),
        expression_element_entity(),
        aggregate_element_entity()
      ]
    ]
  }
end
```

### 2.2 Update Band Entity

Modify the `band_entity/0` function to include layout containers:

```elixir
def band_entity do
  %Entity{
    name: :band,
    # ... existing properties ...
    entities: [
      elements: [
        label_element_entity(),
        field_element_entity(),
        expression_element_entity(),
        aggregate_element_entity(),
        line_element_entity(),
        box_element_entity(),
        image_element_entity(),
        bar_chart_element_entity(),
        line_chart_element_entity(),
        pie_chart_element_entity(),
        area_chart_element_entity(),
        scatter_chart_element_entity(),
        gantt_chart_element_entity(),
        sparkline_element_entity()
      ],
      # New layout containers
      rows: [row_entity()],
      grids: [grid_entity()],
      table_layouts: [table_layout_entity()],
      stacks: [stack_entity()]
    ],
    recursive_as: :bands
  }
end
```

---

## Phase 3: Typst Generator Updates

Update `lib/ash_reports/typst/dsl_generator.ex` to handle layout containers.

### 3.1 Add Layout Detection

Add a function to detect if a band has layout containers:

```elixir
defp has_layout_containers?(band) do
  has_rows = Map.get(band, :rows, []) != []
  has_grids = Map.get(band, :grids, []) != []
  has_table_layouts = Map.get(band, :table_layouts, []) != []
  has_stacks = Map.get(band, :stacks, []) != []

  has_rows or has_grids or has_table_layouts or has_stacks
end
```

### 3.2 Generate Row Layout

```elixir
defp generate_row(row, context) do
  elements = row.elements || []
  spacing = row.spacing || "5pt"

  cells = elements
  |> Enum.map(&generate_element(&1, context))
  |> Enum.join(", ")

  column_count = length(elements)

  """
  #grid(
    columns: (#{String.duplicate("1fr, ", column_count - 1)}1fr),
    gutter: #{spacing},
    #{cells}
  )
  """
end
```

### 3.3 Generate Grid Layout

```elixir
defp generate_grid_layout(grid, context) do
  elements = grid.elements || []
  columns = format_columns(grid.columns)
  gutter = grid.gutter || "5pt"

  cells = elements
  |> Enum.map(&generate_element(&1, context))
  |> Enum.join(", ")

  rows_spec = if grid.rows do
    "rows: #{format_rows(grid.rows)},"
  else
    ""
  end

  """
  #grid(
    columns: #{columns},
    #{rows_spec}
    gutter: #{gutter},
    #{cells}
  )
  """
end

defp format_columns(columns) when is_integer(columns) do
  "(#{String.duplicate("1fr, ", columns - 1)}1fr)"
end

defp format_columns(columns) when is_binary(columns), do: columns

defp format_columns(columns) when is_list(columns) do
  "(#{Enum.join(columns, ", ")})"
end

defp format_rows(rows) when is_integer(rows) do
  "(#{String.duplicate("auto, ", rows - 1)}auto)"
end

defp format_rows(rows) when is_binary(rows), do: rows

defp format_rows(rows) when is_list(rows) do
  "(#{Enum.join(rows, ", ")})"
end
```

### 3.4 Generate Table Layout

```elixir
defp generate_table_layout(table, context) do
  elements = table.elements || []
  columns = format_columns(table.columns)
  stroke = table.stroke || "none"
  inset = table.inset || "5pt"

  cells = elements
  |> Enum.map(&generate_element(&1, context))
  |> Enum.join(", ")

  """
  #table(
    columns: #{columns},
    stroke: #{stroke},
    inset: #{inset},
    #{cells}
  )
  """
end
```

### 3.5 Generate Stack Layout

```elixir
defp generate_stack_layout(stack, context) do
  elements = stack.elements || []
  spacing = stack.spacing || "5pt"

  direction = case stack.direction do
    :vertical -> "ttb"
    :horizontal -> "ltr"
    :ttb -> "ttb"
    :btt -> "btt"
    :ltr -> "ltr"
    :rtl -> "rtl"
    _ -> "ttb"
  end

  cells = elements
  |> Enum.map(&generate_element(&1, context))
  |> Enum.join(", ")

  """
  #stack(
    dir: #{direction},
    spacing: #{spacing},
    #{cells}
  )
  """
end
```

### 3.6 Update Band Generation

Modify the band generation function to handle layout containers:

```elixir
defp generate_band_content(band, context) do
  cond do
    # Check for rows first (most common use case)
    Map.get(band, :rows, []) != [] ->
      rows = band.rows
      rows
      |> Enum.map(&generate_row(&1, context))
      |> Enum.join("\n#v(5pt)\n")

    # Check for grids
    Map.get(band, :grids, []) != [] ->
      grids = band.grids
      grids
      |> Enum.map(&generate_grid_layout(&1, context))
      |> Enum.join("\n")

    # Check for table layouts
    Map.get(band, :table_layouts, []) != [] ->
      tables = band.table_layouts
      tables
      |> Enum.map(&generate_table_layout(&1, context))
      |> Enum.join("\n")

    # Check for stacks
    Map.get(band, :stacks, []) != [] ->
      stacks = band.stacks
      stacks
      |> Enum.map(&generate_stack_layout(&1, context))
      |> Enum.join("\n")

    # Default: flat elements (existing behavior)
    true ->
      generate_flat_elements(band, context)
  end
end
```

---

## Phase 4: DSL Usage Examples

### 4.1 Row Layout (Group Footer with Multiple Rows)

```elixir
band :group_footer do
  type :group_footer
  group_level(1)

  row :summary_row do
    label :count do
      text "Customers: [group_customer_count]"
    end

    label :credit do
      text "Total Credit: [group_total_credit_limit]"
    end

    label :health do
      text "Avg Health: [group_avg_health_score]"
    end
  end

  row :detail_row do
    label :active do
      text "Active: [group_active_count]"
    end

    label :inactive do
      text "Inactive: [group_inactive_count]"
    end
  end
end
```

### 4.2 Grid Layout (Metrics Dashboard)

```elixir
band :summary do
  type :summary

  grid :metrics do
    columns 3
    gutter "10pt"

    # Row 1 - Labels
    label :revenue_label do
      text "Revenue"
      style font_weight: :bold
    end

    label :costs_label do
      text "Costs"
      style font_weight: :bold
    end

    label :profit_label do
      text "Profit"
      style font_weight: :bold
    end

    # Row 2 - Values
    field :revenue do
      source :total_revenue
      format :currency
    end

    field :costs do
      source :total_costs
      format :currency
    end

    field :profit do
      source :net_profit
      format :currency
    end
  end
end
```

### 4.3 Table Layout (Data Table)

```elixir
band :detail do
  type :detail

  table_layout :invoice_items do
    columns "(2fr, 1fr, 1fr, 1fr)"
    stroke "0.5pt"
    inset "8pt"

    # Header row
    label :desc_header do
      text "Description"
      style font_weight: :bold
    end

    label :qty_header do
      text "Qty"
      style font_weight: :bold
    end

    label :price_header do
      text "Price"
      style font_weight: :bold
    end

    label :total_header do
      text "Total"
      style font_weight: :bold
    end

    # Data row (repeated for each record)
    field :description do
      source :line_description
    end

    field :quantity do
      source :quantity
      format :number
    end

    field :unit_price do
      source :unit_price
      format :currency
    end

    field :line_total do
      source :line_total
      format :currency
    end
  end
end
```

### 4.4 Stack Layout (Vertical Address)

```elixir
band :detail do
  type :detail

  stack :customer_address do
    direction :vertical
    spacing "2pt"

    label :name do
      text "[customer_name]"
      style font_weight: :bold
    end

    label :street do
      text "[street_address]"
    end

    label :city_state_zip do
      text "[city], [state] [zip]"
    end

    label :country do
      text "[country]"
    end
  end
end
```

---

## Phase 5: Testing Plan

### 5.1 Unit Tests

Create tests in `test/ash_reports/layout/`:

- `row_test.exs` - Test row struct creation and validation
- `grid_test.exs` - Test grid configuration options
- `table_layout_test.exs` - Test table layout options
- `stack_test.exs` - Test stack direction options

### 5.2 DSL Tests

Add tests to `test/ash_reports/dsl_test.exs`:

- Test that layout containers parse correctly
- Test that elements within containers are validated
- Test error handling for invalid configurations

### 5.3 Typst Generator Tests

Add tests to `test/ash_reports/typst/dsl_generator_test.exs`:

- Test row generation produces correct Typst grid syntax
- Test grid generation with various column configurations
- Test table layout generation with stroke/inset options
- Test stack generation with different directions

### 5.4 Integration Tests

Update `test/ash_reports_demo/` tests:

- Modify customer_summary report to use rows
- Generate PDF and verify visual output
- Test with different dataset sizes

---

## Phase 6: Demo Application Updates

### 6.1 Update Customer Summary Report

Modify `lib/ash_reports_demo/domain.ex` to demonstrate rows:

```elixir
band :group_footer do
  type :group_footer
  group_level(1)

  row :counts_row do
    label :group_count do
      text "Customers in [group_value]: [group_customer_count]"
    end
  end

  row :totals_row do
    label :credit_total do
      text "Total Credit Limit: [group_total_credit_limit]"
    end

    label :health_avg do
      text "Avg Health Score: [group_avg_health_score]"
    end
  end
end
```

### 6.2 Create New Demo Report

Consider creating a new report that showcases all layout options:

```elixir
report :layout_demo do
  title("Layout Containers Demo")
  driving_resource(AshReportsDemo.Customer)

  band :title do
    type :title

    grid :header_grid do
      columns 2

      label :title do
        text "Layout Demo Report"
        style font_size: 24, font_weight: :bold
      end

      label :date do
        text "Generated: [report_date]"
        align :right
      end
    end
  end

  # ... additional bands demonstrating each layout type
end
```

---

## Implementation Checklist

### Phase 1: Struct Modules
- [x] Create `lib/ash_reports/layout/row.ex`
- [x] Create `lib/ash_reports/layout/grid.ex`
- [x] Create `lib/ash_reports/layout/table_layout.ex`
- [x] Create `lib/ash_reports/layout/stack.ex`

### Phase 2: DSL Entities
- [ ] Add `row_entity/0` to `dsl.ex`
- [ ] Add `grid_entity/0` to `dsl.ex`
- [ ] Add `table_layout_entity/0` to `dsl.ex`
- [ ] Add `stack_entity/0` to `dsl.ex`
- [ ] Update `band_entity/0` to include layout containers

### Phase 3: Typst Generator
- [ ] Add `generate_row/2` function
- [ ] Add `generate_grid_layout/2` function
- [ ] Add `generate_table_layout/2` function
- [ ] Add `generate_stack_layout/2` function
- [ ] Update band generation to detect and handle containers
- [ ] Add helper functions for formatting columns/rows

### Phase 4: Testing
- [ ] Create unit tests for struct modules
- [ ] Add DSL parsing tests
- [ ] Add Typst generation tests
- [ ] Create integration tests

### Phase 5: Demo
- [ ] Update customer_summary with rows
- [ ] Verify PDF output
- [ ] Update documentation

---

## Future Enhancements

### Nested Layouts
Allow layout containers to nest within each other:

```elixir
grid :outer do
  columns 2

  stack :left_column do
    direction :vertical
    # elements...
  end

  grid :right_column do
    columns 2
    # elements...
  end
end
```

### Cell Spanning
Add colspan/rowspan support:

```elixir
grid :with_spans do
  columns 3

  label :header do
    text "Header"
    colspan 3
  end

  label :sidebar do
    text "Sidebar"
    rowspan 2
  end
end
```

### Conditional Layouts
Allow layouts to be conditionally rendered:

```elixir
row :conditional_row do
  conditional expr(total > 1000)

  label :warning do
    text "High value!"
  end
end
```

---

## References

- [Typst Grid Documentation](https://typst.app/docs/reference/layout/grid/)
- [Typst Table Documentation](https://typst.app/docs/reference/model/table/)
- [Typst Stack Documentation](https://typst.app/docs/reference/layout/stack/)
- [Spark DSL Documentation](https://hexdocs.pm/spark/Spark.html)
