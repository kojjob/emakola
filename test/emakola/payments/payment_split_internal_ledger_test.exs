defmodule Emakola.Payments.PaymentSplitInternalLedgerTest do
  @moduledoc """
  Internal-rail ledger vocabulary on PaymentSplit ("one ledger, two rails"):
  settlement method, currency, and the paid-out claim state.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.PaymentSplit

  setup do
    store = create_store!()
    payment = create_payment!(store)
    {:ok, store: store, payment: payment}
  end

  defp create_split!(store, payment, attrs) do
    params = Map.merge(%{store_id: store.id, payment_id: payment.id}, Map.new(attrs))

    PaymentSplit
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end

  describe "ledger attributes" do
    test "settlement_method defaults to :gateway_share and accepts :internal_hold", %{
      store: store,
      payment: payment
    } do
      default = create_split!(store, payment, %{role: :platform, amount: 840})
      assert default.settlement_method == :gateway_share

      internal =
        create_split!(store, payment, %{
          role: :merchant,
          recipient_store_id: store.id,
          amount: 41_160,
          settlement_method: :internal_hold,
          currency: "GHS"
        })

      assert internal.settlement_method == :internal_hold
      assert internal.currency == "GHS"
      assert is_nil(internal.paid_out_at)
      assert is_nil(internal.payout_id)
      assert is_nil(internal.paid_amount)
      assert internal.netted_reversal_amount == 0
    end
  end
end
