defmodule AshReports.Info do
  @moduledoc """
  Introspection helpers for AshReports.
  
  This module provides functions to retrieve report definitions and related
  information from domains that use the AshReports extension.
  """

  use Spark.InfoGenerator,
    extension: AshReports.Domain,
    sections: [:reports]

  @doc """
  Gets a specific report by name from a domain.
  """
  @spec report(Ash.Domain.t() | Spark.Dsl.t(), atom()) :: AshReports.Report.t() | nil
  def report(domain_or_dsl_state, name) do
    domain_or_dsl_state
    |> reports()
    |> Enum.find(&(&1.name == name))
  end

  @doc """
  Gets all reports for the given domain.
  """
  @spec reports(Ash.Domain.t() | Spark.Dsl.t()) :: [AshReports.Report.t()]
  def reports(domain_or_dsl_state) do
    Spark.Dsl.Extension.get_entities(domain_or_dsl_state, [:reports])
  end

  @doc """
  Gets all band names from all reports in the domain.
  """
  @spec all_band_names(Ash.Domain.t() | Spark.Dsl.t()) :: [atom()]
  def all_band_names(domain_or_dsl_state) do
    domain_or_dsl_state
    |> reports()
    |> Enum.flat_map(&get_band_names_from_report/1)
    |> Enum.uniq()
  end

  defp get_band_names_from_report(report) do
    get_band_names_recursive(report.bands || [])
  end

  defp get_band_names_recursive(bands) do
    Enum.flat_map(bands, fn band ->
      [band.name | get_band_names_recursive(band.bands || [])]
    end)
  end

  @doc """
  Gets all variable names from all reports in the domain.
  """
  @spec all_variable_names(Ash.Domain.t() | Spark.Dsl.t()) :: [atom()]
  def all_variable_names(domain_or_dsl_state) do
    domain_or_dsl_state
    |> reports()
    |> Enum.flat_map(& &1.variables)
    |> Enum.map(& &1.name)
    |> Enum.uniq()
  end

  @doc """
  Gets all parameter names from all reports in the domain.
  """
  @spec all_parameter_names(Ash.Domain.t() | Spark.Dsl.t()) :: [atom()]
  def all_parameter_names(domain_or_dsl_state) do
    domain_or_dsl_state
    |> reports()
    |> Enum.flat_map(& &1.parameters)
    |> Enum.map(& &1.name)
    |> Enum.uniq()
  end

  @doc """
  Checks if a domain has a specific report.
  """
  @spec has_report?(Ash.Domain.t() | Spark.Dsl.t(), atom()) :: boolean()
  def has_report?(domain_or_dsl_state, name) do
    domain_or_dsl_state
    |> reports()
    |> Enum.any?(&(&1.name == name))
  end

  @doc """
  Gets all driving resources used by reports in the domain.
  """
  @spec driving_resources(Ash.Domain.t() | Spark.Dsl.t()) :: [atom()]
  def driving_resources(domain_or_dsl_state) do
    domain_or_dsl_state
    |> reports()
    |> Enum.map(& &1.driving_resource)
    |> Enum.uniq()
  end
end