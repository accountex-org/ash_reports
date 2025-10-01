defmodule AshReports.TypstMockData do
  @moduledoc """
  Mock data generators for Typst testing using StreamData.

  Provides property-based testing data generators for:
  - Report templates with varying complexity
  - Table data with configurable rows/columns
  - Nested structures and hierarchical content
  - Edge cases (empty data, special characters, etc.)

  ## Usage

      import AshReports.TypstMockData

      test "handles various table sizes" do
        check all table_data <- table_generator(rows: 1..100, cols: 1..10) do
          template = generate_table_template(table_data)
          assert {:ok, _pdf} = compile_and_validate(template)
        end
      end
  """

  import StreamData

  @doc """
  Generates report template strings with varying complexity.

  ## Options

  - `:sections` - Range for number of sections (default: 1..10)
  - `:paragraphs_per_section` - Range for paragraphs (default: 1..5)
  - `:include_tables` - Whether to include tables (default: true)

  ## Examples

      iex> gen = report_template_generator()
      iex> template = Enum.take(gen, 1) |> List.first()
      iex> is_binary(template)
      true
  """
  def report_template_generator(opts \\ []) do
    sections_range = Keyword.get(opts, :sections, 1..10)
    paragraphs_range = Keyword.get(opts, :paragraphs_per_section, 1..5)
    _include_tables? = Keyword.get(opts, :include_tables, true)

    # Generate template directly without complex nesting
    map(
      tuple({integer(sections_range), integer(paragraphs_range)}),
      fn {num_sections, num_paragraphs} ->
        sections =
          for i <- 1..num_sections do
            paragraphs =
              for _j <- 1..num_paragraphs do
                paragraph_generator()
              end

            """
            == Section #{i}

            #{Enum.join(paragraphs, "\n\n")}
            """
          end

        """
        #set page(paper: "a4")
        #set text(font: "Liberation Sans")

        = Test Report

        #{Enum.join(sections, "\n\n")}
        """
      end
    )
  end

  @doc """
  Generates table data with configurable dimensions.

  Returns a map with:
  - `:headers` - List of column headers
  - `:rows` - List of rows (each row is a list of cells)

  ## Options

  - `:rows` - Range or fixed number of rows (default: 1..20)
  - `:cols` - Range or fixed number of columns (default: 2..6)

  ## Examples

      iex> gen = table_generator(rows: 5, cols: 3)
      iex> data = Enum.take(gen, 1) |> List.first()
      iex> length(data.headers)
      3
      iex> length(data.rows)
      5
  """
  def table_generator(opts \\ []) do
    rows_spec = Keyword.get(opts, :rows, 1..20)
    cols_spec = Keyword.get(opts, :cols, 2..6)

    rows = normalize_spec(rows_spec)
    cols = normalize_spec(cols_spec)

    bind(tuple({rows, cols}), fn {num_rows, num_cols} ->
      headers =
        for i <- 1..num_cols do
          "Column #{i}"
        end

      rows =
        for _i <- 1..num_rows do
          for _j <- 1..num_cols do
            cell_value_generator()
          end
        end

      constant(%{headers: headers, rows: rows})
    end)
  end

  @doc """
  Generates edge case data for testing robustness.

  Includes:
  - Empty strings
  - Very long strings
  - Special characters
  - Unicode content
  - Null/nil values

  ## Examples

      iex> gen = edge_case_generator()
      iex> value = Enum.take(gen, 1) |> List.first()
      iex> is_binary(value) or is_nil(value)
      true
  """
  def edge_case_generator do
    one_of([
      constant(""),
      # Empty string
      constant(String.duplicate("x", 1000)),
      # Very long string
      constant("Special: <>&\"'"),
      # Special characters
      constant("Unicode: 你好世界 ñ ü ö"),
      # Unicode
      constant(nil),
      # Nil value
      constant("Line\nBreak\nTest"),
      # Newlines
      constant("\t\tTabs\t\tTest\t\t"),
      # Tabs
      constant("   Leading/Trailing Spaces   ")
      # Spaces
    ])
  end

  @doc """
  Generates nested structure data for hierarchical reports.

  Returns data representing:
  - Categories with subcategories
  - Groups with items
  - Hierarchical relationships

  ## Examples

      iex> gen = nested_structure_generator(depth: 2)
      iex> structure = Enum.take(gen, 1) |> List.first()
      iex> is_map(structure)
      true
  """
  def nested_structure_generator(opts \\ []) do
    max_depth = Keyword.get(opts, :depth, 3)
    items_per_level = Keyword.get(opts, :items_per_level, 1..5)

    nested_structure_helper(max_depth, items_per_level, 0)
  end

  @doc """
  Generates a complete Typst table template string from table data.

  ## Examples

      iex> data = %{headers: ["A", "B"], rows: [["1", "2"], ["3", "4"]]}
      iex> template = generate_table_template(data)
      iex> template =~ "#table"
      true
  """
  def generate_table_template(table_data) do
    headers_str = table_data.headers |> Enum.map_join(", ", &"[#{&1}]")

    rows_str =
      table_data.rows
      |> Enum.map(fn row ->
        row |> Enum.map_join(", ", &"[#{&1}]")
      end)
      |> Enum.join(",\n  ")

    """
    #table(
      columns: #{length(table_data.headers)},
      #{headers_str},
      #{rows_str}
    )
    """
  end

  @doc """
  Generates a complete mock report with all data filled in.

  ## Options

  - `:sections` - Number of sections
  - `:tables` - Number of tables
  - `:complexity` - :simple | :medium | :complex

  ## Examples

      iex> report = generate_mock_report(complexity: :simple)
      iex> is_binary(report)
      true
  """
  def generate_mock_report(opts \\ []) do
    complexity = Keyword.get(opts, :complexity, :simple)

    case complexity do
      :simple ->
        """
        #set page(paper: "a4")
        = Simple Test Report

        This is a simple test report with minimal content.

        == Section 1
        #{generate_lorem_paragraph()}

        == Section 2
        #{generate_lorem_paragraph()}
        """

      :medium ->
        table_data = %{
          headers: ["Product", "Quantity", "Price"],
          rows: [
            ["Widget A", "10", "\\$50.00"],
            ["Widget B", "25", "\\$75.00"],
            ["Widget C", "15", "\\$100.00"]
          ]
        }

        """
        #set page(paper: "a4")
        #set text(font: "Liberation Sans")

        = Medium Complexity Report

        == Summary
        #{generate_lorem_paragraph()}

        == Data Table
        #{generate_table_template(table_data)}

        == Analysis
        #{generate_lorem_paragraph()}
        #{generate_lorem_paragraph()}
        """

      :complex ->
        """
        #set page(paper: "a4", margin: 2cm)
        #set text(font: "Liberation Sans", size: 11pt)
        #set heading(numbering: "1.1")

        = Complex Multi-Section Report
        #outline()

        == Chapter 1: Introduction
        #{generate_lorem_paragraph()}

        === Section 1.1
        #{generate_lorem_paragraph()}

        === Section 1.2
        #{generate_lorem_paragraph()}

        #{generate_table_template(%{headers: ["A", "B", "C"], rows: [["1", "2", "3"], ["4", "5", "6"]]})}

        == Chapter 2: Data Analysis
        #{generate_lorem_paragraph()}

        === Section 2.1
        #{generate_lorem_paragraph()}

        === Section 2.2
        #{generate_lorem_paragraph()}

        #pagebreak()

        == Chapter 3: Conclusion
        #{generate_lorem_paragraph()}
        """
    end
  end

  # Private helpers

  defp paragraph_generator do
    sentences = :rand.uniform(5) + 2

    words = [
      "lorem",
      "ipsum",
      "dolor",
      "sit",
      "amet",
      "consectetur",
      "adipiscing",
      "elit"
    ]

    1..sentences
    |> Enum.map(fn _ ->
      sentence_length = :rand.uniform(10) + 5

      sentence =
        1..sentence_length
        |> Enum.map(fn _ -> Enum.random(words) end)
        |> Enum.join(" ")

      String.capitalize(sentence) <> "."
    end)
    |> Enum.join(" ")
  end

  defp simple_table_generator do
    rows = :rand.uniform(5) + 2
    cols = :rand.uniform(4) + 2

    headers = for i <- 1..cols, do: "Col#{i}"

    data =
      for _i <- 1..rows do
        for _j <- 1..cols do
          "Data#{:rand.uniform(100)}"
        end
      end

    generate_table_template(%{headers: headers, rows: data})
  end

  defp cell_value_generator do
    types = [:string, :number, :currency, :date]
    type = Enum.random(types)

    case type do
      :string -> "Item#{:rand.uniform(1000)}"
      :number -> "#{:rand.uniform(10000)}"
      :currency -> "$#{:rand.uniform(1000)}.#{:rand.uniform(99)}"
      :date -> "2024-#{:rand.uniform(12)}-#{:rand.uniform(28)}"
    end
  end

  defp nested_structure_helper(max_depth, items_range, current_depth)
       when current_depth >= max_depth do
    constant(%{
      name: "Leaf#{:rand.uniform(100)}",
      value: :rand.uniform(1000),
      children: []
    })
  end

  defp nested_structure_helper(max_depth, items_range, current_depth) do
    num_items = normalize_value(items_range)

    # Create list of child generators and convert to tuple
    child_generators =
      for _i <- 1..num_items do
        nested_structure_helper(max_depth, items_range, current_depth + 1)
      end
      |> List.to_tuple()

    # Use bind to resolve all children before creating the parent
    bind(tuple(child_generators), fn children_tuple ->
      children = Tuple.to_list(children_tuple)

      constant(%{
        name: "Node#{current_depth}_#{:rand.uniform(100)}",
        value: :rand.uniform(1000),
        children: children
      })
    end)
  end

  defp normalize_spec(range) when is_struct(range, Range) do
    integer(range)
  end

  defp normalize_spec(n) when is_integer(n) do
    constant(n)
  end

  defp normalize_value(range) when is_struct(range, Range) do
    Enum.random(range)
  end

  defp normalize_value(n) when is_integer(n), do: n

  defp generate_lorem_paragraph do
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris."
  end
end
