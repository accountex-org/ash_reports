defmodule AshReports.TypstVisualRegression do
  @moduledoc """
  Visual regression testing for Typst PDF output.

  Provides utilities for:
  - Capturing PDF snapshots as baselines
  - Comparing PDF output against baselines
  - Detecting visual regressions through text and structure comparison
  - Managing baseline storage and updates

  ## Usage

      import AshReports.TypstVisualRegression

      test "PDF output matches baseline" do
        pdf = generate_sales_report()

        {:ok, comparison} = compare_with_baseline(pdf, "sales_report_v1")

        assert comparison.text_match
        assert comparison.structure_match
      end

  ## Baseline Storage

  Baselines are stored in `test/fixtures/typst_baselines/` as:
  - `{name}.pdf` - PDF binary
  - `{name}.txt` - Extracted text content
  - `{name}.json` - Metadata (page count, creation date, etc.)
  """

  alias AshReports.TypstTestHelpers

  @baseline_dir "test/fixtures/typst_baselines"

  @doc """
  Captures a PDF snapshot as a baseline for future comparisons.

  Creates baseline files:
  - PDF binary
  - Extracted text
  - Metadata JSON

  ## Options

  - `:overwrite` - Whether to overwrite existing baseline (default: false)
  - `:metadata` - Additional metadata to store

  ## Examples

      iex> pdf = generate_report()
      iex> capture_pdf_snapshot(pdf, "my_report")
      {:ok, %{baseline_path: "test/fixtures/typst_baselines/my_report.pdf"}}
  """
  def capture_pdf_snapshot(pdf_binary, name, opts \\ []) do
    overwrite? = Keyword.get(opts, :overwrite, false)
    metadata = Keyword.get(opts, :metadata, %{})

    baseline_path = Path.join(@baseline_dir, "#{name}.pdf")
    text_path = Path.join(@baseline_dir, "#{name}.txt")
    meta_path = Path.join(@baseline_dir, "#{name}.json")

    # Check if baseline exists and overwrite is false
    if File.exists?(baseline_path) and not overwrite? do
      {:error, "Baseline already exists. Use overwrite: true to replace it."}
    else
      # Ensure directory exists
      File.mkdir_p!(@baseline_dir)

      # Save PDF
      File.write!(baseline_path, pdf_binary)

      # Extract and save text
      text_content =
        case TypstTestHelpers.extract_pdf_text(pdf_binary) do
          {:ok, text} ->
            File.write!(text_path, text)
            text

          {:error, _} ->
            # If text extraction fails, save empty text
            File.write!(text_path, "")
            ""
        end

      # Save metadata
      meta = %{
        name: name,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        pdf_size: byte_size(pdf_binary),
        text_length: String.length(text_content),
        page_count: estimate_page_count(text_content),
        metadata: metadata
      }

      File.write!(meta_path, Jason.encode!(meta, pretty: true))

      {:ok,
       %{
         baseline_path: baseline_path,
         text_path: text_path,
         meta_path: meta_path,
         metadata: meta
       }}
    end
  end

  @doc """
  Compares a PDF against a stored baseline.

  Returns comparison results including:
  - Text match percentage
  - Structure match (page count)
  - Differences detected

  ## Examples

      iex> pdf = generate_report()
      iex> {:ok, comparison} = compare_with_baseline(pdf, "my_report")
      iex> comparison.text_similarity
      0.98
  """
  def compare_with_baseline(pdf_binary, name) do
    baseline_path = Path.join(@baseline_dir, "#{name}.pdf")
    text_path = Path.join(@baseline_dir, "#{name}.txt")
    meta_path = Path.join(@baseline_dir, "#{name}.json")

    cond do
      not File.exists?(baseline_path) ->
        {:error, "Baseline '#{name}' not found. Create it with capture_pdf_snapshot/2."}

      true ->
        # Load baseline
        _baseline_pdf = File.read!(baseline_path)
        baseline_text = File.read!(text_path)
        baseline_meta = File.read!(meta_path) |> Jason.decode!()

        # Extract current PDF text
        current_text =
          case TypstTestHelpers.extract_pdf_text(pdf_binary) do
            {:ok, text} -> text
            {:error, _} -> ""
          end

        # Compare structure
        current_page_count = estimate_page_count(current_text)
        baseline_page_count = baseline_meta["page_count"] || 0

        # Calculate text similarity
        text_similarity = calculate_text_similarity(baseline_text, current_text)

        # Detect differences
        differences = detect_text_differences(baseline_text, current_text)

        {:ok,
         %{
           text_match: text_similarity > 0.95,
           text_similarity: text_similarity,
           structure_match: current_page_count == baseline_page_count,
           page_count: {baseline_page_count, current_page_count},
           pdf_size: {baseline_meta["pdf_size"], byte_size(pdf_binary)},
           differences: differences,
           baseline_name: name,
           baseline_created: baseline_meta["created_at"]
         }}
    end
  end

  @doc """
  Lists all available baselines.

  Returns a list of baseline names.

  ## Examples

      iex> list_baselines()
      ["sales_report_v1", "invoice_template", "summary_report"]
  """
  def list_baselines do
    if File.exists?(@baseline_dir) do
      File.ls!(@baseline_dir)
      |> Enum.filter(&String.ends_with?(&1, ".pdf"))
      |> Enum.map(&String.replace_suffix(&1, ".pdf", ""))
      |> Enum.sort()
    else
      []
    end
  end

  @doc """
  Deletes a baseline.

  ## Examples

      iex> delete_baseline("old_report")
      :ok
  """
  def delete_baseline(name) do
    baseline_path = Path.join(@baseline_dir, "#{name}.pdf")
    text_path = Path.join(@baseline_dir, "#{name}.txt")
    meta_path = Path.join(@baseline_dir, "#{name}.json")

    File.rm(baseline_path)
    File.rm(text_path)
    File.rm(meta_path)

    :ok
  end

  @doc """
  Updates a baseline with new PDF content.

  Convenience function for re-capturing a baseline.

  ## Examples

      iex> pdf = generate_updated_report()
      iex> update_baseline(pdf, "my_report")
      {:ok, %{baseline_path: ...}}
  """
  def update_baseline(pdf_binary, name, opts \\ []) do
    capture_pdf_snapshot(pdf_binary, name, Keyword.put(opts, :overwrite, true))
  end

  # Private helpers

  defp estimate_page_count(text) do
    # Estimate page count from text content
    # Form feeds are the most reliable indicator
    form_feeds = text |> String.graphemes() |> Enum.count(&(&1 == "\f"))

    if form_feeds > 0 do
      form_feeds + 1
    else
      # Fallback: estimate based on content length (rough heuristic)
      lines = String.split(text, "\n") |> length()
      max(1, div(lines, 60))
    end
  end

  defp calculate_text_similarity(text1, text2) do
    # Normalize whitespace for comparison
    norm1 = normalize_text(text1)
    norm2 = normalize_text(text2)

    # Calculate similarity using Jaccard index
    words1 = String.split(norm1) |> MapSet.new()
    words2 = String.split(norm2) |> MapSet.new()

    intersection = MapSet.intersection(words1, words2) |> MapSet.size()
    union = MapSet.union(words1, words2) |> MapSet.size()

    if union > 0 do
      intersection / union
    else
      if norm1 == "" and norm2 == "", do: 1.0, else: 0.0
    end
  end

  defp normalize_text(text) do
    text
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/[^\w\s]/, "")
  end

  defp detect_text_differences(text1, text2) do
    lines1 = String.split(text1, "\n") |> Enum.map(&String.trim/1)
    lines2 = String.split(text2, "\n") |> Enum.map(&String.trim/1)

    # Pad the shorter list with empty strings for proper zipping
    max_length = max(length(lines1), length(lines2))
    padded_lines1 = lines1 ++ List.duplicate("", max_length - length(lines1))
    padded_lines2 = lines2 ++ List.duplicate("", max_length - length(lines2))

    # Find lines that are significantly different - O(n) instead of O(n²)
    padded_lines1
    |> Enum.zip(padded_lines2)
    |> Enum.with_index(1)
    |> Enum.reject(fn {{line1, line2}, _line_num} ->
      # Consider lines different if they differ by more than minor whitespace
      normalize_text(line1) == normalize_text(line2)
    end)
    |> Enum.take(20)
    # Limit to first 20 differences
    |> Enum.map(fn {{line1, line2}, line_num} ->
      %{
        line: line_num,
        baseline: String.slice(line1, 0, 100),
        current: String.slice(line2, 0, 100)
      }
    end)
  end
end
