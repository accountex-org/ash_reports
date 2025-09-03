defmodule DigitalToken.Config do
  json = if(Code.ensure_loaded?(Cldr.Json), do: Cldr.Json, else: nil)
  poison = if(Code.ensure_loaded?(Poison), do: Poison, else: nil)
  jason = if(Code.ensure_loaded?(Jason), do: Jason, else: nil)
  digital_token_json = Application.compile_env(:digital_token, :json_library)
  @json_lib digital_token_json || json || jason || poison

  cond do
    Code.ensure_loaded?(@json_lib) and function_exported?(@json_lib, :decode!, 1) ->
      :ok

    digital_token_json ->
      raise ArgumentError,
            "Could not load configured :json_library, " <>
              "make sure #{inspect(digital_token_json)} is listed as a dependency"

    true ->
      raise ArgumentError, """
      A JSON library has not been configured.\n
      Please configure a JSON lib in your `mix.exs`
      file. The suggested library is `:jason`.

      For example in your `mix.exs`:

          def deps() do
            [
              {:jason, "~> 1.0"},
              ...
            ]
          end

      You can then configure this library for `ex_cldr`
      in your `config.exs` as follows:

          config :digital_token,
            json_library: Jason

      If no configuration is provided, `digital_token` will
      attempt to detect if Jason or Poison are configured.
      """
  end

  @doc """
  Return the configured json lib
  """
  def json_library do
    @json_lib
  end
end