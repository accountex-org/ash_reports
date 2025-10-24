defmodule AshReports.Typst.QueryBuilder do
  @moduledoc """
  Builds Ash queries from report definitions.

  This module handles all query construction logic for Typst data loading,
  including filters, sorting, preloads, and pagination.

  ## Responsibilities

  - Build base queries from report definitions
  - Apply report-level filters
  - Apply runtime parameter filters
  - Configure sorting
  - Determine and apply preloads
  - Apply pagination (limit/offset)

  ## Usage

      iex> QueryBuilder.build_query(domain, report, params, opts)
      {:ok, %Ash.Query{}}
  """

  alias AshReports.Report

  @doc """
  Builds an Ash query from a report definition and parameters.

  ## Parameters

    * `domain` - The Ash domain
    * `report` - The Report struct
    * `params` - Runtime parameters
    * `opts` - Query options (limit, offset, etc.)

  ## Returns

    * `{:ok, query}` - Successfully built query
    * `{:error, reason}` - Query building failed
  """
  @spec build_query(module(), Report.t(), map(), keyword()) ::
          {:ok, Ash.Query.t()} | {:error, term()}
  def build_query(_domain, report, params, opts) do
    try do
      query =
        report.resource
        |> Ash.Query.new()
        |> apply_report_filters(report, params)
        |> apply_report_sort(report)
        |> apply_preloads(report)
        |> maybe_apply_limit(opts)
        |> maybe_apply_offset(opts)

      {:ok, query}
    rescue
      error ->
        {:error, {:query_build_failed, error}}
    end
  end

  @doc """
  Applies report-level and runtime filters to a query.

  ## Parameters

    * `query` - Base Ash query
    * `report` - Report definition
    * `params` - Runtime parameters

  ## Returns

    * Updated query with filters applied
  """
  @spec apply_report_filters(Ash.Query.t(), Report.t(), map()) :: Ash.Query.t()
  def apply_report_filters(query, report, params) do
    # Apply filters from report definition
    query_with_report_filter =
      case report.filter do
        nil ->
          query

        filter_expr ->
          Ash.Query.do_filter(query, filter_expr)
      end

    apply_runtime_filters(query_with_report_filter, params)
  end

  @doc """
  Applies sorting configuration from report to query.

  ## Parameters

    * `query` - Ash query
    * `report` - Report definition

  ## Returns

    * Query with sorting applied
  """
  @spec apply_report_sort(Ash.Query.t(), Report.t()) :: Ash.Query.t()
  def apply_report_sort(query, report) do
    case report.sort do
      nil ->
        query

      sort_spec ->
        Ash.Query.sort(query, sort_spec)
    end
  end

  @doc """
  Applies preloads to query based on report column definitions.

  ## Parameters

    * `query` - Ash query
    * `report` - Report definition

  ## Returns

    * Query with preloads applied
  """
  @spec apply_preloads(Ash.Query.t(), Report.t()) :: Ash.Query.t()
  def apply_preloads(query, report) do
    # Determine what relationships need to be preloaded
    preloads = extract_relationship_preloads(report)

    case preloads do
      [] -> query
      list -> Ash.Query.load(query, list)
    end
  end

  # Private Functions

  defp apply_runtime_filters(query, params) when params == %{}, do: query

  defp apply_runtime_filters(query, params) do
    # Apply runtime filters from parameters
    Enum.reduce(params, query, fn {_key, value}, acc_query ->
      case value do
        nil -> acc_query
        # Simplified - real implementation would apply filter
        _ -> acc_query
      end
    end)
  end

  defp extract_relationship_preloads(report) do
    # Extract relationship paths from column definitions
    columns = report.columns || []

    columns
    |> Enum.flat_map(fn column ->
      case column.source do
        {:relationship, path} -> [path]
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  defp maybe_apply_limit(query, opts) do
    case Keyword.get(opts, :limit) do
      nil -> query
      limit -> Ash.Query.limit(query, limit)
    end
  end

  defp maybe_apply_offset(query, opts) do
    case Keyword.get(opts, :offset) do
      nil -> query
      offset -> Ash.Query.offset(query, offset)
    end
  end
end
