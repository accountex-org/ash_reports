defmodule AshReports.TypstTestHelpers do
  @moduledoc """
  Test helpers for Typst PDF compilation and validation.

  Provides utilities for:
  - Compiling Typst templates and validating PDF output
  - Asserting PDF validity and structure
  - Extracting text content from PDFs
  - Comparing PDF structure between outputs

  ## Usage

      import AshReports.TypstTestHelpers

      test "generates valid PDF" do
        template = "#set page(paper: \\"a4\\")\\n= Sales Report"
        data = %{total: 1000}

        {:ok, pdf_binary} = compile_and_validate(template, data)
        assert_pdf_valid(pdf_binary)
      end
  """

  alias AshReports.Typst.BinaryWrapper

  @doc """
  Compiles a Typst template and validates the output.

  ## Options

  - `:validate` - Whether to validate PDF structure (default: true)
  - `:timeout` - Compilation timeout in milliseconds (default: 5000)

  ## Examples

      iex> compile_and_validate("#set page(paper: \\"a4\\")\\n= Test")
      {:ok, <<37, 80, 68, 70, ...>>}

      iex> compile_and_validate("invalid typst")
      {:error, %{message: "compilation failed"}}
  """
  def compile_and_validate(template, opts \\ []) do
    validate? = Keyword.get(opts, :validate, true)
    timeout = Keyword.get(opts, :timeout, 5000)

    case BinaryWrapper.compile(template, timeout: timeout) do
      {:ok, pdf_binary} when validate? ->
        if pdf_valid?(pdf_binary) do
          {:ok, pdf_binary}
        else
          {:error, %{message: "Invalid PDF structure"}}
        end

      {:ok, pdf_binary} ->
        {:ok, pdf_binary}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Asserts that a binary contains a valid PDF.

  ## Examples

      test "PDF is valid" do
        pdf = generate_pdf()
        assert_pdf_valid(pdf)
      end
  """
  def assert_pdf_valid(pdf_binary) when is_binary(pdf_binary) do
    unless pdf_valid?(pdf_binary) do
      raise ExUnit.AssertionError,
        message: "Expected valid PDF, but PDF structure is invalid",
        expr: "assert_pdf_valid(pdf_binary)"
    end
  end

  @doc """
  Checks if a binary is a valid PDF.

  Validates PDF header and basic structure.

  ## Examples

      iex> pdf_valid?(<<37, 80, 68, 70, 45, ...>>)
      true

      iex> pdf_valid?(<<"not a pdf">>)
      false
  """
  def pdf_valid?(pdf_binary) when is_binary(pdf_binary) do
    # Check PDF header (starts with %PDF-)
    case pdf_binary do
      <<"%PDF-", _::binary>> ->
        # Check for EOF marker
        String.contains?(pdf_binary, "%%EOF")

      _ ->
        false
    end
  end

  @doc """
  Extracts text content from a PDF binary using pdftotext.

  Requires `poppler-utils` to be installed on the system.

  ## Examples

      iex> pdf = generate_sales_report()
      iex> {:ok, text} = extract_pdf_text(pdf)
      iex> text =~ "Sales Report"
      true
  """
  def extract_pdf_text(pdf_binary) when is_binary(pdf_binary) do
    # Write PDF to temporary file
    tmp_pdf = Path.join(System.tmp_dir!(), "test_pdf_#{:rand.uniform(100_000)}.pdf")
    tmp_txt = Path.join(System.tmp_dir!(), "test_pdf_#{:rand.uniform(100_000)}.txt")

    try do
      File.write!(tmp_pdf, pdf_binary)

      # Use pdftotext to extract text
      case System.cmd("pdftotext", [tmp_pdf, tmp_txt], stderr_to_stdout: true) do
        {_, 0} ->
          text = File.read!(tmp_txt)
          {:ok, text}

        {error, _} ->
          {:error, "pdftotext failed: #{error}"}
      end
    rescue
      e ->
        {:error, "Text extraction failed: #{Exception.message(e)}"}
    after
      File.rm(tmp_pdf)
      File.rm(tmp_txt)
    end
  end

  @doc """
  Compares the structure of two PDFs.

  Returns a map with comparison results:
  - `:page_count_match` - Whether page counts match
  - `:text_similarity` - Similarity score (0.0 - 1.0)
  - `:differences` - List of detected differences

  ## Examples

      test "PDFs have same structure" do
        pdf1 = generate_report(version: :v1)
        pdf2 = generate_report(version: :v2)

        result = compare_pdf_structure(pdf1, pdf2)
        assert result.page_count_match
        assert result.text_similarity > 0.95
      end
  """
  def compare_pdf_structure(pdf1, pdf2) when is_binary(pdf1) and is_binary(pdf2) do
    with {:ok, text1} <- extract_pdf_text(pdf1),
         {:ok, text2} <- extract_pdf_text(pdf2) do
      # Count pages (simple heuristic - count "Page" markers)
      page_count1 = count_pages_heuristic(text1)
      page_count2 = count_pages_heuristic(text2)

      # Calculate text similarity using Levenshtein-like approach
      similarity = calculate_text_similarity(text1, text2)

      # Detect differences
      differences = detect_differences(text1, text2)

      %{
        page_count_match: page_count1 == page_count2,
        page_count: {page_count1, page_count2},
        text_similarity: similarity,
        differences: differences
      }
    else
      {:error, reason} ->
        %{
          error: reason,
          page_count_match: false,
          text_similarity: 0.0,
          differences: ["Failed to extract text: #{reason}"]
        }
    end
  end

  @doc """
  Generates a simple test PDF for testing purposes.

  ## Examples

      iex> pdf = generate_test_pdf(title: "Test Report")
      iex> assert_pdf_valid(pdf)
  """
  def generate_test_pdf(opts \\ []) do
    title = Keyword.get(opts, :title, "Test Report")
    content = Keyword.get(opts, :content, "Test content")

    template = """
    #set page(paper: "a4")
    #set text(font: "Liberation Sans")

    = #{title}

    #{content}
    """

    case BinaryWrapper.compile(template) do
      {:ok, pdf} -> pdf
      {:error, reason} -> raise "Failed to generate test PDF: #{inspect(reason)}"
    end
  end

  # Private helpers

  defp count_pages_heuristic(text) do
    # Simple heuristic: count form feeds or use line count / 60
    form_feeds = text |> String.graphemes() |> Enum.count(&(&1 == "\f"))

    if form_feeds > 0 do
      form_feeds + 1
    else
      # Fallback: estimate based on content length
      lines = String.split(text, "\n") |> length()
      max(1, div(lines, 60))
    end
  end

  defp calculate_text_similarity(text1, text2) do
    # Normalize whitespace
    norm1 = String.trim(text1) |> String.replace(~r/\s+/, " ")
    norm2 = String.trim(text2) |> String.replace(~r/\s+/, " ")

    # Calculate simple similarity based on character overlap
    len1 = String.length(norm1)
    len2 = String.length(norm2)

    if len1 == 0 and len2 == 0 do
      1.0
    else
      # Simple similarity: intersection over union of characters
      chars1 = norm1 |> String.graphemes() |> MapSet.new()
      chars2 = norm2 |> String.graphemes() |> MapSet.new()

      intersection = MapSet.intersection(chars1, chars2) |> MapSet.size()
      union = MapSet.union(chars1, chars2) |> MapSet.size()

      if union > 0, do: intersection / union, else: 0.0
    end
  end

  defp detect_differences(text1, text2) do
    lines1 = String.split(text1, "\n")
    lines2 = String.split(text2, "\n")

    # Pad the shorter list with empty strings for proper zipping
    max_length = max(length(lines1), length(lines2))
    padded_lines1 = lines1 ++ List.duplicate("", max_length - length(lines1))
    padded_lines2 = lines2 ++ List.duplicate("", max_length - length(lines2))

    # Find lines that differ - O(n) instead of O(n²)
    padded_lines1
    |> Enum.zip(padded_lines2)
    |> Enum.with_index(1)
    |> Enum.reject(fn {{line1, line2}, _line_num} -> line1 == line2 end)
    |> Enum.take(10)
    |> Enum.map(fn {{line1, line2}, line_num} ->
      "Line #{line_num}: '#{line1}' vs '#{line2}'"
    end)
  end
end
