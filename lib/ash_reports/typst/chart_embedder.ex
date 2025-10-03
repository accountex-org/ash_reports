defmodule AshReports.Typst.ChartEmbedder do
  @moduledoc """
  Embeds SVG charts into Typst templates for PDF generation.

  Provides utilities for converting chart SVG output into Typst `#image()`
  function calls with proper encoding, positioning, and layout.

  ## Encoding Strategies

  - **Base64** (primary): Embeds SVG directly in template, no file dependencies
  - **File path** (fallback): For large SVGs (>1MB) to avoid template bloat

  ## Layout Support

  - Single chart embedding with positioning and sizing
  - Grid layouts for multi-chart pages
  - Flow layouts for vertical stacking
  - Caption and title support

  ## Examples

      # Single chart embedding
      {:ok, svg} = Charts.generate(:bar, data, config)
      {:ok, typst} = ChartEmbedder.embed(svg, width: "100%", caption: "Sales by Region")

      # Grid layout
      charts = [
        {svg1, [caption: "Chart 1"]},
        {svg2, [caption: "Chart 2"]}
      ]
      {:ok, typst} = ChartEmbedder.embed_grid(charts, columns: 2)

      # Generate and embed in one step
      {:ok, typst} = ChartEmbedder.generate_and_embed(
        :bar, data, config,
        width: "100%", caption: "Sales"
      )
  """

  alias AshReports.Charts
  alias AshReports.Charts.Config
  alias AshReports.Typst.ChartEmbedder.TypstFormatter

  @max_base64_size 1_048_576  # 1MB

  @doc """
  Embeds a single chart SVG into Typst code.

  ## Parameters

    - `svg` - SVG string from Charts.generate/3
    - `opts` - Embedding options:
      - `:width` - Chart width (e.g., "100%", "300pt", "50mm")
      - `:height` - Chart height (optional, maintains aspect ratio if omitted)
      - `:caption` - Caption text below chart
      - `:title` - Title text above chart
      - `:position` - Position in layout (:top, :center, :bottom, :left, :right)
      - `:encoding` - :base64 (default) or :file

  ## Returns

    - `{:ok, typst_code}` - Typst code string to embed in template
    - `{:error, reason}` - Encoding or validation failed

  ## Examples

      svg = "<svg>...</svg>"
      {:ok, typst} = ChartEmbedder.embed(svg, width: "100%", caption: "Sales by Region")
  """
  @spec embed(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def embed(svg, opts \\ [])

  def embed(svg, opts) when is_binary(svg) do
    with {:ok, encoding} <- determine_encoding(svg, opts),
         {:ok, image_code} <- encode_svg(svg, encoding),
         {:ok, sized_code} <- apply_sizing(image_code, opts),
         {:ok, final_code} <- wrap_with_text(sized_code, opts) do
      {:ok, final_code}
    end
  end

  def embed(_, _), do: {:error, :invalid_svg}

  @doc """
  Embeds multiple charts in a grid layout.

  ## Parameters

    - `charts` - List of {svg, opts} tuples
    - `layout_opts` - Grid configuration:
      - `:columns` - Number of columns (default: 2)
      - `:gutter` - Space between cells (default: "10pt")
      - `:column_widths` - Custom column widths (e.g., ["1fr", "2fr"])

  ## Returns

    - `{:ok, typst_code}` - Typst grid code

  ## Examples

      charts = [
        {svg1, [caption: "Chart 1"]},
        {svg2, [caption: "Chart 2"]}
      ]
      {:ok, typst} = ChartEmbedder.embed_grid(charts, columns: 2)
  """
  @spec embed_grid(list({String.t(), keyword()}), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def embed_grid(charts, layout_opts \\ []) when is_list(charts) do
    with {:ok, embedded_charts} <- embed_all(charts),
         {:ok, grid_code} <- TypstFormatter.build_grid(embedded_charts, layout_opts) do
      {:ok, grid_code}
    end
  end

  @doc """
  Embeds multiple charts in a vertical flow layout.

  ## Parameters

    - `charts` - List of {svg, opts} tuples
    - `spacing` - Vertical spacing between charts (default: "20pt")

  ## Examples

      charts = [
        {svg1, [caption: "Q1 Results"]},
        {svg2, [caption: "Q2 Results"]}
      ]
      {:ok, typst} = ChartEmbedder.embed_flow(charts, spacing: "30pt")
  """
  @spec embed_flow(list({String.t(), keyword()}), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def embed_flow(charts, opts \\ []) when is_list(charts) do
    spacing = Keyword.get(opts, :spacing, "20pt")

    with {:ok, embedded_charts} <- embed_all(charts),
         {:ok, flow_code} <- TypstFormatter.build_flow(embedded_charts, spacing) do
      {:ok, flow_code}
    end
  end

  @doc """
  Generates chart from data and embeds in one operation.

  ## Parameters

    - `chart_type` - Chart type atom (:bar, :line, :pie, etc.)
    - `data` - Chart data
    - `config` - Chart config (Config struct or map)
    - `embed_opts` - Embedding options (same as embed/2)

  ## Examples

      data = [%{category: "A", value: 10}]
      config = %Config{title: "Sales", width: 600, height: 400}

      {:ok, typst} = ChartEmbedder.generate_and_embed(
        :bar, data, config,
        width: "100%", caption: "Sales by Category"
      )
  """
  @spec generate_and_embed(atom(), list(map()), Config.t() | map(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_and_embed(chart_type, data, config, embed_opts \\ []) do
    with {:ok, svg} <- Charts.generate(chart_type, data, config) do
      embed(svg, embed_opts)
    end
  end

  # Private functions

  defp determine_encoding(svg, opts) do
    encoding = Keyword.get(opts, :encoding, :base64)
    svg_size = byte_size(svg)

    cond do
      encoding == :file ->
        {:ok, :file}

      encoding == :base64 && svg_size > @max_base64_size ->
        {:ok, :file}

      encoding == :base64 ->
        {:ok, :base64}

      true ->
        {:error, {:invalid_encoding, encoding}}
    end
  end

  defp encode_svg(svg, :base64) do
    encoded = Base.encode64(svg)
    {:ok, "#image.decode(\"#{encoded}\", format: \"svg\")"}
  end

  defp encode_svg(svg, :file) do
    with {:ok, path} <- write_temp_svg(svg) do
      {:ok, "#image(\"#{path}\")"}
    end
  end

  defp write_temp_svg(svg) do
    # Generate unique filename
    filename = "chart_#{:erlang.unique_integer([:positive])}.svg"
    path = Path.join(System.tmp_dir!(), filename)

    case File.write(path, svg) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, {:file_write_failed, reason}}
    end
  end

  defp apply_sizing(image_code, opts) do
    width = Keyword.get(opts, :width)
    height = Keyword.get(opts, :height)

    sized_code =
      case {width, height} do
        {nil, nil} ->
          image_code

        {w, nil} when not is_nil(w) ->
          formatted_width = TypstFormatter.format_dimension(w)
          String.replace(image_code, ")", ", width: #{formatted_width})")

        {nil, h} when not is_nil(h) ->
          formatted_height = TypstFormatter.format_dimension(h)
          String.replace(image_code, ")", ", height: #{formatted_height})")

        {w, h} ->
          formatted_width = TypstFormatter.format_dimension(w)
          formatted_height = TypstFormatter.format_dimension(h)

          image_code
          |> String.replace(")", ", width: #{formatted_width}, height: #{formatted_height})")
      end

    {:ok, sized_code}
  end

  defp wrap_with_text(image_code, opts) do
    title = Keyword.get(opts, :title)
    caption = Keyword.get(opts, :caption)

    result =
      []
      |> add_title(title)
      |> add_image(image_code)
      |> add_caption(caption)
      |> Enum.join("\n")

    {:ok, result}
  end

  defp add_title(acc, nil), do: acc

  defp add_title(acc, title) when is_binary(title) do
    escaped = TypstFormatter.escape_string(title)
    acc ++ ["#text(size: 14pt, weight: \"bold\")[#{escaped}]"]
  end

  defp add_image(acc, image_code) do
    acc ++ [image_code]
  end

  defp add_caption(acc, nil), do: acc

  defp add_caption(acc, caption) when is_binary(caption) do
    escaped = TypstFormatter.escape_string(caption)
    acc ++ ["#text(size: 10pt, style: \"italic\")[#{escaped}]"]
  end

  defp embed_all(charts) do
    results =
      Enum.map(charts, fn {svg, opts} ->
        embed(svg, opts)
      end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      embedded = Enum.map(results, fn {:ok, code} -> code end)
      {:ok, embedded}
    else
      error = Enum.find(results, &match?({:error, _}, &1))
      error
    end
  end
end
