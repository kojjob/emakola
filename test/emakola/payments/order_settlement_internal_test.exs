defmodule Emakola.Payments.OrderSettlementInternalTest do
  @moduledoc """
  Internal-rail recording: record_splits! persists the settlement method and
  currency; persist_payment/2 makes payment + splits one transaction; the
  internal allocation builders reuse the gateway rail's exact fee math.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.OrderSettlement

  describe "record_splits!/2 ledger columns" do
    test "persists settlement_method and stamps the payment's currency" do
      store = create_store!()
      payment = create_payment!(store, currency: "GHS")

      OrderSettlement.record_splits!(payment, [
        %{
          role: :merchant,
          recipient_store_id: store.id,
          amount: 490_000,
          subaccount_code: nil,
          settlement_method: :internal_hold
        },
        %{role: :platform, recipient_store_id: nil, amount: 10_000, subaccount_code: nil}
      ])

      {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)
      by_role = Map.new(splits, &{&1.role, &1})

      assert by_role[:merchant].settlement_method == :internal_hold
      # Absent key defaults to the gateway rail — existing callers unchanged.
      assert by_role[:platform].settlement_method == :gateway_share
      assert Enum.all?(splits, &(&1.currency == "GHS"))
    end
  end
end
