defmodule Cldr.Calendar.Parse do
  @moduledoc false

  @split_reg ~r/[\sT]/

  def parse_date(<<"-", year::bytes-4, "-", month::bytes-2, "-", day::bytes-2>>, calendar) do
    with {:ok, {year, month, day}} <- return_date(year, month, day, calendar) do
      {:ok, {-year, month, day}}
    end
  end

  def parse_date(<<year::bytes-4, "-", month::bytes-2, "-", day::bytes-2>>, calendar) do
    return_date(year, month, day, calendar)
  end

  def parse_date(_string, _calendar) do
    {:error, :invalid_date}
  end

  def parse_week_date(<<"-", year::bytes-4, "-W", month::bytes-2, "-", day::bytes-1>>, calendar) do
    with {:ok, {year, month, day}} <- return_date(year, month, day, calendar) do
      {:ok, {-year, month, day}}
    end
  end

  def parse_week_date(<<year::bytes-4, "-W", month::bytes-2, "-", day::bytes-1>>, calendar) do
    return_date(year, month, day, calendar)
  end

  def parse_week_date(string, calendar) do
    parse_date(string, calendar)
  end

  defp return_date(year, month, day, calendar) do
    year = String.to_integer(year)
    month = String.to_integer(month)
    day = String.to_integer(day)

    if calendar.valid_date?(year, month, day) do
      {:ok, {year, month, day}}
    else
      {:error, :invalid_date}
    end
  end

  [match_time, guard_time, read_time] =
    quote do
      [
        <<h1, h2, ?:, i1, i2, ?:, s1, s2>>,
        h1 >= ?0 and h1 <= ?9 and h2 >= ?0 and h2 <= ?9 and i1 >= ?0 and i1 <= ?9 and i2 >= ?0 and
          i2 <= ?9 and s1 >= ?0 and s1 <= ?9 and s2 >= ?0 and s2 <= ?9,
        {
          (h1 - ?0) * 10 + (h2 - ?0),
          (i1 - ?0) * 10 + (i2 - ?0),
          (s1 - ?0) * 10 + (s2 - ?0)
        }
      ]
    end

  defdelegate time_to_day_fraction(hour, minute, second, microsecond), to: Calendar.ISO
  defdelegate add_day_fraction_to_iso_days(fraction, offset, microseconds), to: Calendar.ISO
  defdelegate time_from_day_fraction(fraction), to: Calendar.ISO
  defdelegate date_to_iso_days(year, month, day), to: Calendar.ISO

  @doc false
  def parse_naive_datetime(string, calendar) do
    case String.split(string, @split_reg) do
      [date, time] ->
        with {:ok, {year, month, day}} <- calendar.parse_date(date),
             {:ok, {hour, minute, second, microsecond}} <- calendar.parse_time(time) do
          {:ok, {year, month, day, hour, minute, second, microsecond}}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  @doc false
  def parse_utc_datetime(string, calendar) do
    case String.split(string, @split_reg) do
      [date, time_and_offset] ->
        with <<unquote(match_time), rest::binary>> when unquote(guard_time) <- time_and_offset,
             {microsecond, rest} <- parse_microsecond(rest),
             {offset, ""} <- parse_offset(rest),
             {:ok, {year, month, day}} <- calendar.parse_date(date) do
          {hour, minute, second} = unquote(read_time)

          cond do
            not calendar.valid_time?(hour, minute, second, microsecond) ->
              {:error, :invalid_time}

            offset == 0 ->
              {:ok, {year, month, day, hour, minute, second, microsecond}, offset}

            is_nil(offset) ->
              {:error, :missing_offset}

            true ->
              day_fraction = time_to_day_fraction(hour, minute, second, {0, 0})

              {{year, month, day}, {hour, minute, second, _}} =
                case add_day_fraction_to_iso_days({0, day_fraction}, -offset, 86400) do
                  {0, day_fraction} ->
                    {{year, month, day}, time_from_day_fraction(day_fraction)}

                  {extra_days, day_fraction} ->
                    base_days = calendar.date_to_iso_days(year, month, day)

                    {calendar.date_from_iso_days(base_days + extra_days),
                     time_from_day_fraction(day_fraction)}
                end

              {:ok, {year, month, day, hour, minute, second, microsecond}, offset}
          end
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp parse_microsecond("." <> rest) do
    case parse_microsecond(rest, 0, "") do
      {"", 0, _} ->
        :error

      {microsecond, precision, rest} when precision in 1..6 ->
        pad = String.duplicate("0", 6 - byte_size(microsecond))
        {{String.to_integer(microsecond <> pad), precision}, rest}

      {microsecond, _precision, rest} ->
        {{String.to_integer(binary_part(microsecond, 0, 6)), 6}, rest}
    end
  end

  defp parse_microsecond("," <> rest) do
    parse_microsecond("." <> rest)
  end

  defp parse_microsecond(rest) do
    {{0, 0}, rest}
  end

  defp parse_microsecond(<<head, tail::binary>>, precision, acc) when head in ?0..?9,
    do: parse_microsecond(tail, precision + 1, <<acc::binary, head>>)

  defp parse_microsecond(rest, precision, acc), do: {acc, precision, rest}

  defp parse_offset(""), do: {nil, ""}
  defp parse_offset("Z"), do: {0, ""}
  defp parse_offset("-00:00"), do: :error

  defp parse_offset(<<?+, hour::2-bytes, ?:, min::2-bytes, rest::binary>>),
    do: parse_offset(1, hour, min, rest)

  defp parse_offset(<<?-, hour::2-bytes, ?:, min::2-bytes, rest::binary>>),
    do: parse_offset(-1, hour, min, rest)

  defp parse_offset(<<?+, hour::2-bytes, min::2-bytes, rest::binary>>),
    do: parse_offset(1, hour, min, rest)

  defp parse_offset(<<?-, hour::2-bytes, min::2-bytes, rest::binary>>),
    do: parse_offset(-1, hour, min, rest)

  defp parse_offset(<<?+, hour::2-bytes, rest::binary>>), do: parse_offset(1, hour, "00", rest)
  defp parse_offset(<<?-, hour::2-bytes, rest::binary>>), do: parse_offset(-1, hour, "00", rest)
  defp parse_offset(_), do: :error

  defp parse_offset(sign, hour, min, rest) do
    with {hour, ""} when hour < 24 <- Integer.parse(hour),
         {min, ""} when min < 60 <- Integer.parse(min) do
      {(hour * 60 + min) * 60 * sign, rest}
    else
      _ -> :error
    end
  end
end
