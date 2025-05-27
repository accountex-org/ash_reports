defmodule AshReports.Parameter do
  @moduledoc """
  Represents a runtime parameter that can be passed to a report.
  """

  defstruct [
    :name,
    :type,
    :required,
    :default,
    :constraints
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: atom(),
          required: boolean(),
          default: any(),
          constraints: Keyword.t()
        }

  @doc """
  Creates a new Parameter struct with the given name, type, and options.
  """
  @spec new(atom(), atom(), Keyword.t()) :: t()
  def new(name, type, opts \\ []) do
    struct(
      __MODULE__,
      [name: name, type: type]
      |> Keyword.merge(opts)
      |> Keyword.put_new(:required, false)
      |> Keyword.put_new(:constraints, [])
    )
  end

  @doc """
  Validates a value against this parameter's type and constraints.
  """
  @spec validate_value(t(), any()) :: {:ok, any()} | {:error, String.t()}
  def validate_value(%__MODULE__{} = param, value) do
    with {:ok, value} <- validate_type(param.type, value),
         {:ok, value} <- validate_constraints(param.type, value, param.constraints) do
      {:ok, value}
    end
  end

  defp validate_type(:string, value) when is_binary(value), do: {:ok, value}
  defp validate_type(:integer, value) when is_integer(value), do: {:ok, value}
  defp validate_type(:float, value) when is_float(value), do: {:ok, value}
  defp validate_type(:float, value) when is_integer(value), do: {:ok, value * 1.0}
  defp validate_type(:boolean, value) when is_boolean(value), do: {:ok, value}
  defp validate_type(:atom, value) when is_atom(value), do: {:ok, value}
  defp validate_type(:date, %Date{} = value), do: {:ok, value}
  defp validate_type(:datetime, %DateTime{} = value), do: {:ok, value}
  defp validate_type(:decimal, %Decimal{} = value), do: {:ok, value}
  defp validate_type(type, value), do: {:error, "Invalid value for type #{type}: #{inspect(value)}"}

  defp validate_constraints(_type, value, []), do: {:ok, value}
  
  defp validate_constraints(:string, value, constraints) do
    cond do
      min = constraints[:min_length] ->
        if String.length(value) < min do
          {:error, "String must be at least #{min} characters long"}
        else
          validate_constraints(:string, value, Keyword.delete(constraints, :min_length))
        end
      
      max = constraints[:max_length] ->
        if String.length(value) > max do
          {:error, "String must be at most #{max} characters long"}
        else
          validate_constraints(:string, value, Keyword.delete(constraints, :max_length))
        end
      
      pattern = constraints[:pattern] ->
        if Regex.match?(pattern, value) do
          validate_constraints(:string, value, Keyword.delete(constraints, :pattern))
        else
          {:error, "String does not match required pattern"}
        end
      
      true ->
        {:ok, value}
    end
  end

  defp validate_constraints(:integer, value, constraints) do
    validate_numeric_constraints(value, constraints)
  end

  defp validate_constraints(:float, value, constraints) do
    validate_numeric_constraints(value, constraints)
  end

  defp validate_constraints(_type, value, _constraints), do: {:ok, value}

  defp validate_numeric_constraints(value, constraints) do
    cond do
      min = constraints[:min] ->
        if value < min do
          {:error, "Value must be at least #{min}"}
        else
          validate_numeric_constraints(value, Keyword.delete(constraints, :min))
        end
      
      max = constraints[:max] ->
        if value > max do
          {:error, "Value must be at most #{max}"}
        else
          validate_numeric_constraints(value, Keyword.delete(constraints, :max))
        end
      
      true ->
        {:ok, value}
    end
  end
end