defmodule Emakola.Payments.PayoutService do
  @moduledoc """
  Prepares a merchant payout — the decision half of the payout-execution engine.

  `prepare_payout/1` resolves a MoMo transfer destination, gathers the store's
  outstanding un-split (`split_mode: :none`) successful payments, creates a
  pending `Payout` for their sum, and stamps each covered payment (`paid_out_at`,
  `payout_id`) so it leaves the backlog and can never be paid twice. The actual
  gateway transfer is executed asynchronously by `Workers.PayoutWorker`.
  """
  alias Emakola.Payments
  alias Emakola.Payments.Payment
  alias Emakola.Stores

  # Paystack Ghana mobile-money telco codes (List Banks, type: mobile_money).
  @provider_codes %{"mtn" => "MTN", "vodafone" => "VOD", "airteltigo" => "ATL"}

  @doc """
  Resolve a usable MoMo transfer destination for a store, or `{:error,
  :no_momo_destination}` if none is configured. Shaped for
  `gateway.create_transfer_recipient/1`.
  """
  def transfer_destination(store_id) do
    with {:ok, %{payout_destination: %{"method" => "mobile_money"} = dest}} <-
           Stores.get_payout_account(store_id, authorize?: false, not_found_error?: false),
         bank_code when is_binary(bank_code) <- @provider_codes[dest["provider"]],
         number when is_binary(number) <- dest["number"] do
      {:ok,
       %{
         type: "mobile_money",
         name: dest["account_name"] || "",
         account_number: number,
         bank_code: bank_code,
         currency: "GHS"
       }}
    else
      _ -> {:error, :no_momo_destination}
    end
  end

  @doc "A store's outstanding un-split successful payments (the manual-payout backlog)."
  def outstanding_payments(store_id) do
    # "Outstanding" is defined once, on the resource — see
    # Payment.outstanding_for_payout.
    Payment
    |> Ash.Query.for_read(:outstanding_for_payout, %{store_id: store_id})
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Create a pending payout for a store's outstanding balance and stamp the covered
  payments. Returns `{:ok, payout}`, `{:error, :no_momo_destination}` or
  `{:error, :nothing_outstanding}` (validating the destination first so nothing is
  stamped when a payout can't be made).
  """
  def prepare_payout(store_id) do
    with {:ok, _dest} <- transfer_destination(store_id) do
      # One transaction with a row lock on the outstanding payments is the
      # serialization point: a concurrent approval blocks on `FOR UPDATE`, then
      # re-reads the now-stamped rows as empty — so the same balance can never be
      # claimed by two payouts (no double-pay).
      Emakola.Repo.transaction(fn ->
        payments =
          Payment
          |> Ash.Query.for_read(:outstanding_for_payout, %{store_id: store_id})
          |> Ash.Query.lock("FOR UPDATE")
          |> Ash.read!(authorize?: false)

        # Pay one currency per payout (stores are single-currency in practice);
        # take the currency of the claimed set rather than summing across currencies.
        currency = payments |> List.first(%{}) |> Map.get(:currency, "GHS")
        claimed = Enum.filter(payments, &(&1.currency == currency))

        if claimed == [] do
          Emakola.Repo.rollback(:nothing_outstanding)
        end

        # A released buyer-protection hold snapshots `payable_amount` (the net,
        # after the platform fee) on the payment — pay that instead of the
        # gross `amount` when present. Unprotected payments have no
        # `payable_amount`, so `|| amount` leaves them byte-identical.
        amount = claimed |> Enum.map(&(&1.payable_amount || &1.amount)) |> Enum.sum()
        reference = "po_" <> Ecto.UUID.generate()

        {:ok, payout} =
          Payments.create_payout(
            %{
              store_id: store_id,
              amount: amount,
              currency: currency,
              transfer_reference: reference
            },
            authorize?: false
          )

        Enum.each(claimed, fn payment ->
          {:ok, _} =
            Payments.mark_payment_paid_out(payment, %{payout_id: payout.id}, authorize?: false)
        end)

        payout
      end)
    else
      {:error, :no_momo_destination} = err -> err
    end
  end

  @doc "True when the store has a usable MoMo transfer destination."
  def momo_destination?(store_id) do
    match?({:ok, _}, transfer_destination(store_id))
  end

  @doc """
  Create a pending allocation-basis payout for a store's payable internal
  balance and claim the covered splits. Mirrors `prepare_payout/1`'s
  serialization exactly: one transaction, `FOR UPDATE` on the payable set, so
  a concurrent approval re-reads empty (no double-pay).

  `Payout.amount` must be final at creation (`PayoutWorker` reads it to build
  the transfer), but claiming a split via `mark_paid_out` requires the
  payout's id — so the amount is precomputed from the FOR-UPDATE-locked rows
  with `PaymentSplit.frozen_paid_amount/1` — THE single formula authority,
  the exact function `mark_paid_out` itself calls to freeze `paid_amount` —
  the payout is created for that sum, and only then is each split claimed
  with the real `payout_id`. Since both calls share one function, they can
  never disagree on the formula; the assertion below instead guards the call
  path — that `mark_paid_out` really applied `frozen_paid_amount/1` to the
  exact row this precompute read (the `FOR UPDATE` lock rules out a stale
  read) — and would only fire if a future edit broke that wiring.
  """
  def prepare_internal_payout(recipient_store_id) do
    with {:ok, _dest} <- transfer_destination(recipient_store_id) do
      Emakola.Repo.transaction(fn ->
        splits =
          Emakola.Payments.PaymentSplit
          |> Ash.Query.for_read(:payable_internal, %{recipient_store_id: recipient_store_id})
          |> Ash.Query.lock("FOR UPDATE")
          |> Ash.read!(authorize?: false)

        # One currency per payout, same partition rule as prepare_payout/1.
        currency = splits |> List.first(%{}) |> Map.get(:currency, "GHS")
        claimed = Enum.filter(splits, &(&1.currency == currency))

        if claimed == [] do
          Emakola.Repo.rollback(:nothing_outstanding)
        end

        amount =
          claimed |> Enum.map(&Emakola.Payments.PaymentSplit.frozen_paid_amount/1) |> Enum.sum()

        reference = "po_" <> Ecto.UUID.generate()

        {:ok, payout} =
          Emakola.Payments.create_payout(
            %{
              store_id: recipient_store_id,
              amount: amount,
              currency: currency,
              transfer_reference: reference,
              basis: :allocations
            },
            authorize?: false
          )

        Enum.each(claimed, fn split ->
          expected = Emakola.Payments.PaymentSplit.frozen_paid_amount(split)

          {:ok, updated} =
            Emakola.Payments.mark_payment_split_paid_out(split, %{payout_id: payout.id},
              authorize?: false
            )

          if updated.paid_amount != expected do
            raise "paid_amount drift on split #{split.id}: mark_paid_out froze " <>
                    "#{updated.paid_amount}, prepare_internal_payout precomputed #{expected} " <>
                    "(FOR UPDATE lock should make this impossible)"
          end
        end)

        payout
      end)
    else
      {:error, :no_momo_destination} = err -> err
    end
  end

  @doc """
  Release every charge (payments and/or splits) a payout claimed, back to
  payable. Shared by two callers:

  - `Workers.PaystackWebhookHandler`, when a `transfer.failed`/`transfer.reversed`
    webhook drives a payout to a terminal failure state.
  - `Workers.PayoutWorker`, when it marks a payout `:failed` itself on a
    definitive PRE-webhook rejection (no destination, or a definitive
    Paystack error from `initiate_transfer`) — no transfer was ever created,
    so no webhook will ever run to release the claim otherwise, and the
    claimed charge would be stranded (gone from payable, unreachable by
    retry) forever.

  Idempotent — safe to re-run: `by_payout` re-reads fresh rows, and a charge
  already released (or re-claimed by a fresh payout) simply doesn't match, so
  a retry after a crash mid-release, or a webhook replay, still completes
  without burying the balance. Legacy-basis payouts claim Payments;
  allocation-basis payouts claim PaymentSplits instead — each list is empty
  for the other basis, so both loops are safe to run unconditionally.
  """
  def release_payout_balance(payout) do
    {:ok, payments} = Payments.list_payments_by_payout(payout.id, authorize?: false)

    Enum.each(payments, fn payment ->
      payment
      |> Ash.Changeset.for_update(:release_from_payout, %{})
      |> Ash.update!(authorize?: false)
    end)

    {:ok, splits} = Payments.list_payment_splits_by_payout(payout.id, authorize?: false)

    Enum.each(splits, fn split ->
      {:ok, _} = Payments.release_payment_split_from_payout(split, authorize?: false)
    end)
  end
end
