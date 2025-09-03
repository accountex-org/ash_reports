if Code.ensure_loaded?(:json) do
  defmodule Cldr.Json do
    @moduledoc """
    A wrapper for the OTP 27 :json module.

    It implements a `decode!/1` function that wraps
    `:json.decode/1`  with `decode!/1` so that its
    compatible with the calling conventions of
    Elixir - which is used by `ex_cldr`.

    This allows configuration such as:
    ```elixir
    config :ex_cldr,
      json_library: Cldr.Json
    ```

    """
    @doc since: "2.27.0"

    @doc """
    Implements a Jason-compatible decode!/1,2 function suitable
    for decoding CLDR json data.

    ### Example

        iex> Cldr.Json.decode!("{\\"foo\\": 1}")
        %{"foo" => 1}

        iex> Cldr.Json.decode!("{\\"foo\\": 1}", keys: :atoms)
        %{foo: 1}

    """
    def decode!(string) when is_binary(string) do
      {json, :ok, ""} = :json.decode(string, :ok, %{null: nil})
      json
    end

    def decode!(charlist) when is_list(charlist) do
      charlist
      |> :erlang.iolist_to_binary()
      |> decode!()
    end

    def decode!(string, [keys: :atoms]) when is_binary(string) do
      push = fn key, value, acc ->
        [{String.to_atom(key), value} | acc]
      end

      decoders = %{
        null: nil,
        object_push: push
      }

      {json, :ok, ""} = :json.decode(string, :ok, decoders)
      json
    end

    def decode!(charlist, options) when is_list(charlist) do
      charlist
      |> :erlang.iolist_to_binary()
      |> decode!(options)
    end

  end
end