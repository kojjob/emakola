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
      assert Enum.all?(allocations, &is_nil(&1.subaccount_code))
    end

    # Post-review hardening: prepare_internal/2's own-stock and dropship tests
    # above both use stores with no active credit agreement, so the carve is a
    # no-op in them — they can't catch a reorder of internal_hold before the
    # carve. This test sets up a REAL active PartnerCreditAgreement (fixture
    # copied verbatim from partner_credit_test.exs) so carve_sales_proceeds
    # actually produces a :credit_partner row with a non-nil subaccount_code,
    # then asserts internal_hold still nils it out.
    test "an active partner-credit agreement is carved, then internal_hold overrides its subaccount code" do
      {provider, provider_store} = create_merchant_with_store!(%{name: "Capital Supplier IH"})
      {borrower, store} = create_merchant_with_store!(%{name: "Seller IH"})
      {:ok, passport} = Emakola.Suppliers.CommercePassports.refresh(borrower, store.id)

      {:ok, offer} =
        Emakola.Suppliers.PartnerCredit.create_offer(provider, %{
          provider_type: :supplier,
          provider_store_id: provider_store.id,
          provider_name: "Capital Supplier IH",
          creditor_subaccount_code: "ACCT_credit_ih",
          borrower_store_id: store.id,
          minimum_tier: :starter,
          principal_amount: 10_000,
          fee_amount: 1_000,
          repayment_bps: 2_500,
          term_days: 90,
          reason_code: "STARTER_TRADE_CREDIT",
          decision_snapshot: %{"passport_id" => passport.id, "tier" => "starter"}
        })

      {:ok, agreement} = Emakola.Suppliers.PartnerCredit.accept(borrower, offer.id, true)

      {:ok, _active} =
        Emakola.Suppliers.PartnerCredit.activate(provider, agreement.id, "BANK-IH-001")

      order = checkout_own_stock_order!(store)

      {:split, %{total: total, allocations: allocations, mode: :internal}} =
        OrderSettlement.prepare_internal(order.id, store.id)

      credit = Enum.find(allocations, &(&1.role == :credit_partner))

      # Real assertion: fails if the agreement fixture above didn't take (i.e.
      # carve_sales_proceeds saw no active agreement and was a no-op).
      refute is_nil(credit),
             "expected an active credit agreement to produce a :credit_partner row"

      assert credit.credit_agreement_id == agreement.id

      # The override: internal_hold runs AFTER the carve and must nil out the
      # creditor's subaccount too, even though carve_sales_proceeds sets it
      # unconditionally to offer.creditor_subaccount_code.
      assert is_nil(credit.subaccount_code)
      assert credit.settlement_method == :internal_hold

      assert Enum.all?(allocations, &is_nil(&1.subaccount_code))
      assert Enum.all?(allocations, &(&1.settlement_method == :internal_hold))
      assert total == order.total
      assert Enum.sum(Enum.map(allocations, & &1.amount)) == order.total
    end
  end
end
