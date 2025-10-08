defmodule AshReports.RendererTestHelpers do
  @moduledoc """
  Test helpers for renderer testing.

  Provides utilities for building RenderContext, creating mocks,
  and asserting on rendered output across different formats (HTML, PDF, JSON).
  """

  import ExUnit.Assertions

  alias AshReports.RenderContext

  @doc """
  Builds a minimal valid RenderContext for testing renderers.

  ## Options

  - `:report` - Report definition (default: mock report)
  - `:records` - Data records (default: empty list)
  - `:data_result` - Data result map (default: empty map)
  - `:metadata` - Metadata map (default: empty map)
  - `:config` - Configuration options (default: empty map)
  - `:locale` - Locale string (default: "en")
  - `:variables` - Variables map (default: empty map)

  ## Examples

      context = build_render_context(
        report: my_report,
        records: my_data,
        metadata: %{format: :pdf}
      )
  """
  def build_render_context(opts \\ []) do
    report = Keyword.get(opts, :report, build_mock_report())
    records = Keyword.get(opts, :records, [])
    data_result = Keyword.get(opts, :data_result, %{})
    metadata = Keyword.get(opts, :metadata, %{})
    config = Keyword.get(opts, :config, %{})
    locale = Keyword.get(opts, :locale, "en")
    variables = Keyword.get(opts, :variables, %{})

    # Build layout_state from report bands
    layout_state = build_mock_layout_state(report)

    %RenderContext{
      report: report,
      records: records,
      data_result: data_result,
      metadata: metadata,
      config: config,
      locale: locale,
      variables: variables,
      text_direction: "ltr",
      layout_state: layout_state
    }
  end

  @doc """
  Builds a mock report definition for testing.

  ## Options

  - `:name` - Report name (default: :test_report)
  - `:title` - Report title (default: "Test Report")
  - `:resource` - Driving resource (default: nil)
  - `:bands` - List of bands (default: simple band list)
  - `:parameters` - List of parameters (default: [])
  - `:variables` - List of variables (default: [])

  ## Examples

      report = build_mock_report(name: :sales_report, title: "Sales Report")
  """
  def build_mock_report(opts \\ []) do
    name = Keyword.get(opts, :name, :test_report)
    title = Keyword.get(opts, :title, "Test Report")
    resource = Keyword.get(opts, :resource)
    bands = Keyword.get(opts, :bands, build_mock_bands())
    parameters = Keyword.get(opts, :parameters, [])
    variables = Keyword.get(opts, :variables, [])

    %{
      name: name,
      title: title,
      driving_resource: resource,
      bands: bands,
      parameters: parameters,
      variables: variables,
      groups: [],
      page_size: :a4,
      orientation: :portrait,
      margins: %{top: 20, bottom: 20, left: 20, right: 20}
    }
  end

  @doc """
  Builds mock band definitions for testing.

  Returns a list of basic band structures covering common band types.
  """
  def build_mock_bands do
    [
      %{
        name: :report_header,
        type: :report_header,
        height: 50,
        elements: [
          %{type: :label, name: :title, text: "Test Report", position: %{x: 0, y: 0}}
        ]
      },
      %{
        name: :detail,
        type: :detail,
        height: 30,
        elements: [
          %{type: :field, name: :field1, source: :name, position: %{x: 0, y: 0}}
        ]
      },
      %{
        name: :report_footer,
        type: :report_footer,
        height: 30,
        elements: [
          %{type: :label, name: :footer, text: "End of Report", position: %{x: 0, y: 0}}
        ]
      }
    ]
  end

  @doc """
  Builds mock layout_state from report bands for testing.

  Creates a layout_state structure with band layouts for CSS generation
  and element positioning.
  """
  def build_mock_layout_state(report) do
    bands =
      report.bands
      |> Enum.with_index()
      |> Enum.map(fn {band, index} ->
        {band.name,
         %{
           dimensions: %{width: 800, height: Map.get(band, :height, 50)},
           position: %{x: 0, y: index * 50},
           elements:
             Enum.map(Map.get(band, :elements, []), fn element ->
               %{
                 element: element,
                 position: Map.get(element, :position, %{x: 0, y: 0}),
                 dimensions: %{width: 100, height: 20}
               }
             end)
         }}
      end)
      |> Enum.into(%{})

    %{bands: bands}
  end

  @doc """
  Builds mock data for testing renderers.

  ## Options

  - `:count` - Number of records (default: 10)
  - `:fields` - Map of field names to generators (default: basic fields)

  ## Examples

      data = build_mock_data(count: 5, fields: %{
        name: fn i -> "Item \#{i}" end,
        value: fn i -> i * 10 end
      })
  """
  def build_mock_data(opts \\ []) do
    count = Keyword.get(opts, :count, 10)
    fields = Keyword.get(opts, :fields, %{
      id: fn i -> i end,
      name: fn i -> "Record #{i}" end,
      value: fn i -> i * 100 end
    })

    Enum.map(1..count, fn i ->
      Enum.into(fields, %{}, fn {field, generator} ->
        {field, generator.(i)}
      end)
    end)
  end

  # HTML Renderer Test Helpers

  @doc """
  Asserts that HTML output contains expected structure.

  ## Examples

      assert_html_structure(html,
        has_tag: "table",
        has_class: "report-table",
        has_content: "Test Report"
      )
  """
  def assert_html_structure(html, assertions \\ []) do
    Enum.each(assertions, fn
      {:has_tag, tag} ->
        assert html =~ ~r/<#{tag}[^>]*>/, "Expected HTML to contain <#{tag}> tag"

      {:has_class, class} ->
        assert html =~ ~r/class="[^"]*#{class}[^"]*"/, "Expected HTML to contain class '#{class}'"

      {:has_id, id} ->
        assert html =~ ~r/id="#{id}"/, "Expected HTML to contain id '#{id}'"

      {:has_content, content} ->
        assert html =~ content, "Expected HTML to contain '#{content}'"

      {:has_attribute, {tag, attr, value}} ->
        assert html =~ ~r/<#{tag}[^>]*#{attr}="#{value}"[^>]*>/,
               "Expected <#{tag}> to have #{attr}='#{value}'"
    end)
  end

  @doc """
  Extracts text content from HTML, stripping tags.

  ## Examples

      text = extract_html_text(html)
      assert text =~ "Test Report"
  """
  def extract_html_text(html) do
    html
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  @doc """
  Asserts that HTML is valid (well-formed).

  Checks for balanced tags and basic HTML structure.
  """
  def assert_valid_html(html) do
    # Basic checks for well-formed HTML
    assert String.starts_with?(String.trim(html), "<"), "HTML should start with a tag"

    # Check for balanced <html>, <head>, <body> if present
    if html =~ ~r/<html[^>]*>/ do
      assert html =~ ~r/<\/html>/, "Expected closing </html> tag"
    end

    if html =~ ~r/<head[^>]*>/ do
      assert html =~ ~r/<\/head>/, "Expected closing </head> tag"
    end

    if html =~ ~r/<body[^>]*>/ do
      assert html =~ ~r/<\/body>/, "Expected closing </body> tag"
    end

    :ok
  end

  # PDF Renderer Test Helpers (Typst-based)

  @doc """
  Creates a stub for Typst compiler to avoid actual PDF generation in tests.

  Returns a mock PDF binary for testing. In the real implementation,
  Typst compiles .typ files to PDF.
  """
  def stub_typst_pdf do
    # Mock PDF header (simplified)
    "%PDF-1.7\n%Mock Typst-generated PDF for testing\n%%EOF"
  end

  @doc """
  Creates mock Typst template content for testing.

  ## Examples

      typst_template = stub_typst_template()
      assert typst_template =~ "#set page"
  """
  def stub_typst_template do
    """
    #set page(paper: "a4", margin: 2cm)
    #set text(font: "New Computer Modern", size: 11pt)

    = Test Report

    #table(
      columns: 2,
      [Name], [Value],
      [Record 1], [100],
      [Record 2], [200]
    )
    """
  end

  @doc """
  Asserts that binary data appears to be a valid PDF.

  Checks for PDF header and basic structure.
  """
  def assert_valid_pdf(pdf_binary) when is_binary(pdf_binary) do
    assert String.starts_with?(pdf_binary, "%PDF-"),
           "Expected PDF to start with %PDF- header"

    assert String.contains?(pdf_binary, "%%EOF"),
           "Expected PDF to contain %%EOF marker"

    :ok
  end

  @doc """
  Extracts metadata from PDF binary (simplified for testing).

  Returns a map with basic PDF information.
  """
  def extract_pdf_metadata(pdf_binary) when is_binary(pdf_binary) do
    # This is a simplified extraction for testing
    # Real implementation would use a PDF parsing library
    %{
      has_header: String.starts_with?(pdf_binary, "%PDF-"),
      has_eof: String.contains?(pdf_binary, "%%EOF"),
      size_bytes: byte_size(pdf_binary)
    }
  end

  @doc """
  Asserts that Typst template content is valid.

  Checks for basic Typst syntax elements.

  ## Examples

      assert_valid_typst_template(template)
  """
  def assert_valid_typst_template(typst_content) when is_binary(typst_content) do
    # Basic Typst syntax checks
    assert typst_content =~ ~r/#(set|show|let|import|include)/,
           "Expected Typst template to contain Typst directives (#set, #show, etc.)"

    :ok
  end

  @doc """
  Asserts that Typst template contains expected report elements.

  ## Examples

      assert_typst_has_elements(template,
        has_table: true,
        has_heading: true,
        has_image: true
      )
  """
  def assert_typst_has_elements(typst_content, checks \\ []) when is_binary(typst_content) do
    Enum.each(checks, fn
      {:has_table, true} ->
        assert typst_content =~ ~r/#table\(/, "Expected Typst template to contain #table"

      {:has_heading, true} ->
        assert typst_content =~ ~r/^=/m, "Expected Typst template to contain headings (=)"

      {:has_image, true} ->
        assert typst_content =~ ~r/#image\(/, "Expected Typst template to contain #image"

      {:has_page_break, true} ->
        assert typst_content =~ ~r/#pagebreak\(\)/, "Expected Typst template to contain #pagebreak()"

      {:has_chart, true} ->
        assert typst_content =~ ~r/#image\(.*(svg|png)/,
               "Expected Typst template to contain embedded chart image"
    end)

    :ok
  end

  @doc """
  Creates a mock Typst compiler that returns a PDF without actually compiling.

  ## Examples

      compiler = mock_typst_compiler()
      {:ok, pdf} = compiler.compile(typst_template)
  """
  def mock_typst_compiler do
    %{
      compile: fn _template -> {:ok, stub_typst_pdf()} end,
      compile_to_file: fn _template, _output_path -> {:ok, "/tmp/mock.pdf"} end
    }
  end

  # JSON Renderer Test Helpers

  @doc """
  Asserts that JSON output has expected structure.

  ## Examples

      assert_json_structure(json_string,
        has_key: "report",
        has_nested: ["data", "records"],
        has_value: {"format", "json"}
      )
  """
  def assert_json_structure(json_string, assertions \\ []) when is_binary(json_string) do
    {:ok, json} = Jason.decode(json_string)

    Enum.each(assertions, fn
      {:has_key, key} ->
        assert Map.has_key?(json, key), "Expected JSON to have key '#{key}'"

      {:has_nested, path} when is_list(path) ->
        assert get_in(json, path) != nil, "Expected JSON to have nested path #{inspect(path)}"

      {:has_value, {key, value}} ->
        assert Map.get(json, key) == value,
               "Expected JSON key '#{key}' to equal #{inspect(value)}, got #{inspect(Map.get(json, key))}"

      {:array_length, {key, length}} ->
        array = Map.get(json, key)
        assert is_list(array) && Enum.count(array) == length,
               "Expected JSON key '#{key}' to be array of length #{length}"
    end)
  end

  @doc """
  Asserts that JSON conforms to a schema.

  Checks for required keys and types.

  ## Examples

      assert_json_schema(json_string,
        required_keys: ["report", "data", "metadata"],
        types: %{"data" => :list, "metadata" => :map}
      )
  """
  def assert_json_schema(json_string, schema \\ []) when is_binary(json_string) do
    {:ok, json} = Jason.decode(json_string)

    required_keys = Keyword.get(schema, :required_keys, [])
    types = Keyword.get(schema, :types, %{})

    # Check required keys
    Enum.each(required_keys, fn key ->
      assert Map.has_key?(json, key), "Expected JSON to have required key '#{key}'"
    end)

    # Check types
    Enum.each(types, fn {key, expected_type} ->
      value = Map.get(json, key)

      case expected_type do
        :list -> assert is_list(value), "Expected '#{key}' to be a list"
        :map -> assert is_map(value), "Expected '#{key}' to be a map"
        :string -> assert is_binary(value), "Expected '#{key}' to be a string"
        :number -> assert is_number(value), "Expected '#{key}' to be a number"
        :boolean -> assert is_boolean(value), "Expected '#{key}' to be a boolean"
        :null -> assert is_nil(value), "Expected '#{key}' to be null"
      end
    end)
  end

  @doc """
  Validates that JSON is well-formed.

  Attempts to parse and re-encode to ensure validity.
  """
  def assert_valid_json(json_string) when is_binary(json_string) do
    assert {:ok, decoded} = Jason.decode(json_string), "Expected valid JSON, but parsing failed"
    assert {:ok, _reencoded} = Jason.encode(decoded), "Expected JSON to be re-encodable"
    :ok
  end

  # Mock / Stub Helpers

  @doc """
  Creates a mock for chart generation that returns SVG strings.

  ## Examples

      mock_chart = mock_chart_generator(type: :bar)
      svg = mock_chart.generate(%{data: [1, 2, 3]})
  """
  def mock_chart_generator(opts \\ []) do
    type = Keyword.get(opts, :type, :bar)

    %{
      generate: fn _data ->
        {:ok, "<svg><rect/></svg>"}
      end,
      type: type
    }
  end

  @doc """
  Creates a mock data loader that returns predefined data.

  ## Examples

      loader = mock_data_loader(data: mock_data)
      {:ok, data} = loader.load(query)
  """
  def mock_data_loader(opts \\ []) do
    data = Keyword.get(opts, :data, [])

    %{
      load: fn _query -> {:ok, data} end
    }
  end

  @doc """
  Measures the time it takes to render.

  Returns {result, time_in_microseconds}.

  ## Examples

      {rendered, time_us} = measure_render_time(fn ->
        Renderer.render(context)
      end)
  """
  def measure_render_time(render_fun) do
    :timer.tc(render_fun)
  end

  @doc """
  Measures memory used during rendering.

  Returns {result, memory_bytes_used}.

  ## Examples

      {rendered, memory_bytes} = measure_render_memory(fn ->
        Renderer.render(context)
      end)
  """
  def measure_render_memory(render_fun) do
    before_memory = :erlang.memory(:total)
    result = render_fun.()
    after_memory = :erlang.memory(:total)
    memory_used = after_memory - before_memory

    {result, memory_used}
  end

  @doc """
  Asserts that rendering completes within a time limit.

  ## Examples

      assert_renders_within(1000, fn ->
        Renderer.render(large_context)
      end)
  """
  def assert_renders_within(max_milliseconds, render_fun) do
    {_result, time_us} = :timer.tc(render_fun)
    time_ms = div(time_us, 1000)

    assert time_ms <= max_milliseconds,
           "Expected rendering to complete within #{max_milliseconds}ms, but took #{time_ms}ms"
  end

  @doc """
  Asserts that rendering uses less than a specified amount of memory.

  ## Examples

      assert_renders_with_memory(10_000_000, fn ->
        Renderer.render(context)
      end)
  """
  def assert_renders_with_memory(max_bytes, render_fun) do
    {_result, memory_used} = measure_render_memory(render_fun)

    assert memory_used <= max_bytes,
           "Expected rendering to use less than #{max_bytes} bytes, but used #{memory_used} bytes"
  end
end
