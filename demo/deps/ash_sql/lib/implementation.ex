defmodule AshSql.Implementation do
  @moduledoc false
  @callback table(Ash.Resource.t()) :: String.t()
  @callback schema(Ash.Resource.t()) :: String.t() | nil
  @callback repo(Ash.Resource.t(), :mutate | :read) :: module
  @callback expr(Ecto.Query.t(), Ash.Expr.t(), map, boolean, AshSql.Expr.ExprInfo.t(), term) ::
              {:ok, term, AshSql.Expr.ExprInfo.t()} | {:error, term} | :error
  @callback simple_join_first_aggregates(Ash.Resource.t()) :: list(atom)

  @callback parameterized_type(
              Ash.Type.t() | Ecto.Type.t(),
              constraints :: Keyword.t()
            ) ::
              term

  @callback storage_type(resource :: Ash.Resource.t(), field :: atom()) :: nil | term

  @callback ilike?() :: boolean()

  @callback determine_types(module, list(term)) :: {list(term), term} | list(term)
  @callback determine_types(module, list(term), returns :: term) ::
              {list(term), term} | list(term)

  @callback list_aggregate(Ash.Resource.t()) :: String.t() | nil

  @callback multicolumn_distinct?() :: boolean

  @callback manual_relationship_function() :: atom
  @callback manual_relationship_subquery_function() :: atom

  @callback require_ash_functions_for_or_and_and?() :: boolean
  @callback require_extension_for_citext() :: {true, String.t()} | false
  @callback strpos_function() :: String.t()
  @callback type_expr(expr :: term, type :: term) :: term

  @optional_callbacks determine_types: 3

  defmacro __using__(_) do
    quote do
      @behaviour AshSql.Implementation
      require Ecto.Query

      def strpos_function, do: "strpos"

      def expr(_, _, _, _, _, _), do: :error
      def simple_join_first_aggregates(_), do: []
      def list_aggregate(_), do: nil
      def multicolumn_distinct?, do: true
      def require_ash_functions_for_or_and_and?, do: false
      def require_extension_for_citext, do: false
      def ilike?, do: true
      def storage_type(_, _), do: nil

      def type_expr(expr, type) do
        type =
          if Ash.Type.ash_type?(type) do
            parameterized_type(type, [])
          else
            type
          end

        Ecto.Query.dynamic(type(^expr, ^type))
      end

      defoverridable expr: 6,
                     ilike?: 0,
                     strpos_function: 0,
                     require_ash_functions_for_or_and_and?: 0,
                     require_extension_for_citext: 0,
                     simple_join_first_aggregates: 1,
                     type_expr: 2,
                     storage_type: 2,
                     list_aggregate: 1,
                     multicolumn_distinct?: 0
    end
  end
end
