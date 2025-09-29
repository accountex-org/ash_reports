defmodule AshReports.Typst.BinaryWrapperTest do
  use ExUnit.Case, async: true

  alias AshReports.Typst.BinaryWrapper

  describe "compile/2" do
    test "compiles a simple Typst template to PDF" do
      template = """
      #set text(size: 12pt)
      = Hello, World!

      This is a test document.
      """

      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      # PDF magic number
      assert <<"%PDF", _rest::binary>> = pdf
    end

    test "handles empty template with error" do
      assert {:error, :empty_template} = BinaryWrapper.compile("", format: :pdf)
    end

    test "validates format parameter" do
      template = "Test content"
      assert {:error, {:invalid_format, :invalid}} = BinaryWrapper.compile(template, format: :invalid)
    end

    test "compiles with basic Typst formatting" do
      template = """
      #set page(paper: "a4")
      #set text(font: "Liberation Serif")

      = Report Title

      This is a paragraph with *bold* and _italic_ text.

      - Item 1
      - Item 2
      - Item 3
      """

      assert {:ok, pdf} = BinaryWrapper.compile(template)
      assert byte_size(pdf) > 1000  # Should produce a reasonable PDF
    end

    @tag :skip
    test "respects timeout option" do
      # Create a template that would take long to compile
      template = """
      #for i in range(1000000) {
        [Line #i]
      }
      """

      assert {:error, :timeout} = BinaryWrapper.compile(template, timeout: 100)
    end
  end

  describe "compile_file/2" do
    setup do
      # Create a temporary test template file
      tmp_dir = System.tmp_dir!()
      file_path = Path.join(tmp_dir, "test_template.typ")

      File.write!(file_path, """
      #set text(size: 14pt)
      = Test File Template

      This template was loaded from a file.
      """)

      on_exit(fn -> File.rm(file_path) end)

      {:ok, file_path: file_path}
    end

    test "compiles a template from file", %{file_path: file_path} do
      assert {:ok, pdf} = BinaryWrapper.compile_file(file_path)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
    end

    test "handles non-existent file" do
      assert {:error, {:file_error, :enoent}} = BinaryWrapper.compile_file("/non/existent/file.typ")
    end
  end

  describe "validate_nif/0" do
    test "confirms NIF is loaded and operational" do
      assert :ok = BinaryWrapper.validate_nif()
    end
  end

  describe "error handling" do
    test "handles syntax errors in templates" do
      # Invalid Typst syntax
      template = """
      #set text(size: 12pt  // Missing closing parenthesis
      Content here
      """

      assert {:error, error} = BinaryWrapper.compile(template)
      assert is_map(error) or is_binary(error) or is_atom(error)
    end

    @tag :skip
    test "handles very large templates" do
      # Create a 11MB template (over the 10MB limit)
      large_template = String.duplicate("A", 11_000_000)
      assert {:error, :template_too_large} = BinaryWrapper.compile(large_template)
    end
  end
end