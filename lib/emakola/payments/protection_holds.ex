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

  require Ash.Query
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
  Cheap existence check: does `order_id` currently have an actively `:held`
  buyer-protection hold? A single query directly against
  `ProtectionHold.order_id` — used to gate whether a release trigger is
  worth enqueueing at all, without paying for the full payment lookup
  `release_for_order/3` does (only worth it once we know there's something
  to release) or a fulfillment scan.

  A frozen hold is still `status: :held` (freezing doesn't change status —
  see `ProtectionHold`'s moduledoc), so this returns `true` for one too;
  the actual release, once enqueued, correctly no-ops on it.
  """
  def active_hold_for_order?(order_id, store_id) do
    ProtectionHold
    |> Ash.Query.filter(order_id == ^order_id and status == :held)
    |> Ash.Query.limit(1)
    |> Ash.read!(tenant: store_id, authorize?: false)
    |> Enum.any?()
  end

  @doc """
  Fetches `order_id`'s buyer-protection hold in ANY state (`held`, and a
  `held` hold may additionally be `frozen_at`-flagged, `released`, or
  `refunded`) — for surfaces that display the current hold regardless of
  whether it's still active, e.g. the tracking page's protection strip
  (renders for every viewer once a hold exists, not just while `:held` —
  see `active_hold_for_order?/2` for the held-only existence check used to
  gate release triggers). Returns `nil` when the order was never protected.
  """
  def get_hold_for_order(order_id, store_id) do
    ProtectionHold
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.Query.limit(1)
    |> Ash.read!(tenant: store_id, authorize?: false)
    |> List.first()
  end

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
