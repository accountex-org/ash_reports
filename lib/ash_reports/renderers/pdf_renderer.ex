defmodule AshReports.PdfRenderer do
  @moduledoc """
  PDF Renderer using Typst compilation.

  This renderer implements the Renderer behaviour to generate PDF output
  by converting report data through the Typst template system and compiling
  to PDF using the Typst binary wrapper.

  ## Architecture

  The PDF generation follows this pipeline:
  1. Report Definition → Typst Template (via DSL Generator)
  2. Typst Template + Data → PDF Binary (via Typst Compiler)

  ## Usage

      context = RenderContext.new(report, data_result)
      {:ok, result} = PdfRenderer.render_with_context(context)

      # result.content contains binary PDF data
      File.write!("report.pdf", result.content)

  ## Configuration

  PDF-specific options can be passed through the context config:

      config = %{
        pdf: %{
          page_size: :a4,
          orientation: :portrait,
          margins: %{top: 20, right: 20, bottom: 20, left: 20}
        }
      }

      context = RenderContext.new(report, data_result, config)

  """

  @behaviour AshReports.Renderer

  alias AshReports.{RenderContext, Typst}

  @doc """
  Renders a report to PDF format using Typst compilation.

  Implements the Renderer behaviour's main rendering function.
  """
  @impl AshReports.Renderer
  def render_with_context(%RenderContext{} = context, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    with {:ok, pdf_context} <- prepare_pdf_context(context, opts),
         {:ok, typst_template} <- generate_typst_template(pdf_context),
         {:ok, pdf_binary} <- compile_to_pdf(typst_template, pdf_context),
         {:ok, metadata} <- build_pdf_metadata(pdf_context, start_time) do
      # Include the Typst template in metadata for debugging/viewing
      metadata_with_template = Map.put(metadata, :typst_template, typst_template)

      result = %{
        content: pdf_binary,
        metadata: metadata_with_template,
        context: pdf_context
      }

      {:ok, result}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  PDF renderer does not support streaming.

  Typst compilation generates the complete PDF document in one pass.
  """
  @impl AshReports.Renderer
  def supports_streaming?, do: false

  @doc """
  Returns the file extension for PDF format.
  """
  @impl AshReports.Renderer
  def file_extension, do: "pdf"

  @doc """
  Returns the MIME content type for PDF format.
  """
  @impl AshReports.Renderer
  def content_type, do: "application/pdf"

  @doc """
  Validates that the context is suitable for PDF rendering.
  """
  @impl AshReports.Renderer
  def validate_context(%RenderContext{} = context) do
    with :ok <- validate_report_exists(context),
         :ok <- validate_data_exists(context),
         :ok <- validate_typst_available() do
      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Prepares the renderer for PDF generation.
  """
  @impl AshReports.Renderer
  def prepare(%RenderContext{} = context, opts) do
    pdf_config = build_pdf_config(opts)
    updated_config = Map.put(context.config, :pdf, pdf_config)
    enhanced_context = %{context | config: updated_config}

    {:ok, enhanced_context}
  end

  @doc """
  Cleans up after PDF rendering.
  """
  @impl AshReports.Renderer
  def cleanup(%RenderContext{} = _context, _result) do
    # Typst handles its own cleanup
    :ok
  end

  @doc """
  Legacy render callback for backward compatibility.
  """
  @impl AshReports.Renderer
  def render(report_module, data, opts) do
    config = Keyword.get(opts, :config, %{})
    context = RenderContext.new(report_module, %{records: data}, config)

    case render_with_context(context, opts) do
      {:ok, result} -> {:ok, result.content}
      {:error, _reason} = error -> error
    end
  end

  # Private implementation functions

  defp prepare_pdf_context(%RenderContext{} = context, opts) do
    with {:ok, prepared} <- prepare(context, opts) do
      {:ok, prepared}
    end
  end

  defp generate_typst_template(%RenderContext{} = context) do
    # Use the Typst DSL Generator to create the template
    report = context.report

    options = [
      format: :pdf,
      theme: "default",
      debug: false,
      context: context  # Pass the full context with data
    ]

    case Typst.DSLGenerator.generate_template(report, options) do
      {:ok, template} -> {:ok, template}
      {:error, reason} -> {:error, {:template_generation_failed, reason}}
    end
  end

  defp compile_to_pdf(typst_template, %RenderContext{} = context) do
    compile_options = [
      format: :pdf,
      timeout: get_compile_timeout(context),
      working_dir: get_working_directory(context)
    ]

    case Typst.BinaryWrapper.compile(typst_template, compile_options) do
      {:ok, pdf_binary} -> {:ok, pdf_binary}
      {:error, reason} -> {:error, {:typst_compilation_failed, reason}}
    end
  end

  defp build_pdf_metadata(%RenderContext{} = context, start_time) do
    end_time = System.monotonic_time(:microsecond)
    render_time = end_time - start_time

    metadata = %{
      format: :pdf,
      render_time_us: render_time,
      pdf_engine: :typst,
      record_count: length(context.records),
      variable_count: map_size(context.variables),
      group_count: map_size(context.groups),
      locale: RenderContext.get_locale(context),
      renderer_version: "1.0.0-typst"
    }

    {:ok, metadata}
  end

  defp validate_report_exists(%RenderContext{report: nil}), do: {:error, :missing_report}
  defp validate_report_exists(_context), do: :ok

  defp validate_data_exists(%RenderContext{records: []}), do: {:error, :no_data_to_render}
  defp validate_data_exists(_context), do: :ok

  defp validate_typst_available do
    case Code.ensure_loaded?(AshReports.Typst.BinaryWrapper) do
      true -> :ok
      false -> {:error, :typst_not_available}
    end
  end

  defp build_pdf_config(opts) do
    %{
      page_size: Keyword.get(opts, :page_size, :a4),
      orientation: Keyword.get(opts, :orientation, :portrait),
      margins: Keyword.get(opts, :margins, %{top: 20, right: 20, bottom: 20, left: 20}),
      font_size: Keyword.get(opts, :font_size, 11),
      font_family: Keyword.get(opts, :font_family, "sans-serif"),
      quality: Keyword.get(opts, :quality, :high)
    }
  end

  defp get_compile_timeout(%RenderContext{} = context) do
    get_in(context.config, [:pdf, :timeout]) || 30_000
  end

  defp get_working_directory(%RenderContext{} = context) do
    get_in(context.config, [:pdf, :working_dir]) || System.tmp_dir()
  end
end
