defmodule AshReports.Typst.AggregationConfigurator do
  @moduledoc """
  Configures streaming aggregations from report DSL definitions.

  This module analyzes report groups and variables to build aggregation
  configurations for the streaming pipeline. It handles cumulative grouping,
  memory estimation, and aggregation type derivation.

  ## Responsibilities

  - Build aggregation configurations from DSL groups
  - Configure cumulative grouping across levels
  - Derive aggregation types from variables
  - Validate memory requirements
  - Estimate group cardinality

  ## Usage

      iex> AggregationConfigurator.build_aggregations(report)
      [%{group_by: :region, aggregations: [:sum, :count], level: 1}]
  """

  require Logger

  alias AshReports.Report
  alias AshReports.Typst.ExpressionParser

  @doc """
  Builds grouped aggregation configurations from report DSL.

  Analyzes report groups and creates aggregation configurations with
  cumulative grouping (each level includes fields from previous levels).

  ## Parameters

    * `report` - The Report struct

  ## Returns

    * List of aggregation configs

  ## Examples

      iex> report = %Report{groups: [%{name: :region_group, level: 1, ...}]}
      iex> AggregationConfigurator.build_aggregations(report)
      [%{group_by: :region, level: 1, aggregations: [:sum, :count], sort: :asc}]
  """
  @spec build_aggregations(Report.t()) :: [map()]
  def build_aggregations(report) do
    groups = report.groups || []

    case groups do
      [] ->
        Logger.debug(fn -> "No groups defined in report, skipping aggregation configuration" end)
        []

      group_list ->
        Logger.debug(fn ->
          "Building aggregation configuration for #{length(group_list)} groups"
        end)

        # Use reduce to accumulate fields from previous levels for cumulative grouping
        # Prepend to lists (O(1)) instead of append (O(n)), then reverse at the end
        {configs, _accumulated_fields} =
          group_list
          |> Enum.sort_by(& &1.level)
          |> Enum.reduce({[], []}, fn group, {configs, accumulated_fields} ->
            # Extract field name for current group
            field_name = extract_field_for_group(group)

            # Prepend to accumulated fields (O(1) instead of O(n))
            new_accumulated_fields = [field_name | accumulated_fields]

            # Build config with cumulative fields (reverse for correct order)
            config =
              build_aggregation_config_for_group_cumulative(
                group,
                report,
                Enum.reverse(new_accumulated_fields)
              )

            # Prepend config (O(1) instead of O(n))
            {[config | configs], new_accumulated_fields}
          end)

        configs = configs |> Enum.reverse() |> Enum.reject(&is_nil/1)

        # Validate memory requirements for cumulative grouping
        validate_aggregation_memory(configs, report)

        configs
    end
  end

  @doc """
  Validates aggregation memory requirements and logs warnings if high.

  ## Parameters

    * `configs` - List of aggregation configurations
    * `report` - The Report struct

  ## Returns

    * `:ok`
  """
  @spec validate_aggregation_memory([map()], Report.t()) :: :ok
  def validate_aggregation_memory(configs, report) do
    # Estimate total groups across all aggregation configs
    total_estimated_groups =
      Enum.reduce(configs, 0, fn config, acc ->
        # Estimate groups for this config based on field count
        # This is a heuristic - actual cardinality depends on data
        field_count =
          case config.group_by do
            list when is_list(list) -> length(list)
            _atom -> 1
          end

        estimated_groups = estimate_group_cardinality(field_count)
        acc + estimated_groups
      end)

    # Estimate memory per group (aggregation state + overhead)
    bytes_per_group = 600
    estimated_memory = total_estimated_groups * bytes_per_group

    # Log warning if memory estimate is high
    if estimated_memory > 50_000_000 do
      # 50 MB threshold
      Logger.warning("""
      High memory usage estimated for aggregations in report #{report.name}:
        - Total estimated groups: #{total_estimated_groups}
        - Estimated memory: #{format_bytes(estimated_memory)}
        - Consider reducing grouping levels or field cardinality

      This is based on heuristics and actual usage may vary.
      """)
    end

    :ok
  end

  # Private Functions

  # Extract field name from a group (helper for cumulative grouping)
  defp extract_field_for_group(group) do
    case ExpressionParser.extract_field_with_fallback(group.expression, group.name) do
      {:ok, field} ->
        field

      _error ->
        Logger.warning(fn ->
          """
          Failed to parse group expression for #{group.name}, falling back to group name.
          Expression: #{inspect(group.expression)}
          """
        end)

        group.name
    end
  end

  # Build aggregation config with cumulative grouping (includes fields from all previous levels)
  defp build_aggregation_config_for_group_cumulative(group, report, accumulated_fields) do
    # Derive aggregation types from variables
    aggregations = derive_aggregations_for_group(group.level, report)

    # Normalize group_by: single field as atom, multiple fields as list
    group_by = normalize_group_by_fields(accumulated_fields)

    Logger.debug(fn ->
      """
      Group #{group.name} (level #{group.level}):
        - Accumulated fields: #{inspect(accumulated_fields)}
        - Normalized group_by: #{inspect(group_by)}
        - Aggregations: #{inspect(aggregations)}
      """
    end)

    %{
      group_by: group_by,
      level: group.level,
      aggregations: aggregations,
      sort: group.sort || :asc
    }
  rescue
    error ->
      Logger.error("""
      Failed to build aggregation config for group #{inspect(group)}:
      #{inspect(error)}
      """)

      nil
  end

  # Normalize group_by fields: single field as atom, multiple fields as list
  defp normalize_group_by_fields([single_field]), do: single_field
  defp normalize_group_by_fields(fields) when is_list(fields), do: fields

  defp derive_aggregations_for_group(group_level, report) do
    variables = report.variables || []

    # Find variables that reset at this group level
    group_variables =
      variables
      |> Enum.filter(fn var ->
        var.reset_on == :group and var.reset_group == group_level
      end)

    # Map variable types to aggregation functions
    aggregation_types =
      group_variables
      |> Enum.map(&map_variable_type_to_aggregation/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    # Default aggregations if none specified
    case aggregation_types do
      [] ->
        Logger.debug(fn ->
          "No group-scoped variables found for level #{group_level}, using defaults"
        end)

        [:sum, :count]

      types ->
        types
    end
  end

  defp map_variable_type_to_aggregation(variable) do
    case variable.type do
      :sum -> :sum
      :average -> :avg
      :count -> :count
      :min -> :min
      :max -> :max
      :first -> :first
      :last -> :last
      _ -> nil
    end
  end

  # Estimate group cardinality based on number of grouping fields
  # This is a rough heuristic - actual cardinality depends on data distribution
  defp estimate_group_cardinality(field_count) when field_count == 1, do: 100
  defp estimate_group_cardinality(field_count) when field_count == 2, do: 1_000
  defp estimate_group_cardinality(field_count) when field_count == 3, do: 5_000
  defp estimate_group_cardinality(field_count) when field_count >= 4, do: 10_000

  # Format bytes for human-readable output
  defp format_bytes(bytes) when bytes < 1_024, do: "#{bytes} bytes"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1_024, 2)} KB"

  defp format_bytes(bytes) when bytes < 1_073_741_824,
    do: "#{Float.round(bytes / 1_048_576, 2)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_073_741_824, 2)} GB"

  # Test-only public interface (DO NOT USE IN PRODUCTION)
  if Mix.env() == :test do
    @doc false
    def __test_build_grouped_aggregations__(report) do
      build_aggregations(report)
    end
  end
end
