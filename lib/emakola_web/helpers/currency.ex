defmodule EmakolaWeb.Helpers.Currency do
  @moduledoc """
  Currency formatting helpers for storefront display.

  All monetary amounts are stored as integers in minor units
  (pesewas for GHS, kobo for NGN). This module converts them
  to human-readable strings.
  """

  @doc """
  Formats an integer amount in minor currency units to a display string.

  Round numbers (no minor units) omit the decimal portion for cleaner display.

  ## Examples

      iex> EmakolaWeb.Helpers.Currency.format_price(15000)
      "GH\\u20B5 150"

      iex> EmakolaWeb.Helpers.Currency.format_price(480000)
      "GH\\u20B5 4,800"

      iex> EmakolaWeb.Helpers.Currency.format_price(5050, "NGN")
      "\\u20A6 50.50"

      iex> EmakolaWeb.Helpers.Currency.format_price(0)
      "GH\\u20B5 0"
  """
  @spec format_price(integer(), String.t()) :: String.t()
  def format_price(amount_minor_units, currency \\ "GHS") when is_integer(amount_minor_units) do
    major = amount_minor_units |> div(100) |> Emakola.Money.group_thousands()
    minor = rem(amount_minor_units, 100)
    symbol = currency_symbol(currency)

    if minor == 0 do
      "#{symbol} #{major}"
    else
      minor_str = minor |> abs() |> Integer.to_string() |> String.pad_leading(2, "0")
      "#{symbol} #{major}.#{minor_str}"
    end
  end

  @doc """
  Formats a price range from min/max pesewas.
  If min == max, shows a single price. Otherwise "GH\\u20B5 10.00 - GH\\u20B5 25.00".
  """
  @spec format_price_range(integer() | nil, integer() | nil, String.t()) :: String.t()
  def format_price_range(nil, nil, _currency), do: "Price not set"
  def format_price_range(min, nil, currency), do: format_price(min, currency)
  def format_price_range(nil, max, currency), do: format_price(max, currency)

  def format_price_range(min, max, currency) when min == max,
    do: format_price(min, currency)

  def format_price_range(min, max, currency),
    do: "#{format_price(min, currency)} - #{format_price(max, currency)}"

  @doc "Returns the currency symbol for a given currency code."
  @spec currency_symbol(String.t()) :: String.t()
  def currency_symbol("GHS"), do: "GH\u20B5"
  def currency_symbol("NGN"), do: "\u20A6"
  def currency_symbol("USD"), do: "$"
  def currency_symbol(_), do: ""
end
