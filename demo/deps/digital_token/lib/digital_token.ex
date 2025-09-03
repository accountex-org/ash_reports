defmodule DigitalToken do
  @moduledoc """
  Functions to validate, search and retrieve digital token
  data sourced from the [DTIF registry](https://dtif.org).

  """

  defstruct [
    header: nil,
    informative: nil,
    metadata: nil,
    normative: nil
  ]

  @typedoc """
  The structure of data matching that hosted in
  the [DTIF registry](https://dtif.org)/

  """
  @type t :: %__MODULE__{
    header: map(),
    informative: map(),
    metadata: map(),
    normative: map()
  }

  @typedoc """
  token_id is a random 9-character
  string defined by the [dtif registry](https://dtif.org)
  that uniquely identifies a digital token.

  """
  @type token_id :: String.t()

  @typedoc """
  The type of a token
  """
  @type token_type :: :native | :auxiliary | :distributed | :fungible

  @typedoc """
  A digital token may have zero or more short
  names associated with it. They are arbitrary
  strings, usually three or four characters in
  length. For example "BTC", "ETH" and "DOGE".

  """
  @type short_name :: String.t()

  @typedoc """
  A mapping of digital token identifiers
  to the registry data for that token.

  """
  @type token_map :: %{
    token_id() => t()
  }

  @typedoc """
  A mapping from a short name to token
  identifier.

  """
  @type short_name_map :: %{
    {token_id(), token_type} => token_id()
  }

  @typedoc """
  A mapping of digital token identifiers
  to a currency symbol for that token.

  """
  @type symbol_map :: %{
    token_id() => String.t()
  }

  defguard is_digital_token(token_id) when is_binary(token_id) and byte_size(token_id) == 9

  @doc """
  Returns a map of the digital tokens in the
  [dtif registry](https://dtif.org).

  """
  @spec tokens :: token_map()
  def tokens do
    DigitalToken.Data.tokens()
  end

  @doc """
  Returns a mapping of digital token short
  names to digital token identifiers.

  """
  @spec short_names :: short_name_map()
  def short_names do
    DigitalToken.Data.short_names()
  end

  @doc """
  Returns a mapping of digital token identifiers
  names to a currency symbol.

  """
  @spec symbols :: symbol_map()
  def symbols do
    DigitalToken.Data.symbols()
  end

  @doc """
  Validates a token identifier or short name
  and returns the token identifier or an error.

  ## Arguments

  * `id` is any token identifier or short name

  ## Returns

  * `{:ok, token_id}` or

  * `{:error, {exception, id}}`

  ## Example

      iex> DigitalToken.validate_token("BTC")
      {:ok, "4H95J0R2X"}

      iex> DigitalToken.validate_token("Bitcoin")
      {:ok, "4H95J0R2X"}

      iex> DigitalToken.validate_token "4H95J0R2X"
      {:ok, "4H95J0R2X"}

      iex> DigitalToken.validate_token("Nothing")
      {:error, {DigitalToken.UnknownTokenError, "Nothing"}}

  """
  @spec validate_token(token_id() | short_name()) ::
    {:ok, token_id()} | {:error, {module(), any()}}
  def validate_token(id) do
    cond do
      Map.has_key?(tokens(), id) ->
        {:ok, id}

      token = Map.get(short_names(), {id, :native}) ->
        {:ok, token}

      token = Map.get(short_names(), {id, :auxiliary}) ->
        {:ok, token}

      token = Map.get(short_names(), {id, :distributed}) ->
        {:ok, token}

      token = Map.get(short_names(), {id, :fungible}) ->
        {:ok, token}

      id ->
        {:error, unknown_token_error(id)}
    end
  end

  @doc """
  Returns the short name of a digital token.

  ## Arguments

  * `token_id` is any valid digital token identifier.

  ## Returns

  * `{:ok, short_name}` where `short_name` is either
    the first short name in `token.informative.short_names` or
    the token long name if there are no short names.

  * `{:error, {exception, reason}}`

  ## Examples

      iex> DigitalToken.short_name "BTC"
      {:ok, "BTC"}

      iex> DigitalToken.short_name "4H95J0R2X"
      {:ok, "BTC"}

      iex> DigitalToken.short_name "W0HBX7RC4"
      {:ok, "Terra Classic"}

  """
  @spec short_name(token_id) :: {:ok, String.t()} | {:error, {module(), String.t}}
  def short_name(token_id) do
    with {:ok, token} <- get_token(token_id) do
      case Map.get(token.informative, :short_names) do
        [first | _rest] -> {:ok, first}
        _other -> {:ok, token.informative.long_name}
      end
    end
  end

  @doc """
  Returns the long name of a digital token.

  ## Arguments

  * `token_id` is any valid digital token identifier.

  ## Returns

  * `{:ok, long_name}` where `long_name` is the token's
    registered name.

  * `{:error, {exception, reason}}`

  ## Examples

      iex> DigitalToken.long_name "BTC"
      {:ok, "Bitcoin"}

      iex> DigitalToken.long_name "4H95J0R2X"
      {:ok, "Bitcoin"}

      iex> DigitalToken.long_name "W0HBX7RC4"
      {:ok, "Terra Classic"}

  """
  @spec long_name(token_id) :: {:ok, String.t()} | {:error, {module(), String.t}}
  def long_name(token_id) do
    with {:ok, token} <- get_token(token_id) do
      Map.fetch(token.informative, :long_name)
    end
  end

  @doc """
  Returns a currency symbol used in number formatting.

  ## Arguments

  * `token_id` is any valid digital token identifier.

  * `style` is a number in the range `1` to `4` as follows:
      * `1` is the token's symbol, if it exists
      * `2` is the token's short name as a proxy for a currency code
      * `3` is the token's long name
      * `4` is the token's symbol as a proxy for a narrow currency symbol

  ## Returns

  * `{:ok, symbol}` or

  * `{:error, {exception, reason}}`

  ## Examples

      iex> DigitalToken.symbol "BTC", 1
      {:ok, "₿"}

      iex> DigitalToken.symbol "BTC", 2
      {:ok, "BTC"}

      iex> DigitalToken.symbol "BTC", 3
      {:ok, "Bitcoin"}

      iex> DigitalToken.symbol "BTC", 4
      {:ok, "₿"}

      iex> DigitalToken.symbol "ETH", 4
      {:ok, "Ξ"}

      iex> DigitalToken.symbol "DOGE", 4
      {:ok, "Ð"}

      iex> DigitalToken.symbol "DODGY", 4
      {:error, {DigitalToken.UnknownTokenError, "DODGY"}}

  """
  @spec symbol(token_id, 1..4) :: {:ok, String.t()} | {:error, {module(), String.t}}
  def symbol(token_id, style) when style in [1, 4] do
    with {:ok, token_id} <- validate_token(token_id),
         {:ok, symbol} <- Map.fetch(symbols(), token_id) do
      {:ok, symbol}
    else
      :error -> short_name(token_id)
      other_error -> other_error
    end
  end

  def symbol(token_id, 2)  do
    short_name(token_id)
  end

  def symbol(token_id, 3) do
    long_name(token_id)
  end

  @doc """
  Returns the registry data for a given token
  identifier.

  ## Arguments

  * `id` is any token identifier or short name

  ## Returns

  * `{:ok, registry_data}` or

  * `{:error, {exception, id}}`

  ## Example

      DigitalToken.get_token("BTC")
      #=> {:ok,
       %DigitalToken{
         header: %{
           dlt_type: :blockchain,
           dti: "4H95J0R2X",
           dti_type: :native,
           template_version: #Version<1.0.0>
         },
         informative: %{
           long_name: "Bitcoin",
           public_distributed_ledger_indication: false,
           short_names: ["BTC", "XBT"],
           unit_multiplier: 100000000,
           url: "https://github.com/bitcoin/bitcoin"
         },
         metadata: %{
           .....

  """
  @spec get_token(token_id() | short_name()) :: {:ok, t()} | {:error, {module(), any()}}
  def get_token(id) do
    with {:ok, token} <- validate_token(id) do
      {:ok, Map.fetch!(tokens(), token)}
    end
  end

  @doc """
  Returns the registry data for a given token
  identifier.

  ## Arguments

  * `id` is any token identifier or short name

  ## Returns

  * `registry_data` or

  * raises an exception

  ## Example

      DigitalToken.get_token("BTC")
      #=> %DigitalToken{
         header: %{
           dlt_type: :blockchain,
           dti: "4H95J0R2X",
           dti_type: :native,
           template_version: #Version<1.0.0>
         },
         informative: %{
           long_name: "Bitcoin",
           public_distributed_ledger_indication: false,
           short_names: ["BTC", "XBT"],
           unit_multiplier: 100000000,
           url: "https://github.com/bitcoin/bitcoin"
         },
         metadata: %{
           .....

  """
  @spec get_token!(token_id() | short_name()) :: t() | no_return()
  def get_token!(id) do
    case get_token(id) do
      {:ok, token} -> token
      {:error, {exception, id}} -> raise exception, id
    end
  end

  defp unknown_token_error(id) do
    {DigitalToken.UnknownTokenError, id}
  end
end
