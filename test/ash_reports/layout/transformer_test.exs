defmodule AshReports.Layout.TransformerTest do
  @moduledoc """
  Tests for DSL to IR transformers.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.{Grid, Table, Stack, Row, GridCell, TableCell}
  alias AshReports.Layout.{Transformer, IR}
  alias AshReports.Element.{Label, Field}

  describe "Transformer.transform/1" do
    test "dispatches to Grid transformer for Grid struct" do
      grid = %Grid{name: :test_grid, columns: 3, rows: 2}
      assert {:ok, ir} = Transformer.transform(grid)
      assert ir.type == :grid
    end

    test "dispatches to Table transformer for Table struct" do
      table = %Table{name: :test_table, columns: 3, rows: 2}
      assert {:ok, ir} = Transformer.transform(table)
      assert ir.type == :table
    end

    test "dispatches to Stack transformer for Stack struct" do
      stack = %Stack{name: :test_stack, dir: :ttb}
      assert {:ok, ir} = Transformer.transform(stack)
      assert ir.type == :stack
    end

    test "handles map with type: :grid" do
      map = %{type: :grid, name: :test, columns: 2}
      assert {:ok, ir} = Transformer.transform(map)
      assert ir.type == :grid
    end

    test "handles map with type: :table" do
      map = %{type: :table, name: :test, columns: 2}
      assert {:ok, ir} = Transformer.transform(map)
      assert ir.type == :table
    end

    test "handles map with type: :stack" do
      map = %{type: :stack, name: :test, dir: :ttb}
      assert {:ok, ir} = Transformer.transform(map)
      assert ir.type == :stack
    end

    test "returns error for unsupported type" do
      assert {:error, {:unsupported_layout_type, _}} = Transformer.transform(%{unknown: true})
    end
  end

  describe "Grid Transformer" do
    alias AshReports.Layout.Transformer.Grid, as: GridTransformer

    test "transforms basic grid with integer columns" do
      grid = %Grid{name: :basic, columns: 3}
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert ir.type == :grid
      assert ir.properties.columns == ["auto", "auto", "auto"]
    end

    test "transforms grid with explicit column tracks" do
      grid = %Grid{name: :explicit, columns: ["1fr", "2fr", "100pt"]}
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert ir.properties.columns == ["1fr", "2fr", "100pt"]
    end

    test "transforms grid with integer rows" do
      grid = %Grid{name: :rows, columns: 2, rows: 3}
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert ir.properties.rows == ["auto", "auto", "auto"]
    end

    test "transforms grid with explicit row tracks" do
      grid = %Grid{name: :explicit_rows, columns: 2, rows: ["50pt", "1fr"]}
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert ir.properties.rows == ["50pt", "1fr"]
    end

    test "transforms grid with gutter" do
      grid = %Grid{name: :gutter, columns: 2, gutter: "10pt"}
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert ir.properties.gutter == "10pt"
    end

    test "transforms grid with column and row gutter" do
      grid = %Grid{name: :gutters, columns: 2, column_gutter: "5pt", row_gutter: "10pt"}
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert ir.properties.column_gutter == "5pt"
      assert ir.properties.row_gutter == "10pt"
      refute Map.has_key?(ir.properties, :gutter)
    end

    test "transforms grid with align" do
      grid = %Grid{name: :aligned, columns: 2, align: "center+horizon"}
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert ir.properties.align == "center+horizon"
    end

    test "transforms grid with fill and stroke" do
      grid = %Grid{name: :styled, columns: 2, fill: "blue", stroke: "1pt"}
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert ir.properties.fill == "blue"
      assert ir.properties.stroke == "1pt"
    end

    test "transforms grid with row entities" do
      grid = %Grid{
        name: :with_rows,
        columns: 2,
        row_entities: [
          %Row{elements: []}
        ]
      }
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert length(ir.children) == 1
      assert %IR.Row{} = hd(ir.children)
    end

    test "transforms grid with grid cells" do
      grid = %Grid{
        name: :with_cells,
        columns: 2,
        grid_cells: [
          %GridCell{x: 0, y: 0, elements: []}
        ]
      }
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert length(ir.children) == 1
      assert %IR.Cell{} = hd(ir.children)
    end

    test "transforms grid with elements" do
      grid = %Grid{
        name: :with_elements,
        columns: 2,
        elements: [
          %Label{text: "Hello"}
        ]
      }
      assert {:ok, ir} = GridTransformer.transform(grid)
      assert length(ir.children) == 1
      assert %IR.Cell{} = hd(ir.children)
      assert length(hd(ir.children).content) == 1
    end

    test "removes nil properties" do
      grid = %Grid{name: :minimal, columns: 2}
      assert {:ok, ir} = GridTransformer.transform(grid)
      refute Map.has_key?(ir.properties, :gutter)
      refute Map.has_key?(ir.properties, :fill)
      # stroke has a default of :none
      assert ir.properties.stroke == :none
    end
  end

  describe "Table Transformer" do
    alias AshReports.Layout.Transformer.Table, as: TableTransformer

    test "transforms basic table" do
      table = %Table{name: :basic, columns: 3}
      assert {:ok, ir} = TableTransformer.transform(table)
      assert ir.type == :table
      assert ir.properties.columns == ["auto", "auto", "auto"]
    end

    test "applies table default stroke" do
      table = %Table{name: :defaults, columns: 2}
      assert {:ok, ir} = TableTransformer.transform(table)
      assert ir.properties.stroke == "1pt"
    end

    test "applies table default inset" do
      table = %Table{name: :defaults, columns: 2}
      assert {:ok, ir} = TableTransformer.transform(table)
      assert ir.properties.inset == "5pt"
    end

    test "respects explicit stroke override" do
      table = %Table{name: :custom, columns: 2, stroke: "2pt"}
      assert {:ok, ir} = TableTransformer.transform(table)
      assert ir.properties.stroke == "2pt"
    end

    test "respects explicit inset override" do
      table = %Table{name: :custom, columns: 2, inset: "10pt"}
      assert {:ok, ir} = TableTransformer.transform(table)
      assert ir.properties.inset == "10pt"
    end

    test "transforms table with row entities" do
      table = %Table{
        name: :with_rows,
        columns: 2,
        row_entities: [
          %Row{elements: []}
        ]
      }
      assert {:ok, ir} = TableTransformer.transform(table)
      assert length(ir.children) == 1
    end

    test "transforms table with table cells" do
      table = %Table{
        name: :with_cells,
        columns: 2,
        table_cells: [
          %TableCell{x: 0, y: 0, elements: []}
        ]
      }
      assert {:ok, ir} = TableTransformer.transform(table)
      assert length(ir.children) == 1
    end

    test "transforms table with headers" do
      table = %Table{
        name: :with_headers,
        columns: 2,
        headers: [
          %{repeat: true, level: 0, elements: []}
        ]
      }
      assert {:ok, ir} = TableTransformer.transform(table)
      assert length(ir.headers) == 1
      assert %IR.Header{} = hd(ir.headers)
      assert hd(ir.headers).repeat == true
    end

    test "transforms table with footers" do
      table = %Table{
        name: :with_footers,
        columns: 2,
        footers: [
          %{repeat: false, elements: []}
        ]
      }
      assert {:ok, ir} = TableTransformer.transform(table)
      assert length(ir.footers) == 1
      assert %IR.Footer{} = hd(ir.footers)
      assert hd(ir.footers).repeat == false
    end

    test "transforms headers with rows" do
      table = %Table{
        name: :header_rows,
        columns: 2,
        headers: [
          %{
            repeat: true,
            elements: [
              %{elements: [%{text: "Header 1"}, %{text: "Header 2"}]}
            ]
          }
        ]
      }
      assert {:ok, ir} = TableTransformer.transform(table)
      assert length(ir.headers) == 1
      header = hd(ir.headers)
      assert length(header.rows) == 1
    end

    test "transforms headers with cells" do
      table = %Table{
        name: :header_cells,
        columns: 2,
        headers: [
          %{
            repeat: true,
            elements: [
              %{text: "Cell 1"}
            ]
          }
        ]
      }
      assert {:ok, ir} = TableTransformer.transform(table)
      assert length(ir.headers) == 1
      header = hd(ir.headers)
      assert length(header.rows) == 1
    end
  end

  describe "Stack Transformer" do
    alias AshReports.Layout.Transformer.Stack, as: StackTransformer

    test "transforms basic stack" do
      stack = %Stack{name: :basic, dir: :ttb}
      assert {:ok, ir} = StackTransformer.transform(stack)
      assert ir.type == :stack
      assert ir.properties.dir == :ttb
    end

    test "transforms stack with spacing" do
      stack = %Stack{name: :spaced, dir: :ltr, spacing: "10pt"}
      assert {:ok, ir} = StackTransformer.transform(stack)
      assert ir.properties.spacing == "10pt"
    end

    test "transforms stack with different directions" do
      for dir <- [:ttb, :ltr, :btt, :rtl] do
        stack = %Stack{name: :dir_test, dir: dir}
        assert {:ok, ir} = StackTransformer.transform(stack)
        assert ir.properties.dir == dir
      end
    end

    test "transforms stack with label elements" do
      stack = %Stack{
        name: :with_labels,
        dir: :ttb,
        elements: [
          %Label{text: "First"},
          %Label{text: "Second"}
        ]
      }
      assert {:ok, ir} = StackTransformer.transform(stack)
      assert length(ir.children) == 2
      assert Enum.all?(ir.children, &match?(%IR.Cell{}, &1))
    end

    test "transforms stack with field elements" do
      stack = %Stack{
        name: :with_fields,
        dir: :ttb,
        elements: [
          %Field{source: :name}
        ]
      }
      assert {:ok, ir} = StackTransformer.transform(stack)
      assert length(ir.children) == 1
    end

    test "transforms stack with nested grid" do
      stack = %Stack{
        name: :nested,
        dir: :ttb,
        elements: [
          %Grid{name: :inner, columns: 2}
        ]
      }
      assert {:ok, ir} = StackTransformer.transform(stack)
      assert length(ir.children) == 1
      cell = hd(ir.children)
      assert %IR.Cell{} = cell
      assert length(cell.content) == 1
      content = hd(cell.content)
      assert %IR.Content.NestedLayout{} = content
    end

    test "transforms stack with nested table" do
      stack = %Stack{
        name: :nested_table,
        dir: :ttb,
        elements: [
          %Table{name: :inner_table, columns: 3}
        ]
      }
      assert {:ok, ir} = StackTransformer.transform(stack)
      assert length(ir.children) == 1
    end

    test "transforms stack with nested stack" do
      stack = %Stack{
        name: :outer,
        dir: :ttb,
        elements: [
          %Stack{name: :inner, dir: :ltr, elements: []}
        ]
      }
      assert {:ok, ir} = StackTransformer.transform(stack)
      assert length(ir.children) == 1
    end

    test "removes nil properties" do
      stack = %Stack{name: :minimal, dir: :ttb}
      assert {:ok, ir} = StackTransformer.transform(stack)
      refute Map.has_key?(ir.properties, :spacing)
    end
  end

  describe "Cell Transformer" do
    alias AshReports.Layout.Transformer.Cell, as: CellTransformer

    test "transforms GridCell" do
      cell = %GridCell{x: 1, y: 2, elements: []}
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert %IR.Cell{} = ir
      assert ir.position == {1, 2}
    end

    test "transforms TableCell" do
      cell = %TableCell{x: 0, y: 0, elements: []}
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert %IR.Cell{} = ir
    end

    test "transforms cell with colspan and rowspan" do
      # Use map since GridCell struct doesn't have colspan/rowspan fields
      cell = %{x: 0, y: 0, colspan: 2, rowspan: 3, elements: []}
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert ir.span == {2, 3}
    end

    test "defaults span to {1, 1}" do
      cell = %GridCell{x: 0, y: 0, elements: []}
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert ir.span == {1, 1}
    end

    test "transforms cell with label content" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %Label{text: "Hello"}
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert length(ir.content) == 1
      content = hd(ir.content)
      assert %IR.Content.Label{} = content
      assert content.text == "Hello"
    end

    test "transforms cell with field content" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %Field{source: :name, format: :string}
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert length(ir.content) == 1
      content = hd(ir.content)
      assert %IR.Content.Field{} = content
      assert content.source == :name
      assert content.format == :string
    end

    test "transforms cell with multiple elements" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %Label{text: "Label"},
          %Field{source: :value}
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert length(ir.content) == 2
    end

    test "transforms cell properties" do
      cell = %GridCell{
        x: 0,
        y: 0,
        align: "center",
        inset: "5pt",
        fill: "gray",
        stroke: "1pt",
        elements: []
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert ir.properties.align == "center"
      assert ir.properties.inset == "5pt"
      assert ir.properties.fill == "gray"
      assert ir.properties.stroke == "1pt"
    end

    test "transforms label map elements" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %{text: "Map Label"}
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert length(ir.content) == 1
      assert %IR.Content.Label{} = hd(ir.content)
    end

    test "transforms field map elements" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %{source: :field_name}
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert length(ir.content) == 1
      assert %IR.Content.Field{} = hd(ir.content)
    end

    test "transforms nested layout in cell" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %{type: :grid, name: :nested, columns: 2}
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      assert length(ir.content) == 1
      assert %IR.Content.NestedLayout{} = hd(ir.content)
    end

    test "returns error for unknown element type" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %{unknown_key: "value"}
        ]
      }
      assert {:error, {:unknown_element_type, _}} = CellTransformer.transform(cell)
    end
  end

  describe "Row Transformer" do
    alias AshReports.Layout.Transformer.Row, as: RowTransformer

    test "transforms Row struct" do
      row = %Row{elements: []}
      assert {:ok, ir} = RowTransformer.transform(row, 0)
      assert %IR.Row{} = ir
      assert ir.index == 0
    end

    test "transforms row map" do
      row = %{elements: []}
      assert {:ok, ir} = RowTransformer.transform(row, 5)
      assert ir.index == 5
    end

    test "transforms row with cells" do
      row = %Row{
        elements: [
          %GridCell{x: 0, y: 0, elements: []},
          %GridCell{x: 1, y: 0, elements: []}
        ]
      }
      assert {:ok, ir} = RowTransformer.transform(row, 0)
      assert length(ir.cells) == 2
    end

    test "transforms row properties" do
      row = %Row{
        height: "50pt",
        fill: "lightgray",
        stroke: "0.5pt",
        align: "left",
        inset: "3pt",
        elements: []
      }
      assert {:ok, ir} = RowTransformer.transform(row, 0)
      assert ir.properties.height == "50pt"
      assert ir.properties.fill == "lightgray"
      assert ir.properties.stroke == "0.5pt"
      assert ir.properties.align == "left"
      assert ir.properties.inset == "3pt"
    end

    test "removes nil properties" do
      row = %Row{elements: []}
      assert {:ok, ir} = RowTransformer.transform(row, 0)
      assert ir.properties == %{}
    end
  end

  describe "Style transformation" do
    alias AshReports.Layout.Transformer.Cell, as: CellTransformer

    test "transforms label with style properties" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %Label{
            text: "Styled",
            style: %{
              font_weight: :bold,
              color: "red",
              font_family: "Arial"
            },
            align: "center"
          }
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      content = hd(ir.content)
      assert content.style != nil
      assert content.style.font_weight == :bold
      assert content.style.color == "red"
      assert content.style.font_family == "Arial"
      assert content.style.text_align == "center"
    end

    test "transforms field with style properties" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %Field{
            source: :amount,
            align: "right"
          }
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      content = hd(ir.content)
      assert content.style != nil
      assert content.style.text_align == "right"
    end

    test "returns nil style when no style properties" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %Label{text: "Plain"}
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      content = hd(ir.content)
      assert content.style == nil
    end

    test "transforms label with nested style map" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %Label{
            text: "Nested",
            style: %{font_size: "12pt", font_weight: :bold}
          }
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      content = hd(ir.content)
      assert content.style != nil
      assert content.style.font_size == "12pt"
      assert content.style.font_weight == :bold
    end
  end

  describe "Field format transformation" do
    alias AshReports.Layout.Transformer.Cell, as: CellTransformer

    test "preserves field format" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %Field{source: :price, format: :currency}
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      content = hd(ir.content)
      assert content.format == :currency
    end

    test "preserves field decimal_places" do
      cell = %GridCell{
        x: 0,
        y: 0,
        elements: [
          %Field{source: :rate, format: :number, decimal_places: 4}
        ]
      }
      assert {:ok, ir} = CellTransformer.transform(cell)
      content = hd(ir.content)
      assert content.decimal_places == 4
    end
  end

  describe "Pipeline Orchestration" do
    test "full pipeline transforms entity with positioning and resolution" do
      grid = %Grid{
        name: :pipeline_test,
        columns: 2,
        align: "center",
        inset: "5pt",
        row_entities: [
          %Row{
            elements: [
              %GridCell{x: nil, y: nil, elements: [%Label{text: "A"}]},
              %GridCell{x: nil, y: nil, elements: [%Label{text: "B"}]}
            ]
          }
        ]
      }

      assert {:ok, ir} = Transformer.transform(grid)
      assert ir.type == :grid

      # Check that rows are positioned
      [row] = ir.children
      assert %IR.Row{} = row

      # Check that cells within row have positions
      [cell1, cell2] = row.cells
      assert cell1.position == {0, 0}
      assert cell2.position == {1, 0}

      # Check property resolution occurred
      assert cell1.properties.align == "center"
      assert cell1.properties.inset == "5pt"
    end

    test "pipeline applies positioning to loose cells" do
      grid = %Grid{
        name: :loose_cells,
        columns: 3,
        grid_cells: [
          %GridCell{x: nil, y: nil, elements: [%Label{text: "1"}]},
          %GridCell{x: nil, y: nil, elements: [%Label{text: "2"}]},
          %GridCell{x: nil, y: nil, elements: [%Label{text: "3"}]},
          %GridCell{x: nil, y: nil, elements: [%Label{text: "4"}]}
        ]
      }

      assert {:ok, ir} = Transformer.transform(grid)

      # Should have 4 cells positioned in row-major order
      cells = ir.children
      assert length(cells) == 4

      positions = Enum.map(cells, & &1.position)
      assert {0, 0} in positions
      assert {1, 0} in positions
      assert {2, 0} in positions
      assert {0, 1} in positions
    end

    test "pipeline can skip positioning with option" do
      grid = %Grid{
        name: :no_position,
        columns: 2,
        grid_cells: [
          %GridCell{x: nil, y: nil, elements: [%Label{text: "A"}]}
        ]
      }

      assert {:ok, ir} = Transformer.transform(grid, position: false)

      # Cell should still have nil position
      [cell] = ir.children
      assert cell.position == {nil, nil}
    end

    test "pipeline can skip resolution with option" do
      grid = %Grid{
        name: :no_resolve,
        columns: 2,
        align: "center",
        grid_cells: [
          %GridCell{x: nil, y: nil, elements: [%Label{text: "A"}]}
        ]
      }

      assert {:ok, ir} = Transformer.transform(grid, resolve: false)

      # Cell properties should not have inherited align
      [cell] = ir.children
      refute Map.has_key?(cell.properties, :align)
    end

    test "pipeline handles table with headers and footers" do
      table = %Table{
        name: :full_table,
        columns: 2,
        headers: [
          %{repeat: true, elements: [%{text: "H1"}, %{text: "H2"}]}
        ],
        footers: [
          %{repeat: false, elements: [%{text: "F1"}, %{text: "F2"}]}
        ],
        row_entities: [
          %Row{elements: [
            %TableCell{x: nil, y: nil, elements: [%Label{text: "D1"}]},
            %TableCell{x: nil, y: nil, elements: [%Label{text: "D2"}]}
          ]}
        ]
      }

      assert {:ok, ir} = Transformer.transform(table)
      assert ir.type == :table
      assert length(ir.headers) == 1
      assert length(ir.footers) == 1
      assert length(ir.children) == 1
    end

    test "pipeline handles nested layouts" do
      stack = %Stack{
        name: :outer,
        dir: :ttb,
        elements: [
          %Grid{
            name: :inner,
            columns: 2,
            grid_cells: [
              %GridCell{x: nil, y: nil, elements: [%Label{text: "A"}]},
              %GridCell{x: nil, y: nil, elements: [%Label{text: "B"}]}
            ]
          }
        ]
      }

      assert {:ok, ir} = Transformer.transform(stack)
      assert ir.type == :stack
      assert length(ir.children) == 1
    end

    test "pipeline resolves properties through inheritance chain" do
      grid = %Grid{
        name: :inheritance,
        columns: 2,
        align: "left",
        fill: "white",
        row_entities: [
          %Row{
            fill: "gray",
            elements: [
              %GridCell{x: nil, y: nil, align: "right", elements: [%Label{text: "Cell"}]}
            ]
          }
        ]
      }

      assert {:ok, ir} = Transformer.transform(grid)
      [row] = ir.children
      [cell] = row.cells

      # Cell should have its own align (right), row's fill (gray), grid's inset (inherited default)
      assert cell.properties.align == "right"
      assert cell.properties.fill == "gray"
    end
  end

  describe "Band Integration" do
    test "transform_band_layout extracts and transforms layout from band" do
      band = %{
        layout: %Grid{name: :band_grid, columns: 3}
      }

      assert {:ok, ir} = Transformer.transform_band_layout(band)
      assert ir.type == :grid
      assert ir.properties.columns == ["auto", "auto", "auto"]
    end

    test "transform_band_layout handles band with table" do
      band = %{
        layout: %Table{name: :band_table, columns: 2}
      }

      assert {:ok, ir} = Transformer.transform_band_layout(band)
      assert ir.type == :table
    end

    test "transform_band_layout handles band with grid key fallback" do
      band = %{
        grid: %Grid{name: :fallback_grid, columns: 2}
      }

      assert {:ok, ir} = Transformer.transform_band_layout(band)
      assert ir.type == :grid
    end

    test "transform_band_layout handles band with table key fallback" do
      band = %{
        table: %Table{name: :fallback_table, columns: 3}
      }

      assert {:ok, ir} = Transformer.transform_band_layout(band)
      assert ir.type == :table
    end

    test "transform_band_layout returns error for band without layout" do
      band = %{name: :no_layout}

      assert {:error, {:no_layout_in_band, _}} = Transformer.transform_band_layout(band)
    end

    test "transform_band_layout applies full pipeline" do
      band = %{
        layout: %Grid{
          name: :full_pipeline_band,
          columns: 2,
          align: "center",
          grid_cells: [
            %GridCell{x: nil, y: nil, elements: [%Label{text: "A"}]},
            %GridCell{x: nil, y: nil, elements: [%Label{text: "B"}]}
          ]
        }
      }

      assert {:ok, ir} = Transformer.transform_band_layout(band)

      # Should have positioning applied
      [cell1, cell2] = ir.children
      assert cell1.position == {0, 0}
      assert cell2.position == {1, 0}

      # Should have resolution applied
      assert cell1.properties.align == "center"
    end
  end

  describe "Error Handling" do
    test "returns error for unsupported entity type" do
      assert {:error, {:unsupported_layout_type, _}} = Transformer.transform(%{invalid: true})
    end

    test "handles nil layout in band" do
      band = %{layout: nil, name: :nil_layout}

      assert {:error, {:no_layout_in_band, _}} = Transformer.transform_band_layout(band)
    end
  end
end
