defmodule Cldr.Calendar.FiscalYear do
  @fiscal_year_data "./priv/fiscal_years_by_territory.csv"

  [_headings | rows] =
    @fiscal_year_data
    |> File.read!()
    |> String.split("\r\n")

  rows =
    Enum.map(rows, fn row ->
      String.split(row, ~r/(,\"|\",)/)
      |> Enum.flat_map(fn r ->
        if String.contains?(r, "\"") do
          ["dont_care"]
        else
          String.split(r, ",")
        end
      end)
    end)

  @fiscal_year_by_territory rows
                            |> Enum.map(fn
                              [_, "", _, _, _month, _day, _min_days, _] ->
                                nil

                              [
                                _,
                                territory,
                                _,
                                "Cldr.Calendar.Gregorian" = calendar,
                                month,
                                _day,
                                _min_days,
                                _
                              ] ->
                                {:ok, territory} = Cldr.validate_territory(territory)
                                calendar = Module.concat([calendar])
                                month = String.to_integer(month)
                                {territory, [calendar: calendar, month_of_year: month]}

                              _other ->
                                nil
                            end)
                            |> Enum.reject(&is_nil/1)
                            |> Map.new()

  @known_fiscal_calendars Map.keys(@fiscal_year_by_territory)

  def known_fiscal_years do
    @fiscal_year_by_territory
  end

  def known_fiscal_calendars do
    @known_fiscal_calendars
  end

  def calendar_for(territory) do
    with {:ok, territory} <- Cldr.validate_territory(territory),
         {:ok, territory} <- known_fiscal_calendar(territory) do
      get_or_create_calendar_for(territory, Map.get(known_fiscal_years(), territory))
    end
  end

  defp known_fiscal_calendar(territory) do
    if territory in @known_fiscal_calendars do
      {:ok, territory}
    else
      {:error,
       {Cldr.UnknownCalendarError, "Fiscal calendar is unknown for #{inspect(territory)}"}}
    end
  end

  defp get_or_create_calendar_for(territory, config) do
    module = Module.concat(Cldr.Calendar.FiscalYear, territory)
    Cldr.Calendar.new(module, :month, config)
  end
end
