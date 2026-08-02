defmodule Emakola.Suppliers.SupplierLedgerUnificationTest do
  @moduledoc """
  Phase 2 Task 5: one supplier obligation, claimed by platform settlement
  instead of coexisting with the manual `SupplierLedgerEntry` flow.

  `settle_splits/1` (webhook charge.success) claims the ledger entry behind a
  settled wholesaler split: a gateway-rail split (`:gateway_share`) already
  moved the money at charge time, so the entry is claimed AND paid
  immediately (INTENTIONAL behavior change — see the dedicated test below);
  an internal-rail split (`:internal_hold`) only claims, and the entry is
  marked paid once the allocation payout's transfer.success arrives.

  Fixtures use a real `CheckoutService.checkout!` dropship order (so real
  Fulfillment + SupplierLedgerEntry rows exist, matching
  `order_settlement_internal_test.exs`'s pattern) and drive settlement
  directly through the webhook worker via `perform_job/2`, matching
  `paystack_webhook_handler_test.exs`.
  """
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  alias Emakola.Payments.Workers.PaystackWebhookHandler

  # -- fixtures --------------------------------------------------------

  defp checkout_dropship_order!(dropshipper, supplier, attrs \\ []) do
    price = Keyword.get(attrs, :price, 5_000)
    cost_price = Keyword.get(attrs, :cost_price, 3_000)

    product =
      create_product!(dropshipper,
        title: "Ledger Unification Product #{System.unique_integer([:positive])}"
      )

    variant =
      create_variant!(product, dropshipper,
        price: price,
        sku: "LU-#{System.unique_integer([:positive])}",
        supplier_id: supplier.id,
        cost_price: cost_price
      )

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        dropshipper.id,
        [%{variant_id: variant.id, quantity: 1}],
        []
      )

    order
  end

  defp fulfillment_for(order, supplier) do
    order.id
    |> Emakola.Orders.list_fulfillments_by_order!(authorize?: false)
    |> Enum.find(&(&1.supplier_id == supplier.id))
  end

  defp ledger_entry_for(order, supplier) do
    order
    |> fulfillment_for(supplier)
    |> Map.fetch!(:id)
    |> Emakola.Suppliers.list_supplier_ledger_entries_by_fulfillment!(authorize?: false)
    |> List.first()
  end

  defp reload_entry(entry) do
    entry.fulfillment_id
    |> Emakola.Suppliers.list_supplier_ledger_entries_by_fulfillment!(authorize?: false)
    |> List.first()
  end

  defp create_wholesaler_split!(dropshipper, order, supplier, wholesaler_store, extra_attrs) do
    payment = create_payment!(dropshipper, %{order_id: order.id, amount: order.total})

    split =
      Emakola.Payments.create_payment_split!(
        Map.merge(
          %{
            store_id: dropshipper.id,
            payment_id: payment.id,
            role: :wholesaler,
            recipient_store_id: wholesaler_store.id,
            supplier_id: supplier.id,
            amount: 3_000
          },
          Map.new(extra_attrs)
        ),
        authorize?: false
      )

    {payment, split}
  end

  defp create_payout_account!(store) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      payout_destination: %{
        "method" => "mobile_money",
        "provider" => "mtn",
        "number" => "02440#{System.unique_integer([:positive])}",
        "account_name" => "Ledger Unification Payout"
      }
    })
    |> Ash.create!(authorize?: false)
  end

  defp charge_success!(payment) do
    perform_job(PaystackWebhookHandler, %{
      "event" => "charge.success",
      "data" => %{"reference" => payment.gateway_reference}
    })
  end

  defp transfer_success!(payout) do
    perform_job(PaystackWebhookHandler, %{
      "event" => "transfer.success",
      "data" => %{"reference" => payout.transfer_reference, "status" => "success"}
    })
  end

  defp refund_processed!(payment, amount) do
    perform_job(PaystackWebhookHandler, %{
      "event" => "refund.processed",
      "data" => %{
        "transaction" => %{"reference" => payment.gateway_reference},
        "amount" => amount
      }
    })
  end

  # -- (a) gateway wholesaler split -------------------------------------

  test "(a) gateway wholesaler split settling claims :split_gateway and pays the entry immediately" do
    dropshipper = create_store!(name: "GW Dropshipper")
    wholesaler_store = create_store!(name: "GW Wholesaler")

    supplier =
      create_supplier!(dropshipper, name: "GW Supplier", linked_store_id: wholesaler_store.id)

    order = checkout_dropship_order!(dropshipper, supplier)
    entry = ledger_entry_for(order, supplier)
    assert entry.status == :owed
    assert entry.settlement_source == :manual

    {payment, split} =
      create_wholesaler_split!(dropshipper, order, supplier, wholesaler_store,
        settlement_method: :gateway_share,
        subaccount_code: "ACCT_gw"
      )

    assert :ok = charge_success!(payment)

    entry_after = reload_entry(entry)
    assert entry_after.status == :paid
    assert entry_after.settlement_source == :split_gateway
    assert entry_after.payment_split_id == split.id
    refute is_nil(entry_after.paid_at)

    supplier_after = Ash.load!(supplier, :outstanding_balance, authorize?: false)
    assert supplier_after.outstanding_balance == 0
  end

  test "INTENTIONAL behavior change: gateway settlement pays the entry so a later manual mark_paid is rejected (no double-pay)" do
    dropshipper = create_store!(name: "GW NoDouble Dropshipper")
    wholesaler_store = create_store!(name: "GW NoDouble Wholesaler")

    supplier =
      create_supplier!(dropshipper,
        name: "GW NoDouble Supplier",
        linked_store_id: wholesaler_store.id
      )

    order = checkout_dropship_order!(dropshipper, supplier)
    entry = ledger_entry_for(order, supplier)

    {payment, _split} =
      create_wholesaler_split!(dropshipper, order, supplier, wholesaler_store,
        settlement_method: :gateway_share,
        subaccount_code: "ACCT_gw_nodouble"
      )

    assert :ok = charge_success!(payment)

    entry_after = reload_entry(entry)
    assert entry_after.status == :paid

    # Before this change, a gateway-settled supplier's entry stayed :owed and
    # :manual, so the merchant could still "mark paid" it by hand — a real
    # double payment (once at the gateway, once manually). Now it's claimed
    # and paid by the platform settlement, so the manual action is refused.
    assert {:error, %Ash.Error.Invalid{}} =
             entry_after
             |> Ash.Changeset.for_update(:mark_paid, %{})
             |> Ash.update(authorize?: false)
  end

  # -- (b) internal wholesaler split -------------------------------------

  test "(b) internal wholesaler split settling claims :platform_payout and stays unpaid until the allocation payout's transfer.success" do
    dropshipper = create_store!(name: "IH Dropshipper")
    wholesaler_store = create_store!(name: "IH Wholesaler")

    supplier =
      create_supplier!(dropshipper, name: "IH Supplier", linked_store_id: wholesaler_store.id)

    order = checkout_dropship_order!(dropshipper, supplier)
    entry = ledger_entry_for(order, supplier)

    create_payout_account!(wholesaler_store)

    {payment, split} =
      create_wholesaler_split!(dropshipper, order, supplier, wholesaler_store,
        settlement_method: :internal_hold
      )

    assert :ok = charge_success!(payment)

    entry_after_settle = reload_entry(entry)
    assert entry_after_settle.status == :owed
    assert entry_after_settle.settlement_source == :platform_payout
    assert entry_after_settle.payment_split_id == split.id

    # Claimed != manual — no longer counted in the merchant's manual balance.
    supplier_after_settle = Ash.load!(supplier, :outstanding_balance, authorize?: false)
    assert supplier_after_settle.outstanding_balance == 0

    {:ok, payout} = Emakola.Payments.PayoutService.prepare_internal_payout(wholesaler_store.id)

    assert :ok = transfer_success!(payout)

    entry_final = reload_entry(entry)
    assert entry_final.status == :paid
    refute is_nil(entry_final.paid_at)
  end

  # -- (c) unrelated entries untouched -----------------------------------

  test "(c) an unrelated :manual entry is untouched by a different supplier's split" do
    dropshipper = create_store!(name: "Untouched Dropshipper")
    wholesaler_store = create_store!(name: "Untouched Wholesaler")

    supplier_a =
      create_supplier!(dropshipper,
        name: "Untouched Settled Supplier",
        linked_store_id: wholesaler_store.id
      )

    supplier_b = create_supplier!(dropshipper, name: "Untouched Manual Supplier")

    product_a =
      create_product!(dropshipper,
        title: "Untouched Product A #{System.unique_integer([:positive])}"
      )

    variant_a =
      create_variant!(product_a, dropshipper,
        price: 5_000,
        sku: "UNT-A-#{System.unique_integer([:positive])}",
        supplier_id: supplier_a.id,
        cost_price: 3_000
      )

    product_b =
      create_product!(dropshipper,
        title: "Untouched Product B #{System.unique_integer([:positive])}"
      )

    variant_b =
      create_variant!(product_b, dropshipper,
        price: 4_000,
        sku: "UNT-B-#{System.unique_integer([:positive])}",
        supplier_id: supplier_b.id,
        cost_price: 2_000
      )

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        dropshipper.id,
        [
          %{variant_id: variant_a.id, quantity: 1},
          %{variant_id: variant_b.id, quantity: 1}
        ],
        []
      )

    entry_a = ledger_entry_for(order, supplier_a)
    entry_b = ledger_entry_for(order, supplier_b)

    {payment, _split} =
      create_wholesaler_split!(dropshipper, order, supplier_a, wholesaler_store,
        settlement_method: :gateway_share,
        subaccount_code: "ACCT_untouched"
      )

    assert :ok = charge_success!(payment)

    entry_a_after = reload_entry(entry_a)
    assert entry_a_after.status == :paid
    assert entry_a_after.settlement_source == :split_gateway

    entry_b_after = reload_entry(entry_b)
    assert entry_b_after.status == :owed
    assert entry_b_after.settlement_source == :manual
    assert is_nil(entry_b_after.payment_split_id)
  end

  # -- (d) claim_for_platform_settlement guards --------------------------

  describe "(d) claim_for_platform_settlement" do
    test "refuses a non-owed entry" do
      store = create_store!()
      supplier = create_supplier!(store)
      order = create_order!(store)
      fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)

      entry =
        create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 1_000)

      {:ok, paid} =
        entry
        |> Ash.Changeset.for_update(:mark_paid, %{})
        |> Ash.update(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               paid
               |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{
                 source: :platform_payout
               })
               |> Ash.update(authorize?: false)
    end

    test "refuses an already-claimed (non-manual) entry" do
      store = create_store!()
      supplier = create_supplier!(store)
      order = create_order!(store)
      fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)

      entry =
        create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 1_000)

      {:ok, claimed} =
        entry
        |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{source: :platform_payout})
        |> Ash.update(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               claimed
               |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{
                 source: :split_gateway
               })
               |> Ash.update(authorize?: false)
    end
  end

  # -- mark_paid guard against claimed entries (CRITICAL review finding) --

  describe "mark_paid guard" do
    test "action-level: a claimed (:platform_payout, :owed) entry refuses manual mark_paid" do
      store = create_store!()
      supplier = create_supplier!(store)
      order = create_order!(store)
      fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)

      entry = create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 1_000)

      {:ok, claimed} =
        entry
        |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{source: :platform_payout})
        |> Ash.update(authorize?: false)

      assert claimed.status == :owed

      assert {:error, %Ash.Error.Invalid{}} =
               claimed
               |> Ash.Changeset.for_update(:mark_paid, %{})
               |> Ash.update(authorize?: false)

      # Untouched — still owed and still claimed, no double-pay opportunity.
      reloaded = reload_entry(claimed)
      assert reloaded.status == :owed
      assert reloaded.settlement_source == :platform_payout
    end

    test "action-level: a claimed (:split_gateway, :paid) entry refuses manual mark_paid too" do
      store = create_store!()
      supplier = create_supplier!(store)
      order = create_order!(store)
      fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)

      entry = create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 1_000)

      claimed =
        entry
        |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{source: :split_gateway})
        |> Ash.update!(authorize?: false)
        |> Ash.Changeset.for_update(:mark_platform_paid, %{})
        |> Ash.update!(authorize?: false)

      assert claimed.status == :paid

      assert {:error, %Ash.Error.Invalid{}} =
               claimed
               |> Ash.Changeset.for_update(:mark_paid, %{})
               |> Ash.update(authorize?: false)
    end
  end

  # -- gateway two-step stranding recovery (IMPORTANT review finding) -----

  test "charge.success replay finishes a stranded :split_gateway claim (claimed but never marked paid)" do
    dropshipper = create_store!(name: "Strand Dropshipper")
    wholesaler_store = create_store!(name: "Strand Wholesaler")

    supplier =
      create_supplier!(dropshipper, name: "Strand Supplier", linked_store_id: wholesaler_store.id)

    order = checkout_dropship_order!(dropshipper, supplier)
    entry = ledger_entry_for(order, supplier)

    {payment, split} =
      create_wholesaler_split!(dropshipper, order, supplier, wholesaler_store,
        settlement_method: :gateway_share,
        subaccount_code: "ACCT_strand"
      )

    # Simulate a prior attempt that ran claim_for_platform_settlement (the
    # first of two independent Ash.update! calls in
    # claim_supplier_ledger_entry/2) but crashed before mark_platform_paid
    # (the second) ever ran — the split is already :settled (as a real
    # charge.success would have left it) but the entry is stranded
    # :owed/:split_gateway.
    split
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)

    entry
    |> Ash.Changeset.for_update(:claim_for_platform_settlement, %{
      payment_split_id: split.id,
      source: :split_gateway
    })
    |> Ash.update!(authorize?: false)

    stranded = reload_entry(entry)
    assert stranded.status == :owed
    assert stranded.settlement_source == :split_gateway

    # Replay recovers it — no re-claim attempt (would fail the :manual
    # pre-guard), just finishes the mark-paid half.
    assert :ok = charge_success!(payment)

    recovered = reload_entry(entry)
    assert recovered.status == :paid
    refute is_nil(recovered.paid_at)
  end

  # -- refund <-> supplier coupling --------------------------------------

  test "refund.processed voids a claimed-unpaid entry when its wholesaler split fully reverses" do
    dropshipper = create_store!(name: "Void Dropshipper")
    wholesaler_store = create_store!(name: "Void Wholesaler")

    supplier =
      create_supplier!(dropshipper, name: "Void Supplier", linked_store_id: wholesaler_store.id)

    order = checkout_dropship_order!(dropshipper, supplier)
    entry = ledger_entry_for(order, supplier)

    {payment, _split} =
      create_wholesaler_split!(dropshipper, order, supplier, wholesaler_store,
        settlement_method: :internal_hold
      )

    assert :ok = charge_success!(payment)

    claimed = reload_entry(entry)
    assert claimed.status == :owed
    assert claimed.settlement_source == :platform_payout

    # Full refund fully reverses the wholesaler split.
    assert :ok = refund_processed!(payment, payment.amount)

    voided = reload_entry(entry)
    assert voided.status == :voided
    assert voided.settlement_source == :platform_payout
    assert is_nil(voided.paid_at)
  end
end
