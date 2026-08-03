defmodule Emakola.Payments.InternallyPayableParityTest do
  @moduledoc """
  Predicate-parity guard (money-surfaces PR-2 fix wave).

  `earnings_live`'s "payable now" tile used to filter its capped history
  read via `PaymentSplit.internally_payable?/1` in memory, while
  `payout_live`'s accrued tile filters via the `payable_internal` Ash read
  action — a hand-maintained Elixir mirror of a filter expression, with
  nothing forcing the two to stay in sync if either definition ever
  changes. (`earnings_live` has since moved to calling `payable_internal`
  directly for `payable_now`, but `internally_payable?/1` remains public —
  documented on `PaymentSplit` as the mirror for callers that already
  loaded splits via one query — so the drift risk is still live.)

  One fixture per discriminating clause in the read's filter, asserting
  `internally_payable?/1` selects EXACTLY the rows `payable_internal`
  returns (membership equivalence) — a future edit to either side that
  breaks the mirror fails loudly here instead of surfacing as a silent
  number mismatch between the two merchant money pages.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments
  alias Emakola.Payments.PaymentSplit

  defp create_split!(store, payment, attrs) do
    params = Map.merge(%{store_id: store.id, payment_id: payment.id}, Map.new(attrs))

    PaymentSplit
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end

  defp settle!(split) do
    split
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)
  end

  test "internally_payable?/1 selects exactly the rows payable_internal returns" do
    store = create_store!()

    # Included — every clause satisfied.
    payable =
      settle!(
        create_split!(store, create_payment!(store), %{
          role: :merchant,
          recipient_store_id: store.id,
          amount: 10_000,
          settlement_method: :internal_hold
        })
      )

    # Excluded — settlement_method: money already left at charge time via
    # the gateway rail, so it can never be "owed" through the ledger.
    gateway_share =
      settle!(
        create_split!(store, create_payment!(store), %{
          role: :wholesaler,
          recipient_store_id: store.id,
          supplier_id: Ash.UUID.generate(),
          subaccount_code: "ACCT_w",
          amount: 5_000,
          settlement_method: :gateway_share
        })
      )

    # Excluded — role: the platform's own cut never sits in the payable
    # ledger.
    platform =
      settle!(
        create_split!(store, create_payment!(store), %{
          role: :platform,
          amount: 800,
          settlement_method: :internal_hold
        })
      )

    # Excluded — status: never settled.
    pending =
      create_split!(store, create_payment!(store), %{
        role: :dropshipper,
        recipient_store_id: store.id,
        amount: 2_000,
        settlement_method: :internal_hold
      })

    # Excluded — paid_out_at: already claimed by a payout.
    claimed =
      settle!(
        create_split!(store, create_payment!(store), %{
          role: :credit_partner,
          recipient_store_id: store.id,
          amount: 3_000,
          settlement_method: :internal_hold
        })
      )
      |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
      |> Ash.update!(authorize?: false)

    # Excluded — amount > reversed_amount: fully reversed by amount (a
    # partial reversal would stay payable for its net; this one reversed
    # the entire amount).
    fully_reversed =
      settle!(
        create_split!(store, create_payment!(store), %{
          role: :merchant,
          recipient_store_id: store.id,
          amount: 4_000,
          settlement_method: :internal_hold
        })
      )
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 4_000})
      |> Ash.update!(authorize?: false)

    all_splits = [payable, gateway_share, platform, pending, claimed, fully_reversed]

    {:ok, read_rows} = Payments.list_payable_internal_splits(nil, authorize?: false)
    read_ids = read_rows |> Enum.map(& &1.id) |> MapSet.new()

    predicate_ids =
      all_splits
      |> Enum.filter(&PaymentSplit.internally_payable?/1)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    assert predicate_ids == MapSet.new([payable.id])
    assert read_ids == predicate_ids
  end
end
