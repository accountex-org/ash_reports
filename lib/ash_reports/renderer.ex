defmodule AshReports.Renderer do
  @moduledoc """
  Behaviour for report renderers.

  Each output format (HTML, PDF, HEEX, JSON) implements this behaviour
  to provide format-specific rendering capabilities.
  """

  @type report_module :: module()
  @type data :: any()
  @type opts :: Keyword.t()
  @type rendered :: String.t() | binary()

  @doc """
  Renders the report data in the specific format.
  """
  @callback render(report_module, data, opts) :: {:ok, rendered} | {:error, term()}

  @doc """
  Whether this renderer supports streaming output.
  """
  @callback supports_streaming?() :: boolean()

  @doc """
  The file extension for this format.
  """
  @callback file_extension() :: String.t()

  @doc """
  Renders a report using the appropriate renderer for the given format.
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

  defp get_renderer(report_module, format) do
    Module.concat(report_module, format |> to_string() |> Macro.camelize())
  rescue
    _ -> nil
  end
end
