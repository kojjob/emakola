defmodule Emakola.Payments.PaymentRouter do
  @moduledoc """
  Routes payment method selection to the correct gateway module.

  Supported methods:
  - `:momo_mtn` — MTN Mobile Money via Paystack
  - `:momo_vodafone` — Vodafone Cash via Paystack
  - `:momo_airteltigo` — AirtelTigo Money via Paystack
  - `:card` — Card payment via Paystack
  - `:cod` — Cash on Delivery (no external gateway)

  ## Usage

      {:ok, gateway, gateway_params} = PaymentRouter.route_payment(:momo_mtn, %{
        amount: 500_000,
        email: "customer@example.com",
        phone: "0241234567",
        ...
      })

      # Then call the gateway
      {:ok, result} = gateway.initiate_payment(gateway_params)
  """

  alias Emakola.Payments.Gateways.{CashOnDelivery, Paystack}

  @type payment_method :: :momo_mtn | :momo_vodafone | :momo_airteltigo | :card | :cod

  @momo_providers %{
    momo_mtn: "mtn",
    momo_vodafone: "vod",
    momo_airteltigo: "tgo"
  }

  @doc """
  Routes a payment method to the correct gateway and builds gateway-specific params.

  Returns `{:ok, gateway_module, gateway_params}` on success,
  or `{:error, {:unknown_payment_method, method}}` for unsupported methods.
  """
  @spec route_payment(payment_method(), map()) ::
          {:ok, module(), map()} | {:error, {:unknown_payment_method, atom()}}
  def route_payment(method, params) when is_map_key(@momo_providers, method) do
    provider = Map.fetch!(@momo_providers, method)

    gateway_params =
      params
      |> Map.put(:channel, "mobile_money")
      |> Map.put(:mobile_money_provider, provider)

    {:ok, Paystack, gateway_params}
  end

  def route_payment(:card, params) do
    gateway_params = Map.put(params, :channel, "card")
    {:ok, Paystack, gateway_params}
  end

  def route_payment(:cod, params) do
    {:ok, CashOnDelivery, params}
  end

  def route_payment(method, _params) do
    {:error, {:unknown_payment_method, method}}
  end
end
