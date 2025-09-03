defmodule DigitalToken.Decode do
  @moduledoc false

  # This module reads the json file and formats the
  # data into a format useful for looking up registry
  # data.

  import Cldr.Map

  alias DigitalToken.Config
  alias DigitalToken.Data

  @priv_dir Application.app_dir(:digital_token, "priv")
  @tokens_file_name Path.join(@priv_dir, "digital_token_registry.etf")
  @symbols_file_name Path.join(@priv_dir, "digital_token_symbols.etf")

  @external_resource @tokens_file_name
  @external_resource @symbols_file_name

  def tokens_file_name do
    @tokens_file_name
  end

  def symbols_file_name do
    @symbols_file_name
  end

  def decode_tokens(body) do
    body
    |> Config.json_library().decode!
    |> Map.fetch!("records")
    |> Enum.map(&restructure_key/1)
    |> merge_map_list()
  end

  def decode_symbols(body) do
    body
    |> Config.json_library().decode!
    |> Cldr.Map.atomize_keys()
    |> Enum.map(fn token ->
      cond do
        token_id = Map.get(Data.short_names(), {token.symbol, :native}) ->
          {token_id, token.usym}

        token_id = Map.get(Data.short_names(), {token.symbol, :auxiliary}) ->
          {token_id, token.usym}

        token_id = Map.get(Data.short_names(), {token.symbol, :distributed}) ->
          {token_id, token.usym}

        token_id = Map.get(Data.short_names(), {token.symbol, :fungible}) ->
          {token_id, token.usym}

        true ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new
  end

  @skip_atomize [
    "template_version",
    "genesis_block_utc_timestamp",
    "fork_block_utc_timestamp",
    "rec_date_time"
  ]

  def restructure_key(map) do
    header = Map.fetch!(map, "Header")
    dti= Map.fetch!(header, "DTI")

    map =
      map
      |> underscore_keys()
      |> deep_map(&transform/1)
      |> atomize_keys(skip: @skip_atomize)
      |> structify(DigitalToken)

    %{dti => map}
  end

  def short_names(data) do
    Enum.flat_map(data, fn {token, values} ->
      short_names = Map.get(values.informative, :short_names, [])
      [{{values.informative.long_name, values.header.dti_type}, token} |
        Enum.map(short_names, &{{&1, values.header.dti_type}, token})]
    end)
    |> Map.new()
  end

  defp structify(map, struct) do
    struct(struct, map)
  end

  # The type is assigned to the token by DTIF based on the form used and
  # official details of the token. Possible values:
  # 0=Auxiliary Digital Token
  # 1=Native Digital Token
  # 2=Distributed Ledger Without a Native Digital Token
  # 3=Functionally Fungible Group of Digital Tokens

  defp transform({"dti_type" = key, 3}) do
    {key, :fungible}
  end

  defp transform({"dti_type" = key, 2}) do
    {key, :distributed}
  end

  defp transform({"dti_type" = key, 1}) do
    {key, :native}
  end

  defp transform({"dti_type" = key, 0}) do
    {key, :auxiliary}
  end

  # dlt type

  defp transform({"dlt_type" = key, 1}) do
    {key, :blockchain}
  end

  defp transform({"dlt_type" = key, 0}) do
    {key, :other}
  end

  # Template version

  defp transform({"template_version" = key, "V" <> version}) do
    {key, Version.parse!(version)}
  end

  # genesis_block_utc_timestamp

  defp transform({"genesis_block_utc_timestamp" = key, datetime}) do
    {key, NaiveDateTime.from_iso8601!(datetime)}
  end

  # "fork_block_utc_timestamp"

  defp transform({"fork_block_utc_timestamp" = key, datetime}) do
    {key, NaiveDateTime.from_iso8601!(datetime)}
  end

  # rec_date_time

  defp transform({"rec_date_time" = key, datetime}) do
    {key, NaiveDateTime.from_iso8601!(datetime)}
  end

  # Short names becomes a simple list

  defp transform({"short_names" = key, names}) do
    short_names =
      names
      |> Enum.map(&Map.fetch!(&1, "short_name"))
      |> Enum.sort_by(&String.length/1)

    {key, short_names}
  end

  # Hashes

  defp transform({"genesis_block_hash" = key, "0x" <> hash}) do
    case Integer.parse(hash, 16) do
      {integer_hash, ""} -> {key, integer_hash}
      {integer_hash, remainder} -> {key, {integer_hash, remainder}}
    end
  end

  defp transform({"auxiliary_technical_reference" = key, "0x" <> hash}) do
    case Integer.parse(hash, 16) do
      {integer_hash, ""} -> {key, integer_hash}
      {integer_hash, remainder} -> {key, {integer_hash, remainder}}
    end
  end

  # Otherwise do nothing

  defp transform(other) do
    other
  end

end