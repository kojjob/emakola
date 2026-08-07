defmodule Emakola.Payments.OrderSettlementRailTest do
  @moduledoc """
  Rail-policy routing through OrderSettlement.prepare/3: under
  `rail: :internal_first` no Paystack subaccount state decides the route —
  verified stores land on the internal ledger exactly like unverified ones,
  while buyer protection keeps its own-stock precedence and dropship keeps
  beating protection. `rail: :gateway_first` preserves today's behavior.

  Pinned via the `rail:` option (not app config) so this file stays
  async-safe.
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

  defp own_stock_order!(store) do
    product = create_product!(store, title: "Rail Own-Stock")
    variant = create_variant!(product, store, price: 5_000, sku: "RAIL-OWN", stock_quantity: 20)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 1}],
        []
      )

    order
  end

  defp dropship_order!(dropshipper) do
    wholesaler = create_store!(name: "Rail Wholesaler")
    verified_payout!(wholesaler, "ACCT_rail_whole")
    supplier = create_supplier!(dropshipper, name: "Rail Linked", linked_store_id: wholesaler.id)
    product = create_product!(dropshipper, title: "Rail Dropship")

    drop =
      create_variant!(product, dropshipper,
        price: 5_000,
        sku: "RAIL-DROP",
        supplier_id: supplier.id,
        cost_price: 800
      )

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        dropshipper.id,
        [%{variant_id: drop.id, quantity: 2}],
        []
      )

    order
  end

  defp enable_protection!(store) do
    store
    |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
    |> Ash.update!(authorize?: false)
  end

  describe "prepare/3 with rail: :internal_first" do
    test "verified own-stock store routes internal — subaccount state does not decide" do
      store = create_store!(name: "Rail Verified Own")
      verified_payout!(store, "ACCT_rail_own")
      order = own_stock_order!(store)

      assert {:split, %{total: total, allocations: allocations, shares: [], mode: :internal}} =
               OrderSettlement.prepare(order.id, store.id, rail: :internal_first)

      assert total == order.total
      assert Enum.sum(Enum.map(allocations, & &1.amount)) == order.total
      assert Enum.all?(allocations, &(&1.settlement_method == :internal_hold))
      assert Enum.all?(allocations, &is_nil(&1.subaccount_code))

      # Fee parity with the gateway rail's PlatformFee math.
      %{fee: fee, net: net} =
        Emakola.Payments.PlatformFee.calculate(
          order.total,
          Application.get_env(:emakola, :platform_fee_rate_bps, 200)
        )

      assert Enum.find(allocations, &(&1.role == :platform)).amount == fee
      assert Enum.find(allocations, &(&1.role == :merchant)).amount == net
    end

    test "verified dropship order routes internal with no gateway shares" do
      dropshipper = create_store!(name: "Rail Verified Drop")
      verified_payout!(dropshipper, "ACCT_rail_drop")
      order = dropship_order!(dropshipper)

      assert {:split, %{allocations: allocations, shares: [], mode: :internal}} =
               OrderSettlement.prepare(order.id, dropshipper.id, rail: :internal_first)

      assert Enum.sum(Enum.map(allocations, & &1.amount)) == order.total

      roles = Enum.map(allocations, & &1.role)
      assert :wholesaler in roles
      assert :dropshipper in roles
      assert :platform in roles
      assert Enum.all?(allocations, &(&1.settlement_method == :internal_hold))
    end

    test "protected own-stock order still holds — escrow precedence preserved" do
      store = create_store!(name: "Rail Protected Own")
      verified_payout!(store, "ACCT_rail_prot")
      enable_protection!(store)
      order = own_stock_order!(store)

      assert {:hold, :buyer_protection} =
               OrderSettlement.prepare(order.id, store.id, rail: :internal_first)
    end

    test "protected dropship order routes internal, not held — dropship precedence preserved" do
      dropshipper = create_store!(name: "Rail Protected Drop")
      verified_payout!(dropshipper, "ACCT_rail_pd")
      enable_protection!(dropshipper)
      order = dropship_order!(dropshipper)

      assert {:split, %{mode: :internal}} =
               OrderSettlement.prepare(order.id, dropshipper.id, rail: :internal_first)
    end
  end

  describe "prepare/3 with rail: :gateway_first" do
    test "verified own-stock store keeps today's platform-fee gateway split" do
      store = create_store!(name: "Rail Gateway Own")
      verified_payout!(store, "ACCT_rail_gw")
      order = own_stock_order!(store)

      assert {:split, %{mode: :platform_fee, shares: [_ | _]}} =
               OrderSettlement.prepare(order.id, store.id, rail: :gateway_first)
    end
  end
end
