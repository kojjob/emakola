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

  describe "persist_payment/2" do
    test "creates the payment and its splits atomically" do
      store = create_store!()

      settlement =
        {:split,
         %{
           total: 500_000,
           mode: :internal,
           shares: [],
           allocations: [
             %{
               role: :merchant,
               recipient_store_id: store.id,
               amount: 490_000,
               subaccount_code: nil,
               settlement_method: :internal_hold
             },
             %{
               role: :platform,
               recipient_store_id: nil,
               amount: 10_000,
               subaccount_code: nil,
               settlement_method: :internal_hold
             }
           ]
         }}

      {:ok, payment} =
        OrderSettlement.persist_payment(
          %{
            store_id: store.id,
            amount: 500_000,
            currency: "GHS",
            gateway: :paystack,
            gateway_reference: "PAY-persist-#{System.unique_integer([:positive])}",
            split_mode: :internal
          },
          settlement
        )

      assert payment.split_mode == :internal
      {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)
      assert length(splits) == 2
      assert Enum.sum(Enum.map(splits, & &1.amount)) == 500_000
    end

    test "records nothing extra for no_split and hold settlements" do
      store = create_store!()

      for settlement <- [{:no_split, :payout_unverified}, {:hold, :buyer_protection}] do
        {:ok, payment} =
          OrderSettlement.persist_payment(
            %{
              store_id: store.id,
              amount: 10_000,
              currency: "GHS",
              gateway: :paystack,
              gateway_reference: "PAY-plain-#{System.unique_integer([:positive])}",
              split_mode: :none
            },
            settlement
          )

        {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)
        assert splits == []
      end
    end

    test "an invalid payment rolls back — no orphan splits, error returned" do
      store = create_store!()

      settlement =
        {:split,
         %{
           total: 500,
           mode: :internal,
           shares: [],
           allocations: [
             %{
               role: :platform,
               recipient_store_id: nil,
               amount: 500,
               subaccount_code: nil,
               settlement_method: :internal_hold
             }
           ]
         }}

      # amount is required on Payment — creation fails inside the transaction.
      assert {:error, _reason} =
               OrderSettlement.persist_payment(
                 %{
                   store_id: store.id,
                   currency: "GHS",
                   gateway: :paystack,
                   gateway_reference: "PAY-bad-#{System.unique_integer([:positive])}"
                 },
                 settlement
               )
    end
  end

  describe "prepare_internal/2" do
    defp checkout_own_stock_order!(store) do
      product = create_product!(store, title: "Internal Own-Stock")
      variant = create_variant!(product, store, price: 5_000, sku: "INT-OWN", stock_quantity: 20)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          store.id,
          [%{variant_id: variant.id, quantity: 1}],
          []
        )

      order
    end

    test "own-stock: identical platform fee to the gateway rail, all internal_hold" do
      # NOTE: store has NO payout account — the exact population Phase 3 routes here.
      store = create_store!()
      order = checkout_own_stock_order!(store)

      {:split, %{total: total, allocations: allocations, shares: [], mode: :internal}} =
        OrderSettlement.prepare_internal(order.id, store.id)

      assert total == order.total
      assert Enum.sum(Enum.map(allocations, & &1.amount)) == order.total

      # Fee parity: same PlatformFee.calculate as prepare_platform_fee (200 bps default).
      %{fee: fee, net: net} =
        Emakola.Payments.PlatformFee.calculate(
          order.total,
          Application.get_env(:emakola, :platform_fee_rate_bps, 200)
        )

      platform = Enum.find(allocations, &(&1.role == :platform))
      merchant = Enum.find(allocations, &(&1.role == :merchant))
      assert platform.amount == fee
      assert merchant.amount == net
      assert merchant.recipient_store_id == store.id

      assert Enum.all?(allocations, &(&1.settlement_method == :internal_hold))
      assert Enum.all?(allocations, &is_nil(&1.subaccount_code))
    end

    test "dropship with an UNVERIFIED linked wholesaler: internal mode, sum-exact" do
      dropshipper = create_store!(name: "Unverified Dropshipper")
      wholesaler_store = create_store!(name: "Unverified Wholesaler")
      # Linked but NO verified_payout! on either side — gateway prepare/2 would refuse this.
      supplier =
        create_supplier!(dropshipper, name: "Linked NoSub", linked_store_id: wholesaler_store.id)

      product = create_product!(dropshipper, title: "Internal Dropship")

      variant =
        create_variant!(product, dropshipper,
          price: 5_000,
          sku: "INT-DROP",
          supplier_id: supplier.id,
          cost_price: 800
        )

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          dropshipper.id,
          [%{variant_id: variant.id, quantity: 2}],
          []
        )

      {:split, %{total: total, allocations: allocations, shares: [], mode: :internal}} =
        OrderSettlement.prepare_internal(order.id, dropshipper.id)

      assert total == order.total
      assert Enum.sum(Enum.map(allocations, & &1.amount)) == order.total

      wholesaler = Enum.find(allocations, &(&1.role == :wholesaler))
      assert wholesaler.recipient_store_id == wholesaler_store.id
      assert Enum.any?(allocations, &(&1.role == :platform))
      assert Enum.all?(allocations, &(&1.settlement_method == :internal_hold))
    end
  end
end
