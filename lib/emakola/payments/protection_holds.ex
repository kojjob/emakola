defmodule Emakola.Payments.ProtectionHolds do
  @moduledoc """
  Idempotent `ProtectionHold` creation for a webhook-confirmed payment
  (TC-2). Called from both webhook confirm sites (Paystack + Hubtel)
  immediately after the payment is marked `:success`.

  `ProtectionHold`'s unique `payment_id` identity makes a retry a no-op: a
  webhook replay or a redelivery after a crashed post-processing step simply
  hits the identity violation, which is rescued into `:ok`. Never raises into
  the calling worker.
  """

  require Logger

  alias Emakola.Payments.PlatformFee

  @doc "Creates the protection hold for a payment held for buyer protection. No-op otherwise."
  def ensure_hold(%{payout_hold_reason: "buyer_protection"} = payment) do
    %{fee: fee, net: net} = PlatformFee.calculate(payment.amount, fee_rate_bps())

    Emakola.Payments.create_protection_hold!(
      %{
        store_id: payment.store_id,
        payment_id: payment.id,
        order_id: payment.order_id,
        amount: payment.amount,
        fee: fee,
        net: net
      },
      tenant: payment.store_id,
      authorize?: false
    )

    :ok
  rescue
    error ->
      Logger.error(
        "[protection_holds] ensure_hold failed for payment=#{payment.id}: #{Exception.format(:error, error, __STACKTRACE__)}"
      )

      :ok
  end

  def ensure_hold(_payment), do: :ok

  defp fee_rate_bps do
    Application.get_env(:emakola, :platform_fee_rate_bps, 200)
  end
end
