defmodule DigitalToken.UnknownTokenError do
  @moduledoc """
  Exception raised when a digital token is unknown.

  """

  defexception message: "Unknown error"

  @impl true
  def exception(id) when is_binary(id) do
    message = "The token #{inspect id} is not known"
    %__MODULE__{message: message}
  end
end