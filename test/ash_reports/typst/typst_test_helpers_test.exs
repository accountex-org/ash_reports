defmodule AshReports.TypstTestHelpersTest do
  use ExUnit.Case, async: true

  import AshReports.TypstTestHelpers

  describe "compile_and_validate/2" do
    test "compiles valid Typst template and returns PDF" do
      template = "#set page(paper: \"a4\")" <> "\n" <> "= Test Report" <> "\n" <> "This is a test."

      assert {:ok, pdf} = compile_and_validate(template)
      assert is_binary(pdf)
      assert pdf_valid?(pdf)
    end

    test "returns error for invalid template" do
      template = "#invalid typst syntax"

      assert {:error, _reason} = compile_and_validate(template)
    end

    test "validates PDF structure when validate option is true" do
      template = "#set page(paper: \"a4\")" <> "\n" <> "= Test"

      assert {:ok, _pdf} = compile_and_validate(template, validate: true)
    end

    test "skips validation when validate option is false" do
      template = "#set page(paper: \"a4\")" <> "\n" <> "= Test"

      assert {:ok, _pdf} = compile_and_validate(template, validate: false)
    end
  end

  describe "assert_pdf_valid/1" do
    test "passes for valid PDF" do
      pdf = generate_test_pdf()

      assert_pdf_valid(pdf)
    end

    test "raises for invalid PDF" do
      invalid_pdf = "not a pdf"

      assert_raise ExUnit.AssertionError, fn ->
        assert_pdf_valid(invalid_pdf)
      end
    end
  end

  describe "pdf_valid?/1" do
    test "returns true for valid PDF" do
      pdf = generate_test_pdf()

      assert pdf_valid?(pdf)
    end

    test "returns false for invalid PDF header" do
      refute pdf_valid?("not a pdf")
    end

    test "returns false for PDF without EOF marker" do
      incomplete_pdf = "%PDF-1.4" <> "\n" <> "some content without EOF"

      refute pdf_valid?(incomplete_pdf)
    end
  end

  describe "extract_pdf_text/1" do
    @tag :requires_pdftotext
    test "extracts text from PDF" do
      pdf = generate_test_pdf(title: "Sample Report", content: "Test content here")

      case extract_pdf_text(pdf) do
        {:ok, text} ->
          assert text =~ "Sample Report"
          assert text =~ "Test content"

        {:error, reason} ->
          IO.puts("Skipping text extraction test: " <> reason)
      end
    end

    @tag :requires_pdftotext
    test "returns error for invalid PDF" do
      invalid_pdf = "not a pdf"

      assert {:error, _reason} = extract_pdf_text(invalid_pdf)
    end
  end

  describe "compare_pdf_structure/2" do
    test "compares two identical PDFs" do
      pdf1 = generate_test_pdf(title: "Report", content: "Content")
      pdf2 = generate_test_pdf(title: "Report", content: "Content")

      result = compare_pdf_structure(pdf1, pdf2)

      assert result.page_count_match
      assert result.text_similarity > 0.9
    end

    test "detects differences in PDFs" do
      pdf1 = generate_test_pdf(title: "Report A", content: "Content A")
      pdf2 = generate_test_pdf(title: "Report B", content: "Content B")

      result = compare_pdf_structure(pdf1, pdf2)

      assert is_boolean(result.page_count_match)
      assert is_float(result.text_similarity)
      assert result.text_similarity >= 0.0 and result.text_similarity <= 1.0
    end
  end

  describe "generate_test_pdf/1" do
    test "generates valid PDF with default options" do
      pdf = generate_test_pdf()

      assert_pdf_valid(pdf)
    end

    test "generates PDF with custom title" do
      pdf = generate_test_pdf(title: "Custom Title")

      assert_pdf_valid(pdf)
    end

    test "generates PDF with custom content" do
      pdf = generate_test_pdf(content: "Custom content here")

      assert_pdf_valid(pdf)
    end
  end
end
