defmodule Cldr.String do
  @moduledoc """
  Functions that operate on a `String.t` that are not provided
  in the standard lib.
  """

  @doc """
  Hash a string using a polynomial rolling hash function.

  See https://cp-algorithms.com/string/string-hashing.html for
  a description of the algoithim.
  """

  @p 99991
  @m trunc(1.0e9) + 9
  def hash(string) do
    {hash, _} =
      string
      |> String.to_charlist()
      |> Enum.reduce({0, 1}, fn char, {hash, p_pow} ->
        hash = rem(hash + char * p_pow, @m)
        p_pow = rem(p_pow * @p, @m)
        {hash, p_pow}
      end)

    hash
  end

  @doc """
  Replaces "-" with "_" in a string.

  ## Examples

      iex> Cldr.String.to_underscore("this-one")
      "this_one"

  """
  def to_underscore(string) when is_binary(string) do
    String.replace(string, "-", "_")
  end

  @doc """
  This is the code of Macro.underscore with modifications:

  The change is to cater for strings in the format:

      This_That

  which in Macro.underscore gets formatted as:

      this__that (note the double underscore)

  when we actually want:

      that_that

  """
  def underscore(atom) when is_atom(atom) do
    "Elixir." <> rest = Atom.to_string(atom)
    underscore(rest)
  end

  def underscore(<<h, t::binary>>) do
    <<to_lower_char(h)>> <> do_underscore(t, h)
  end

  def underscore("") do
    ""
  end

  # h is upper case, next char is not uppercase, or a _ or .  => and prev != _
  defp do_underscore(<<h, t, rest::binary>>, prev)
       when h >= ?A and h <= ?Z and not (t >= ?A and t <= ?Z) and t != ?. and t != ?_ and
              prev != ?_ do
    <<?_, to_lower_char(h), t>> <> do_underscore(rest, t)
  end

  # h is uppercase, previous was not uppercase or _
  defp do_underscore(<<h, t::binary>>, prev)
       when h >= ?A and h <= ?Z and not (prev >= ?A and prev <= ?Z) and prev != ?_ do
    <<?_, to_lower_char(h)>> <> do_underscore(t, h)
  end

  # h is .
  defp do_underscore(<<?., t::binary>>, _) do
    <<?/>> <> underscore(t)
  end

  # Any other char
  defp do_underscore(<<h, t::binary>>, _) do
    <<to_lower_char(h)>> <> do_underscore(t, h)
  end

  defp do_underscore(<<>>, _) do
    <<>>
  end

  def to_upper_char(char) when char >= ?a and char <= ?z, do: char - 32
  def to_upper_char(char), do: char

  def to_lower_char(char) when char >= ?A and char <= ?Z, do: char + 32
  def to_lower_char(char), do: char
end
