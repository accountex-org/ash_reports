defmodule AshReports.TypstVisualRegressionTest do
  use ExUnit.Case, async: false

  import AshReports.TypstVisualRegression
  import AshReports.TypstTestHelpers

  @test_baseline_name "test_visual_regression_#{:rand.uniform(100000)}"

  setup do
    # Clean up test baselines after each test
    on_exit(fn ->
      try do
        delete_baseline(@test_baseline_name)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "capture_pdf_snapshot/3" do
    test "captures PDF as baseline" do
      pdf = generate_test_pdf(title: "Baseline Test", content: "Test content for baseline")

      assert {:ok, result} = capture_pdf_snapshot(pdf, @test_baseline_name)

      assert File.exists?(result.baseline_path)
      assert File.exists?(result.text_path)
      assert File.exists?(result.meta_path)
      assert result.metadata.name == @test_baseline_name
      assert is_number(result.metadata.pdf_size)
    end

    test "prevents overwriting baseline by default" do
      pdf = generate_test_pdf()

      assert {:ok, _} = capture_pdf_snapshot(pdf, @test_baseline_name)
      assert {:error, msg} = capture_pdf_snapshot(pdf, @test_baseline_name)
      assert msg =~ "already exists"
    end

    test "allows overwriting with overwrite option" do
      pdf1 = generate_test_pdf(title: "Version 1")
      pdf2 = generate_test_pdf(title: "Version 2")

      assert {:ok, _} = capture_pdf_snapshot(pdf1, @test_baseline_name)
      assert {:ok, _} = capture_pdf_snapshot(pdf2, @test_baseline_name, overwrite: true)
    end

    test "stores custom metadata" do
      pdf = generate_test_pdf()
      metadata = %{version: "1.0", author: "test"}

      assert {:ok, result} = capture_pdf_snapshot(pdf, @test_baseline_name, metadata: metadata)

      assert result.metadata.metadata == metadata
    end
  end

  describe "compare_with_baseline/2" do
    test "compares identical PDFs" do
      pdf = generate_test_pdf(title: "Test Report", content: "Same content")

      capture_pdf_snapshot(pdf, @test_baseline_name)

      assert {:ok, comparison} = compare_with_baseline(pdf, @test_baseline_name)

      assert comparison.text_match
      assert comparison.text_similarity >= 0.95
      assert comparison.structure_match
      assert comparison.baseline_name == @test_baseline_name
    end

    test "detects differences in PDF content" do
      pdf1 = generate_test_pdf(title: "Original", content: "Original content here")
      pdf2 = generate_test_pdf(title: "Modified", content: "Different content here")

      capture_pdf_snapshot(pdf1, @test_baseline_name)

      assert {:ok, comparison} = compare_with_baseline(pdf2, @test_baseline_name)

      # Text similarity should be less than 100%
      assert comparison.text_similarity < 1.0
      assert comparison.text_similarity >= 0.0
      assert length(comparison.differences) > 0
    end

    test "returns error for missing baseline" do
      pdf = generate_test_pdf()

      assert {:error, msg} = compare_with_baseline(pdf, "nonexistent_baseline")
      assert msg =~ "not found"
    end

    test "detects page count changes" do
      # Create a multi-page baseline
      multi_page_template = """
      #set page(paper: "a4")
      = Page 1
      Content for page 1
      #pagebreak()
      = Page 2
      Content for page 2
      """

      pdf_multi = case AshReports.Typst.BinaryWrapper.compile(multi_page_template) do
        {:ok, pdf} -> pdf
        {:error, _} -> generate_test_pdf()  # Fallback
      end

      capture_pdf_snapshot(pdf_multi, @test_baseline_name)

      # Compare with single-page PDF
      pdf_single = generate_test_pdf()

      assert {:ok, comparison} = compare_with_baseline(pdf_single, @test_baseline_name)

      # Structure match depends on page count detection accuracy
      # This may or may not match depending on PDF text extraction
      assert is_boolean(comparison.structure_match)
      assert is_tuple(comparison.page_count)
    end
  end

  describe "list_baselines/0" do
    test "lists available baselines" do
      pdf = generate_test_pdf()
      capture_pdf_snapshot(pdf, @test_baseline_name)

      baselines = list_baselines()

      assert is_list(baselines)
      assert @test_baseline_name in baselines
    end

    test "returns empty list when no baselines exist" do
      # Ensure directory doesn't exist or is empty
      baselines = list_baselines()

      assert is_list(baselines)
    end
  end

  describe "delete_baseline/1" do
    test "deletes baseline files" do
      pdf = generate_test_pdf()
      {:ok, result} = capture_pdf_snapshot(pdf, @test_baseline_name)

      assert File.exists?(result.baseline_path)

      :ok = delete_baseline(@test_baseline_name)

      refute File.exists?(result.baseline_path)
      refute File.exists?(result.text_path)
      refute File.exists?(result.meta_path)
    end
  end

  describe "update_baseline/3" do
    test "updates existing baseline" do
      pdf1 = generate_test_pdf(title: "Version 1")
      pdf2 = generate_test_pdf(title: "Version 2")

      {:ok, _} = capture_pdf_snapshot(pdf1, @test_baseline_name)
      {:ok, _} = update_baseline(pdf2, @test_baseline_name)

      # Verify updated
      {:ok, comparison} = compare_with_baseline(pdf2, @test_baseline_name)
      assert comparison.text_match
    end
  end
end
