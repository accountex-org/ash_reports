defmodule Mix.Tasks.DigitalToken.Symbols.Update do
  @moduledoc """
  Updates the digital token symbols data.

  Data is copied from [Crypto Currency Symbols](https://github.com/yonilevy/crypto-currency-symbols).

  """

  use Mix.Task
  require Logger

  @shortdoc "Update digital token symbol data"

  @url "https://raw.githubusercontent.com/yonilevy/crypto-currency-symbols/master/symbols.json"

  @symbols_file_name DigitalToken.Decode.symbols_file_name()

  @doc false
  def run(_) do
    require Logger

    case Cldr.Http.get(@url) do
      {:ok, body} ->
        # File.write!("token_symbols.json", body)

        symbols =
          body
          |> :erlang.iolist_to_binary()
          |> DigitalToken.Decode.decode_symbols()
          |> :erlang.term_to_binary()

        File.write!(@symbols_file_name, symbols)
        Logger.info "Updated digital token symbols at #{@symbols_file_name}"

      {:error, reason} ->
        Logger.warning "Failed to update digital token symbols. #{inspect reason}"
    end
  end
end

