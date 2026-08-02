defmodule Emakola.Suppliers.SupplierLedgerEntryTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  setup do
    store = create_store!()
    supplier = create_supplier!(store)
    order = create_order!(store)
    fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)
    {:ok, store: store, supplier: supplier, fulfillment: fulfillment}
  end

  describe "create" do
    test "creates a ledger entry with valid attributes", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx

      entry =
        create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 2500)

      assert entry.id
      assert entry.store_id == store.id
      assert entry.supplier_id == supplier.id
      assert entry.fulfillment_id == fulfillment.id
      assert entry.amount_owed == 2500
      assert entry.status == :owed
      assert is_nil(entry.paid_at)
    end

    test "defaults status to owed", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      entry = create_supplier_ledger_entry!(supplier, fulfillment, store)
      assert entry.status == :owed
    end

    test "rejects negative amount_owed", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx

      assert {:error, _} =
               Emakola.Suppliers.SupplierLedgerEntry
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 supplier_id: supplier.id,
                 fulfillment_id: fulfillment.id,
                 amount_owed: -1
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects missing store_id", ctx do
      %{supplier: supplier, fulfillment: fulfillment} = ctx

      assert {:error, _} =
               Emakola.Suppliers.SupplierLedgerEntry
               |> Ash.Changeset.for_create(:create, %{
                 supplier_id: supplier.id,
                 fulfillment_id: fulfillment.id,
                 amount_owed: 1000
               })
               |> Ash.create(authorize?: false)
    end

    test "is unique per fulfillment", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      create_supplier_ledger_entry!(supplier, fulfillment, store)

      assert {:error, _} =
               Emakola.Suppliers.SupplierLedgerEntry
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 supplier_id: supplier.id,
                 fulfillment_id: fulfillment.id,
                 amount_owed: 1000
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "mark_paid" do
    test "sets status to paid and stamps paid_at", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      entry = create_supplier_ledger_entry!(supplier, fulfillment, store)

      {:ok, paid} =
        entry
        |> Ash.Changeset.for_update(:mark_paid, %{})
        |> Ash.update(authorize?: false)

      assert paid.status == :paid
      assert %DateTime{} = paid.paid_at
    end

    test "rejects marking an already-paid entry", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      entry = create_supplier_ledger_entry!(supplier, fulfillment, store)

      {:ok, paid} =
        entry
        |> Ash.Changeset.for_update(:mark_paid, %{})
        |> Ash.update(authorize?: false)

      assert {:error, _} =
               paid
               |> Ash.Changeset.for_update(:mark_paid, %{})
               |> Ash.update(authorize?: false)
    end
  end

  describe "atomic claim/mark_paid transitions (race proxy — PR #373 review)" do
    # `claim_for_platform_settlement` and `mark_paid` both validate against the
    # in-memory struct the caller loaded. Two concurrent callers (the
    # charge.success webhook claiming, the merchant clicking "mark paid") can
    # both read the same :owed/:manual row before either writes, so both
    # validations pass and both writes land on disjoint columns — one caller
    # holding a STALE struct is exactly that scenario. Deterministic proxy: do
    # the first write for real, then attempt the second from the pre-write
    # struct — it must be rejected, not silently accepted, or the supplier
    # gets paid twice (once by the platform settlement, once manually).
    test "a stale pre-claim struct cannot mark_paid after a concurrent claim landed", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      entry = create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 1_000)

      # `stale` is the handle a second process would still be holding — the
      # same struct read before the claim below ever ran.
      stale = entry

      assert {:ok, claimed} =
               Emakola.Suppliers.claim_supplier_ledger_entry(entry, %{source: :platform_payout},
                 authorize?: false
               )

      assert claimed.settlement_source == :platform_payout

      assert {:error, _} = Emakola.Suppliers.mark_ledger_entry_paid(stale, authorize?: false)

      reloaded = Ash.get!(Emakola.Suppliers.SupplierLedgerEntry, entry.id, authorize?: false)
      assert reloaded.status == :owed
      assert reloaded.settlement_source == :platform_payout
      assert is_nil(reloaded.paid_at)
    end

    test "a stale pre-mark_paid struct cannot claim after a concurrent mark_paid landed", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      entry = create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 1_000)

      stale = entry

      assert {:ok, paid} = Emakola.Suppliers.mark_ledger_entry_paid(entry, authorize?: false)
      assert paid.status == :paid

      assert {:error, _} =
               Emakola.Suppliers.claim_supplier_ledger_entry(stale, %{source: :platform_payout},
                 authorize?: false
               )

      reloaded = Ash.get!(Emakola.Suppliers.SupplierLedgerEntry, entry.id, authorize?: false)
      assert reloaded.status == :paid
      assert reloaded.settlement_source == :manual
    end
  end

  describe "atomic mark_platform_paid/void transitions (Phase 3 Task 1 — conditional-write completion)" do
    # Same race proxy as the describe above, extended to the two remaining
    # transitions that still wrote unconditionally: `mark_platform_paid` and
    # `void`. Deterministic proxy: do the first write for real from a struct,
    # then reuse that SAME pre-write struct for a second write — it must be
    # rejected by the DB-level WHERE filter (StaleRecord), not silently
    # accepted twice.
    test "a stale pre-mark_platform_paid struct cannot mark_platform_paid again after a concurrent mark_platform_paid landed",
         ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      entry = create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 1_000)

      assert {:ok, claimed} =
               Emakola.Suppliers.claim_supplier_ledger_entry(entry, %{source: :platform_payout},
                 authorize?: false
               )

      assert claimed.status == :owed
      assert claimed.settlement_source == :platform_payout

      # `stale` is the handle a second process would still be holding — the
      # same struct read before the first mark_platform_paid below ever ran.
      stale = claimed

      assert {:ok, paid} =
               Emakola.Suppliers.mark_supplier_ledger_entry_platform_paid(claimed,
                 authorize?: false
               )

      assert paid.status == :paid

      assert {:error, %Ash.Error.Invalid{}} =
               Emakola.Suppliers.mark_supplier_ledger_entry_platform_paid(stale,
                 authorize?: false
               )

      reloaded = Ash.get!(Emakola.Suppliers.SupplierLedgerEntry, entry.id, authorize?: false)
      assert reloaded.status == :paid
      assert reloaded.paid_at == paid.paid_at
    end

    test "a stale pre-void struct cannot void again after a concurrent void landed", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      entry = create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 1_000)

      assert {:ok, claimed} =
               Emakola.Suppliers.claim_supplier_ledger_entry(entry, %{source: :platform_payout},
                 authorize?: false
               )

      assert claimed.status == :owed
      assert claimed.settlement_source == :platform_payout

      stale = claimed

      assert {:ok, voided} =
               Emakola.Suppliers.void_supplier_ledger_entry(claimed, authorize?: false)

      assert voided.status == :voided

      assert {:error, %Ash.Error.Invalid{}} =
               Emakola.Suppliers.void_supplier_ledger_entry(stale, authorize?: false)

      reloaded = Ash.get!(Emakola.Suppliers.SupplierLedgerEntry, entry.id, authorize?: false)
      assert reloaded.status == :voided
    end
  end

  describe "list_by_supplier" do
    test "returns that supplier's entries newest first", ctx do
      %{store: store, supplier: supplier, fulfillment: fulfillment} = ctx
      order2 = create_order!(store)
      fulfillment2 = create_fulfillment!(order2, store, supplier_id: supplier.id)

      create_supplier_ledger_entry!(supplier, fulfillment, store, amount_owed: 1000)
      create_supplier_ledger_entry!(supplier, fulfillment2, store, amount_owed: 2000)

      other_supplier = create_supplier!(store)
      order3 = create_order!(store)
      fulfillment3 = create_fulfillment!(order3, store, supplier_id: other_supplier.id)
      create_supplier_ledger_entry!(other_supplier, fulfillment3, store, amount_owed: 9999)

      {:ok, entries} =
        Emakola.Suppliers.list_ledger_entries_by_supplier(supplier.id, authorize?: false)

      assert length(entries) == 2
      assert Enum.all?(entries, &(&1.supplier_id == supplier.id))
      # Declared sort is inserted_at: :desc — newest (the 2000 entry) first.
      assert List.first(entries).amount_owed == 2000
    end
  end
end
