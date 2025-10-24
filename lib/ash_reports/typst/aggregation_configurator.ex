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

  ## Cumulative Grouping and Memory Implications

  By default, each grouping level includes all fields from previous levels:

      # Level 1: :region → 10 groups
      # Level 2: [:region, :city] → 500 groups
      # Level 3: [:region, :city, :product] → 50,000 groups

  **Memory grows exponentially** with nested grouping. Each group stores
  aggregation state (~600 bytes), so:

      - 10,000 groups ≈ 6 MB
      - 50,000 groups ≈ 30 MB
      - 100,000 groups ≈ 60 MB

  ## Options

  - `cumulative: false` - Disable cumulative grouping (each level only groups by its own field)
  - `max_estimated_groups: N` - Fail if estimated groups exceed limit (default: 100,000)
  - `max_estimated_memory: N` - Fail if estimated memory exceeds limit (default: 100 MB)

  ## Usage

      # Default cumulative grouping
      iex> AggregationConfigurator.build_aggregations(report)
      [%{group_by: :region, level: 1}, %{group_by: [:region, :city], level: 2}]

      # Non-cumulative grouping
      iex> AggregationConfigurator.build_aggregations(report, cumulative: false)
      [%{group_by: :region, level: 1}, %{group_by: :city, level: 2}]

      # Strict validation
      iex> AggregationConfigurator.build_aggregations(report, max_estimated_groups: 10_000)
      {:error, {:memory_limit_exceeded, ...}}
  """

  require Logger

  alias AshReports.Report
  alias AshReports.Typst.ExpressionParser

  @default_max_estimated_groups 100_000
  @default_max_estimated_memory 100_000_000
  @bytes_per_group 600

  @doc """
  Builds grouped aggregation configurations from report DSL.

  Analyzes report groups and creates aggregation configurations with
  optional cumulative grouping (each level includes fields from previous levels).

  ## Parameters

    * `report` - The Report struct
    * `opts` - Options (keyword list):
      - `cumulative` - Enable cumulative grouping (default: true)
      - `max_estimated_groups` - Maximum allowed estimated groups (default: 100,000)
      - `max_estimated_memory` - Maximum allowed estimated memory in bytes (default: 100 MB)
      - `enforce_limits` - Return error on limit violation (default: true)

  ## Returns

    * `{:ok, [config]}` - List of aggregation configs
    * `{:error, reason}` - Validation failed

  ## Examples

      iex> report = %Report{groups: [%{name: :region_group, level: 1, ...}]}
      iex> AggregationConfigurator.build_aggregations(report)
      {:ok, [%{group_by: :region, level: 1, aggregations: [:sum, :count], sort: :asc}]}

      iex> AggregationConfigurator.build_aggregations(report, cumulative: false)
      {:ok, [%{group_by: :region, level: 1}, %{group_by: :city, level: 2}]}
  """
  @spec build_aggregations(Report.t(), keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def build_aggregations(report, opts \\ []) do
    groups = report.groups || []
    cumulative = Keyword.get(opts, :cumulative, true)

    case groups do
      [] ->
        Logger.debug(fn -> "No groups defined in report, skipping aggregation configuration" end)
        {:ok, []}

      group_list ->
        Logger.debug(fn ->
          "Building aggregation configuration for #{length(group_list)} groups (cumulative: #{cumulative})"
        end)

        configs =
          if cumulative do
            build_cumulative_configs(group_list, report)
          else
            build_non_cumulative_configs(group_list, report)
          end

        configs = Enum.reject(configs, &is_nil/1)

        # Validate memory requirements
        case validate_aggregation_memory(configs, report, opts) do
          :ok -> {:ok, configs}
          {:error, _reason} = error -> error
        end
    end
  end

  # Build cumulative configs (each level includes all previous fields)
  defp build_cumulative_configs(group_list, report) do
    {configs, _accumulated_fields} =
      group_list
      |> Enum.sort_by(& &1.level)
      |> Enum.reduce({[], []}, fn group, {configs, accumulated_fields} ->
        field_name = extract_field_for_group(group)
        new_accumulated_fields = [field_name | accumulated_fields]

        config =
          build_aggregation_config_for_group(
            group,
            report,
            Enum.reverse(new_accumulated_fields)
          )

        {[config | configs], new_accumulated_fields}
      end)

    Enum.reverse(configs)
  end

  # Build non-cumulative configs (each level only uses its own field)
  defp build_non_cumulative_configs(group_list, report) do
    group_list
    |> Enum.sort_by(& &1.level)
    |> Enum.map(fn group ->
      field_name = extract_field_for_group(group)
      build_aggregation_config_for_group(group, report, [field_name])
    end)
  end

  @doc """
  Validates aggregation memory requirements and returns error if limits exceeded.

  ## Parameters

    * `configs` - List of aggregation configurations
    * `report` - The Report struct
    * `opts` - Validation options:
      - `max_estimated_groups` - Maximum allowed estimated groups (default: 100,000)
      - `max_estimated_memory` - Maximum allowed estimated memory in bytes (default: 100 MB)
      - `enforce_limits` - Return error on violation (default: true)

  ## Returns

    * `:ok` - Validation passed
    * `{:error, reason}` - Validation failed
  """
  @spec validate_aggregation_memory([map()], Report.t(), keyword()) ::
          :ok | {:error, term()}
  def validate_aggregation_memory(configs, report, opts \\ []) do
    max_groups = Keyword.get(opts, :max_estimated_groups, @default_max_estimated_groups)
    max_memory = Keyword.get(opts, :max_estimated_memory, @default_max_estimated_memory)
    enforce = Keyword.get(opts, :enforce_limits, true)

    # Estimate total groups across all aggregation configs
    total_estimated_groups =
      Enum.reduce(configs, 0, fn config, acc ->
        field_count =
          case config.group_by do
            list when is_list(list) -> length(list)
            _atom -> 1
          end

        estimated_groups = estimate_group_cardinality(field_count)
        acc + estimated_groups
      end)

    estimated_memory = total_estimated_groups * @bytes_per_group

    # Check limits
    cond do
      total_estimated_groups > max_groups and enforce ->
        {:error,
         {:memory_limit_exceeded,
          %{
            reason: :too_many_groups,
            estimated_groups: total_estimated_groups,
            max_groups: max_groups,
            report: report.name,
            message: """
            Estimated group count (#{total_estimated_groups}) exceeds limit (#{max_groups}).
            Consider:
            - Using non-cumulative grouping: build_aggregations(report, cumulative: false)
            - Reducing grouping levels
            - Increasing max_estimated_groups option
            """
          }}}

      estimated_memory > max_memory and enforce ->
        {:error,
         {:memory_limit_exceeded,
          %{
            reason: :memory_too_high,
            estimated_memory: estimated_memory,
            estimated_memory_formatted: format_bytes(estimated_memory),
            max_memory: max_memory,
            max_memory_formatted: format_bytes(max_memory),
            report: report.name,
            message: """
            Estimated memory (#{format_bytes(estimated_memory)}) exceeds limit (#{format_bytes(max_memory)}).
            Consider:
            - Using non-cumulative grouping: build_aggregations(report, cumulative: false)
            - Reducing grouping levels
            - Increasing max_estimated_memory option
            """
          }}}

      estimated_memory > 50_000_000 ->
        # 50 MB threshold for warnings
        Logger.warning("""
        High memory usage estimated for aggregations in report #{report.name}:
          - Total estimated groups: #{total_estimated_groups}
          - Estimated memory: #{format_bytes(estimated_memory)}
          - Consider using non-cumulative grouping or reducing grouping levels

        This is based on heuristics and actual usage may vary.
        """)

        :ok

      true ->
        :ok
    end
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

  # Build aggregation config for a group with specified fields
  defp build_aggregation_config_for_group(group, report, accumulated_fields) do
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
      Logger.debug(fn ->
        """
        Failed to build aggregation config for group #{inspect(group)}:
        #{inspect(error)}
        """
      end)

      Logger.error("Failed to build aggregation config for group")

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
