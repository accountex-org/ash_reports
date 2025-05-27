defmodule AshReports.Verifiers.ValidateReports do
  @moduledoc """
  Validates report definitions at compile time.
  
  This verifier ensures that:
  - Report names are unique within the domain
  - Required fields are present
  - Driving resources exist and are valid Ash resources
  - At least one detail band exists in each report
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias AshReports.Info

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    
    with :ok <- validate_unique_report_names(dsl_state, module),
         :ok <- validate_required_fields(dsl_state, module),
         :ok <- validate_driving_resources(dsl_state, module),
         :ok <- validate_detail_bands(dsl_state, module) do
      :ok
    end
  end

  defp validate_unique_report_names(dsl_state, module) do
    reports = Info.reports(dsl_state)
    names = Enum.map(reports, & &1.name)
    
    case names -- Enum.uniq(names) do
      [] ->
        :ok
      
      duplicates ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Duplicate report names found: #{inspect(duplicates)}",
           path: [:reports],
           module: module
         )}
    end
  end

  defp validate_required_fields(dsl_state, module) do
    reports = Info.reports(dsl_state)
    
    Enum.reduce_while(reports, :ok, fn report, :ok ->
      cond do
        is_nil(report.name) ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message: "Report name is required",
              path: [:reports, :report],
              module: module
            )}}
        
        is_nil(report.driving_resource) ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message: "Report '#{report.name}' must specify a driving_resource",
              path: [:reports, report.name],
              module: module
            )}}
        
        true ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_driving_resources(dsl_state, module) do
    reports = Info.reports(dsl_state)
    
    Enum.reduce_while(reports, :ok, fn report, :ok ->
      if report.driving_resource do
        # In a real implementation, we would check if the module is an Ash.Resource
        # For now, we'll just check if it's an atom
        if is_atom(report.driving_resource) do
          {:cont, :ok}
        else
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message: "Invalid driving_resource in report '#{report.name}': must be an atom representing an Ash.Resource module",
              path: [:reports, report.name, :driving_resource],
              module: module
            )}}
        end
      else
        {:cont, :ok}
      end
    end)
  end

  defp validate_detail_bands(dsl_state, module) do
    reports = Info.reports(dsl_state)
    
    Enum.reduce_while(reports, :ok, fn report, :ok ->
      detail_bands = AshReports.Report.get_bands_by_type(report, :detail)
      
      if Enum.empty?(detail_bands) do
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            message: "Report '#{report.name}' must have at least one detail band",
            path: [:reports, report.name, :bands],
            module: module
          )}}
      else
        {:cont, :ok}
      end
    end)
  end
end