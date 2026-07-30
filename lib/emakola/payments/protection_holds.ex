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

  alias Emakola.Payments
  alias Emakola.Payments.{Payment, PlatformFee, ProtectionHold, ProtectionRelease}

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
      if unique_payment_violation?(error) do
        :ok
      else
        Logger.error(
          "[protection_holds] ensure_hold failed for payment=#{payment.id}: #{Exception.format(:error, error, __STACKTRACE__)}"
        )

        :ok
      end
  end

  def ensure_hold(_payment), do: :ok

  @doc """
  Finds `order_id`'s buyer-protection hold — via its captured payment's
  `payout_hold_reason` — and releases it for `reason`.

  Returns `:ok` when the order was never protected (no captured payment
  carries the `"buyer_protection"` hold reason, or the payment has no hold
  row): an ordinary outcome for the vast majority of orders, not a failure.
  Otherwise returns whatever `ProtectionRelease.release/2` returns — release
  itself already treats "already released" and (by default) frozen holds as
  no-op `:ok`s, so an `{:error, _}` here is a genuine failure worth the
  caller logging.

  Shared by every order-level release trigger (delivery-OTP verification;
  the buyer's own tracking-page confirmation) so the payment→hold lookup
  lives in one place.
  """
  def release_for_order(order_id, store_id, reason) do
    with {:ok, payments} <-
           Payments.list_captured_payments_by_order(order_id,
             tenant: store_id,
             authorize?: false
           ),
         %Payment{id: payment_id} <-
           Enum.find(payments, &(&1.payout_hold_reason == "buyer_protection")),
         {:ok, %ProtectionHold{} = hold} <-
           Payments.get_protection_hold_by_payment(payment_id,
             tenant: store_id,
             authorize?: false
           ) do
      ProtectionRelease.release(hold, reason)
    else
      _ -> :ok
    end
  end

  # The expected shape of a retried/replayed create hitting the `:unique_payment`
  # identity — a benign no-op, not a failure worth alerting on. Everything else
  # (a genuinely invalid create, an unexpected exception) still logs.
  defp unique_payment_violation?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidAttribute{field: :payment_id, private_vars: private_vars} ->
        Keyword.get(private_vars, :constraint_type) == :unique

      _ ->
        false
    end)
  end

  defp unique_payment_violation?(_error), do: false

  defp fee_rate_bps do
    Application.get_env(:emakola, :platform_fee_rate_bps, 200)
  end
end
