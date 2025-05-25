defmodule AshReports.SimpleFormatter do
  @moduledoc """
  A simple formatter for report data without CLDR dependencies.
  This is a temporary implementation until CLDR compilation issues are resolved.
  """
  
  def format_number(value, opts \\ []) when is_number(value) do
    precision = Keyword.get(opts, :precision, 2)
    locale = Keyword.get(opts, :locale, "en")
    
    formatted = :erlang.float_to_binary(value * 1.0, [{:decimals, precision}])
    |> to_string()
    
    # Simple locale-based formatting
    case locale do
      "de" -> String.replace(formatted, ".", ",")
      _ -> formatted
    end
  end
  
  def format_currency(value, opts \\ []) when is_number(value) do
    currency = Keyword.get(opts, :currency, "USD")
    formatted = format_number(value, opts)
    
    case currency do
      "USD" -> "$#{formatted}"
      "EUR" -> "#{formatted} €"
      _ -> "#{currency} #{formatted}"
    end
  end
  
  def format_percentage(value, opts \\ []) when is_number(value) do
    multiply = Keyword.get(opts, :multiply, true)
    precision = Keyword.get(opts, :precision, 1)
    percentage_value = if multiply, do: value * 100, else: value
    formatted = format_number(percentage_value, Keyword.put(opts, :precision, precision))
    "#{formatted}%"
  end
  
  def format_date(%Date{} = date, _opts) do
    Date.to_iso8601(date)
  end
  
  def format_datetime(%DateTime{} = datetime, _opts) do
    DateTime.to_iso8601(datetime)
  end
  
  def format_datetime(%NaiveDateTime{} = datetime, _opts) do
    NaiveDateTime.to_iso8601(datetime)
  end
  
  def format_time(%Time{} = time, _opts) do
    Time.to_iso8601(time)
  end
  
  def format_boolean(true, opts) do
    locale = Keyword.get(opts, :locale, "en")
    
    case locale do
      "es" -> "Sí"
      "fr" -> "Oui"
      "de" -> "Ja"
      "pt" -> "Sim"
      _ -> Keyword.get(opts, :true_text, "Yes")
    end
  end
  
  def format_boolean(false, opts) do
    locale = Keyword.get(opts, :locale, "en")
    
    case locale do
      "es" -> "No"
      "fr" -> "Non"
      "de" -> "Nein"
      "pt" -> "Não"
      _ -> Keyword.get(opts, :false_text, "No")
    end
  end
  
  def format_boolean(nil, opts) do
    Keyword.get(opts, :nil_text, "")
  end
  
  def text_direction(locale) when locale in ["ar", "he", "fa", "ur"], do: :rtl
  def text_direction(_), do: :ltr
end