defmodule EmakolaWeb.Admin.OrderLive.Rails do
  @moduledoc """
  Which payment rail an order was paid on, read from the gateway's stored
  charge data, for the rail chip a merchant recognises by colour.

  Paystack keeps `channel` and `authorization.bank` ("MTN", "Telecel",
  "AirtelTigo"); Hubtel's webhook stores neither, so its payments fall back
  to the gateway chip. Shared by the order list and the order page.
  """

  @type rail ::
          :mtn_momo | :telecel_cash | :airteltigo | :mobile_money | :card | :hubtel | :paystack

  @spec for_payment(map()) :: rail()
  def for_payment(payment) do
    gateway_response = payment.gateway_response || %{}

    channel =
      gateway_response["channel"] || get_in(gateway_response, ["authorization", "channel"])

    cond do
      channel == "card" -> :card
      channel == "mobile_money" -> momo_rail(get_in(gateway_response, ["authorization", "bank"]))
      true -> payment.gateway
    end
  end

  defp momo_rail(bank) do
    bank = String.downcase(to_string(bank))

    cond do
      bank =~ "mtn" -> :mtn_momo
      bank =~ "telecel" or bank =~ "vodafone" -> :telecel_cash
      bank =~ "airtel" or bank =~ "tigo" -> :airteltigo
      true -> :mobile_money
    end
  end
end
