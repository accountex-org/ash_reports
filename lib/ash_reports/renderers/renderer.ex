defmodule AshReports.Renderer do
  @moduledoc """
  Enhanced behaviour for report renderers with context management and layout support.

  This module defines the core renderer behaviour for the Phase 3.1 Renderer Interface,
  providing a comprehensive API for format-specific rendering with advanced features
  including context management, layout calculation, and streaming support.

  Each output format (HTML, PDF, HEEX, JSON) implements this behaviour to provide
  format-specific rendering capabilities while benefiting from the unified context
  and layout management system.

  ## Enhanced Features (Phase 3.1)

  - **Context-Aware Rendering**: Renderers receive RenderContext with complete state
  - **Layout Integration**: Automatic layout calculation and element positioning
  - **Streaming Support**: Built-in support for large dataset streaming
  - **Error Recovery**: Comprehensive error handling and recovery mechanisms
  - **Performance Monitoring**: Built-in performance tracking and optimization

  ## Renderer Implementation

  Format-specific renderers must implement the enhanced callback interface:

      defmodule MyReport.Html do
        @behaviour AshReports.Renderer

        def render_with_context(context, opts) do
          # Render using context
        end

        def supports_streaming?(), do: true
        def file_extension(), do: "html"
        def content_type(), do: "text/html"
      end

  ## Integration with Phase 2

  Renderers seamlessly integrate with Phase 2 DataLoader results through RenderContext:

      {:ok, data_result} = DataLoader.load_report(domain, :sales_report, params)
      context = RenderContext.new(report, data_result, config)
      {:ok, output} = Renderer.render_with_context(renderer, context)

  """

  alias AshReports.RenderContext

  @type report_module :: module()
  @type data :: any()
  @type opts :: Keyword.t()
  @type rendered :: String.t() | binary()
  @type render_result :: %{
          content: rendered(),
          metadata: map(),
          context: RenderContext.t()
        }

  # Legacy callback for backward compatibility
  @doc """
  Legacy render callback for backward compatibility.

  Prefer implementing `render_with_context/2` for new renderers.
  """
  @callback render(report_module, data, opts) :: {:ok, rendered} | {:error, term()}

  @doc """
  Enhanced render callback with context support.

  This is the preferred implementation for Phase 3.1 renderers.
  """
  @callback render_with_context(RenderContext.t(), opts) ::
              {:ok, render_result()} | {:error, term()}

  @doc """
  Whether this renderer supports streaming output.
  """
  @callback supports_streaming?() :: boolean()

  @doc """
  The file extension for this format.
  """
  @callback file_extension() :: String.t()

  @doc """
  The MIME content type for this format.
  """
  @callback content_type() :: String.t()

  @doc """
  Validates that the renderer can handle the given context.

  Optional callback for advanced validation.
  """
  @callback validate_context(RenderContext.t()) :: :ok | {:error, term()}

  @doc """
  Prepares the renderer for rendering operations.

  Optional callback for initialization.
  """
  @callback prepare(RenderContext.t(), opts) :: {:ok, RenderContext.t()} | {:error, term()}

  @doc """
  Cleans up after rendering operations.

  Optional callback for cleanup.
  """
  @callback cleanup(RenderContext.t(), render_result()) :: :ok

  # Make optional callbacks optional
  @optional_callbacks [
    render: 3,
    validate_context: 1,
    prepare: 2,
    cleanup: 2
  ]

  @doc """
  Renders a report using the appropriate renderer for the given format.

  Legacy API for backward compatibility. Prefer `render_with_context/3`.
  """
  @spec render(module(), any(), atom(), Keyword.t()) :: {:ok, any()} | {:error, term()}
  def render(report_module, data, format, opts \\ []) do
    renderer = get_renderer(report_module, format)

    if renderer do
      renderer.render(report_module, data, opts)
    else
      {:error, "Unsupported format: #{format}"}
    end
  end

  @doc """
  Renders a report using the enhanced context-aware API.

  This is the main entry point for Phase 3.1 rendering with full context
  and layout support.

  ## Examples

      context = RenderContext.new(report, data_result, config)
      {:ok, result} = Renderer.render_with_context(renderer, context)

  """
  @spec render_with_context(module(), RenderContext.t(), opts()) ::
          {:ok, render_result()} | {:error, term()}
  def render_with_context(renderer, %RenderContext{} = context, opts \\ []) do
    with :ok <- validate_renderer(renderer),
         {:ok, prepared_context} <- prepare_rendering(renderer, context, opts),
         {:ok, result} <- do_render_with_context(renderer, prepared_context, opts),
         :ok <- cleanup_rendering(renderer, prepared_context, result) do
      {:ok, result}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Creates a RenderContext from a report and DataLoader result.

  Convenience function for creating context from Phase 2 output.

  ## Examples

      {:ok, data_result} = DataLoader.load_report(domain, :report_name, params)
      context = Renderer.create_context(report, data_result, config)

  """
  @spec create_context(any(), map(), map()) :: RenderContext.t()
  def create_context(report, data_result, config \\ %{}) do
    RenderContext.new(report, data_result, config)
  end

  @doc """
  Renders a report directly from DataLoader results.

  High-level API that combines context creation and rendering.

  ## Examples

      {:ok, data_result} = DataLoader.load_report(domain, :sales_report, params)
      {:ok, output} = Renderer.render_from_data_result(
        renderer,
        report,
        data_result,
        config
      )

  """
  @spec render_from_data_result(module(), any(), map(), map(), opts()) ::
          {:ok, render_result()} | {:error, term()}
  def render_from_data_result(renderer, report, data_result, config \\ %{}, opts \\ []) do
    context = create_context(report, data_result, config)
    render_with_context(renderer, context, opts)
  end

  @doc """
  Gets available renderers for a report module.

  ## Examples

      renderers = Renderer.get_available_renderers(MyReport)

  """
  @spec get_available_renderers(module()) :: [atom()]
  def get_available_renderers(report_module) do
    formats = [:html, :pdf, :json, :csv, :heex, :xml]

    Enum.filter(formats, fn format ->
      renderer = get_renderer(report_module, format)
      renderer && function_exported?(renderer, :render_with_context, 2)
    end)
  end

  @doc """
  Checks if a renderer supports the given format.

  ## Examples

      if Renderer.supports_format?(MyReport, :pdf) do
        render_as_pdf()
      end

  """
  @spec supports_format?(module(), atom()) :: boolean()
  def supports_format?(report_module, format) do
    renderer = get_renderer(report_module, format)
    renderer && function_exported?(renderer, :render_with_context, 2)
  end

  @doc """
  Gets renderer information for a specific format.

  ## Examples

      info = Renderer.get_renderer_info(MyReport, :html)

  """
  @spec get_renderer_info(module(), atom()) :: map() | nil
  def get_renderer_info(report_module, format) do
    case get_renderer(report_module, format) do
      nil ->
        nil

      renderer ->
        %{
          module: renderer,
          format: format,
          supports_streaming: renderer.supports_streaming?(),
          file_extension: renderer.file_extension(),
          content_type: get_content_type(renderer)
        }
    end
  end

  @doc """
  Validates a renderer module implements the required callbacks.

  ## Examples

      case Renderer.validate_renderer_module(MyRenderer) do
        :ok -> use_renderer(MyRenderer)
        {:error, missing} -> handle_missing_callbacks(missing)
      end

  """
  @spec validate_renderer_module(module()) :: :ok | {:error, [atom()]}
  def validate_renderer_module(renderer) do
    required_callbacks = [
      {:render_with_context, 2},
      {:supports_streaming?, 0},
      {:file_extension, 0},
      {:content_type, 0}
    ]

    missing =
      Enum.filter(required_callbacks, fn {func, arity} ->
        not function_exported?(renderer, func, arity)
      end)

    if missing == [] do
      :ok
    else
      {:error, missing}
    end
  end

  # Private implementation functions

  defp get_renderer(report_module, format) do
    Module.concat(report_module, format |> to_string() |> Macro.camelize())
  rescue
    _ -> nil
  end

  defp validate_renderer(renderer) do
    if function_exported?(renderer, :render_with_context, 2) do
      :ok
    else
      {:error, {:invalid_renderer, renderer}}
    end
  end

  defp prepare_rendering(renderer, context, opts) do
    if function_exported?(renderer, :prepare, 2) do
      renderer.prepare(context, opts)
    else
      {:ok, context}
    end
  end

  defp do_render_with_context(renderer, context, opts) do
    if function_exported?(renderer, :validate_context, 1) do
      case renderer.validate_context(context) do
        :ok -> renderer.render_with_context(context, opts)
        {:error, _reason} = error -> error
      end
    else
      renderer.render_with_context(context, opts)
    end
  end

  defp cleanup_rendering(renderer, context, result) do
    if function_exported?(renderer, :cleanup, 2) do
      renderer.cleanup(context, result)
    else
      :ok
    end
  end

  defp get_content_type(renderer) do
    if function_exported?(renderer, :content_type, 0) do
      renderer.content_type()
    else
      "application/octet-stream"
    end
  end
end
