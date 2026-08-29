defmodule Emakola.Suppliers.VoidUnfulfilledTest do
  @moduledoc """
  When a merchant cancels a fulfilment their supplier never shipped, they are
  left nominally owing money for goods that never moved. This closes that out.

  It is a separate action from `:void` rather than a relaxed version of it.
  `:void`'s `settlement_source == :platform_payout` predicate is load-bearing —
  it is one half of the double-pay guard, with `:mark_paid` refusing claimed
  entries and `:void` refusing unclaimed ones. Relaxing it to cover both would
  dissolve exactly the boundary those two actions exist to hold.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Suppliers.SupplierLedgerEntry

  setup do
    store = create_store!()
    order = create_order!(store)
    supplier = create_supplier!(store)
    fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)

    entry =
      create_supplier_ledger_entry!(supplier, fulfillment, store, %{
        amount_owed: 25_000,
        status: :owed
      })

    %{store: store, supplier: supplier, fulfillment: fulfillment, entry: entry}
  end

  defp reload(e), do: Ash.get!(SupplierLedgerEntry, e.id, authorize?: false)

  test "voids a manual debt the supplier never earned", %{entry: entry} do
    assert entry.settlement_source == :manual

    assert {:ok, voided} =
             Emakola.Suppliers.void_unfulfilled_supplier_ledger_entry(entry, authorize?: false)

    assert voided.status == :voided
  end

  test "refuses an entry the platform has claimed — that is :void's job", %{entry: entry} do
    {:ok, claimed} =
      Emakola.Suppliers.claim_supplier_ledger_entry(entry, %{source: :platform_payout},
        authorize?: false
      )

    assert {:error, _} =
             Emakola.Suppliers.void_unfulfilled_supplier_ledger_entry(claimed, authorize?: false)

    assert reload(entry).status == :owed
  end

  test "refuses an entry the merchant already paid", %{entry: entry} do
    {:ok, paid} = Emakola.Suppliers.mark_ledger_entry_paid(entry, authorize?: false)

    assert {:error, _} =
             Emakola.Suppliers.void_unfulfilled_supplier_ledger_entry(paid, authorize?: false)

    assert reload(entry).status == :paid
  end

  # The merchant clicks void in one tab while a charge.success webhook claims
  # the same entry. Whichever lands second must find the row already moved.
  test "a stale struct cannot void an entry that was claimed underneath it", %{entry: entry} do
    {:ok, _} =
      Emakola.Suppliers.claim_supplier_ledger_entry(entry, %{source: :platform_payout},
        authorize?: false
      )

    assert {:error, _} =
             Emakola.Suppliers.void_unfulfilled_supplier_ledger_entry(entry, authorize?: false)

    assert reload(entry).status == :owed
    assert reload(entry).settlement_source == :platform_payout
  end
end
