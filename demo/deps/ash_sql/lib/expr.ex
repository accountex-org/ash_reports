defmodule AshSql.Expr do
  @moduledoc false

  alias Ash.Filter
  alias Ash.Query.{BooleanExpression, Exists, Not, Ref}
  alias Ash.Query.Operator.IsNil

  alias Ash.Query.Function.{
    Ago,
    At,
    CompositeType,
    Contains,
    CountNils,
    DateAdd,
    DateTimeAdd,
    Error,
    Fragment,
    FromNow,
    GetPath,
    If,
    Lazy,
    Length,
    Now,
    Rem,
    Round,
    StartOfDay,
    StringDowncase,
    StringJoin,
    StringLength,
    StringPosition,
    StringSplit,
    StringTrim,
    Today,
    Type
  }

  require Ecto.Query

  defmodule ExprInfo do
    @moduledoc false
    defstruct has_error?: false

    @type t :: %__MODULE__{}
  end

  def parameterized_type(sql_behaviour, {type, constraints}, _, _location) when type != :array do
    sql_behaviour.parameterized_type(type, constraints)
  end

  def parameterized_type(sql_behaviour, type, constraints, _location) do
    sql_behaviour.parameterized_type(type, constraints)
  end

  def sub_expr?(%{location: {:sub_expr, _}}), do: true
  def sub_expr?(_), do: false

  def within?(bindings, types) when is_list(types) do
    Enum.any?(types, &within?(bindings, &1))
  end

  def within?(%{location: {:sub_expr, type}}, type), do: true
  def within?(%{location: type}, type), do: true
  def within?(_, _), do: false

  def set_location(%{location: {:sub_expr, _}} = bindings, :sub_expr), do: bindings

  def set_location(bindings, :sub_expr) do
    Map.update(bindings, :location, {:sub_expr, :select}, &{:sub_expr, &1})
  end

  def set_location(bindings, location) do
    Map.put(bindings, :location, location)
  end

  def dynamic_expr(query, expr, bindings, embedded? \\ false, type \\ nil, acc \\ %ExprInfo{})

  def dynamic_expr(_query, %Filter{expression: nil}, _bindings, _embedded?, _type, acc) do
    # a nil filter means everything
    {true, acc}
  end

  def dynamic_expr(query, %Filter{expression: expression}, bindings, embedded?, type, acc) do
    dynamic_expr(query, expression, bindings, embedded?, type, acc)
  end

  def dynamic_expr(_, true, _, _, _, acc), do: {true, acc}
  def dynamic_expr(_, false, _, _, _, acc), do: {false, acc}

  def dynamic_expr(query, expression, bindings, embedded?, type, acc) do
    do_dynamic_expr(query, expression, bindings, embedded?, acc, type)
  end

  defp do_dynamic_expr(query, expr, bindings, embedded?, acc, type \\ nil) do
    case bindings.sql_behaviour.expr(query, expr, bindings, embedded?, acc, type) do
      {:ok, expr, acc} -> {expr, acc}
      {:error, error} -> {:error, error}
      :error -> default_dynamic_expr(query, expr, bindings, embedded?, acc, type)
    end
  end

  defp default_dynamic_expr(_, {:embed, other}, _bindings, _true, acc, _type) do
    {other, acc}
  end

  defp default_dynamic_expr(query, %Not{expression: expression}, bindings, embedded?, acc, _type) do
    {new_expression, acc} =
      do_dynamic_expr(
        query,
        expression,
        set_location(bindings, :sub_expr),
        embedded?,
        acc,
        :boolean
      )

    {Ecto.Query.dynamic(not (^new_expression)), acc}
  end

  defp default_dynamic_expr(
         query,
         %IsNil{left: left, right: true, embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       ) do
    {left_expr, acc} =
      do_dynamic_expr(
        query,
        left,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc
      )

    {Ecto.Query.dynamic(is_nil(^left_expr)), acc}
  end

  defp default_dynamic_expr(
         query,
         %IsNil{left: left, right: false, embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       ) do
    {left_expr, acc} =
      do_dynamic_expr(
        query,
        left,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc
      )

    {Ecto.Query.dynamic(not is_nil(^left_expr)), acc}
  end

  defp default_dynamic_expr(
         query,
         %IsNil{left: left, right: right, embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       ) do
    {left_expr, acc} =
      do_dynamic_expr(
        query,
        left,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc
      )

    {right_expr, acc} =
      do_dynamic_expr(
        query,
        right,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        :boolean
      )

    {Ecto.Query.dynamic(is_nil(^left_expr) == ^right_expr), acc}
  end

  defp default_dynamic_expr(
         _query,
         %Lazy{arguments: [{m, f, a}]},
         _bindings,
         _embedded?,
         acc,
         _type
       ) do
    {apply(m, f, a), acc}
  end

  defp default_dynamic_expr(
         query,
         %Ago{arguments: [left, right], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       )
       when is_binary(right) or is_atom(right) do
    {left, acc} =
      do_dynamic_expr(
        query,
        left,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        :integer
      )

    {Ecto.Query.dynamic(
       fragment("(?)", datetime_add(^DateTime.utc_now(), ^left * -1, ^to_string(right)))
     ), acc}
  end

  defp default_dynamic_expr(
         query,
         %StartOfDay{arguments: [value], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    case value do
      %DateTime{} = value ->
        dynamic_expr(
          query,
          DateTime.new!(DateTime.to_date(value), Time.new!(0, 0, 0)),
          bindings,
          pred_embedded? || embedded?,
          type,
          acc
        )

      %Date{} = value ->
        dynamic_expr(
          query,
          DateTime.new!(value, Time.new!(0, 0, 0)),
          bindings,
          pred_embedded? || embedded?,
          type,
          acc
        )

      value ->
        {value, acc} = dynamic_expr(query, value, bindings, pred_embedded? || embedded?, nil, acc)

        {Ecto.Query.dynamic(fragment("date_trunc('day', ?)", ^value)), acc}
    end
  end

  defp default_dynamic_expr(
         query,
         %StartOfDay{arguments: [value, time_zone], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    {value, acc} =
      dynamic_expr(
        query,
        value,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        nil,
        acc
      )

    case value do
      %DateTime{} = value ->
        new_datetime =
          value
          |> DateTime.to_date()
          |> DateTime.new!(Time.new!(0, 0, 0), time_zone)

        dynamic_expr(query, new_datetime, bindings, pred_embedded? || embedded?, type, acc)

      %Date{} = value ->
        new_datetime = DateTime.new!(value, Time.new!(0, 0, 0), time_zone)
        dynamic_expr(query, new_datetime, bindings, pred_embedded? || embedded?, type, acc)

      value ->
        {Ecto.Query.dynamic(
           fragment(
             "timezone('UTC', timezone(?, date_trunc('day', timezone(?, ?))))",
             ^time_zone,
             ^time_zone,
             ^value
           )
         ), acc}
    end
  end

  defp default_dynamic_expr(
         query,
         %At{arguments: [left, right], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       ) do
    {left, acc} =
      do_dynamic_expr(
        query,
        left,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        :integer
      )

    {right, acc} =
      do_dynamic_expr(
        query,
        right,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        :integer
      )

    expr =
      if is_integer(right) do
        Ecto.Query.dynamic(fragment("(?)[?]", ^left, ^(right + 1)))
      else
        Ecto.Query.dynamic(fragment("(?)[? + 1]", ^left, ^right))
      end

    {expr, acc}
  end

  defp default_dynamic_expr(
         query,
         %FromNow{arguments: [left, right], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       )
       when is_binary(right) or is_atom(right) do
    {left, acc} =
      do_dynamic_expr(
        query,
        left,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        :integer
      )

    {Ecto.Query.dynamic(
       fragment("(?)", datetime_add(^DateTime.utc_now(), ^left, ^to_string(right)))
     ), acc}
  end

  defp default_dynamic_expr(
         query,
         %DateTimeAdd{arguments: [datetime, amount, interval], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       )
       when is_binary(interval) or is_atom(interval) do
    {datetime, acc} =
      do_dynamic_expr(
        query,
        datetime,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc
      )

    {amount, acc} =
      do_dynamic_expr(
        query,
        amount,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        :integer
      )

    {Ecto.Query.dynamic(fragment("(?)", datetime_add(^datetime, ^amount, ^to_string(interval)))),
     acc}
  end

  defp default_dynamic_expr(
         query,
         %DateAdd{arguments: [date, amount, interval], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       )
       when is_binary(interval) or is_atom(interval) do
    {date, acc} =
      do_dynamic_expr(
        query,
        date,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc
      )

    {amount, acc} =
      do_dynamic_expr(
        query,
        amount,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        :integer
      )

    {Ecto.Query.dynamic(fragment("(?)", datetime_add(^date, ^amount, ^to_string(interval)))), acc}
  end

  defp default_dynamic_expr(
         query,
         %GetPath{
           arguments: [
             %Ref{attribute: %Ash.Resource.Aggregate{} = aggregate, resource: resource} = left,
             right
           ],
           embedded?: pred_embedded?
         } = expr,
         bindings,
         embedded?,
         acc,
         type
       )
       when is_list(right) do
    case bindings.sql_behaviour.expr(query, expr, bindings, true, acc, type) do
      {:ok, expr, acc} ->
        {expr, acc}

      :error ->
        attribute =
          case aggregate.field do
            nil ->
              nil

            %{} = field ->
              field

            field ->
              related = Ash.Resource.Info.related(resource, aggregate.relationship_path)
              Ash.Resource.Info.attribute(related, field)
          end

        attribute_type =
          if attribute do
            attribute.type
          end

        attribute_constraints =
          if attribute do
            attribute.constraints
          end

        {:ok, type, constraints} =
          Ash.Query.Aggregate.kind_to_type(aggregate.kind, attribute_type, attribute_constraints)

        type
        |> Ash.Resource.Info.aggregate_type(aggregate)
        |> split_at_paths(constraints, right)
        |> Enum.reduce(
          do_dynamic_expr(query, left, set_location(bindings, :sub_expr), embedded?, acc),
          fn data, {expr, acc} ->
            do_get_path(query, expr, data, bindings, embedded?, pred_embedded?, acc)
          end
        )
    end
  end

  defp default_dynamic_expr(
         query,
         %GetPath{
           arguments: [%Ref{attribute: %{type: type, constraints: constraints}} = left, right],
           embedded?: pred_embedded?
         } = expr,
         bindings,
         embedded?,
         acc,
         _
       )
       when is_list(right) do
    case bindings.sql_behaviour.expr(query, expr, bindings, true, acc, type) do
      {:ok, expr, acc} ->
        {expr, acc}

      :error ->
        type
        |> split_at_paths(constraints, right)
        |> Enum.reduce(
          do_dynamic_expr(query, left, set_location(bindings, :sub_expr), embedded?, acc),
          fn data, {expr, acc} ->
            do_get_path(query, expr, data, bindings, embedded?, pred_embedded?, acc)
          end
        )
    end
  end

  defp default_dynamic_expr(
         query,
         %Contains{arguments: [left, %Ash.CiString{} = right], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    if bindings.sql_behaviour.ilike?() do
      text = escape_contains(right.string)

      {left, acc} =
        AshSql.Expr.dynamic_expr(
          query,
          left,
          set_location(bindings, :sub_expr),
          pred_embedded? || embedded?,
          :string,
          acc
        )

      {Ecto.Query.dynamic(ilike(^left, ^text)), acc}
    else
      do_dynamic_expr(
        query,
        %Fragment{
          embedded?: pred_embedded?,
          arguments: [
            raw: "#{bindings.sql_behaviour.strpos_function()}((",
            expr: left,
            raw: "), (",
            expr: right,
            raw: ")) > 0"
          ]
        },
        bindings,
        embedded?,
        acc,
        type
      )
    end
  end

  defp default_dynamic_expr(
         query,
         %CountNils{arguments: [list], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    if is_list(list) do
      list =
        Enum.map(list, fn item ->
          %Ash.Query.Operator.IsNil{left: item, right: true}
        end)

      do_dynamic_expr(
        query,
        %Fragment{
          embedded?: pred_embedded?,
          arguments: [
            raw: "(SELECT COUNT(*) FROM unnest(",
            expr: list,
            raw: ") AS item WHERE item IS TRUE)"
          ]
        },
        bindings,
        embedded?,
        acc,
        type
      )
    else
      do_dynamic_expr(
        query,
        %Fragment{
          embedded?: pred_embedded?,
          arguments: [
            raw: "(SELECT COUNT(*) FROM unnest(",
            expr: list,
            raw: ") AS item WHERE item IS NULL)"
          ]
        },
        bindings,
        embedded?,
        acc,
        type
      )
    end
  end

  defp default_dynamic_expr(
         query,
         %Contains{arguments: [left, right], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       )
       when is_binary(right) do
    text = escape_contains(right)

    {left, acc} =
      AshSql.Expr.dynamic_expr(
        query,
        left,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        :string,
        acc
      )

    {Ecto.Query.dynamic(like(^left, ^text)), acc}
  end

  defp default_dynamic_expr(
         query,
         %Contains{arguments: [left, right], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments: [
          raw: "(#{bindings.sql_behaviour.strpos_function()}((",
          expr: left,
          raw: "), (",
          expr: right,
          raw: ")) > 0)"
        ]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %Length{arguments: [list], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments: [
          raw: "array_length((",
          expr: list,
          raw: "), 1)"
        ]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %If{arguments: [condition, when_true, when_false], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    {[condition_type, when_true_type, when_false_type], type} =
      case determine_types(bindings.sql_behaviour, If, [condition, when_true, when_false], type) do
        {[condition_type, when_true], type} ->
          {[condition_type, when_true, when_true], type}

        {[condition_type, when_true, when_false], type} ->
          {[condition_type, when_true, when_false], type}

        {[condition_type, nil, nil], type} ->
          {[condition_type, type, type], type}

        {[condition_type, when_true, nil], type} ->
          {[condition_type, when_true, type], type}

        {[condition_type, nil, when_false], type} ->
          {[condition_type, type, when_false], type}

        {[condition_type, when_true, when_false], type} ->
          {[condition_type, when_true, when_false], type}
      end

    when_true_type = when_true_type || when_false_type || type
    when_false_type = when_false_type || when_true_type || type

    {condition, acc} =
      do_dynamic_expr(
        query,
        condition,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        condition_type
      )

    {when_true, acc} =
      do_dynamic_expr(
        query,
        when_true,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        when_true_type
      )

    {additional_cases, when_false, acc} =
      extract_cases(
        query,
        when_false,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        when_false_type
      )

    additional_case_fragments =
      additional_cases
      |> Enum.flat_map(fn {condition, when_true} ->
        [
          raw: " WHEN ",
          casted_expr: condition,
          raw: " THEN ",
          casted_expr: when_true
        ]
      end)

    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments:
          [
            raw: "(CASE WHEN ",
            casted_expr: condition,
            raw: " THEN ",
            casted_expr: when_true
          ] ++
            additional_case_fragments ++
            [
              raw: " ELSE ",
              casted_expr: when_false,
              raw: " END)"
            ]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %StringJoin{arguments: [values, joiner], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       )
       when is_list(values) do
    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments:
          Enum.reduce(values, [raw: "concat_ws(", expr: joiner], fn value, frag_acc ->
            frag_acc ++ [raw: ", ", expr: value]
          end) ++ [raw: ")"]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %StringJoin{arguments: [values, joiner], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments: [raw: "array_to_string(", expr: values, raw: ", ", expr: joiner, raw: ")"]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %StringPosition{arguments: [left, right], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments: [
          raw: "#{bindings.sql_behaviour.strpos_function()}((",
          expr: left,
          raw: "), (",
          expr: right,
          raw: "))"
        ]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %Rem{arguments: [left, right], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments: [
          raw: "mod(",
          expr: left,
          raw: ", ",
          expr: right,
          raw: ")"
        ]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %StringSplit{arguments: [string, delimiter, options], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    if options[:trim?] do
      require_ash_functions!(query, "string_split(..., trim?: true)")

      do_dynamic_expr(
        query,
        %Fragment{
          embedded?: pred_embedded?,
          arguments: [
            raw: "ash_trim_whitespace(string_to_array(",
            expr: string,
            raw: ", NULLIF(",
            expr: delimiter,
            raw: ", '')))"
          ]
        },
        bindings,
        embedded?,
        acc,
        type
      )
    else
      do_dynamic_expr(
        query,
        %Fragment{
          embedded?: pred_embedded?,
          arguments: [
            raw: "string_to_array(",
            expr: string,
            raw: ", NULLIF(",
            expr: delimiter,
            raw: ", ''))"
          ]
        },
        bindings,
        embedded?,
        acc,
        type
      )
    end
  end

  defp default_dynamic_expr(
         query,
         %StringJoin{arguments: [values], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       )
       when is_list(values) do
    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments:
          [raw: "concat("] ++
            (values
             |> Enum.reduce([], fn value, acc ->
               acc ++ [expr: value]
             end)
             |> Enum.intersperse({:raw, ", "})) ++
            [raw: ")"]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %StringJoin{arguments: [values], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      %StringJoin{arguments: [values, ""], embedded?: pred_embedded?},
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %StringLength{arguments: [value], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments: [raw: "length(normalize(", expr: value, raw: "))"]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %StringDowncase{arguments: [value], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments: [raw: "lower(", expr: value, raw: ")"]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %StringTrim{arguments: [value], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      %Fragment{
        embedded?: pred_embedded?,
        arguments: [
          raw: "REGEXP_REPLACE(REGEXP_REPLACE(",
          expr: value,
          raw: ", '\s+$', ''), '^\s+', '')"
        ]
      },
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %Fragment{arguments: arguments, embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       ) do
    arguments =
      case arguments do
        [{:raw, raw} | rest] ->
          [{:raw, raw} | rest]

        arguments ->
          [{:raw, ""} | arguments]
      end

    arguments =
      case List.last(arguments) do
        nil ->
          arguments

        {:raw, _} ->
          arguments

        _ ->
          arguments ++ [{:raw, ""}]
      end

    {params, fragment_data, _, acc} =
      Enum.reduce(arguments, {[], [], 0, acc}, fn
        {:raw, str}, {params, fragment_data, count, acc} ->
          {params, [{:raw, str} | fragment_data], count, acc}

        {:casted_expr, dynamic}, {params, fragment_data, count, acc} ->
          {item, params, count} =
            {{:^, [], [count]}, [{dynamic, :any} | params], count + 1}

          {params, [{:expr, item} | fragment_data], count, acc}

        {:expr, expr}, {params, fragment_data, count, acc} ->
          {dynamic, acc} =
            do_dynamic_expr(
              query,
              expr,
              set_location(bindings, :sub_expr),
              pred_embedded? || embedded?,
              acc
            )

          {item, params, count} =
            {{:^, [], [count]}, [{dynamic, :any} | params], count + 1}

          {params, [{:expr, item} | fragment_data], count, acc}
      end)

    {%Ecto.Query.DynamicExpr{
       fun: fn _query ->
         {{:fragment, [], Enum.reverse(fragment_data)}, Enum.reverse(params), [], %{}}
       end,
       binding: [],
       file: __ENV__.file,
       line: __ENV__.line
     }, acc}
  end

  defp default_dynamic_expr(
         query,
         %BooleanExpression{op: op, left: left, right: right},
         bindings,
         embedded?,
         acc,
         _type
       ) do
    {left_expr, acc} =
      do_dynamic_expr(query, left, set_location(bindings, :sub_expr), embedded?, acc, :boolean)

    {right_expr, acc} =
      do_dynamic_expr(query, right, set_location(bindings, :sub_expr), embedded?, acc, :boolean)

    expr =
      case op do
        :and ->
          Ecto.Query.dynamic(^left_expr and ^right_expr)

        :or ->
          Ecto.Query.dynamic(^left_expr or ^right_expr)
      end

    {expr, acc}
  end

  defp default_dynamic_expr(
         query,
         %Ash.Query.Function.Minus{arguments: [arg], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    {[determined_type], type} =
      determine_types(bindings.sql_behaviour, Ash.Query.Function.Minus, [arg], type)

    {expr, acc} =
      do_dynamic_expr(
        query,
        arg,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        determined_type || type
      )

    {Ecto.Query.dynamic(-(^expr)), acc}
  end

  defp default_dynamic_expr(
         query,
         %mod{
           __predicate__?: _,
           left: left,
           right: right,
           embedded?: pred_embedded?,
           operator: operator
         },
         bindings,
         embedded?,
         acc,
         type
       ) do
    {[left_type, right_type], type} =
      case operator do
        :/ ->
          {types, result} = determine_types(bindings.sql_behaviour, mod, [left, right], type)

          {types, result} =
            {Enum.map(types, fn
               {Ash.Type.Float, _} -> {Ash.Type.Decimal, []}
               other -> other
             end),
             case result do
               {Ash.Type.Float, _} -> {Ash.Type.Decimal, []}
               other -> other
             end}

          case result do
            {Ash.Type.Decimal, _} ->
              {Enum.map(types, fn _ -> {Ash.Type.Decimal, []} end), result}

            _ ->
              {types, result}
          end

        _ ->
          determine_types(bindings.sql_behaviour, mod, [left, right], type)
      end

    {left_expr, acc} =
      if left_type do
        maybe_type_expr(
          query,
          left,
          set_location(bindings, :sub_expr),
          pred_embedded? || embedded?,
          acc,
          left_type
        )
      else
        do_dynamic_expr(
          query,
          left,
          set_location(bindings, :sub_expr),
          pred_embedded? || embedded?,
          acc,
          left_type
        )
      end

    with :in <- operator,
         {:ok, item_type} <- extract_multidimensional_array_type(right_type),
         {:ok, right} <- extract_list_value(right) do
      Enum.reduce(right, {nil, acc}, fn item, {expr, acc} ->
        {elem_expr, acc} =
          do_dynamic_expr(
            query,
            item,
            set_location(bindings, :sub_expr),
            pred_embedded? || embedded?,
            acc,
            item_type
          )

        if is_nil(expr) do
          {Ecto.Query.dynamic(^left_expr == ^elem_expr), acc}
        else
          {Ecto.Query.dynamic(^expr or ^left_expr == ^elem_expr), acc}
        end
      end)
    else
      _ ->
        {right_expr, acc} =
          if right_type do
            maybe_type_expr(
              query,
              right,
              set_location(bindings, :sub_expr),
              pred_embedded? || embedded?,
              acc,
              right_type
            )
          else
            do_dynamic_expr(
              query,
              right,
              set_location(bindings, :sub_expr),
              pred_embedded? || embedded?,
              acc,
              right_type
            )
          end

        case operator do
          :== ->
            {Ecto.Query.dynamic(^left_expr == ^right_expr), acc}

          :!= ->
            {Ecto.Query.dynamic(^left_expr != ^right_expr), acc}

          :> ->
            {Ecto.Query.dynamic(^left_expr > ^right_expr), acc}

          :< ->
            {Ecto.Query.dynamic(^left_expr < ^right_expr), acc}

          :>= ->
            {Ecto.Query.dynamic(^left_expr >= ^right_expr), acc}

          :<= ->
            {Ecto.Query.dynamic(^left_expr <= ^right_expr), acc}

          :in ->
            {Ecto.Query.dynamic(^left_expr in ^right_expr), acc}

          :+ ->
            {Ecto.Query.dynamic(^left_expr + ^right_expr), acc}

          :- ->
            {Ecto.Query.dynamic(^left_expr - ^right_expr), acc}

          :/ ->
            {Ecto.Query.dynamic(^left_expr / ^right_expr), acc}

          :* ->
            {Ecto.Query.dynamic(^left_expr * ^right_expr), acc}

          :<> ->
            do_dynamic_expr(
              query,
              %Fragment{
                embedded?: pred_embedded?,
                arguments: [
                  raw: "(",
                  casted_expr: left_expr,
                  raw: " || ",
                  casted_expr: right_expr,
                  raw: ")"
                ]
              },
              bindings,
              embedded?,
              acc,
              type
            )

          :|| ->
            cond do
              boolean_type?(left_type) and boolean_type?(right_type) and
                  cant_return_nil?(left) ->
                {Ecto.Query.dynamic(^left_expr or ^right_expr), acc}

              boolean_type?(left_type) and boolean_type?(right_type) ->
                {Ecto.Query.dynamic(coalesce(^left_expr or ^right_expr, false)), acc}

              cannot_be_boolean?(left_type) ->
                {Ecto.Query.dynamic(coalesce(^left_expr, ^right_expr)), acc}

              true ->
                if "ash-functions" in query.__ash_bindings__.sql_behaviour.repo(
                     query.__ash_bindings__.resource,
                     :mutate
                   ).installed_extensions() do
                  do_dynamic_expr(
                    query,
                    %Fragment{
                      embedded?: pred_embedded?,
                      arguments: [
                        raw: "ash_elixir_or(",
                        casted_expr: left_expr,
                        raw: ", ",
                        casted_expr: right_expr,
                        raw: ")"
                      ]
                    },
                    bindings,
                    embedded?,
                    acc,
                    type
                  )
                else
                  if query.__ash_bindings__.sql_behaviour.require_ash_functions_for_or_and_and?() do
                    require_ash_functions!(query, "||")
                  end

                  do_dynamic_expr(
                    query,
                    %Ash.Query.Function.Fragment{
                      embedded?: pred_embedded?,
                      arguments: [
                        raw: "(CASE WHEN (",
                        casted_expr: left_expr,
                        raw: " = FALSE OR ",
                        casted_expr: left_expr,
                        raw: " IS NULL) THEN ",
                        casted_expr: right_expr,
                        raw: " ELSE ",
                        casted_expr: left_expr,
                        raw: "END)"
                      ]
                    },
                    bindings,
                    embedded?,
                    acc,
                    type
                  )
                end
            end

          :&& ->
            cond do
              boolean_type?(left_type) and boolean_type?(right_type) and
                  cant_return_nil?(left) ->
                {Ecto.Query.dynamic(^left_expr and ^right_expr), acc}

              boolean_type?(left_type) and boolean_type?(right_type) ->
                {Ecto.Query.dynamic(coalesce(^left_expr and ^right_expr, false)), acc}

              true ->
                if "ash-functions" in query.__ash_bindings__.sql_behaviour.repo(
                     query.__ash_bindings__.resource,
                     :mutate
                   ).installed_extensions() do
                  do_dynamic_expr(
                    query,
                    %Fragment{
                      embedded?: pred_embedded?,
                      arguments: [
                        raw: "ash_elixir_and(",
                        casted_expr: left_expr,
                        raw: ", ",
                        casted_expr: right_expr,
                        raw: ")"
                      ]
                    },
                    bindings,
                    embedded?,
                    acc,
                    type
                  )
                else
                  if query.__ash_bindings__.sql_behaviour.require_ash_functions_for_or_and_and?() do
                    require_ash_functions!(query, "&&")
                  end

                  do_dynamic_expr(
                    query,
                    %Fragment{
                      embedded?: pred_embedded?,
                      arguments: [
                        raw: "(CASE WHEN (",
                        casted_expr: left_expr,
                        raw: " = FALSE OR ",
                        casted_expr: left_expr,
                        raw: " IS NULL) THEN ",
                        casted_expr: left_expr,
                        raw: " ELSE ",
                        casted_expr: right_expr,
                        raw: "END)"
                      ]
                    },
                    bindings,
                    embedded?,
                    acc,
                    type
                  )
                end
            end

          other ->
            raise "Operator not implemented #{other}"
        end
    end
  end

  defp default_dynamic_expr(query, %MapSet{} = mapset, bindings, embedded?, acc, type) do
    do_dynamic_expr(query, Enum.to_list(mapset), bindings, embedded?, acc, type)
  end

  defp default_dynamic_expr(
         query,
         %Ash.CiString{string: string} = expression,
         bindings,
         embedded?,
         acc,
         type
       ) do
    case query.__ash_bindings__.sql_behaviour.require_extension_for_citext() do
      {true, extension} ->
        require_extension!(query.__ash_bindings__.resource, extension, expression, query)

        do_dynamic_expr(
          query,
          %Ash.Query.Function.Fragment{arguments: [raw: "(", expr: string, raw: "::citext)"]},
          bindings,
          embedded?,
          acc,
          type
        )

      false ->
        do_dynamic_expr(
          query,
          %Ash.Query.Function.Type{arguments: [string, Ash.Type.CiString, []]},
          bindings,
          embedded?,
          acc,
          type
        )
    end
  end

  defp default_dynamic_expr(
         query,
         %Ref{
           attribute: %Ash.Query.Calculation{} = calculation,
           relationship_path: relationship_path
         },
         bindings,
         embedded?,
         acc,
         _type
       ) do
    calculation = %{calculation | load: calculation.name}

    resource =
      Ash.Resource.Info.related(
        bindings.resource,
        List.wrap(bindings[:refs_at_path]) ++ relationship_path
      )

    case Ash.Filter.hydrate_refs(
           calculation.module.expression(calculation.opts, calculation.context),
           %{
             resource: resource,
             aggregates: %{},
             calculations: %{},
             public?: false,
             parent_stack: query.__ash_bindings__[:parent_resources] || []
           }
         ) do
      {:ok, expression} ->
        expression =
          Ash.Filter.move_to_relationship_path(
            expression,
            relationship_path
          )

        expression =
          Ash.Actions.Read.add_calc_context_to_filter(
            expression,
            calculation.context.actor,
            calculation.context.authorize?,
            calculation.context.tenant,
            calculation.context.tracer,
            query.__ash_bindings__[:domain],
            resource,
            parent_stack: query.__ash_bindings__[:parent_resources] || []
          )

        do_dynamic_expr(
          query,
          expression,
          set_location(bindings, :sub_expr),
          embedded?,
          acc,
          {calculation.type, Map.get(calculation, :constraints, [])}
        )

      {:error, error} ->
        raise """
        Failed to hydrate references for resource #{inspect(resource)} in #{inspect(calculation.module.expression(calculation.opts, calculation.context))}

        #{inspect(error)}
        """
    end
  end

  defp default_dynamic_expr(
         query,
         %Ref{
           attribute:
             %Ash.Query.Aggregate{
               kind: :exists,
               relationship_path: agg_relationship_path,
               query: agg_query,
               join_filters: join_filters
             } = aggregate,
           relationship_path: ref_relationship_path
         },
         bindings,
         embedded?,
         acc,
         type
       ) do
    related? = Map.get(aggregate, :related?, true)

    if related? == false do
      filter =
        if is_nil(agg_query.filter) do
          true
        else
          agg_query.filter
        end

      subquery_result =
        aggregate.query
        |> Ash.Query.set_context(query.__ash_bindings__.context)
        |> Ash.Query.set_context(%{
          data_layer: %{
            table: nil,
            parent_bindings: query.__ash_bindings__,
            start_bindings_at: (query.__ash_bindings__.current || 0) + 1
          }
        })
        |> then(fn ash_query ->
          if filter != true do
            require Ash.Query
            Ash.Query.filter(ash_query, filter)
          else
            ash_query
          end
        end)
        |> Ash.Query.data_layer_query()

      case subquery_result do
        {:ok, ecto_query} ->
          subquery = Ecto.Query.exclude(ecto_query, :select)
          {Ecto.Query.dynamic(exists(subquery)), acc}

        {:error, error} ->
          raise "Failed to create unrelated exists subquery: #{inspect(error)}"
      end
    else
      filter =
        if is_nil(agg_query.filter) do
          true
        else
          agg_query.filter
        end

      do_dynamic_expr(
        query,
        %Ash.Query.Exists{
          path: agg_relationship_path,
          expr: filter,
          at_path: ref_relationship_path
        }
        |> Map.put(:__join_filters__, join_filters),
        bindings,
        embedded?,
        acc,
        type
      )
    end
  end

  defp default_dynamic_expr(
         query,
         %Ref{attribute: %Ash.Query.Aggregate{} = aggregate} = ref,
         bindings,
         _embedded?,
         acc,
         _type
       ) do
    %{attribute: aggregate} =
      ref =
      case bindings.aggregate_names[aggregate.name] do
        nil ->
          ref

        name ->
          %{ref | attribute: %{aggregate | name: name}}
      end

    related? = Map.get(aggregate, :related?, true)

    resource = aggregate.resource

    first_optimized_aggregate? =
      AshSql.Aggregate.optimizable_first_aggregate?(resource, aggregate, query)

    {ref_binding, field_name, value, acc} =
      if first_optimized_aggregate? do
        if related? do
          ref =
            %{
              ref
              | attribute: %Ash.Resource.Attribute{name: :fake},
                relationship_path: ref.relationship_path ++ aggregate.relationship_path
            }

          ref_binding = ref_binding(ref, bindings)

          ref =
            %Ash.Query.Ref{
              attribute:
                AshSql.Aggregate.aggregate_field(
                  aggregate,
                  aggregate.query.resource,
                  query
                ),
              relationship_path: ref.relationship_path,
              resource: resource
            }

          ref =
            Ash.Actions.Read.add_calc_context_to_filter(
              ref,
              Map.get(aggregate.context, :actor),
              Map.get(aggregate.context, :authorize?),
              Map.get(aggregate.context, :tenant),
              Map.get(aggregate.context, :tracer),
              query.__ash_bindings__[:domain],
              resource,
              parent_stack: query.__ash_bindings__[:parent_resources] || []
            )

          {value, acc} = do_dynamic_expr(query, ref, query.__ash_bindings__, false, acc)

          if is_nil(ref_binding) do
            reference_error!(query, ref)
          end

          {ref_binding, aggregate.field, value, acc}
        else
          ref_binding = ref_binding(ref, bindings)

          {ref_binding, aggregate.field, nil, acc}
        end
      else
        ref_binding = ref_binding(ref, bindings)

        if is_nil(ref_binding) do
          reference_error!(query, ref)
        end

        {ref_binding, aggregate.name, nil, acc}
      end

    field_name =
      if is_binary(field_name) do
        new_field_name =
          query.__ash_bindings__.aggregate_names[field_name]

        unless new_field_name do
          raise "Unbound aggregate field: #{inspect(field_name)}"
        end

        new_field_name
      else
        field_name
      end

    expr =
      if value do
        value
      else
        if query.__ash_bindings__[:parent?] &&
             ref_binding not in List.wrap(bindings[:lateral_join_bindings]) do
          if bindings[:parent?] do
            Ecto.Query.dynamic(field(parent_as(^ref_binding), ^field_name))
          else
            Ecto.Query.dynamic(field(as(^ref_binding), ^field_name))
          end
        else
          if bindings[:parent?] do
            Ecto.Query.dynamic(field(parent_as(^ref_binding), ^field_name))
          else
            Ecto.Query.dynamic(field(as(^ref_binding), ^field_name))
          end
        end
      end

    type =
      parameterized_type(
        bindings.sql_behaviour,
        aggregate.type,
        aggregate.constraints,
        :expr
      )

    validate_type!(query, type, ref)

    coalesced =
      if is_nil(aggregate.default_value) do
        expr
      else
        if type do
          typed_default =
            query.__ash_bindings__.sql_behaviour.type_expr(aggregate.default_value, type)

          Ecto.Query.dynamic(coalesce(^expr, ^typed_default))
        else
          Ecto.Query.dynamic(coalesce(^expr, ^aggregate.default_value))
        end
      end

    if type do
      {query.__ash_bindings__.sql_behaviour.type_expr(coalesced, type), acc}
    else
      {coalesced, acc}
    end
  end

  defp default_dynamic_expr(
         query,
         %Ash.CustomExpression{expression: expr},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(query, expr, bindings, embedded?, acc, type)
  end

  defp default_dynamic_expr(
         query,
         %Round{arguments: [num | rest], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       ) do
    precision = Enum.at(rest, 0) || 1

    frag =
      %Fragment{
        embedded?: pred_embedded?,
        arguments: [
          raw: "ROUND(",
          expr: num,
          raw: ", ",
          expr: precision,
          raw: ")"
        ]
      }

    do_dynamic_expr(query, frag, bindings, pred_embedded? || embedded?, acc)
  end

  defp default_dynamic_expr(
         query,
         %Type{
           arguments: [
             %Type{arguments: [arg1 | _]},
             type,
             constraints
           ]
         } = type_expr,
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      %{type_expr | arguments: [arg1, type, constraints]},
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %Type{
           arguments: [
             %Ash.Query.Ref{attribute: %{type: type}} = arg1,
             type | _
           ]
         },
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      arg1,
      bindings,
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %Type{arguments: [arg1, arg2, constraints]},
         bindings,
         embedded?,
         acc,
         _type
       ) do
    arg2 = Ash.Type.get_type(arg2)
    arg1 = maybe_uuid_to_binary(arg2, arg1, arg1)

    type =
      parameterized_type(
        bindings.sql_behaviour,
        arg2,
        constraints,
        :expr
      )

    if type do
      bindings =
        case arg1 do
          %Ash.Query.Ref{attribute: %Ash.Resource.Attribute{}} ->
            Map.put(bindings, :no_cast?, true)

          _ ->
            if Ash.Expr.expr?(arg1) do
              bindings
            else
              Map.put(bindings, :no_cast?, true)
            end
        end

      validate_type!(query, type, arg1)

      {expr, acc} = do_dynamic_expr(query, arg1, bindings, embedded?, acc, {arg2, constraints})

      case {type, expr} do
        {{:parameterized, Ash.Type.Map.EctoType, []}, %Ecto.Query.DynamicExpr{}} ->
          {expr, acc}

        {{:parameterized, {Ash.Type.Map.EctoType, []}}, %Ecto.Query.DynamicExpr{}} ->
          {expr, acc}

        _ ->
          {query.__ash_bindings__.sql_behaviour.type_expr(expr, type), acc}
      end
    else
      do_dynamic_expr(query, arg1, bindings, embedded?, acc, arg2)
    end
  end

  defp default_dynamic_expr(
         query,
         %CompositeType{arguments: [arg1, arg2, constraints], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         _type
       )
       when is_map(arg1) do
    type = Ash.Type.get_type(arg2)

    composite_keys = Ash.Type.composite_types(type, constraints)

    type =
      parameterized_type(
        bindings.sql_behaviour,
        type,
        constraints,
        :expr
      )

    values =
      composite_keys
      |> Enum.map(fn config ->
        key = elem(config, 0)
        {:expr, Map.get(arg1, key)}
      end)
      |> Enum.intersperse({:raw, ","})

    frag =
      %Fragment{
        embedded?: pred_embedded?,
        arguments:
          [
            raw: "ROW("
          ] ++
            values ++
            [
              raw: ")"
            ]
      }

    {frag, acc} =
      do_dynamic_expr(query, frag, bindings, embedded?, acc)

    {query.__ash_bindings__.sql_behaviour.type_expr(frag, type), acc}
  end

  defp default_dynamic_expr(
         query,
         %Now{embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      DateTime.utc_now(),
      bindings,
      embedded? || pred_embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %Today{embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type
       ) do
    do_dynamic_expr(
      query,
      Date.utc_today(),
      bindings,
      embedded? || pred_embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %Ash.Query.Parent{expr: expr},
         bindings,
         embedded?,
         acc,
         type
       ) do
    parent? = Map.get(bindings.parent_bindings, :parent_is_parent_as?, true)
    new_bindings = set_location(Map.put(bindings.parent_bindings, :parent?, parent?), :sub_expr)

    do_dynamic_expr(
      %{query | __ash_bindings__: new_bindings},
      expr,
      set_location(new_bindings, :sub_expr),
      embedded?,
      acc,
      type
    )
  end

  defp default_dynamic_expr(
         query,
         %Error{arguments: [exception, input]} = value,
         bindings,
         embedded?,
         acc,
         type
       ) do
    require_ash_functions!(query, "error/2")

    acc = %{acc | has_error?: true}

    unless Keyword.keyword?(input) || is_map(input) do
      raise "Input expression to `error` must be a map or keyword list"
    end

    {encoded, acc} =
      if Ash.Expr.expr?(input) do
        frag_parts =
          Enum.flat_map(input, fn {key, value} ->
            if Ash.Expr.expr?(value) do
              [
                expr: to_string(key),
                raw: "::text, ",
                expr: value,
                raw: ", "
              ]
            else
              [
                expr: to_string(key),
                raw: "::text, ",
                expr: value,
                raw: "::jsonb, "
              ]
            end
          end)

        frag_parts =
          List.update_at(frag_parts, -1, fn {:raw, text} ->
            {:raw, String.trim_trailing(text, ", ") <> "))"}
          end)

        do_dynamic_expr(
          query,
          %Fragment{
            embedded?: false,
            arguments:
              [
                raw: "jsonb_build_object('exception', ",
                expr: inspect(exception),
                raw: "::text, 'input', jsonb_build_object("
              ] ++
                frag_parts
          },
          bindings,
          embedded?,
          acc
        )
      else
        {Jason.encode!(%{exception: inspect(exception), input: Map.new(input)}), acc}
      end

    if type do
      # This is a type hint, if we're raising an error, we tell it what the value
      # type *would* be in this expression so that we can return a "NULL" of that type
      # its weird, but there isn't any other way that I can tell :)
      validate_type!(query, type, value)

      type =
        parameterized_type(
          bindings.sql_behaviour,
          type,
          [],
          :expr
        )

      if type do
        dynamic = Ecto.Query.dynamic(type(fragment("NULL"), ^type))

        {Ecto.Query.dynamic(fragment("ash_raise_error(?::jsonb, ?)", ^encoded, ^dynamic)), acc}
      else
        {Ecto.Query.dynamic(fragment("ash_raise_error(?::jsonb)", ^encoded)), acc}
      end
    else
      {Ecto.Query.dynamic(fragment("ash_raise_error(?::jsonb)", ^encoded)), acc}
    end
  end

  defp default_dynamic_expr(
         query,
         %Exists{related?: false, expr: expr, resource: resource},
         bindings,
         _embedded?,
         acc,
         _type
       ) do
    {:ok, subquery} =
      resource
      |> Ash.Query.new()
      |> Ash.Query.set_context(bindings.context)
      |> Ash.Query.set_context(%{
        data_layer: %{
          parent_bindings: query.__ash_bindings__,
          start_bindings_at: (query.__ash_bindings__.current || 0) + 1
        }
      })
      |> then(fn ash_query ->
        if ash_query.__validated_for_action__ do
          ash_query
        else
          Ash.Query.for_read(
            ash_query,
            Ash.Resource.Info.primary_action!(ash_query.resource, :read).name,
            %{},
            actor: bindings.context[:private][:actor],
            tenant: bindings.context[:private][:tenant]
          )
        end
      end)
      |> Ash.Query.unset([:sort, :distinct, :select, :limit, :offset])
      |> AshSql.Join.handle_attribute_multitenancy(bindings.context[:private][:tenant])
      |> AshSql.Join.hydrate_refs(bindings.context[:private][:actor])
      |> then(fn related_query ->
        if expr != true do
          Ash.Query.do_filter(related_query, expr)
        else
          related_query
        end
      end)
      |> case do
        %{valid?: true} = related_query ->
          case Ash.Query.data_layer_query(related_query) do
            {:ok, ecto_query} ->
              {:ok, Ecto.Query.exclude(ecto_query, :select)}

            {:error, error} ->
              {:error, error}
          end

        %{errors: errors} ->
          {:error, errors}
      end

    # Create the exists dynamic expression
    {Ecto.Query.dynamic(exists(subquery)), acc}
  end

  defp default_dynamic_expr(
         query,
         %Exists{at_path: at_path, path: [first | rest], expr: expr} = exists,
         bindings,
         _embedded?,
         acc,
         _type
       ) do
    resource = Ash.Resource.Info.related(bindings.resource, at_path)
    first_relationship = Ash.Resource.Info.relationship(resource, first)

    unless first_relationship do
      raise Ash.Error.Framework.AssumptionFailed,
        message: """
        Unknown relationship #{inspect(bindings.resource)}.#{first}

        in exists expression: `#{inspect(exists)}`
        """
    end

    filter = Ash.Filter.move_to_relationship_path(expr, rest)

    filter =
      exists
      |> Map.get(:__join_filters__, %{})
      |> Map.fetch([first_relationship.name])
      |> case do
        {:ok, join_filter} ->
          Ash.Query.BooleanExpression.optimized_new(
            :and,
            filter,
            Ash.Filter.move_to_relationship_path(
              join_filter,
              rest ++ [first_relationship.name]
            )
          )

        :error ->
          filter
      end

    filter =
      exists
      |> Map.get(:__join_filters__, %{})
      |> Map.delete([first_relationship.name])
      |> Enum.reduce(filter, fn {path, path_filter}, filter ->
        path = Enum.drop(path, 1)
        parent_path = :lists.droplast(path)

        Ash.Query.BooleanExpression.optimized_new(
          :and,
          filter,
          Ash.Filter.move_to_relationship_path(path_filter, path)
        )
        |> Ash.Filter.map(fn
          %Ash.Query.Parent{expr: expr} ->
            {:halt, Ash.Filter.move_to_relationship_path(expr, parent_path)}

          other ->
            other
        end)
      end)

    query =
      if first_relationship.type == :many_to_many do
        put_in(query.__ash_bindings__[:lateral_join_bindings], [:join_source])
        |> AshSql.Bindings.explicitly_set_binding(
          %{
            type: :left,
            path: [first_relationship.join_relationship]
          },
          :join_source
        )
      else
        query
      end

    {:ok, subquery} =
      AshSql.Join.related_subquery(first_relationship, query,
        filter: filter,
        filter_subquery?: true,
        sort?: Map.get(first_relationship, :from_many?),
        start_bindings_at: 1,
        select_star?: !Map.get(first_relationship, :manual),
        in_group?: true,
        parent_resources: [
          query.__ash_bindings__.resource
          | query.__ash_bindings__[:parent_resources] || []
        ],
        return_subquery?: true,
        on_subquery: fn subquery ->
          subquery =
            Ecto.Query.from(row in subquery, select: row)
            |> Map.put(:__ash_bindings__, subquery.__ash_bindings__)

          cond do
            Map.get(first_relationship, :manual) ->
              {module, opts} = first_relationship.manual

              source_binding =
                ref_binding(
                  %Ref{
                    attribute:
                      Ash.Resource.Info.attribute(resource, first_relationship.source_attribute),
                    relationship_path: at_path,
                    resource: resource
                  },
                  bindings
                )

              {:ok, subquery} =
                apply(
                  module,
                  query.__ash_bindings__.sql_behaviour.manual_relationship_subquery_function(),
                  [
                    opts,
                    source_binding,
                    1,
                    subquery
                  ]
                )

              subquery

            Map.get(first_relationship, :no_attributes?) ->
              subquery

            first_relationship.type == :many_to_many ->
              source_ref =
                ref_binding(
                  %Ref{
                    attribute:
                      Ash.Resource.Info.attribute(resource, first_relationship.source_attribute),
                    relationship_path: at_path,
                    resource: resource
                  },
                  bindings
                )

              through_relationship =
                Ash.Resource.Info.relationship(resource, first_relationship.join_relationship)

              {:ok, through} =
                AshSql.Join.related_subquery(through_relationship, query)

              Ecto.Query.from(destination in subquery,
                join: through in ^through,
                as: ^:join_source,
                on:
                  field(through, ^first_relationship.destination_attribute_on_join_resource) ==
                    field(destination, ^first_relationship.destination_attribute),
                on:
                  field(parent_as(^source_ref), ^first_relationship.source_attribute) ==
                    field(through, ^first_relationship.source_attribute_on_join_resource)
              )

            true ->
              source_ref =
                ref_binding(
                  %Ref{
                    attribute:
                      Ash.Resource.Info.attribute(resource, first_relationship.source_attribute),
                    relationship_path: at_path,
                    resource: resource
                  },
                  bindings
                )

              Ecto.Query.from(destination in subquery,
                where:
                  field(parent_as(^source_ref), ^first_relationship.source_attribute) ==
                    field(destination, ^first_relationship.destination_attribute)
              )
          end
        end
      )

    {Ecto.Query.dynamic(exists(subquery)), acc}
  end

  defp default_dynamic_expr(
         _query,
         %Ref{
           attribute: %Ash.Query.CombinationAttr{
             name: name
           }
         },
         bindings,
         _embedded?,
         acc,
         _expr_type
       ) do
    ref_binding = bindings.root_binding

    dynamic =
      if bindings[:parent?] &&
           ref_binding not in List.wrap(bindings[:lateral_join_bindings]) do
        Ecto.Query.dynamic(field(parent_as(^ref_binding), ^name))
      else
        Ecto.Query.dynamic(field(as(^ref_binding), ^name))
      end

    {dynamic, acc}
  end

  defp default_dynamic_expr(
         query,
         %Ref{
           attribute: %Ash.Resource.Attribute{
             name: name,
             type: attr_type,
             constraints: constraints
           }
         } = ref,
         bindings,
         _embedded?,
         acc,
         expr_type
       ) do
    ref_binding = ref_binding(ref, bindings)

    if is_nil(ref_binding) do
      reference_error!(query, ref)
    end

    constraints =
      if attr_type do
        constraints
      end

    type =
      if !bindings[:no_cast?] do
        parameterized_type(
          bindings.sql_behaviour,
          attr_type || expr_type,
          constraints,
          :expr
        )
      end

    expr =
      case type do
        nil ->
          # magic atoms FTW
          if query.__ash_bindings__[:parent?] &&
               ref_binding not in List.wrap(bindings[:lateral_join_bindings]) do
            Ecto.Query.dynamic(field(parent_as(^ref_binding), ^name))
          else
            Ecto.Query.dynamic(field(as(^ref_binding), ^name))
          end

        type ->
          validate_type!(query, type, ref)

          ref_dynamic =
            if query.__ash_bindings__[:parent?] &&
                 ref_binding not in List.wrap(bindings[:lateral_join_bindings]) do
              Ecto.Query.dynamic(field(parent_as(^ref_binding), ^name))
            else
              Ecto.Query.dynamic(field(as(^ref_binding), ^name))
            end

          query.__ash_bindings__.sql_behaviour.type_expr(ref_dynamic, type)
      end

    {expr, acc}
  end

  defp default_dynamic_expr(
         query,
         %Ref{attribute: %Ash.Resource.Aggregate{name: name}} = ref,
         bindings,
         _embedded?,
         acc,
         _expr_type
       ) do
    ref_binding = ref_binding(ref, bindings)

    if is_nil(ref_binding) do
      reference_error!(query, ref)
    end

    expr =
      if query.__ash_bindings__[:parent?] &&
           ref_binding not in List.wrap(bindings[:lateral_join_bindings]) do
        Ecto.Query.dynamic(field(parent_as(^ref_binding), ^name))
      else
        Ecto.Query.dynamic(field(as(^ref_binding), ^name))
      end

    {expr, acc}
  end

  defp default_dynamic_expr(_query, %Ash.Vector{} = value, _bindings, _embedded?, acc, _type) do
    {value, acc}
  end

  defp default_dynamic_expr(query, value, bindings, embedded?, acc, type)
       when is_map(value) and not is_struct(value) do
    if (within?(bindings, :select) && sub_expr?(bindings)) ||
         (within?(bindings, [:update, :aggregate]) && Ash.Expr.expr?(value)) do
      elements =
        value
        |> Enum.flat_map(fn {key, list_item} ->
          list_item = reverse_engineer_type(list_item)

          if is_atom(key) do
            [
              {:expr, %Ash.Query.Function.Type{arguments: [key, :atom, []]}},
              [
                {:raw, "("},
                {:expr, list_item},
                {:raw, ")"}
              ]
            ]
          else
            [
              {:expr, %Ash.Query.Function.Type{arguments: [key, :string, []]}},
              [{:raw, "("}, {:expr, list_item}, {:raw, ")"}]
            ]
          end
        end)
        |> Enum.intersperse({:raw, ","})
        |> List.flatten()

      do_dynamic_expr(
        query,
        %Fragment{
          embedded?: embedded?,
          arguments:
            squash_raw(
              [
                raw: "jsonb_build_object("
              ] ++ elements ++ [raw: ")"]
            )
        },
        bindings,
        embedded?,
        acc,
        type
      )
    else
      if bindings[:location] == :select do
        Enum.reduce(value, {%{}, acc}, fn {key, value}, {map, acc} ->
          {value, acc} = do_dynamic_expr(query, value, bindings, embedded?, acc)

          {Map.put(map, key, value), acc}
        end)
      else
        {value, acc}
      end
    end
  end

  defp default_dynamic_expr(query, other, bindings, true, acc, type) do
    if other && is_atom(other) && !is_boolean(other) do
      {to_string(other), acc}
    else
      if Ash.Expr.expr?(other) do
        if is_list(other) do
          list_expr(query, other, bindings, true, acc, type)
        else
          case bindings.sql_behaviour.expr(query, other, bindings, true, acc, type) do
            {:ok, expr, acc} ->
              {expr, acc}

            {:error, error} ->
              raise "Error while building expression: #{error}"

            :error ->
              raise "Unsupported expression in #{bindings.sql_behaviour} query: #{inspect(other, structs: false)}"
          end
        end
      else
        handle_literal(query, other, bindings, true, acc, type)
      end
    end
  end

  defp default_dynamic_expr(query, value, bindings, embedded?, acc, {:in, type})
       when is_list(value) do
    list_expr(query, value, bindings, embedded?, acc, {:array, type})
  end

  defp default_dynamic_expr(query, value, bindings, embedded?, acc, type)
       when not is_nil(value) and is_atom(value) and not is_boolean(value) do
    do_dynamic_expr(query, to_string(value), bindings, embedded?, acc, type)
  end

  defp default_dynamic_expr(_, nil, _, _, acc, _) do
    {Ecto.Query.dynamic(fragment("NULL")), acc}
  end

  defp default_dynamic_expr(query, value, bindings, false, acc, type)
       when type == nil or type == :any do
    if is_list(value) do
      list_expr(query, value, bindings, false, acc, type)
    else
      handle_literal(query, value, bindings, true, acc, type)
    end
  end

  defp default_dynamic_expr(query, value, bindings, false, acc, type) do
    if Ash.Expr.expr?(value) do
      if is_list(value) do
        list_expr(query, value, bindings, false, acc, type)
      else
        case bindings.sql_behaviour.expr(query, value, bindings, false, acc, type) do
          {:ok, expr, acc} ->
            {expr, acc}

          {:error, error} ->
            raise "Error while building expression: #{error}"

          :error ->
            raise "Unsupported expression in #{bindings.sql_behaviour} query: #{inspect(value, structs: false)}"
        end
      end
    else
      if bindings[:no_cast?] do
        {value, acc}
      else
        case handle_literal(query, value, bindings, true, acc, type) do
          {^value, acc} ->
            if type do
              type =
                parameterized_type(
                  bindings.sql_behaviour,
                  type,
                  [],
                  :expr
                )

              if type do
                validate_type!(query, type, value)

                {query.__ash_bindings__.sql_behaviour.type_expr(value, type), acc}
              else
                {value, acc}
              end
            else
              {value, acc}
            end

          {value, acc} ->
            {value, acc}
        end
      end
    end
  end

  defp extract_list_value(value) when is_list(value), do: {:ok, value}
  defp extract_list_value(%MapSet{} = value), do: {:ok, value}

  defp extract_list_value(%Ash.Query.Function.Type{arguments: [value | _]}) when is_list(value),
    do: {:ok, value}

  defp extract_list_value(_value), do: :error

  defp extract_multidimensional_array_type({{:array, {:array, type}}, constraints}) do
    {:ok, {{:array, type}, constraints[:items] || []}}
  end

  defp extract_multidimensional_array_type({{:array, type}, constraints}) do
    with true <- Ash.Type.ash_type?(type),
         {:array, _} <- Ash.Type.storage_type(type, constraints[:items] || []) do
      {:ok, {type, constraints[:items] || []}}
    else
      _ -> :error
    end
  end

  defp extract_multidimensional_array_type(_), do: :error

  defp squash_raw(list, trail \\ [])
  defp squash_raw([], trail), do: Enum.reverse(trail)

  defp squash_raw([{:raw, left}, {:raw, right} | rest], trail) do
    squash_raw([{:raw, left <> right} | rest], trail)
  end

  defp squash_raw([other | rest], trail), do: squash_raw(rest, [other | trail])

  # I literally hate this
  defp reverse_engineer_type(value) do
    case value do
      %Type{} = value ->
        value

      list_item when is_integer(list_item) ->
        %Type{arguments: [list_item, :integer, []]}

      list_item when is_float(list_item) ->
        %Type{arguments: [list_item, :float, []]}

      list_item when is_boolean(list_item) ->
        %Type{arguments: [list_item, :boolean, []]}

      list_item when is_binary(list_item) ->
        %Type{arguments: [list_item, :string, []]}

      list_item when is_atom(list_item) ->
        %Type{arguments: [list_item, :atom, []]}

      [] ->
        %Type{arguments: [[], {:array, :string}, []]}

      [item | _] = list_item ->
        %{arguments: [_, type, constraints]} = type_func = reverse_engineer_type(item)
        %{type_func | arguments: [list_item, {:array, type}, [items: constraints || []]]}

      %{} = list_item ->
        %Type{arguments: [list_item, :map, []]}

      %Decimal{} = list_item ->
        %Type{arguments: [list_item, :decimal, []]}

      list_item ->
        list_item
    end
  end

  defp extract_cases(
         query,
         expr,
         bindings,
         embedded?,
         acc,
         type,
         list_acc \\ []
       )

  defp extract_cases(
         query,
         %If{arguments: [condition, when_true, when_false], embedded?: pred_embedded?},
         bindings,
         embedded?,
         acc,
         type,
         list_acc
       ) do
    {[condition_type, when_true_type, when_false_type], type} =
      case determine_types(bindings.sql_behaviour, If, [condition, when_true, when_false], type) do
        {[condition_type, when_true], type} ->
          {[condition_type, when_true, when_true], type}

        {[condition_type, when_true, when_false], type} ->
          {[condition_type, when_true, when_false], type}

        {[condition_type, nil, nil], type} ->
          {[condition_type, type, type], type}

        {[condition_type, when_true, nil], type} ->
          {[condition_type, when_true, type], type}

        {[condition_type, nil, when_false], type} ->
          {[condition_type, type, when_false], type}

        {[condition_type, when_true, when_false], type} ->
          {[condition_type, when_true, when_false], type}
      end

    {condition, acc} =
      do_dynamic_expr(
        query,
        condition,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        condition_type || type
      )

    {when_true, acc} =
      do_dynamic_expr(
        query,
        when_true,
        set_location(bindings, :sub_expr),
        pred_embedded? || embedded?,
        acc,
        when_true_type || type
      )

    extract_cases(
      query,
      when_false,
      set_location(bindings, :sub_expr),
      embedded?,
      acc,
      when_false_type || type,
      [{condition, when_true} | list_acc]
    )
  end

  defp extract_cases(
         query,
         other,
         bindings,
         embedded?,
         acc,
         type,
         list_acc
       ) do
    {expr, acc} =
      do_dynamic_expr(
        query,
        other,
        set_location(bindings, :sub_expr),
        embedded?,
        acc,
        type
      )

    {Enum.reverse(list_acc), expr, acc}
  end

  defp split_at_paths(type, constraints, next, acc \\ [{:bracket, [], nil, nil}])

  defp split_at_paths(_type, _constraints, [], acc) do
    acc
  end

  defp split_at_paths({:array, type}, constraints, [next | rest], [first_acc | rest_acc])
       when is_integer(next) do
    case first_acc do
      {:bracket, path, nil, nil} ->
        split_at_paths(type, constraints[:items] || [], rest, [
          {:bracket, [next | path], type, constraints}
          | rest_acc
        ])

      {:dot, _field, _, _} ->
        split_at_paths(type, constraints[:items] || [], rest, [
          {:bracket, [next], type, constraints},
          first_acc
          | rest_acc
        ])
    end
  end

  defp split_at_paths(type, constraints, [next | rest], [first_acc | rest_acc])
       when is_atom(next) or is_binary(next) do
    bracket_or_dot =
      if type && Ash.Type.composite?(type, constraints) do
        :dot
      else
        :bracket
      end

    {next, type, constraints} =
      cond do
        type && Ash.Type.embedded_type?(type) ->
          type =
            if Ash.Type.NewType.new_type?(type) do
              Ash.Type.NewType.subtype_of(type)
            else
              type
            end

          %{type: type, constraints: constraints} = Ash.Resource.Info.attribute(type, next)
          {next, type, constraints}

        type && Ash.Type.composite?(type, constraints) ->
          condition =
            if is_binary(next) do
              fn {name, _type, _constraints} ->
                to_string(name) == next
              end
            else
              fn {name, _type, _constraints} ->
                name == next
              end
            end

          case Enum.find(Ash.Type.composite_types(type, constraints), condition) do
            nil ->
              {next, nil, nil}

            {_, aliased_as, type, constraints} ->
              {aliased_as, type, constraints}

            {name, type, constraints} ->
              {name, type, constraints}
          end

        true ->
          {next, nil, nil}
      end

    case bracket_or_dot do
      :dot ->
        case first_acc do
          {:bracket, [], _, _} ->
            split_at_paths(type, constraints, rest, [
              {bracket_or_dot, [next], type, constraints} | rest_acc
            ])

          {:bracket, path, nil, nil} ->
            split_at_paths(type, constraints, rest, [
              {bracket_or_dot, [next], type, constraints},
              {:bracket, path, nil, nil}
              | rest_acc
            ])

          {:dot, _path, _, _} ->
            split_at_paths(type, constraints, rest, [
              {bracket_or_dot, [next], nil, nil},
              first_acc | rest_acc
            ])
        end

      :bracket ->
        case first_acc do
          {:bracket, path, nil, nil} ->
            split_at_paths(type, constraints, rest, [
              {bracket_or_dot, [next | path], type, constraints}
              | rest_acc
            ])

          {:dot, _path, _, _} ->
            split_at_paths(type, constraints, rest, [
              {bracket_or_dot, [next], nil, nil},
              first_acc | rest_acc
            ])
        end
    end
  end

  defp list_requires_encoding?(value) do
    !Enum.empty?(value) &&
      Enum.any?(value, fn value ->
        Ash.Expr.expr?(value) || is_map(value) || is_list(value)
      end)
  end

  defp encode_list(query, value, bindings, embedded?, acc, type) do
    first = Enum.at(value, 0)

    first_embedded? =
      is_struct(first) and Ash.Resource.Info.resource?(first.__struct__) and
        Ash.Resource.Info.embedded?(first.__struct__)

    is_map? = type in [:map, :jsonb, :json]

    if first_embedded? && !is_map? do
      {value, acc}
    else
      value =
        if first_embedded? do
          {:ok, value} =
            Ash.Type.dump_to_embedded({:array, first.__struct__}, value, [])

          value
        else
          value
        end

      element_type =
        case type do
          {{:array, type}, _} -> type
          {{:in, type}, _} -> type
          _ -> nil
        end

      elements =
        Enum.map(value, fn list_item ->
          if type do
            {:expr, %Ash.Query.Function.Type{arguments: [list_item, element_type, []]}}
          else
            {:expr, list_item}
          end
        end)
        |> Enum.intersperse({:raw, ","})

      if is_map? do
        do_dynamic_expr(
          query,
          %Fragment{
            embedded?: embedded?,
            arguments:
              [
                raw: "array_to_json(ARRAY["
              ] ++ elements ++ [raw: "])"]
          },
          bindings,
          embedded?,
          acc,
          type
        )
      else
        do_dynamic_expr(
          query,
          %Fragment{
            embedded?: embedded?,
            arguments:
              [
                raw: "ARRAY["
              ] ++ elements ++ [raw: "]"]
          },
          bindings,
          embedded?,
          acc,
          type
        )
      end
    end
  end

  defp list_expr(query, value, bindings, embedded?, acc, type) do
    if list_requires_encoding?(value) do
      encode_list(query, value, bindings, embedded?, acc, type)
    else
      type =
        case type do
          {:array, type} -> type
          {:in, type} -> type
          _ -> nil
        end

      {params, exprs, _, acc} =
        Enum.reduce(value, {[], [], 0, acc}, fn value, {params, data, count, acc} ->
          case do_dynamic_expr(
                 query,
                 value,
                 bindings,
                 embedded?,
                 acc,
                 type
               ) do
            {%Ecto.Query.DynamicExpr{} = dynamic, acc} ->
              result =
                Ecto.Query.Builder.Dynamic.partially_expand(
                  :select,
                  query,
                  dynamic,
                  params,
                  count
                )

              expr = elem(result, 0)
              new_params = elem(result, 1)
              new_count = result |> Tuple.to_list() |> List.last()

              {new_params, [expr | data], new_count, acc}

            {other, acc} ->
              {params, [other | data], count, acc}
          end
        end)

      {%Ecto.Query.DynamicExpr{
         fun: fn _query ->
           {Enum.reverse(exprs), Enum.reverse(params), [], []}
         end,
         binding: [],
         file: __ENV__.file,
         line: __ENV__.line
       }, acc}
    end
  end

  defp maybe_uuid_to_binary({:array, type}, value, _original_value) when is_list(value) do
    Enum.map(value, &maybe_uuid_to_binary(type, &1, &1))
  end

  defp maybe_uuid_to_binary(type, value, original_value)
       when type in [
              Ash.Type.UUID.EctoType,
              :uuid
            ] and is_binary(value) do
    case Ecto.UUID.dump(value) do
      {:ok, encoded} -> encoded
      _ -> original_value
    end
  end

  defp maybe_uuid_to_binary(_type, _value, original_value), do: original_value

  @doc false
  def validate_type!(%{__ash_bindings__: %{resource: resource}} = query, type, context) do
    validate_type!(resource, type, context, query)
  end

  defp validate_type!(resource, type, context, query) do
    case query.__ash_bindings__.sql_behaviour.require_extension_for_citext() do
      {true, extension} ->
        case type do
          {:parameterized, AshSql.Type.CiString, _} ->
            require_extension!(resource, extension, context, query)

          {:parameterized, {AshSql.Type.CiString, _}} ->
            require_extension!(resource, extension, context, query)

          {:parameterized, {AshPostgres.Type.CiStringWrapper.EctoType, _}} ->
            require_extension!(resource, extension, context, query)

          {:parameterized, AshPostgres.Type.CiStringWrapper.EctoType, _} ->
            require_extension!(resource, extension, context, query)

          :ci_string ->
            require_extension!(resource, extension, context, query)

          :citext ->
            require_extension!(resource, extension, context, query)

          _ ->
            :ok
        end

      false ->
        :ok
    end
  end

  defp handle_literal(query, value, bindings, embedded?, acc, type) do
    if is_list(value) do
      if list_requires_encoding?(value) do
        encode_list(query, value, bindings, embedded?, acc, type)
      else
        value
        |> Enum.reduce({[], acc}, fn item, {list, acc} ->
          {new_item, acc} =
            do_dynamic_expr(query, item, set_location(bindings, :sub_expr), embedded?, acc, type)

          {[new_item | list], acc}
        end)
        |> then(fn {list, acc} ->
          {Enum.reverse(list), acc}
        end)
      end
    else
      {value, acc}
    end
  end

  @doc false
  def ref_binding(
        %{attribute: %Ash.Query.Aggregate{name: name}, relationship_path: relationship_path},
        bindings
      ) do
    relationship_path = List.wrap(bindings[:refs_at_path]) ++ relationship_path

    Enum.find_value(bindings.bindings, fn {binding, data} ->
      data.type == :aggregate &&
        data.path == relationship_path &&
        Enum.any?(data.aggregates, &(&1.name == name)) && binding
    end) ||
      Enum.find_value(bindings.bindings, fn {binding, data} ->
        data.type in [:inner, :left, :root] &&
          Ash.SatSolver.synonymous_relationship_paths?(
            bindings.resource,
            data.path,
            relationship_path
          ) && binding
      end)
  end

  def ref_binding(
        %{
          attribute: %Ash.Resource.Aggregate{name: name},
          relationship_path: relationship_path
        },
        bindings
      ) do
    relationship_path = List.wrap(bindings[:refs_at_path]) ++ relationship_path

    Enum.find_value(bindings.bindings, fn {binding, data} ->
      data.type == :aggregate &&
        data.path == relationship_path &&
        Enum.any?(data.aggregates, &(&1.name == name)) && binding
    end)
  end

  def ref_binding(%{attribute: %Ash.Resource.Attribute{}} = ref, bindings) do
    relationship_path = List.wrap(bindings[:refs_at_path]) ++ ref.relationship_path

    Enum.find_value(bindings.bindings, fn {binding, data} ->
      data.type in [:inner, :left, :root] &&
        Ash.SatSolver.synonymous_relationship_paths?(
          bindings.resource,
          data.path,
          relationship_path
        ) && binding
    end)
  end

  defp do_get_path(
         query,
         expr,
         {:bracket, path, type, constraints},
         bindings,
         embedded?,
         pred_embedded?,
         acc
       ) do
    type =
      parameterized_type(
        bindings.sql_behaviour,
        type,
        constraints,
        :expr
      )

    path = path |> Enum.reverse() |> Enum.map(&to_string/1)

    path_frags =
      path
      |> Enum.flat_map(fn item ->
        [expr: item, raw: "::text,"]
      end)
      |> :lists.droplast()
      |> Enum.concat(raw: "::text)")

    {expr, acc} =
      do_dynamic_expr(
        query,
        %Fragment{
          embedded?: pred_embedded?,
          arguments:
            [
              raw: "jsonb_extract_path_text(",
              expr: expr,
              raw: "::jsonb,"
            ] ++ path_frags
        },
        bindings,
        embedded?,
        acc
      )

    if type do
      {query.__ash_bindings__.sql_behaviour.type_expr(expr, type), acc}
    else
      {expr, acc}
    end
  end

  defp do_get_path(
         query,
         expr,
         {:dot, [field], type, constraints},
         bindings,
         embedded?,
         pred_embedded?,
         acc
       )
       when is_atom(field) do
    type =
      parameterized_type(
        bindings.sql_behaviour,
        type,
        constraints,
        :expr
      )

    {expr, acc} =
      do_dynamic_expr(
        query,
        %Fragment{
          embedded?: pred_embedded?,
          arguments: [
            raw: "(",
            expr: expr,
            raw: ").#{field}"
          ]
        },
        bindings,
        embedded?,
        acc
      )

    if type do
      {query.__ash_bindings__.sql_behaviour.type_expr(expr, type), acc}
    else
      {expr, acc}
    end
  end

  defp require_ash_functions!(query, operator) do
    installed_extensions =
      query.__ash_bindings__.sql_behaviour.repo(query.__ash_bindings__.resource, :mutate).installed_extensions()

    unless "ash-functions" in installed_extensions do
      raise """
      Cannot use `#{operator}` without adding the extension `ash-functions` to your repo.

      Add it to the list in `installed_extensions/0` and generate migrations.
      """
    end
  end

  defp require_extension!(resource, extension, context, query) do
    repo = query.__ash_bindings__.sql_behaviour.repo(resource, :mutate)

    if extension not in repo.installed_extensions() do
      raise Ash.Error.Query.InvalidExpression,
        expression: context,
        message:
          "The #{extension} extension needs to be installed before #{inspect(context)} can be used. Please add \"#{extension}\" to the list of installed_extensions in #{inspect(repo)}."
    end
  end

  @doc false
  def set_parent_path(query, parent, parent_is_parent_as? \\ true) do
    # This is a stupid name. Its actually the path we *remove* when stepping up a level. I.e the child's path
    Map.update!(query, :__ash_bindings__, fn ash_bindings ->
      ash_bindings
      |> Map.put(
        :parent_bindings,
        parent.__ash_bindings__ |> Map.put(:parent_is_parent_as?, parent_is_parent_as?)
      )
      |> Map.put(:parent_resources, [
        parent.__ash_bindings__.resource | parent.__ash_bindings__[:parent_resources] || []
      ])
    end)
  end

  @doc false
  def merge_accumulator(
        %{__ash_bindings__: %{expression_accumulator: expression_accumulator}} = query,
        right
      ) do
    %{
      query
      | __ash_bindings__: %{
          query.__ash_bindings__
          | expression_accumulator: merge_accumulator(expression_accumulator, right)
        }
    }
  end

  @doc false
  def merge_accumulator(%ExprInfo{has_error?: left_has_error?}, %ExprInfo{
        has_error?: right_has_error?
      }) do
    %ExprInfo{has_error?: left_has_error? || right_has_error?}
  end

  @doc false
  def split_statements(nil, _op), do: []

  def split_statements([left, right | rest], op) do
    split_statements([%BooleanExpression{op: op, left: left, right: right} | rest], op)
  end

  def split_statements([last], op), do: split_statements(last, op)

  def split_statements(other, op), do: do_split_statements(other, op)

  def do_split_statements(%Ash.Filter{expression: expression}, op) do
    do_split_statements(expression, op)
  end

  def do_split_statements(
        %Not{
          expression: %BooleanExpression{op: :or, left: left, right: right}
        },
        op
      ) do
    do_split_statements(
      %BooleanExpression{
        op: :and,
        left: %Not{expression: left},
        right: %Not{expression: right}
      },
      op
    )
  end

  def do_split_statements(%Not{expression: %Not{expression: expression}}, op) do
    do_split_statements(expression, op)
  end

  def do_split_statements(%BooleanExpression{op: op, left: left, right: right}, op) do
    do_split_statements(left, op) ++ do_split_statements(right, op)
  end

  def do_split_statements(other, _op), do: [other]

  defp escape_contains(text) do
    "%" <> String.replace(text, ~r/([\%_])/u, "\\\\\\0") <> "%"
  end

  defp determine_types(sql_behaviour, mod, args, returns) do
    {types, new_returns} =
      if function_exported?(sql_behaviour, :determine_types, 3) do
        case sql_behaviour.determine_types(mod, args, returns) do
          {types, returns} -> {types, returns}
          types -> {types, nil}
        end
      else
        case sql_behaviour.determine_types(mod, args) do
          {types, returns} -> {types, returns}
          types -> {types, nil}
        end
      end

    {types, new_returns || returns}
  end

  defp maybe_type_expr(query, expr, bindings, embedded?, acc, type) do
    if type do
      {type, constraints} =
        case type do
          {:array, type} -> {{:array, type}, []}
          {type, constraints} -> {type, constraints}
          type -> {type, []}
        end

      do_dynamic_expr(
        query,
        %Ash.Query.Function.Type{arguments: [expr, type, constraints]},
        bindings,
        embedded?,
        acc,
        type
      )
    else
      do_dynamic_expr(query, expr, bindings, embedded?, acc, type)
    end
  end

  defp cant_return_nil?(%Ash.Query.Ref{attribute: %{allow_nil?: false}, relationship_path: []}) do
    true
  end

  defp cant_return_nil?(other) do
    if Ash.Expr.expr?(other) do
      false
    else
      not is_nil(other)
    end
  end

  defp reference_error!(query, ref) do
    parent =
      if query.__ash_bindings__[:parent?] do
        "parent "
      else
        ""
      end

    raise """
    Error while building #{parent}reference: #{inspect(ref)}

    Query so far:

    #{inspect(query)}

    Current bindings:

    #{inspect(query.__ash_bindings__.bindings)}
    """
  end

  # Helper function to detect if a type is definitely boolean
  defp boolean_type?(:boolean), do: true
  defp boolean_type?({:boolean, _}), do: true
  defp boolean_type?({Ash.Type.Boolean, _}), do: true
  defp boolean_type?(Ash.Type.Boolean), do: true
  defp boolean_type?(_), do: false

  # Helper function to detect if a type definitely cannot be boolean
  defp cannot_be_boolean?(nil), do: false
  defp cannot_be_boolean?(:boolean), do: false
  defp cannot_be_boolean?({:boolean, _}), do: false
  defp cannot_be_boolean?({Ash.Type.Boolean, _}), do: false
  defp cannot_be_boolean?(Ash.Type.Boolean), do: false
  defp cannot_be_boolean?(_), do: true
end
