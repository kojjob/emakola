defmodule Emakola.Payments.OrderSettlementInternalTest do
  @moduledoc """
  Internal-rail recording: record_splits! persists the settlement method and
  currency; persist_payment/2 makes payment + splits one transaction; the
  internal allocation builders reuse the gateway rail's exact fee math.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.OrderSettlement
  alias Emakola.Payments.Payment

  describe "outstanding_for_payout excludes :internal split_mode (no-double-count)" do
    test "an :internal payment never enters the legacy payout backlog; an identical :none one does" do
      store = create_store!()

      mark_success = fn payment ->
        payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)
      end

      internal =
        create_payment!(store, %{amount: 50_000, split_mode: :internal}) |> mark_success.()

      none = create_payment!(store, %{amount: 50_000, split_mode: :none}) |> mark_success.()

      for store_id <- [store.id, nil] do
        ids =
          Payment
          |> Ash.Query.for_read(:outstanding_for_payout, %{store_id: store_id})
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.id)

        refute internal.id in ids
        assert none.id in ids
      end
    end
  end

  describe "record_splits!/2 ledger columns" do
    test "persists settlement_method and stamps the payment's currency" do
      store = create_store!()
      payment = create_payment!(store, currency: "NGN")

      OrderSettlement.record_splits!(payment, [
        %{
          role: :merchant,
          recipient_store_id: store.id,
          amount: 490_000,
          subaccount_code: nil,
          settlement_method: :internal_hold
        },
        # Absent key: platform rows always default to internal_hold (spec §3
        # — that money stays in the main account on both rails).
        %{role: :platform, recipient_store_id: nil, amount: 10_000, subaccount_code: nil},
        # Absent key, non-platform role: still defaults to the gateway rail —
        # existing-caller compatibility.
        %{
          role: :wholesaler,
          recipient_store_id: store.id,
          amount: 0,
          subaccount_code: "ACCT_wholesaler"
        }
      ])

      {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)
      by_role = Map.new(splits, &{&1.role, &1})

      assert by_role[:merchant].settlement_method == :internal_hold
      assert by_role[:platform].settlement_method == :internal_hold
      assert by_role[:wholesaler].settlement_method == :gateway_share
      assert Enum.all?(splits, &(&1.currency == "NGN"))
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

    # Post-review hardening (PR #372): finalize_internal used to carve and
    # reserve! BEFORE checking for a negative non-platform allocation — a
    # discount can push the dropshipper's folded share negative while a
    # DIFFERENT recipient's allocation (the wholesaler's cost) stays positive,
    # so reserve! would already have persisted a reserved_recovery_amount bump
    # against that other recipient's liability by the time the negative check
    # rejected the split. Nothing then released it — a stranded reservation.
    # The fix runs the negative check before reserve! ever executes.
    test "a discount-driven negative dropshipper allocation rejects before reserve! runs — no stranded reservation on another recipient" do
      dropshipper = create_store!(name: "Discount Dropshipper IH")
      wholesaler_store = create_store!(name: "Discount Wholesaler IH")

      supplier =
        create_supplier!(dropshipper,
          name: "Linked Discount IH",
          linked_store_id: wholesaler_store.id
        )

      product = create_product!(dropshipper, title: "Internal Discount Drop")

      variant =
        create_variant!(product, dropshipper,
          price: 5_000,
          sku: "INT-DISC-IH",
          supplier_id: supplier.id,
          cost_price: 4_800
        )

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          dropshipper.id,
          [%{variant_id: variant.id, quantity: 1}],
          []
        )

      # Margin net is 180; a 1_000 discount folded via adjust_dropshipper
      # drives the dropshipper's allocation to -820. The wholesaler's
      # allocation (cost 4_800) stays positive.
      order
      |> Ash.Changeset.for_update(:update, %{discount_amount: 1_000})
      |> Ash.update!(authorize?: false)

      liability = refundable_liability!(dropshipper, wholesaler_store, 700)

      assert {:no_split, :unrepresentable_split} =
               OrderSettlement.prepare_internal(order.id, dropshipper.id)

      reloaded = Ash.get!(Emakola.Payments.PaymentSplit, liability.id, authorize?: false)
      assert reloaded.reserved_recovery_amount == 0
    end

    # Post-review hardening (PR #372): internalize/3 folds an unlinked
    # supplier's cost into the dropshipper's allocation, but that folded money
    # is owed to the supplier manually (SupplierLedgerEntry) — it is not the
    # dropshipper's sales proceeds. Without passthrough_amount fencing it, a
    # high-repayment-bps credit agreement could carve the entire passthrough.
    test "an active partner-credit agreement never carves into folded unlinked-supplier passthrough money" do
      {provider, provider_store} = create_merchant_with_store!(%{name: "Capital Supplier PT"})
      {borrower, store} = create_merchant_with_store!(%{name: "Seller PT"})
      {:ok, passport} = Emakola.Suppliers.CommercePassports.refresh(borrower, store.id)

      {:ok, offer} =
        Emakola.Suppliers.PartnerCredit.create_offer(provider, %{
          provider_type: :supplier,
          provider_store_id: provider_store.id,
          provider_name: "Capital Supplier PT",
          creditor_subaccount_code: "ACCT_credit_pt",
          borrower_store_id: store.id,
          minimum_tier: :starter,
          principal_amount: 5_000,
          fee_amount: 0,
          # Max bps: the tightest case — without the passthrough fence this
          # would carve the dropshipper allocation all the way to zero.
          repayment_bps: 10_000,
          term_days: 90,
          reason_code: "STARTER_TRADE_CREDIT",
          decision_snapshot: %{"passport_id" => passport.id, "tier" => "starter"}
        })

      {:ok, agreement} = Emakola.Suppliers.PartnerCredit.accept(borrower, offer.id, true)

      {:ok, _active} =
        Emakola.Suppliers.PartnerCredit.activate(provider, agreement.id, "BANK-PT-001")

      unlinked = create_supplier!(store, name: "Unlinked PT", linked_store_id: nil)
      product = create_product!(store, title: "Internal Passthrough Drop")

      variant =
        create_variant!(product, store,
          price: 5_000,
          sku: "INT-PT",
          supplier_id: unlinked.id,
          cost_price: 3_000
        )

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          store.id,
          [%{variant_id: variant.id, quantity: 1}],
          []
        )

      {:split, %{total: total, allocations: allocations, mode: :internal}} =
        OrderSettlement.prepare_internal(order.id, store.id)

      dropshipper_alloc = Enum.find(allocations, &(&1.role == :dropshipper))
      credit = Enum.find(allocations, &(&1.role == :credit_partner))

      # Passthrough (unlinked supplier's cost, folded): 3_000. Pre-carve
      # dropshipper proceeds: margin_net(1_800) + passthrough(3_000) = 4_800.
      passthrough = 3_000
      pre_carve_amount = 4_800

      refute is_nil(credit),
             "expected the max-bps agreement to produce a credit_partner carve"

      assert credit.amount <= pre_carve_amount - passthrough
      assert dropshipper_alloc.amount >= passthrough

      assert total == order.total
      assert Enum.sum(Enum.map(allocations, & &1.amount)) == order.total
    end

    # Post-review hardening (PR #372): the same passthrough fence applies to
    # refund-recovery reservation — a pre-existing liability on the
    # dropshipper's own store must not claw back the folded passthrough money
    # either.
    test "a pre-existing refund liability cannot claw back folded unlinked-supplier passthrough money" do
      store = create_store!(name: "Seller Passthrough Refund")
      unlinked = create_supplier!(store, name: "Unlinked Refund PT", linked_store_id: nil)
      product = create_product!(store, title: "Internal Passthrough Refund Drop")

      variant =
        create_variant!(product, store,
          price: 5_000,
          sku: "INT-PT-REFUND",
          supplier_id: unlinked.id,
          cost_price: 3_000
        )

      # Over-reversed, unclaimed internal split on the dropshipper's own
      # store: 2_000 is recoverable at reserve! time (see effective_netted/1).
      liability = refundable_internal_liability!(store, 10_000, 12_000)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          store.id,
          [%{variant_id: variant.id, quantity: 1}],
          []
        )

      {:split, %{total: total, allocations: allocations, mode: :internal}} =
        OrderSettlement.prepare_internal(order.id, store.id)

      dropshipper_alloc = Enum.find(allocations, &(&1.role == :dropshipper))

      passthrough = 3_000
      pre_reserve_amount = 4_800

      assert dropshipper_alloc.recovery_amount <= pre_reserve_amount - passthrough
      assert dropshipper_alloc.amount >= passthrough

      reloaded = Ash.get!(Emakola.Payments.PaymentSplit, liability.id, authorize?: false)
      assert reloaded.reserved_recovery_amount == dropshipper_alloc.recovery_amount

      assert total == order.total
      assert Enum.sum(Enum.map(allocations, & &1.amount)) == order.total
    end

    defp refundable_liability!(tenant_store, recipient_store, reversed_amount) do
      payment = create_payment!(tenant_store)

      Emakola.Payments.create_payment_split!(
        %{
          store_id: tenant_store.id,
          payment_id: payment.id,
          role: :wholesaler,
          recipient_store_id: recipient_store.id,
          amount: 1_000
        },
        authorize?: false
      )
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed_amount})
      |> Ash.update!(authorize?: false)
    end

    defp refundable_internal_liability!(store, amount, reversed_amount) do
      payment = create_payment!(store)

      Emakola.Payments.create_payment_split!(
        %{
          store_id: store.id,
          payment_id: payment.id,
          role: :merchant,
          recipient_store_id: store.id,
          amount: amount,
          settlement_method: :internal_hold
        },
        authorize?: false
      )
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed_amount})
      |> Ash.update!(authorize?: false)
    end
  end

  # -- Task 4: the flip — prepare/2 reroutes verification failures ---------
  # Today (pre-flip) each of these reasons falls through prepare/2's catch-all
  # as {:no_split, reason}. Post-flip, the four verification-failure reasons
  # (:payout_unverified, :dropshipper_payout_unverified,
  # :wholesaler_payout_unverified, :supplier_not_linked) route to
  # prepare_internal/2 instead — buyer protection (c) and a verified store's
  # gateway path (d) are unaffected (precedence/no-regression guards).
  describe "prepare/2 — the flip (verification failures route to the internal rail)" do
    defp verified_payout!(store, code) do
      Emakola.Stores.StorePayoutAccount
      |> Ash.Changeset.for_create(:create, %{store_id: store.id})
      |> Ash.create!(authorize?: false)
      |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: code})
      |> Ash.update!(authorize?: false)
    end

    # (a) own-stock, unverified store: DropshipSettlement.prepare/3 sees no
    # dropship items, prepare_platform_fee's verified_subaccount check then
    # fails with :payout_unverified.
    test "(a) own-stock unverified store: flips to :internal with fee parity to the gateway rail" do
      store = create_store!()
      order = checkout_own_stock_order!(store)

      assert {:split, %{mode: :internal, allocations: allocations, shares: []}} =
               OrderSettlement.prepare(order.id, store.id)

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
      assert Enum.sum(Enum.map(allocations, & &1.amount)) == order.total
    end

    # (b) dropship, dropshipper itself verified but the linked wholesaler is
    # NOT: DropshipSettlement.prepare/3 resolves the dropshipper's own
    # subaccount fine, then fails resolving the wholesaler's ->
    # :wholesaler_payout_unverified.
    test "(b) dropship with an unverified linked wholesaler: flips to :internal, sum-exact" do
      dropshipper = create_store!(name: "Flip Dropshipper")
      verified_payout!(dropshipper, "ACCT_flip_drop")
      wholesaler_store = create_store!(name: "Flip Wholesaler")

      supplier =
        create_supplier!(dropshipper, name: "Flip Linked", linked_store_id: wholesaler_store.id)

      product = create_product!(dropshipper, title: "Flip Dropship")

      variant =
        create_variant!(product, dropshipper,
          price: 5_000,
          sku: "FLIP-DROP",
          supplier_id: supplier.id,
          cost_price: 800
        )

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          dropshipper.id,
          [%{variant_id: variant.id, quantity: 2}],
          []
        )

      assert {:split, %{mode: :internal, allocations: allocations, shares: []}} =
               OrderSettlement.prepare(order.id, dropshipper.id)

      wholesaler = Enum.find(allocations, &(&1.role == :wholesaler))
      assert wholesaler.recipient_store_id == wholesaler_store.id
      assert Enum.all?(allocations, &(&1.settlement_method == :internal_hold))
      assert Enum.all?(allocations, &is_nil(&1.subaccount_code))
      assert Enum.sum(Enum.map(allocations, & &1.amount)) == order.total
    end

    # (c) precedence guard: buyer protection must still win over the internal
    # rail — an unverified, protected store still gets a payout hold, not an
    # internal split.
    test "(c) protected unverified own-stock store: buyer protection still wins (precedence unchanged)" do
      store = create_store!()

      store
      |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
      |> Ash.update!(authorize?: false)

      order = checkout_own_stock_order!(store)

      assert {:hold, :buyer_protection} = OrderSettlement.prepare(order.id, store.id)
    end

    # (d) no-regression guard: a verified store's own-stock order stays on the
    # gateway rail exactly as before — fee-parity pair with (a).
    test "(d) verified store: prepare/2 stays on the gateway rail (:platform_fee) — no regression" do
      store = create_store!()
      verified_payout!(store, "ACCT_flip_verified")
      order = checkout_own_stock_order!(store)

      assert {:split, %{mode: :platform_fee, shares: shares, allocations: allocations}} =
               OrderSettlement.prepare(order.id, store.id)

      assert shares != []
      merchant = Enum.find(allocations, &(&1.role == :merchant))
      platform = Enum.find(allocations, &(&1.role == :platform))
      assert merchant.subaccount_code == "ACCT_flip_verified"

      # Fee parity with (a): same PlatformFee.calculate math on both rails.
      %{fee: fee, net: net} =
        Emakola.Payments.PlatformFee.calculate(
          order.total,
          Application.get_env(:emakola, :platform_fee_rate_bps, 200)
        )

      assert platform.amount == fee
      assert merchant.amount == net
    end

    # (e) unlinked supplier: dropshipper itself IS verified (isolates
    # :supplier_not_linked from :dropshipper_payout_unverified), but the
    # supplier has no linked_store_id -> DropshipSettlement.prepare/3 refuses
    # at resolve_supplier/2.
    test "(e) unlinked supplier: flips to :internal with the supplier's cost folded into the dropshipper" do
      store = create_store!(name: "Flip Unlinked")
      verified_payout!(store, "ACCT_flip_unlinked")
      unlinked = create_supplier!(store, name: "Flip Unlinked Supplier", linked_store_id: nil)
      product = create_product!(store, title: "Flip Unlinked Product")

      variant =
        create_variant!(product, store,
          price: 5_000,
          sku: "FLIP-UNLINK",
          supplier_id: unlinked.id,
          cost_price: 3_000
        )

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          store.id,
          [%{variant_id: variant.id, quantity: 1}],
          []
        )

      assert {:split, %{mode: :internal, allocations: allocations, shares: []}} =
               OrderSettlement.prepare(order.id, store.id)

      dropshipper_alloc = Enum.find(allocations, &(&1.role == :dropshipper))
      refute is_nil(dropshipper_alloc)
      assert dropshipper_alloc.amount >= 3_000
      assert Enum.all?(allocations, &(&1.settlement_method == :internal_hold))
      assert Enum.all?(allocations, &is_nil(&1.subaccount_code))
      assert Enum.sum(Enum.map(allocations, & &1.amount)) == order.total
    end
  end
end
