defmodule Mix.Tasks.DigitalToken.Registry.Update do
  @moduledoc """
  Updates the digital token registry data.
  """

  use Mix.Task
  require Logger


  @shortdoc "Update digital token registry data"

  @url "https://download.dtif.org/data.json"

  @tokens_file_name DigitalToken.Decode.tokens_file_name()

  @doc false
  def run(_) do
    require Logger

    case Cldr.Http.get(@url) do
      {:ok, body} ->
        tokens =
          body
          |> DigitalToken.Decode.decode_tokens()
          |> :erlang.term_to_binary()

        File.write!(@tokens_file_name, tokens)
        Logger.info "Updated digital token registry at #{@tokens_file_name}"

      {:error, reason} ->
        Logger.warning "Failed to update digital token registry. #{inspect reason}"
    end
  end
end

