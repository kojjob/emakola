defmodule Emakola.SplitPay.Checkout do
  @moduledoc """
  Builds the SplitPay charge for an own-stock order: merchant net as a
  fixed allocation (recipient_ref "store_<id>"), platform fee as the
  remainder — the same 200 bps math the local rails use, computed here
  because SplitPay accepts plans, it never invents them. The order
  number is the external reference and the idempotency key, so a
  double-submit returns the same charge.
  """

  alias Emakola.Payments.PlatformFee
  alias Emakola.SplitPay.Client

  def initiate(order, store, opts \\ []) do
    %{net: net} =
      PlatformFee.calculate(
        order.total,
        Application.get_env(:emakola, :platform_fee_rate_bps, 200)
      )

    params = %{
      amount: order.total,
      currency: store.currency || "GHS",
      provider: "paystack",
      external_reference: order.order_number,
      customer_email: opts[:customer_email],
      metadata: %{"source" => "makola_pay_link", "order_id" => order.id},
      allocations: [
        %{recipient_ref: "store_#{store.id}", amount: net},
        %{recipient_ref: "platform", remainder: true}
      ]
    }

    case Client.create_charge(params, order.order_number) do
      {:ok, %{"checkout_url" => url} = body} when is_binary(url) ->
        {:ok, %{checkout_url: url, charge_id: body["id"]}}

      {:ok, body} ->
        {:error, {:splitpay_error, :missing_checkout_url, body}}

      {:error, _reason} = error ->
        error
    end
  end
end
