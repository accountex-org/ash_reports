defmodule Cldr.Decimal do
  @moduledoc """
  Adds a compatibility layer for functions which changed
  either semantics or returns types between Decimal version
  1.x and 2.x.

  """
  decimal_version = Application.ensure_all_started(:decimal) &&
                     Application.spec(:decimal, :vsn)
                     |> List.to_string()

  # To cater for both Decimal 1.x and 2.x
  if Code.ensure_loaded?(Decimal) && function_exported?(Decimal, :normalize, 1) do
    def reduce(decimal) do
      Decimal.normalize(decimal)
    end
  else
    def reduce(decimal) do
      Decimal.reduce(decimal)
    end
  end

  @spec compare(Decimal.t(), Decimal.t()) :: :eq | :lt | :gt
  if Version.match?(decimal_version, "~> 1.6 or ~> 1.9.0-rc or ~> 1.9") do
    def compare(d1, d2) do
      Decimal.cmp(d1, d2)
    end
  else
    def compare(d1, d2) do
      Decimal.compare(d1, d2)
    end
  end

  if Version.match?(decimal_version, "~> 2.0") do
    def parse(string) do
      case Decimal.parse(string) do
        {decimal, ""} -> {decimal, ""}
        _other -> {:error, string}
      end
    end
  else
    def parse(string) do
      case Decimal.parse(string) do
        {:ok, decimal} -> {decimal, ""}
        _other -> {:error, string}
      end
    end
  end
end
