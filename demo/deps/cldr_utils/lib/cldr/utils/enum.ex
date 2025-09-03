defmodule Cldr.Enum do
  @doc """
  Very simple reduce that passes both the head and the tail
  to the reducing function so it has some lookahead.
  """

  def reduce_peeking(_list, {:halt, acc}, _fun),
    do: {:halted, acc}

  def reduce_peeking(list, {:suspend, acc}, fun),
    do: {:suspended, acc, &reduce_peeking(list, &1, fun)}

  def reduce_peeking([], {:cont, acc}, _fun),
    do: {:done, acc}

  def reduce_peeking([head | tail], {:cont, acc}, fun),
    do: reduce_peeking(tail, fun.(head, tail, acc), fun)

  def reduce_peeking(list, acc, fun),
    do: reduce_peeking(list, {:cont, acc}, fun) |> elem(1)

  def combine_list([head]),
    do: [to_string(head)]

  def combine_list([head | [next | tail]]),
    do: [to_string(head) | combine_list(["#{head}_#{next}" | tail])]
end
