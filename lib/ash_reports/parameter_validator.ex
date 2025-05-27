defmodule AshReports.ParameterValidator do
  @moduledoc """
  Validates report parameters against their definitions.
  """

  alias AshReports.{Report, Parameter}

  @doc """
  Validates the given parameters against the report's parameter definitions.
  """
  @spec validate(Report.t(), map()) :: {:ok, map()} | {:error, list(String.t())}
  def validate(report, params) when is_map(params) do
    params = stringify_keys(params)
    
    case do_validate(report.parameters || [], params) do
      {:ok, validated} -> {:ok, validated}
      {:error, errors} -> {:error, errors}
    end
  end

  def validate(_report, _params), do: {:error, ["Parameters must be a map"]}

  defp do_validate(param_defs, params) do
    param_defs
    |> Enum.reduce({:ok, %{}, []}, fn param_def, {status, validated, errors} ->
      key = to_string(param_def.name)
      value = Map.get(params, key, param_def.default)
      
      cond do
        is_nil(value) && param_def.required ->
          {:error, validated, ["Missing required parameter: #{param_def.name}" | errors]}
        
        is_nil(value) ->
          {status, validated, errors}
        
        true ->
          case Parameter.validate_value(param_def, value) do
            {:ok, validated_value} ->
              {status, Map.put(validated, param_def.name, validated_value), errors}
            
            {:error, error} ->
              {:error, validated, ["Parameter #{param_def.name}: #{error}" | errors]}
          end
      end
    end)
    |> case do
      {:ok, validated, []} ->
        {:ok, validated}
      
      {_, _validated, errors} ->
        {:error, Enum.reverse(errors)}
    end
  end

  defp stringify_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end