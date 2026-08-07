defmodule Emakola.Payments.SingleRailFlipTest do
  @moduledoc """
  P1 exit invariants (spec §3.5): every new charge settles internal — ledger
  rows sum to the charge, a platform-fee row is always present, no gateway
  shares are produced, amounts are identical to the old gateway math.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.OrderSettlement

  defp verified_payout!(store, code) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: store.id})
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: code})
    |> Ash.update!(authorize?: false)
  end

  describe "own-stock orders" do
    test "a VERIFIED merchant's charge settles internal with identical amounts" do
      merchant = create_store!(name: "Verified Own-Stock")
      verified_payout!(merchant, "ACCT_verified")
      product = create_product!(merchant, title: "Flip Product")
      own = create_variant!(product, merchant, price: 5_000, sku: "FLIP-OWN", stock_quantity: 20)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          merchant.id,
          [%{variant_id: own.id, quantity: 2}],
          []
        )

      # Verification no longer routes to the gateway: same fee math
      # (2% of 10_000), but internal — no shares, no subaccount.
      assert {:split, %{mode: :internal, total: 10_000, shares: [], allocations: allocs}} =
               OrderSettlement.prepare(order.id, merchant.id)

      by_role = Map.new(allocs, &{&1.role, &1})
      assert by_role[:merchant].amount == 9_800
      assert by_role[:merchant].subaccount_code == nil
      assert by_role[:platform].amount == 200
      assert Enum.all?(allocs, &(&1.settlement_method == :internal_hold))
      assert 10_000 == Enum.sum(Enum.map(allocs, & &1.amount))
    end
  end
end
