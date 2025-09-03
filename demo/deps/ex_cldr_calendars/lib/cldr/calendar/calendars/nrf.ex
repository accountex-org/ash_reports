require Cldr.Calendar.Compiler.Week

defmodule Cldr.Calendar.NRF do
  @moduledoc """
  Implements the US National Retail Federation
  (NRF) calendar.

  The NRF calendar is defined to end on the
  last Saturday of January.

  This week-based approach allows for easier
  comparison of seasonal business performance
  with most US seasonal holidays falling into
  the same week of the year.

  """
  use Cldr.Calendar.Base.Week,
    min_days_in_first_week: 4,
    first_or_last: :last,
    day_of_week: 6,
    month_of_year: 1
end
