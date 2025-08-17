defmodule AshReports.Verifiers.ValidateElements do
  @moduledoc """
  Validates element definitions within bands.

  This verifier ensures that:
  - Element names are unique within each band
  - Element types are valid
  - Required element properties are present
  - Element source references are valid
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias AshReports.Info

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    reports = Info.reports(dsl_state)

    Enum.reduce_while(reports, :ok, fn report, :ok ->
      case verify_report_elements(report, module) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp verify_report_elements(report, module) do
    all_bands = collect_all_bands(report.bands || [])

    Enum.reduce_while(all_bands, :ok, fn band, :ok ->
      case verify_band_elements(band, report, module) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp collect_all_bands(bands) do
    Enum.flat_map(bands, fn band ->
      [band | collect_all_bands(band.bands || [])]
    end)
  end

  defp verify_band_elements(band, report, module) do
    with :ok <- validate_unique_element_names(band, report, module),
         :ok <- validate_element_types(band, report, module) do
      validate_element_properties(band, report, module)
    end
  end

  defp validate_unique_element_names(band, report, module) do
    elements = band.elements || []
    names = Enum.map(elements, & &1.name)

    case names -- Enum.uniq(names) do
      [] ->
        :ok

      duplicates ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "Duplicate element names found in band '#{band.name}': #{inspect(duplicates)}",
           path: [:reports, report.name, :bands, band.name, :elements],
           module: module
         )}
    end
  end

  defp validate_element_types(band, report, module) do
    elements = band.elements || []

    Enum.reduce_while(elements, :ok, fn element, :ok ->
      if element.type in AshReports.element_types() do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            message:
              "Invalid element type '#{element.type}' in element '#{element.name}'. Valid types are: #{inspect(AshReports.element_types())}",
            path: [:reports, report.name, :bands, band.name, :elements, element.name],
            module: module
          )}}
      end
    end)
  end

  defp validate_element_properties(band, report, module) do
    elements = band.elements || []

    Enum.reduce_while(elements, :ok, fn element, :ok ->
      case validate_element_by_type(element, band, report, module) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_element_by_type(%{type: :label} = element, band, report, module) do
    if is_nil(element.text) do
      {:error,
       Spark.Error.DslError.exception(
         message: "Label element '#{element.name}' must have text",
         path: [:reports, report.name, :bands, band.name, :elements, element.name],
         module: module
       )}
    else
      :ok
    end
  end

  defp validate_element_by_type(%{type: :field} = element, band, report, module) do
    if is_nil(element.source) do
      {:error,
       Spark.Error.DslError.exception(
         message: "Field element '#{element.name}' must have a source",
         path: [:reports, report.name, :bands, band.name, :elements, element.name],
         module: module
       )}
    else
      :ok
    end
  end

  defp validate_element_by_type(%{type: :expression} = element, band, report, module) do
    if is_nil(element.expression) do
      {:error,
       Spark.Error.DslError.exception(
         message: "Expression element '#{element.name}' must have an expression",
         path: [:reports, report.name, :bands, band.name, :elements, element.name],
         module: module
       )}
    else
      :ok
    end
  end

  defp validate_element_by_type(%{type: :aggregate} = element, band, report, module) do
    cond do
      is_nil(element.function) ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Aggregate element '#{element.name}' must have a function",
           path: [:reports, report.name, :bands, band.name, :elements, element.name],
           module: module
         )}

      is_nil(element.source) ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Aggregate element '#{element.name}' must have a source",
           path: [:reports, report.name, :bands, band.name, :elements, element.name],
           module: module
         )}

      element.function not in [:sum, :count, :average, :min, :max] ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "Invalid aggregate function '#{element.function}' in element '#{element.name}'",
           path: [:reports, report.name, :bands, band.name, :elements, element.name, :function],
           module: module
         )}

      true ->
        :ok
    end
  end

  defp validate_element_by_type(%{type: :image} = element, band, report, module) do
    if is_nil(element.source) do
      {:error,
       Spark.Error.DslError.exception(
         message: "Image element '#{element.name}' must have a source",
         path: [:reports, report.name, :bands, band.name, :elements, element.name],
         module: module
       )}
    else
      :ok
    end
  end

  defp validate_element_by_type(_element, _band, _report, _module) do
    # Line and Box elements don't have required properties beyond the basics
    :ok
  end
end
