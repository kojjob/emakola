defmodule Emakola.Notifications.Emails.EmailHelpers do
  @moduledoc """
  Shared formatting helpers for email templates.

  All monetary amounts are expected as integers in minor currency units
  (pesewas for GHS, kobo for NGN). Formatting to human-readable form
  with thousands separators happens here.
  """

  @doc """
  Formats a minor-unit integer as a currency string with symbol.

  ## Examples

      iex> Emakola.Notifications.Emails.EmailHelpers.format_money(40000, "GHS")
      "GH₵400.00"

      iex> Emakola.Notifications.Emails.EmailHelpers.format_money(250000, "NGN")
      "₦2,500.00"

      iex> Emakola.Notifications.Emails.EmailHelpers.format_money(99, "GHS")
      "GH₵0.99"
  """
  def format_money(minor_units, currency) when is_integer(minor_units) do
    major = div(minor_units, 100)
    minor = rem(abs(minor_units), 100)
    formatted_major = Emakola.Money.group_thousands(major)

    "#{currency_symbol(currency)}#{formatted_major}.#{String.pad_leading(Integer.to_string(minor), 2, "0")}"
  end

  def format_money(_amount, _currency), do: ""

  @doc """
  Returns the from tuple for an email based on the store.
  Falls back to noreply@makola.io when store has no contact_email.
  """
  def from_address(store) do
    email = store.contact_email || "noreply@makola.io"
    {store.name, email}
  end

  @doc """
  Formats a shipping address map into display lines.
  Returns an empty list for nil addresses.
  """
  def format_address(nil), do: []

  def format_address(address) when is_map(address) do
    [
      address["name"],
      address["address_line_1"],
      address["address_line_2"],
      [address["city"], address["region"]] |> Enum.reject(&is_nil/1) |> Enum.join(", "),
      address["phone"]
    ]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
  end

  @doc """
  Cleans a WhatsApp number for use in wa.me links.
  Strips the leading + sign.
  """
  def whatsapp_link(nil), do: nil

  def whatsapp_link(number) do
    cleaned = String.replace(number, ~r/[^0-9]/, "")
    "https://wa.me/#{cleaned}"
  end

  @doc """
  Formats a DateTime into a human-readable date string.
  """
  def format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y at %I:%M %p UTC")
  end

  def format_date(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y at %I:%M %p")
  end

  def format_date(_), do: ""

  # ── Private ─────────────────────────────────────────────────────

  defp currency_symbol("GHS"), do: "GH\u20B5"
  defp currency_symbol("NGN"), do: "\u20A6"
  defp currency_symbol("USD"), do: "$"
  defp currency_symbol(_), do: ""
end
