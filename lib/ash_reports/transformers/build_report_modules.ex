defmodule AshReports.Transformers.BuildReportModules do
  @moduledoc """
  Transformer that builds report modules at compile time.

  This transformer generates modules for each report defined in the domain,
  creating the necessary infrastructure for report execution and rendering.
  """

  use Spark.Dsl.Transformer

  alias AshReports.Info
  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)
    reports = Info.reports(dsl_state)

    # Store report metadata for runtime access
    dsl_state =
      dsl_state
      |> Transformer.persist(:ash_reports, reports)
      |> Transformer.persist(:ash_reports_modules, build_report_modules(module, reports))

    {:ok, dsl_state}
  end

  defp build_report_modules(domain_module, reports) do
    reports
    |> Enum.map(&build_single_report_module(domain_module, &1))
    |> Map.new()
  end

  defp build_single_report_module(domain_module, report) do
    report_module = generate_report_module_name(domain_module, report.name)
    module_ast = generate_report_module_ast(report, domain_module, report_module)

    Module.create(report_module, module_ast, Macro.Env.location(__ENV__))

    {report.name, report_module}
  end

  defp generate_report_module_name(domain_module, report_name) do
    Module.concat([domain_module, "Reports", Macro.camelize(to_string(report_name))])
  end

  defp generate_report_module_ast(report, domain_module, report_module) do
    module_attributes = generate_module_attributes(report, domain_module)
    interface_functions = generate_interface_functions()
    format_modules = generate_format_modules(report_module, report)

    quote do
      unquote_splicing(module_attributes)
      unquote_splicing(interface_functions)
      unquote(format_modules)
    end
  end

  defp generate_module_attributes(report, domain_module) do
    [
      quote do
        @moduledoc """
        Generated report module for #{unquote(report.name)}.
        This module provides the runtime interface for executing and rendering the report.
        """
      end,
      quote do
        @report unquote(Macro.escape(report))
        @domain_module unquote(domain_module)
      end
    ]
  end

  defp generate_interface_functions do
    basic_functions() ++ execution_functions() ++ utility_functions()
  end

  defp basic_functions do
    [
      quote do
        @doc "Gets the report definition."
        def definition, do: @report
      end,
      quote do
        @doc "Gets the domain module this report belongs to."
        def domain, do: @domain_module
      end
    ]
  end

  defp execution_functions do
    [
      quote do
        @doc "Runs the report with the given parameters and options."
        def run(params \\ %{}, opts \\ []) do
          AshReports.Runner.run(__MODULE__, params, opts)
        end
      end,
      quote do
        @doc "Renders the report in the specified format."
        def render(data, format \\ :html, opts \\ []) do
          AshReports.Renderer.render(__MODULE__, data, format, opts)
        end
      end,
      quote do
        @doc "Validates the given parameters against the report's parameter definitions."
        def validate_params(params) do
          AshReports.ParameterValidator.validate(@report, params)
        end
      end,
      quote do
        @doc "Gets the Ash query for fetching report data."
        def build_query(params \\ %{}) do
          AshReports.QueryBuilder.build(@report, params)
        end
      end
    ]
  end

  defp utility_functions do
    [
      quote do
        @doc "Lists all supported formats for this report."
        def supported_formats, do: @report.formats || [:html]
      end,
      quote do
        @doc "Checks if a format is supported by this report."
        def supports_format?(format), do: format in supported_formats()
      end
    ]
  end

  defp generate_format_modules(base_module, report) do
    formats = report.formats || [:html]
    Enum.map(formats, &generate_single_format_module(base_module, report, &1))
  end

  defp generate_single_format_module(base_module, report, format) do
    format_module = Module.concat(base_module, format |> to_string() |> Macro.camelize())

    quote do
      defmodule unquote(format_module) do
        @moduledoc """
        #{unquote(format)} renderer for #{unquote(report.name)} report.
        """

        @behaviour AshReports.Renderer

        @impl true
        def render(report_module, data, opts) do
          {:ok, "Rendering not yet implemented for #{unquote(format)}"}
        end

        @impl true
        def render_with_context(context, opts) do
          {:ok,
           %{
             content: "Rendering not yet implemented for #{unquote(format)}",
             metadata: %{format: unquote(format)},
             context: context
           }}
        end

        @impl true
        def supports_streaming?, do: unquote(format) != :json

        @impl true
        def file_extension, do: unquote(get_file_extension(format))

        @impl true
        def content_type, do: unquote(get_content_type(format))
      end
    end
  end

  defp get_file_extension(:html), do: ".html"
  defp get_file_extension(:pdf), do: ".pdf"
  defp get_file_extension(:heex), do: ".heex"
  defp get_file_extension(:json), do: ".json"
  defp get_file_extension(_), do: ".txt"

  defp get_content_type(:html), do: "text/html"
  defp get_content_type(:pdf), do: "application/pdf"
  defp get_content_type(:heex), do: "text/html"
  defp get_content_type(:json), do: "application/json"
  defp get_content_type(_), do: "text/plain"

  @impl true
  def after?(AshReports.Verifiers.ValidateReports), do: true
  def after?(AshReports.Verifiers.ValidateBands), do: true
  def after?(AshReports.Verifiers.ValidateElements), do: true
  def after?(_), do: false

  @impl true
  def before?(_), do: false
end
