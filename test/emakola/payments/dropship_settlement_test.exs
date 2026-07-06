defmodule Emakola.Payments.DropshipSettlementTest do
  @moduledoc """
  The settlement decision engine (SP5): resolves each dropship supplier through
  its linked wholesaler store to a verified payout subaccount, and either
  produces a gateway split or signals a fallback to the manual ledger.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  alias Emakola.Payments.DropshipSettlement

  # Verified payout account with a subaccount code for `store`.
  defp verified_payout!(store, code) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: store.id})
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: code})
    |> Ash.update!(authorize?: false)
  end

  defp unverified_payout!(store) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: store.id})
    |> Ash.create!(authorize?: false)
  end

  setup do
    dropshipper = create_store!(name: "Dropshipper")
    {:ok, dropshipper: dropshipper}
  end

  describe "prepare/3 — happy path" do
    setup %{dropshipper: dropshipper} do
      verified_payout!(dropshipper, "ACCT_drop")
      wholesaler = create_store!(name: "Wholesaler")
      verified_payout!(wholesaler, "ACCT_whole")
      supplier = create_supplier!(dropshipper, name: "Linked Sup", linked_store_id: wholesaler.id)

      items = [
        %{unit_price: 5_000, cost_price: 800, quantity: 2, supplier_id: supplier.id},
        %{unit_price: 3_000, cost_price: nil, quantity: 1, supplier_id: nil}
      ]

      {:ok, supplier: supplier, items: items, wholesaler: wholesaler}
    end

    test "produces a split routing each party to its verified subaccount", %{
      dropshipper: dropshipper,
      supplier: supplier,
      items: items
    } do
      assert {:split, %{total: 13_000, allocations: allocs}} =
               DropshipSettlement.prepare(items, dropshipper.id, fee_rate_bps: 1_000)

      wholesaler = Enum.find(allocs, &(&1.role == :wholesaler))
      assert wholesaler.subaccount_code == "ACCT_whole"
      assert wholesaler.supplier_id == supplier.id
      assert wholesaler.amount == 1_600

      assert %{subaccount_code: "ACCT_drop", amount: 10_560} =
               Enum.find(allocs, &(&1.role == :dropshipper))

      assert %{amount: 840} = Enum.find(allocs, &(&1.role == :platform))
    end

    test "enriches allocations with the recipient store for crediting/clawback", %{
      dropshipper: dropshipper,
      wholesaler: wholesaler,
      items: items
    } do
      {:split, %{allocations: allocs}} =
        DropshipSettlement.prepare(items, dropshipper.id, fee_rate_bps: 1_000)

      assert Enum.find(allocs, &(&1.role == :wholesaler)).recipient_store_id == wholesaler.id
      assert Enum.find(allocs, &(&1.role == :dropshipper)).recipient_store_id == dropshipper.id
      assert is_nil(Enum.find(allocs, &(&1.role == :platform)).recipient_store_id)
    end
  end

  describe "prepare/3 — fallback cases" do
    test "no dropship items (own-stock only) does not split", %{dropshipper: dropshipper} do
      verified_payout!(dropshipper, "ACCT_drop")
      items = [%{unit_price: 3_000, cost_price: nil, quantity: 1, supplier_id: nil}]

      assert {:no_split, :no_dropship_items} =
               DropshipSettlement.prepare(items, dropshipper.id, fee_rate_bps: 1_000)
    end

    test "supplier not linked to a store does not split", %{dropshipper: dropshipper} do
      verified_payout!(dropshipper, "ACCT_drop")
      supplier = create_supplier!(dropshipper, name: "External")
      items = [%{unit_price: 5_000, cost_price: 800, quantity: 1, supplier_id: supplier.id}]

      assert {:no_split, :supplier_not_linked} =
               DropshipSettlement.prepare(items, dropshipper.id, fee_rate_bps: 1_000)
    end

    test "unverified wholesaler payout does not split", %{dropshipper: dropshipper} do
      verified_payout!(dropshipper, "ACCT_drop")
      wholesaler = create_store!(name: "Unverified Wholesaler")
      unverified_payout!(wholesaler)
      supplier = create_supplier!(dropshipper, name: "Linked", linked_store_id: wholesaler.id)
      items = [%{unit_price: 5_000, cost_price: 800, quantity: 1, supplier_id: supplier.id}]

      assert {:no_split, :wholesaler_payout_unverified} =
               DropshipSettlement.prepare(items, dropshipper.id, fee_rate_bps: 1_000)
    end

    test "dropshipper without a verified payout does not split", %{dropshipper: dropshipper} do
      wholesaler = create_store!(name: "Wholesaler")
      verified_payout!(wholesaler, "ACCT_whole")
      supplier = create_supplier!(dropshipper, name: "Linked", linked_store_id: wholesaler.id)
      items = [%{unit_price: 5_000, cost_price: 800, quantity: 1, supplier_id: supplier.id}]

      assert {:no_split, :dropshipper_payout_unverified} =
               DropshipSettlement.prepare(items, dropshipper.id, fee_rate_bps: 1_000)
    end
  end
end
