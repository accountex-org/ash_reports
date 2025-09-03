require Cldr.Calendar.Compiler.Month

defmodule Cldr.Calendar.ISO do
  @moduledoc false

  # Same as the Gregorian calendar but ISO8601 says
  # there must be 4 days in the first week (whereas
  # its 1 day in the Gregorian calendar).

  use Cldr.Calendar.Base.Month,
    month_of_year: 1,
    day_of_week: 1,
    min_days_in_first_week: 4,
    day_of_week: Cldr.Calendar.monday()
end
