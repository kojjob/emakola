defmodule Emakola.Payments.DropshipSettlementInternalTest do
  @moduledoc """
  Internal-rail dropship allocations: same SplitCalculator math as the gateway
  rail, but no subaccount requirement. Linked wholesalers become payable ledger
  recipients; unlinked ones fold into the dropshipper (who still owes them
  manually via SupplierLedgerEntry).
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.DropshipSettlement

  # 1000 bps margin fee, same as the gateway-rail tests.
  @fee_rate_bps 1_000

  defp line_item(supplier_id, unit_price, cost_price, quantity) do
    %{
      supplier_id: supplier_id,
      unit_price: unit_price,
      cost_price: cost_price,
      quantity: quantity
    }
  end

  test "linked suppliers get recipient allocations; totals stay sum-exact" do
    dropshipper = create_store!()
    wholesaler_store = create_store!(name: "Wholesaler Co")

    supplier =
      create_supplier!(dropshipper, linked_store_id: wholesaler_store.id)

    {:split, %{total: total, allocations: allocations}} =
      DropshipSettlement.prepare_internal(
        [line_item(supplier.id, 5_000, 3_000, 2)],
        dropshipper.id,
        fee_rate_bps: @fee_rate_bps
      )

    assert total == 10_000
    assert Enum.sum(Enum.map(allocations, & &1.amount)) == total

    wholesaler = Enum.find(allocations, &(&1.role == :wholesaler))
    assert wholesaler.recipient_store_id == wholesaler_store.id
    assert wholesaler.amount == 6_000
    assert is_nil(wholesaler.subaccount_code)

    platform = Enum.find(allocations, &(&1.role == :platform))
    # 10% of the 4_000 margin.
    assert platform.amount == 400

    dropshipper_alloc = Enum.find(allocations, &(&1.role == :dropshipper))
    assert dropshipper_alloc.amount == 3_600
    assert dropshipper_alloc.recipient_store_id == dropshipper.id
  end

  test "an unlinked supplier's cost and dispatch fee fold into the dropshipper" do
    dropshipper = create_store!()
    unlinked = create_supplier!(dropshipper, linked_store_id: nil)

    {:split, %{total: total, allocations: allocations}} =
      DropshipSettlement.prepare_internal(
        [line_item(unlinked.id, 5_000, 3_000, 1)],
        dropshipper.id,
        fee_rate_bps: @fee_rate_bps,
        dispatch_fees: %{unlinked.id => 700}
      )

    # Retail 5_000 + dispatch 700.
    assert total == 5_700
    assert Enum.sum(Enum.map(allocations, & &1.amount)) == total

    refute Enum.any?(allocations, &(&1.role == :wholesaler))

    dropshipper_alloc = Enum.find(allocations, &(&1.role == :dropshipper))
    # Own margin net (1_800) + folded wholesaler cost (3_000) + dispatch (700).
    assert dropshipper_alloc.amount == 5_500

    platform = Enum.find(allocations, &(&1.role == :platform))
    assert platform.amount == 200
  end

  test "no dropship items falls through" do
    dropshipper = create_store!()

    assert {:no_split, :no_dropship_items} =
             DropshipSettlement.prepare_internal(
               [line_item(nil, 5_000, nil, 1)],
               dropshipper.id,
               fee_rate_bps: @fee_rate_bps
             )
  end
end
