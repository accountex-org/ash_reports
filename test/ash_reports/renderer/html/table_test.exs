defmodule AshReports.Renderer.Html.TableTest do
  use ExUnit.Case, async: true

  alias AshReports.Renderer.Html.Table
  alias AshReports.Layout.IR

  describe "render/2" do
    test "renders table with basic structure" do
      ir = IR.table(properties: %{columns: ["1fr", "1fr"]})
      result = Table.render(ir)

      assert String.contains?(result, ~s(<table class="ash-table"))
      assert String.contains?(result, "<tbody></tbody>")
      assert String.contains?(result, "</table>")
    end

    test "renders table with default styling" do
      ir = IR.table(properties: %{columns: ["1fr"]})
      result = Table.render(ir)

      assert String.contains?(result, "border-collapse: collapse")
      assert String.contains?(result, "width: 100%")
    end

    test "renders table with default stroke" do
      ir = IR.table(properties: %{columns: ["1fr"]})
      result = Table.render(ir)

      assert String.contains?(result, "border:")
    end

    test "renders table with custom stroke" do
      ir = IR.table(properties: %{
        columns: ["1fr"],
        stroke: "2px solid red"
      })
      result = Table.render(ir)

      assert String.contains?(result, "border: 2px solid red")
    end

    test "renders table with fill as background-color" do
      ir = IR.table(properties: %{
        columns: ["1fr"],
        fill: "#f0f0f0"
      })
      result = Table.render(ir)

      assert String.contains?(result, "background-color: #f0f0f0")
    end

    test "renders table with header" do
      header = %IR.Header{
        repeat: true,
        rows: [
          %IR.Row{
            cells: [
              IR.Cell.new(content: [%{text: "Header 1"}]),
              IR.Cell.new(content: [%{text: "Header 2"}])
            ]
          }
        ]
      }
      ir = IR.table(
        properties: %{columns: ["1fr", "1fr"]},
        headers: [header]
      )
      result = Table.render(ir)

      assert String.contains?(result, ~s(<thead class="ash-header">))
      assert String.contains?(result, "<th")
      assert String.contains?(result, "</thead>")
    end

    test "renders table with footer" do
      footer = %IR.Footer{
        repeat: false,
        rows: [
          %IR.Row{
            cells: [
              IR.Cell.new(content: [%{text: "Footer 1"}])
            ]
          }
        ]
      }
      ir = IR.table(
        properties: %{columns: ["1fr"]},
        footers: [footer]
      )
      result = Table.render(ir)

      assert String.contains?(result, ~s(<tfoot class="ash-footer">))
      assert String.contains?(result, "</tfoot>")
    end

    test "renders table with body rows" do
      row = %IR.Row{
        cells: [
          IR.Cell.new(content: [%{text: "Cell 1"}]),
          IR.Cell.new(content: [%{text: "Cell 2"}])
        ]
      }
      ir = IR.table(
        properties: %{columns: ["1fr", "1fr"]},
        children: [row]
      )
      result = Table.render(ir)

      assert String.contains?(result, "<tbody>")
      assert String.contains?(result, "<tr>")
      assert String.contains?(result, "<td")
      assert String.contains?(result, "</tbody>")
    end

    test "renders complete table with header, body, and footer" do
      header = %IR.Header{
        repeat: true,
        rows: [%IR.Row{cells: [IR.Cell.new(content: [%{text: "Header"}])]}]
      }
      footer = %IR.Footer{
        repeat: false,
        rows: [%IR.Row{cells: [IR.Cell.new(content: [%{text: "Footer"}])]}]
      }
      row = %IR.Row{cells: [IR.Cell.new(content: [%{text: "Data"}])]}

      ir = IR.table(
        properties: %{columns: ["1fr"]},
        headers: [header],
        children: [row],
        footers: [footer]
      )
      result = Table.render(ir)

      # Check order: thead, tbody, tfoot
      thead_pos = :binary.match(result, "<thead") |> elem(0)
      tbody_pos = :binary.match(result, "<tbody>") |> elem(0)
      tfoot_pos = :binary.match(result, "<tfoot") |> elem(0)

      assert thead_pos < tbody_pos
      assert tbody_pos < tfoot_pos

      # Check CSS classes
      assert String.contains?(result, ~s(<thead class="ash-header">))
      assert String.contains?(result, ~s(<tfoot class="ash-footer">))
    end
  end

  describe "apply_table_defaults/1" do
    test "adds default stroke if not present" do
      properties = %{columns: ["1fr"]}
      result = Table.apply_table_defaults(properties)

      assert Map.has_key?(result, :stroke)
    end

    test "preserves existing stroke" do
      properties = %{columns: ["1fr"], stroke: :none}
      result = Table.apply_table_defaults(properties)

      assert result.stroke == :none
    end
  end

  describe "render_stroke/1" do
    test "renders :none" do
      assert Table.render_stroke(:none) == "none"
    end

    test "renders nil as none" do
      assert Table.render_stroke(nil) == "none"
    end

    test "renders string stroke directly" do
      assert Table.render_stroke("1px solid black") == "1px solid black"
    end

    test "renders stroke map with thickness and paint" do
      stroke = %{thickness: "2pt", paint: "red"}
      result = Table.render_stroke(stroke)

      assert String.contains?(result, "2px")
      assert String.contains?(result, "solid")
      assert String.contains?(result, "red")
    end

    test "renders stroke map with dash" do
      stroke = %{thickness: "1pt", paint: "black", dash: "dashed"}
      result = Table.render_stroke(stroke)

      assert String.contains?(result, "dashed")
    end
  end

  describe "render_length/1" do
    test "converts pt to px" do
      assert Table.render_length("10pt") == "10px"
    end

    test "passes through px values" do
      assert Table.render_length("20px") == "20px"
    end

    test "renders numbers as pixels" do
      assert Table.render_length(15) == "15px"
    end
  end

  describe "render_color/1" do
    test "renders :none as transparent" do
      assert Table.render_color(:none) == "transparent"
    end

    test "renders hex colors" do
      assert Table.render_color("#ff0000") == "#ff0000"
    end

    test "renders named colors from atoms" do
      assert Table.render_color(:blue) == "blue"
    end
  end
end
