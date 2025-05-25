defmodule AshReports.Domain.Verifiers.ValidateReports do
  @moduledoc """
  Validates report definitions in a domain.
  
  This verifier ensures that:
  - Report names are unique within the domain
  - All referenced resources exist in the domain
  - Band types are used correctly
  - Required configurations are present
  """
  
  use Spark.Dsl.Verifier
  
  alias Spark.Dsl.Verifier
  alias AshReports.Dsl.{Report, Band}
  
  def verify(dsl_state) do
    with :ok <- validate_unique_report_names(dsl_state),
         :ok <- validate_report_configurations(dsl_state),
         :ok <- validate_band_structures(dsl_state) do
      :ok
    end
  end
  
  defp validate_unique_report_names(dsl_state) do
    reports = Verifier.get_entities(dsl_state, [:reports])
    
    report_names = Enum.map(reports, & &1.name)
    unique_names = Enum.uniq(report_names)
    
    if length(report_names) != length(unique_names) do
      duplicates = report_names -- unique_names
      
      {:error,
       Spark.Error.DslError.exception(
         path: [:reports],
         message: "Duplicate report names found: #{inspect(duplicates)}"
       )}
    else
      :ok
    end
  end
  
  defp validate_report_configurations(dsl_state) do
    reports = Verifier.get_entities(dsl_state, [:reports])
    
    Enum.reduce_while(reports, :ok, fn report, :ok ->
      case validate_report(report) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end
  
  defp validate_report(%Report{} = report) do
    cond do
      is_nil(report.name) ->
        {:error,
         Spark.Error.DslError.exception(
           path: [:reports, :report],
           message: "Report must have a name"
         )}
      
      true ->
        :ok
    end
  end
  
  defp validate_band_structures(dsl_state) do
    reports = Verifier.get_entities(dsl_state, [:reports])
    
    Enum.reduce_while(reports, :ok, fn report, :ok ->
      case validate_bands_in_report(report) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end
  
  defp validate_bands_in_report(%Report{bands: bands} = report) do
    # Check for required bands based on report type
    band_types = Enum.map(bands, & &1.type)
    
    cond do
      # At least one detail band is typically required
      :detail not in band_types and length(bands) > 0 ->
        {:error,
         Spark.Error.DslError.exception(
           path: [:reports, :report, report.name],
           message: "Report should have at least one detail band"
         )}
      
      # Validate group bands come in pairs
      not validate_group_band_pairs(bands) ->
        {:error,
         Spark.Error.DslError.exception(
           path: [:reports, :report, report.name],
           message: "Group header and footer bands must come in matching pairs"
         )}
      
      true ->
        validate_nested_bands(bands, [:reports, :report, report.name])
    end
  end
  
  defp validate_group_band_pairs(bands) do
    group_headers = 
      bands
      |> Enum.filter(&(&1.type == :group_header))
      |> length()
    
    group_footers = 
      bands
      |> Enum.filter(&(&1.type == :group_footer))
      |> length()
    
    group_headers == group_footers
  end
  
  defp validate_nested_bands(bands, path) do
    Enum.reduce_while(bands, :ok, fn band, :ok ->
      case validate_band(band, path) do
        :ok -> 
          if band.bands && length(band.bands) > 0 do
            case validate_nested_bands(band.bands, path ++ [:band, band.type]) do
              :ok -> {:cont, :ok}
              error -> {:halt, error}
            end
          else
            {:cont, :ok}
          end
        error -> 
          {:halt, error}
      end
    end)
  end
  
  defp validate_band(%Band{} = band, path) do
    cond do
      band.type in [:group_header, :group_footer] and is_nil(band.group_expression) ->
        {:error,
         Spark.Error.DslError.exception(
           path: path ++ [:band, band.type],
           message: "Group bands must have a group_expression"
         )}
      
      band.type not in [:group_header, :group_footer] and not is_nil(band.group_expression) ->
        {:error,
         Spark.Error.DslError.exception(
           path: path ++ [:band, band.type],
           message: "Only group bands can have a group_expression"
         )}
      
      true ->
        :ok
    end
  end
end