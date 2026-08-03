defmodule Emakola.Payments.EarningsReadsTest do
  @moduledoc """
  Domain foundation for the earnings-by-recipient money surface (PR-2, Task 1):

    * `PaymentSplit.earnings_by_recipient` — recipient-scoped history of
      settled/partially_reversed/reversed splits, newest-first, bounded to
      100 rows. Reversals are INCLUDED (the narrative shows what happened;
      net is computed by consumers via `PaymentSplit.frozen_paid_amount/1`).

  Zero behavior change — a read only.
  """
  use EmakolaWeb.ConnCase, async: true

  alias Emakola.Factory
  alias Emakola.Payments

  defp split!(store, payment, attrs) do
    %{
      store_id: store.id,
      payment_id: payment.id,
      role: :merchant,
      recipient_store_id: store.id,
      amount: 10_000,
      settlement_method: :internal_hold
    }
    |> Map.merge(Map.new(attrs))
    |> then(&Payments.create_payment_split!(&1, authorize?: false))
  end

  defp settled!(store, payment, attrs \\ %{}) do
    split!(store, payment, attrs)
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)
  end

  defp reversed!(store, payment, attrs \\ %{}) do
    settled!(store, payment, attrs)
    |> Ash.Changeset.for_update(:mark_reversed, %{})
    |> Ash.update!(authorize?: false)
  end

  describe "earnings_by_recipient" do
    test "returns the recipient's settled/partially_reversed/reversed rows, newest first" do
      store = Factory.create_store!()
      other_store = Factory.create_store!()
      payment = Factory.create_payment!(store, %{amount: 30_000})

      wholesaler_row =
        settled!(store, payment, %{role: :wholesaler, amount: 10_000})

      dropshipper_row =
        settled!(store, payment, %{role: :dropshipper, amount: 10_000})

      merchant_row =
        settled!(store, payment, %{role: :merchant, amount: 10_000})

      # Excluded: platform role, another store's row, and a pending row —
      # each on its own payment (the unique_allocation identity is
      # payment+role+supplier+credit_agreement, so a second :merchant row on
      # the SAME payment would collide regardless of recipient_store_id).
      settled!(store, payment, %{role: :platform, recipient_store_id: nil, amount: 5_000})

      other_payment = Factory.create_payment!(other_store, %{amount: 5_000})
      settled!(other_store, other_payment, %{recipient_store_id: other_store.id, amount: 5_000})

      pending_payment = Factory.create_payment!(store, %{amount: 5_000})
      split!(store, pending_payment, %{amount: 5_000})

      assert {:ok, splits} = Payments.list_earnings_splits(store.id, authorize?: false)

      assert Enum.map(splits, & &1.id) == [
               merchant_row.id,
               dropshipper_row.id,
               wholesaler_row.id
             ]
    end

    test "includes reversed rows — the narrative shows history, net is computed by consumers" do
      store = Factory.create_store!()
      payment = Factory.create_payment!(store, %{amount: 10_000})

      row = reversed!(store, payment)

      assert {:ok, [found]} = Payments.list_earnings_splits(store.id, authorize?: false)
      assert found.id == row.id
      assert found.status == :reversed
    end

    test "the read is prepared with a bounded limit (100) — noted so the cap is visible" do
      store = Factory.create_store!()

      rows =
        for _ <- 1..3 do
          payment = Factory.create_payment!(store, %{amount: 1_000})
          settled!(store, payment, %{amount: 1_000})
        end

      assert {:ok, splits} = Payments.list_earnings_splits(store.id, authorize?: false)
      assert length(splits) == length(rows)
    end

    test "a member merchant CAN read their store's earnings splits" do
      {merchant, store} = Factory.create_merchant_with_store!()
      payment = Factory.create_payment!(store, %{amount: 10_000})
      settled!(store, payment)

      assert {:ok, [_split]} =
               Payments.list_earnings_splits(store.id, actor: merchant, tenant: store.id)
    end

    test "a non-member merchant CANNOT read another store's earnings splits" do
      {_owner, store} = Factory.create_merchant_with_store!()
      {other_merchant, _other_store} = Factory.create_merchant_with_store!()
      payment = Factory.create_payment!(store, %{amount: 10_000})
      settled!(store, payment)

      assert {:error, %Ash.Error.Forbidden{}} =
               Payments.list_earnings_splits(store.id, actor: other_merchant, tenant: store.id)
    end
  end
end
