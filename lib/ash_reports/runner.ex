defmodule AshReports.Runner do
  @moduledoc """
  Executes reports by fetching data and processing it through the band hierarchy.

  This module will be fully implemented in Phase 2 with the query system.
  """

  @doc """
  Runs a report with the given parameters and options.

  This is a placeholder that will be implemented in Phase 2.
  """
  @spec run(module(), map(), Keyword.t()) :: {:ok, any()} | {:error, term()}
  def run(report_module, params \\ %{}, opts \\ []) do
    # Placeholder implementation
    # In Phase 2, this will:
    # 1. Validate parameters
    # 2. Build and execute Ash queries
    # 3. Process data through bands
    # 4. Calculate variables and aggregates
    # 5. Return structured report data

    report = report_module.definition()

    {:ok,
     %{
       report: report,
       params: params,
       data: [],
       metadata: %{
         generated_at: DateTime.utc_now(),
         format: opts[:format] || :html
       }
     }}
  end

  @doc """
  Runs a report by domain and report name with parameters and options.

  Alternative API for running reports by name instead of module.
  """
  @spec run_report(module(), atom(), map(), Keyword.t()) :: {:ok, any()} | {:error, term()}
  def run_report(domain, report_name, params \\ %{}, opts \\ []) do
    format = Keyword.get(opts, :format, :html)
    
    with {:ok, data_result} <- AshReports.DataLoader.load_report(domain, report_name, params),
         {:ok, rendered_result} <- render_report(data_result, format, opts) do
      {:ok, %{
        content: rendered_result.content,
        metadata: Map.merge(data_result.metadata, rendered_result.metadata || %{}),
        format: format,
        data: data_result  # Include data for debugging
      }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp render_report(data_result, format, opts) do
    case get_renderer_for_format(format) do
      {:ok, renderer} ->
        context = AshReports.RenderContext.new(data_result.report || %{}, data_result)
        renderer.render_with_context(context, opts)
        
      {:error, _} = error ->
        error
    end
  end

  defp get_renderer_for_format(:html), do: {:ok, AshReports.HtmlRenderer}
  defp get_renderer_for_format(:pdf), do: {:ok, AshReports.PdfRenderer}
  defp get_renderer_for_format(:heex), do: {:ok, AshReports.HeexRenderer}
  defp get_renderer_for_format(:json), do: {:ok, AshReports.JsonRenderer}
  defp get_renderer_for_format(format), do: {:error, "Unknown format: #{format}"}
end
