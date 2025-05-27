defmodule AshReports.Verifiers.ValidateBands do
  @moduledoc """
  Validates band definitions within reports.
  
  This verifier ensures that:
  - Band names are unique within each report
  - Band types are valid
  - Group bands have appropriate group_level settings
  - Detail bands have appropriate detail_number settings
  - Band hierarchy follows proper ordering rules
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias AshReports.Info

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    reports = Info.reports(dsl_state)
    
    Enum.reduce_while(reports, :ok, fn report, :ok ->
      case verify_report_bands(report, module) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp verify_report_bands(report, module) do
    with :ok <- validate_unique_band_names(report, module),
         :ok <- validate_band_types(report, module),
         :ok <- validate_group_bands(report, module),
         :ok <- validate_detail_bands(report, module),
         :ok <- validate_band_hierarchy(report, module) do
      :ok
    end
  end

  defp validate_unique_band_names(report, module) do
    all_bands = collect_all_bands(report.bands || [])
    names = Enum.map(all_bands, & &1.name)
    
    case names -- Enum.uniq(names) do
      [] ->
        :ok
      
      duplicates ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Duplicate band names found in report '#{report.name}': #{inspect(duplicates)}",
           path: [:reports, report.name, :bands],
           module: module
         )}
    end
  end

  defp collect_all_bands(bands) do
    Enum.flat_map(bands, fn band ->
      [band | collect_all_bands(band.bands || [])]
    end)
  end

  defp validate_band_types(report, module) do
    all_bands = collect_all_bands(report.bands || [])
    
    Enum.reduce_while(all_bands, :ok, fn band, :ok ->
      if band.type in AshReports.band_types() do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            message: "Invalid band type '#{band.type}' in band '#{band.name}'. Valid types are: #{inspect(AshReports.band_types())}",
            path: [:reports, report.name, :bands, band.name],
            module: module
          )}}
      end
    end)
  end

  defp validate_group_bands(report, module) do
    all_bands = collect_all_bands(report.bands || [])
    group_bands = Enum.filter(all_bands, &(&1.type in [:group_header, :group_footer]))
    
    Enum.reduce_while(group_bands, :ok, fn band, :ok ->
      cond do
        is_nil(band.group_level) ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message: "Group band '#{band.name}' must specify a group_level",
              path: [:reports, report.name, :bands, band.name],
              module: module
            )}}
        
        not is_integer(band.group_level) or band.group_level < 1 ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message: "Group band '#{band.name}' must have a positive integer group_level",
              path: [:reports, report.name, :bands, band.name, :group_level],
              module: module
            )}}
        
        true ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_detail_bands(report, module) do
    all_bands = collect_all_bands(report.bands || [])
    detail_bands = Enum.filter(all_bands, &(&1.type == :detail))
    
    # Group detail bands by their detail_number
    detail_numbers = 
      detail_bands
      |> Enum.map(& &1.detail_number)
      |> Enum.reject(&is_nil/1)
    
    # If detail_numbers are used, they should be sequential starting from 1
    if not Enum.empty?(detail_numbers) do
      sorted = Enum.sort(detail_numbers)
      expected = Enum.to_list(1..length(detail_numbers))
      
      if sorted != expected do
        {:error,
         Spark.Error.DslError.exception(
           message: "Detail band numbers must be sequential starting from 1. Found: #{inspect(sorted)}",
           path: [:reports, report.name, :bands],
           module: module
         )}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp validate_band_hierarchy(report, module) do
    # Validate that the band hierarchy follows proper ordering
    # This is a simplified check - in a real implementation, we might want
    # to enforce stricter ordering rules
    
    band_types = report.bands |> Enum.map(& &1.type)
    
    # Check that title band, if present, comes first
    title_index = Enum.find_index(band_types, &(&1 == :title))
    summary_index = Enum.find_index(band_types, &(&1 == :summary))
    
    cond do
      title_index && title_index != 0 ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Title band must be the first band in the report",
           path: [:reports, report.name, :bands],
           module: module
         )}
      
      summary_index && summary_index != length(band_types) - 1 ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Summary band must be the last band in the report",
           path: [:reports, report.name, :bands],
           module: module
         )}
      
      true ->
        :ok
    end
  end
end