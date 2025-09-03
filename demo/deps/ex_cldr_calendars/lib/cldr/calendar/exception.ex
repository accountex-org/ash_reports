defmodule Cldr.IncompatibleCalendarError do
  @moduledoc """
  Exception raised when an attempt is made to use a two incompatible
  calendars.

  """
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Cldr.InvalidCalendarModule do
  @moduledoc """
  Exception raised when a module is not a
  calendar.

  """
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Cldr.InvalidDateOrder do
  @moduledoc """
  Exception raised when two dates
  or times are not ordered from earlier
  to later

  """
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Cldr.IncompatibleTimeZone do
  @moduledoc """
  Exception raised when a two datestimes
  are not in the same timezone

  """
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Cldr.MissingFields do
  @moduledoc """
  Exception raised when the provided
  date does not have the required fields
  for a function.

  """
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end
