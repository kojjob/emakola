defmodule Emakola.Payments.PaymentSplitTest do
  @moduledoc """
  PaymentSplit records how a single customer charge was allocated across the
  wholesaler(s), the platform, and the dropshipper (SP5). Immutable financial
  records: a reversal is a status transition, never a delete.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  alias Emakola.Payments.PaymentSplit

  setup do
    store = create_store!()
    payment = create_payment!(store)
    {:ok, store: store, payment: payment}
  end

  defp create_split!(store, payment, attrs) do
    params =
      Map.merge(%{store_id: store.id, payment_id: payment.id}, Map.new(attrs))

    PaymentSplit
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end

  describe "create" do
    test "persists a wholesaler allocation and defaults to pending", %{
      store: store,
      payment: payment
    } do
      wholesaler = create_store!(name: "Wholesaler Co")

      split =
        create_split!(store, payment, %{
          role: :wholesaler,
          recipient_store_id: wholesaler.id,
          supplier_id: Ash.UUID.generate(),
          subaccount_code: "ACCT_whole",
          amount: 1_600
        })

      assert split.payment_id == payment.id
      assert split.role == :wholesaler
      assert split.recipient_store_id == wholesaler.id
      assert split.subaccount_code == "ACCT_whole"
      assert split.amount == 1_600
      assert split.status == :pending
    end

    test "persists a platform allocation with no recipient store or subaccount", %{
      store: store,
      payment: payment
    } do
      split = create_split!(store, payment, %{role: :platform, amount: 840})

      assert split.role == :platform
      assert is_nil(split.recipient_store_id)
      assert is_nil(split.subaccount_code)
      assert split.amount == 840
    end
  end

  describe "status transitions" do
    test "mark_settled moves a pending split to settled", %{store: store, payment: payment} do
      split = create_split!(store, payment, %{role: :platform, amount: 840})

      {:ok, settled} =
        split
        |> Ash.Changeset.for_update(:mark_settled, %{paystack_split_reference: "SPL_123"})
        |> Ash.update(authorize?: false)

      assert settled.status == :settled
      assert settled.paystack_split_reference == "SPL_123"
    end

    test "mark_reversed moves a settled split to reversed", %{store: store, payment: payment} do
      split = create_split!(store, payment, %{role: :platform, amount: 840})

      {:ok, settled} =
        split |> Ash.Changeset.for_update(:mark_settled, %{}) |> Ash.update(authorize?: false)

      {:ok, reversed} =
        settled |> Ash.Changeset.for_update(:mark_reversed, %{}) |> Ash.update(authorize?: false)

      assert reversed.status == :reversed
    end
  end

  describe "by_payment" do
    test "returns every allocation for a payment", %{store: store, payment: payment} do
      create_split!(store, payment, %{role: :platform, amount: 840})

      create_split!(store, payment, %{
        role: :dropshipper,
        subaccount_code: "ACCT_drop",
        amount: 10_560
      })

      {:ok, splits} =
        PaymentSplit
        |> Ash.Query.for_read(:by_payment, %{payment_id: payment.id})
        |> Ash.read(authorize?: false)

      assert length(splits) == 2
      assert Enum.sort(Enum.map(splits, & &1.amount)) == [840, 10_560]
    end
  end
end
