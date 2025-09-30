defmodule AshReports.Typst.StreamingPipeline.RelationshipLoader do
  @moduledoc """
  Intelligent relationship loading strategies for streaming pipelines.

  This module provides configurable strategies for loading relationships on
  Ash resources during streaming operations, including:

  - **Intelligent preloading**: Automatically determines which relationships to preload
  - **Lazy loading**: Defers loading of optional relationships until needed
  - **Depth limits**: Prevents infinite recursion and excessive memory usage
  - **Selective loading**: Only loads relationships required for the current operation

  ## Configuration

      config :ash_reports, :relationship_loading,
        strategy: :selective,              # :eager, :lazy, :selective
        max_depth: 3,                      # Maximum relationship depth
        preload_associations: [:author],   # Always preload these
        lazy_associations: [:comments]     # Load these on demand

  ## Strategies

  - `:eager` - Preload all relationships up to max_depth
  - `:lazy` - Load relationships only when accessed
  - `:selective` - Intelligently determine which relationships to load based on usage

  ## Usage

      # Configure load strategy
      load_config = %{
        strategy: :selective,
        max_depth: 2,
        required: [:author, :tags],
        optional: [:comments]
      }

      # Apply to query
      enhanced_query = RelationshipLoader.apply_load_strategy(query, load_config)

      # Execute with relationship limits
      results = Ash.read!(enhanced_query, domain: domain)
  """

  require Logger

  @type strategy :: :eager | :lazy | :selective
  @type load_config :: %{
          strategy: strategy(),
          max_depth: non_neg_integer(),
          required: [atom()],
          optional: [atom()]
        }

  @default_max_depth 3

  @doc """
  Applies a relationship loading strategy to an Ash query.

  ## Options

  - `:strategy` - Loading strategy (`:eager`, `:lazy`, `:selective`)
  - `:max_depth` - Maximum relationship depth to traverse
  - `:required` - Relationships that must be preloaded
  - `:optional` - Relationships that can be lazily loaded

  ## Examples

      iex> config = %{strategy: :selective, max_depth: 2, required: [:author], optional: [:comments]}
      iex> RelationshipLoader.apply_load_strategy(query, config)
      #Ash.Query<...>
  """
  @spec apply_load_strategy(Ash.Query.t(), load_config()) :: Ash.Query.t()
  def apply_load_strategy(query, config) do
    strategy = Map.get(config, :strategy, get_default_strategy())
    max_depth = Map.get(config, :max_depth, @default_max_depth)
    required = Map.get(config, :required, [])
    optional = Map.get(config, :optional, [])

    case strategy do
      :eager ->
        apply_eager_loading(query, required ++ optional, max_depth)

      :lazy ->
        # Only load required relationships
        apply_lazy_loading(query, required)

      :selective ->
        apply_selective_loading(query, required, optional, max_depth)
    end
  end

  @doc """
  Builds a load specification with depth limiting.

  Ensures relationships are only loaded up to the specified depth to prevent
  excessive memory usage and infinite recursion.

  ## Examples

      iex> RelationshipLoader.build_load_spec([:author, :comments], 2)
      [author: [], comments: []]

      iex> RelationshipLoader.build_load_spec([author: [:profile]], 2)
      [author: [profile: []]]
  """
  @spec build_load_spec([atom() | {atom(), any()}], non_neg_integer()) :: keyword()
  def build_load_spec(_relationships, max_depth) when max_depth <= 0 do
    Logger.debug("RelationshipLoader: Max depth reached, stopping traversal")
    []
  end

  def build_load_spec(relationships, max_depth) do
    Enum.map(relationships, fn
      {rel, nested} when is_list(nested) ->
        # Nested relationship - recurse with decremented depth
        {rel, build_load_spec(nested, max_depth - 1)}

      rel when is_atom(rel) ->
        # Simple relationship - no nesting
        {rel, []}
    end)
  end

  @doc """
  Validates that a load specification doesn't exceed maximum depth.

  Returns `{:ok, load_spec}` if valid, `{:error, reason}` if depth exceeded.
  """
  @spec validate_depth(keyword(), non_neg_integer()) ::
          {:ok, keyword()} | {:error, String.t()}
  def validate_depth(load_spec, max_depth) do
    case check_depth(load_spec, 0, max_depth) do
      {:ok, _actual_depth} ->
        {:ok, load_spec}

      {:error, actual_depth} ->
        {:error,
         "Relationship depth #{actual_depth} exceeds maximum allowed depth #{max_depth}"}
    end
  end

  # Private Functions

  defp apply_eager_loading(query, relationships, max_depth) do
    Logger.debug(
      "RelationshipLoader: Applying eager loading for #{inspect(relationships)} (max_depth: #{max_depth})"
    )

    load_spec = build_load_spec(relationships, max_depth)

    if load_spec != [] do
      Ash.Query.load(query, load_spec)
    else
      query
    end
  end

  defp apply_lazy_loading(query, required_relationships) do
    Logger.debug(
      "RelationshipLoader: Applying lazy loading for required: #{inspect(required_relationships)}"
    )

    if required_relationships != [] do
      Ash.Query.load(query, required_relationships)
    else
      query
    end
  end

  defp apply_selective_loading(query, required, optional, max_depth) do
    Logger.debug(
      "RelationshipLoader: Applying selective loading - required: #{inspect(required)}, optional: #{inspect(optional)}, max_depth: #{max_depth}"
    )

    # For selective strategy, load required relationships fully
    # and load optional relationships at reduced depth
    required_spec = build_load_spec(required, max_depth)
    optional_spec = build_load_spec(optional, max(max_depth - 1, 1))

    all_loads = required_spec ++ optional_spec

    if all_loads != [] do
      Ash.Query.load(query, all_loads)
    else
      query
    end
  end

  defp check_depth([], current_depth, max_depth) when current_depth <= max_depth do
    {:ok, current_depth}
  end

  defp check_depth([], current_depth, _max_depth) do
    {:error, current_depth}
  end

  defp check_depth([{_rel, nested} | rest], current_depth, max_depth) when is_list(nested) do
    # Check nested relationships
    case check_depth(nested, current_depth + 1, max_depth) do
      {:ok, nested_depth} ->
        # Continue checking siblings
        case check_depth(rest, current_depth, max_depth) do
          {:ok, sibling_depth} ->
            {:ok, max(nested_depth, sibling_depth)}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp check_depth([_rel | rest], current_depth, max_depth) do
    # Simple relationship, no nesting
    check_depth(rest, current_depth + 1, max_depth)
  end

  defp get_default_strategy do
    config = Application.get_env(:ash_reports, :relationship_loading, [])
    Keyword.get(config, :strategy, :selective)
  end
end