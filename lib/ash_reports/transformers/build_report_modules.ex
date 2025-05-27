defmodule AshReports.Transformers.BuildReportModules do
  @moduledoc """
  Transformer that builds report modules at compile time.
  
  This transformer generates modules for each report defined in the domain,
  creating the necessary infrastructure for report execution and rendering.
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer
  alias AshReports.Info

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
    Enum.map(reports, fn report ->
      report_module = Module.concat([domain_module, "Reports", Macro.camelize(to_string(report.name))])
      
      # Generate the report module
      Module.create(report_module, quote do
        @moduledoc """
        Generated report module for #{unquote(report.name)}.
        
        This module provides the runtime interface for executing and rendering the report.
        """
        
        @report unquote(Macro.escape(report))
        @domain_module unquote(domain_module)
        
        @doc """
        Gets the report definition.
        """
        def definition do
          @report
        end
        
        @doc """
        Gets the domain module this report belongs to.
        """
        def domain do
          @domain_module
        end
        
        @doc """
        Runs the report with the given parameters and options.
        """
        def run(params \\ %{}, opts \\ []) do
          AshReports.Runner.run(__MODULE__, params, opts)
        end
        
        @doc """
        Renders the report in the specified format.
        """
        def render(data, format \\ :html, opts \\ []) do
          AshReports.Renderer.render(__MODULE__, data, format, opts)
        end
        
        @doc """
        Validates the given parameters against the report's parameter definitions.
        """
        def validate_params(params) do
          AshReports.ParameterValidator.validate(@report, params)
        end
        
        @doc """
        Gets the Ash query for fetching report data.
        """
        def build_query(params \\ %{}) do
          AshReports.QueryBuilder.build(@report, params)
        end
        
        @doc """
        Lists all supported formats for this report.
        """
        def supported_formats do
          @report.formats || [:html]
        end
        
        @doc """
        Checks if a format is supported by this report.
        """
        def supports_format?(format) do
          format in supported_formats()
        end
        
        # Generate format-specific modules if needed
        unquote(generate_format_modules(report_module, report))
      end, Macro.Env.location(__ENV__))
      
      {report.name, report_module}
    end)
    |> Map.new()
  end

  defp generate_format_modules(base_module, report) do
    formats = report.formats || [:html]
    
    Enum.map(formats, fn format ->
      format_module = Module.concat(base_module, format |> to_string() |> Macro.camelize())
      
      quote do
        defmodule unquote(format_module) do
          @moduledoc """
          #{unquote(format)} renderer for #{unquote(report.name)} report.
          """
          
          @behaviour AshReports.Renderer
          
          @impl true
          def render(report_module, data, opts) do
            # Format-specific rendering logic will be implemented
            # by the renderer modules in Phase 3
            {:ok, "Rendering not yet implemented for #{unquote(format)}"}
          end
          
          @impl true
          def supports_streaming? do
            # Most formats support streaming except JSON which needs the full structure
            unquote(format) != :json
          end
          
          @impl true
          def file_extension do
            case unquote(format) do
              :html -> ".html"
              :pdf -> ".pdf"
              :heex -> ".heex"
              :json -> ".json"
              _ -> ".txt"
            end
          end
        end
      end
    end)
  end

  @impl true
  def after?(AshReports.Verifiers.ValidateReports), do: true
  def after?(AshReports.Verifiers.ValidateBands), do: true
  def after?(AshReports.Verifiers.ValidateElements), do: true
  def after?(_), do: false

  @impl true
  def before?(_), do: false
end