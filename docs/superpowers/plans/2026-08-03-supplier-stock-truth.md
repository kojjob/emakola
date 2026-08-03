# Supplier Stock Truth Cycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Network (dropship) sales decrement the supplier's real stock, supplier stock changes propagate to reseller listing availability, and resellers see supplier stock status — closing the gap where listings sell from an import-time snapshot forever.

**Architecture:** Four layers in binding order (spec `docs/superpowers/specs/2026-08-03-supplier-stock-truth-cycle-design.md`): L1 `Emakola.Suppliers.NetworkStock` decrements source variants at payment confirmation (truth), L2 `SupplierStockSyncWorker` propagates availability (messenger), L0 checkout checks live source stock (prevention), L3 status badges (visibility). Decrement lands before sync so sync never propagates a wrong number.

**Tech Stack:** Elixir/Ash 3.x, Oban, Phoenix LiveView, TailwindCSS.

## Global Constraints (BINDING)

- Worktree `/Users/kojo/Projects/emakola/.claude/worktrees/internal-settlement`, branch `feature/supplier-stock-truth` (off main `83936940`). TDD; `mix format` + `mix credo --strict` clean per commit; parse test-run `Result:` lines — exit codes lie when piping.
- The payment webhook path must NEVER fail, reorder, or slow because of stock logic — every new call rescues and logs (`[NetworkStock]` / `[SupplierStockSync]` prefixes), returns `:ok` regardless.
- Clamp, never negative, never raise: supplier stock short at confirm → decrement what exists, log a warning naming order id, variant id, shortfall. Mirrors `Orders.Changes.DecrementStock`'s log-and-stand contract.
- Reservation-covered units NEVER double-decrement: reserve already moved stock via `Inventory.adjust` at reserve time.
- Availability-only propagation in L2 — do NOT wire `ListingImporter.sync/2` (it overwrites title/description/price; separate product decision).
- Reseller-facing UI shows STATUS ONLY (`In stock` / `Low stock` / `Out of stock`) — the supplier's raw quantity must never appear in reseller-facing markup.
- Cross-tenant reads/writes only through the mapping chain with `authorize?: false`, mirroring `pause_offer_listings!`. `StockMovement` is attribute-multitenant — queries need `tenant:` (the supplier store id).
- Zero changes to money code (splits/settlement/payouts). PR-1 tripwire: no mutation touching flagged splits.
- Paused/retired listings stay paused — only `status == :active` listings flip availability.
- All monetary/stock quantities are integers. No new DB migrations expected (`StockMovement.reason` is an atom one_of over a text column — verify no DB CHECK exists: `grep -rn "reason" priv/repo/migrations/*stock_movement*` — if a CHECK exists, hand-write a migration; `mix ash.codegen` is broken repo-wide).

## Verified grounding (file:line, checked 2026-08-03)

- `consume_for_order` call sites: `lib/emakola/payments/workers/paystack_webhook_handler.ex:244`, `lib/emakola/payments/hubtel_webhook.ex:69` — both inside `if payment.status == :success` blocks; `NetworkStock.decrement_for_order(payment.order_id, payment.store_id)` goes immediately AFTER each.
- `StockMovement.reason` one_of: `[:sale, :restock, :adjustment, :reservation_hold, :reservation_release, :transfer_in, :transfer_out, :import]` (`lib/emakola/inventory/resources/stock_movement.ex:36`) — add `:network_sale`.
- Mapping chain: `Emakola.Suppliers.ResellerListingVariant` (fields `reseller_variant_id`, `offer_variant_id`, `listing_id`) → `Emakola.Suppliers.SupplierOfferVariant` (field `source_variant_id`, `wholesaler_store_id`) → `Emakola.Catalog.Variant`. Consumption rows: `Emakola.Suppliers.InventoryReservationConsumption` keyed by `line_item_id` (see `inventory_reservations.ex:201-207` for the exact already-consumed sum pattern).
- Inventory funnels: `Emakola.Inventory.adjust(variant_id, location_id, delta, reason, opts)` keeps `total == sum(levels)` + records movement with `opts[:order_id]`; `Emakola.Inventory.ensure_default_location!(store_id)`; `locked_variant!` pattern = `Ash.Query.lock("FOR UPDATE")` (`inventory_reservations.ex:320-325`).
- Variant stock write paths: `:adjust_stock` (atomic, used by `Inventory.adjust`/`decrement_for_sale!`), `:restock` (`require_atomic?(false)`), `:update` (admin edits; accepts `available`). Hook seams for L2: domain-level after-success in `Inventory.adjust` + `Inventory.decrement_for_sale!`, plus an Ash change on Variant `:update`/`:restock` — NOT on `:adjust_stock` (atomic; a non-atomic change would break it, and both its callers are covered at the domain seam).
- Worker house pattern: `lib/emakola/suppliers/workers/inventory_reservation_expiry_worker.ex` (`use Oban.Worker, queue: :orders, max_attempts: 3, unique: [...]`).
- Fixture exemplar: `test/emakola/suppliers/listing_importer_test.exs` setup builds wholesaler+reseller stores, product, 2 variants (stock 8 and 5), offer via `Offers.create_draft/add_variant/publish`, `connect!(context)` helper, then `ListingImporter.import(reseller_actor, reseller.id, offer)`. Reuse this shape everywhere.
- Badge data loads: offers tab already loads `offer_variants: :source_variant` (`offers.ex` `available_offers`); `supply_catalog_live/show.ex` `load_offer` and `ListingImporter.list` need `source_variant` added to their loads.
- `Inventory.stock_status/1` (`lib/emakola/inventory/inventory.ex:97-104`): supplier-linked variants route on `available`; tracked → `:in_stock`/`:low`/`:out` (low threshold 10); untracked → `:in_stock`.
- Checkout validation: `lib/emakola/orders/checkout_service.ex:416-434` (`validate_stock/2` + `available_for_order?/2`).
- Pill styling exemplar: `severity_pill` `lib/emakola_web/components/platform_components.ex:96` (platform-side; L3 adds a merchant-admin equivalent in `admin_components.ex`).

---

### Task 1: L1 — NetworkStock decrement at payment confirmation

**Files:**
- Create: `lib/emakola/suppliers/network_stock.ex`
- Modify: `lib/emakola/inventory/resources/stock_movement.ex:36` (add `:network_sale` to one_of)
- Modify: `lib/emakola/payments/workers/paystack_webhook_handler.ex:244-247` (one call after `consume_for_order`)
- Modify: `lib/emakola/payments/hubtel_webhook.ex:69-72` (same)
- Test: `test/emakola/suppliers/network_stock_test.exs` (create)

**Interfaces — Produces:** `Emakola.Suppliers.NetworkStock.decrement_for_order(order_id | nil, store_id) :: :ok` (always `:ok`; rescues internally). Movement reason `:network_sale` exists.

- [ ] **Step 1 (RED):** Write `test/emakola/suppliers/network_stock_test.exs`. Setup: clone the `listing_importer_test.exs` fixture (wholesaler w/ red variant stock 8, offer, connect, import into reseller), then create a confirmed-order shape: reseller-store order with a line item on the imported reseller variant (use existing order/line-item factories; see `checkout` tests for order creation patterns — the module under test only needs `order_id` + line items to exist). Tests:
  - (a) **happy path**: order qty 3 on the imported variant → `decrement_for_order(order.id, reseller.id)` → source variant `stock_quantity` 8→5; one `StockMovement` with `reason: :network_sale`, `order_id: order.id`, `delta: -3` in the WHOLESALER tenant; supplier `total == sum(levels)` holds (read stock levels and assert).
  - (b) **replay idempotency**: call `decrement_for_order` twice → stock still 5, movement count still 1.
  - (c) **reservation shortfall math**: create an active reservation for 2 units on the offer variant (via `InventoryReservations.reserve/4` after creating a policy — see `inventory_reservations` tests for policy/passport fixtures; if passport setup is heavy, insert an `InventoryReservationConsumption` row directly for the line item with quantity 2), order qty 3 → source decrements exactly 1.
  - (d) **clamp**: source stock 2, order qty 5, no reservations → stock 2→0, movement `delta: -2`, no raise, returns `:ok`.
  - (e) **unmapped skip**: a variant with `supplier_id` set but no `ResellerListingVariant` row → no movement, no stock change, `:ok`.
  - (f) **untracked source skip**: source variant `track_inventory: false` → no-op.
  - (g) **nil order**: `decrement_for_order(nil, store_id) == :ok`.
- [ ] **Step 2:** Run: `mix test test/emakola/suppliers/network_stock_test.exs` → expect failures (module doesn't exist).
- [ ] **Step 3 (GREEN):** Add `:network_sale` to the reason one_of. Implement:

```elixir
defmodule Emakola.Suppliers.NetworkStock do
  @moduledoc """
  Decrements supplier source-variant stock for confirmed network (dropship)
  sales — the units a reseller sold out of the supplier's inventory.

  Called from the payment webhook handlers immediately AFTER
  `InventoryReservations.consume_for_order/2` (consumption rows must be final:
  reservation-covered units were already removed from supplier stock at
  reserve time, so only the shortfall decrements here).

  Contract: always returns `:ok`; never raises into the webhook. Supplier
  stock short → clamp to zero and log (the paid order stands for manual
  fulfilment — same discipline as `Orders.Changes.DecrementStock`). A
  zero-clamped line leaves no movement marker, so a webhook redelivery after
  a restock WILL take the still-owed units — deliberate: the sale happened.
  """
  require Ash.Query
  require Logger

  def decrement_for_order(nil, _store_id), do: :ok

  def decrement_for_order(order_id, store_id) do
    line_items =
      Emakola.Orders.LineItem
      |> Ash.Query.filter(order_id == ^order_id)
      |> Ash.read!(authorize?: false, tenant: store_id)

    Enum.each(line_items, &decrement_line(&1, order_id))
    :ok
  rescue
    exception ->
      Logger.error(
        "[NetworkStock] decrement failed for order #{order_id}: " <>
          Exception.message(exception)
      )

      :ok
  end

  defp decrement_line(line_item, order_id) do
    mapping =
      Emakola.Suppliers.ResellerListingVariant
      |> Ash.Query.filter(reseller_variant_id == ^line_item.variant_id)
      |> Ash.Query.load(:offer_variant)
      |> Ash.read_one!(authorize?: false)

    if mapping do
      consumed = consumed_quantity(line_item.id)
      shortfall = line_item.quantity - consumed

      if shortfall > 0 do
        decrement_source(mapping.offer_variant, shortfall, order_id)
      end
    end
  end

  defp consumed_quantity(line_item_id) do
    Emakola.Suppliers.InventoryReservationConsumption
    |> Ash.Query.filter(line_item_id == ^line_item_id)
    |> Ash.read!(authorize?: false)
    |> Enum.reduce(0, &(&1.quantity + &2))
  end

  defp decrement_source(offer_variant, shortfall, order_id) do
    Emakola.Repo.transaction(fn ->
      source = locked_variant!(offer_variant.source_variant_id)

      cond do
        not source.track_inventory ->
          :ok

        already_decremented?(source, order_id) ->
          :ok

        true ->
          take = min(shortfall, max(source.stock_quantity, 0))

          if take < shortfall do
            Logger.warning(
              "[NetworkStock] clamped decrement for order #{order_id} " <>
                "variant #{source.id}: wanted #{shortfall}, took #{take}"
            )
          end

          if take > 0 do
            location = Emakola.Inventory.ensure_default_location!(source.store_id)

            {:ok, _} =
              Emakola.Inventory.adjust(source.id, location.id, -take, :network_sale,
                order_id: order_id
              )
          end

          :ok
      end
    end)
  end

  defp already_decremented?(source, order_id) do
    Emakola.Inventory.StockMovement
    |> Ash.Query.filter(
      variant_id == ^source.id and order_id == ^order_id and reason == :network_sale
    )
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false, tenant: source.store_id)
    |> Enum.any?()
  end

  defp locked_variant!(id) do
    Emakola.Catalog.Variant
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end
end
```

  Verify against the actual resource module names/fields before finalizing (e.g. the StockMovement module path, whether `Inventory.adjust` re-locks — its transaction re-locks the variant, which is re-entrant in the same tx per `inventory_reservations.ex:154`). Add the two webhook call lines directly after each `consume_for_order` call:

```elixir
        Emakola.Suppliers.NetworkStock.decrement_for_order(
          payment.order_id,
          payment.store_id
        )
```

- [ ] **Step 4:** Run: `mix test test/emakola/suppliers/network_stock_test.exs` → all pass. Then the neighbouring suites: `mix test test/emakola/suppliers test/emakola/payments test/emakola/inventory` → green.
- [ ] **Step 5:** Add one webhook-level test each (paystack + hubtel) in their existing suites asserting a confirmed dropship payment triggers the decrement and a replayed webhook does not double it (follow the existing replay-test pattern in `paystack_webhook_handler_test.exs`). Run those suites.
- [ ] **Step 6:** `mix format` + `mix credo --strict` → commit `feat(suppliers): network sales decrement supplier source stock`

### Task 2: L2 — SupplierStockSyncWorker availability propagation

**Files:**
- Create: `lib/emakola/suppliers/workers/supplier_stock_sync_worker.ex`
- Create: `lib/emakola/catalog/changes/enqueue_supplier_stock_sync.ex`
- Modify: `lib/emakola/inventory/inventory.ex` (`adjust/5` and `decrement_for_sale!/4` enqueue after success)
- Modify: `lib/emakola/catalog/resources/variant.ex` (`:update` and `:restock` actions gain the change; NOT `:adjust_stock` — it is atomic and its two callers are the Inventory seams above)
- Test: `test/emakola/suppliers/supplier_stock_sync_worker_test.exs` (create)

**Interfaces — Consumes:** the fixture shape from Task 1's test (offer + import). **Produces:** `SupplierStockSyncWorker.enqueue(variant_id) :: :ok` (fire-and-forget, rescues Oban errors), worker `perform` recomputing from current state.

- [ ] **Step 1 (RED):** Tests:
  - (a) **sell-out propagates**: import fixture (reseller variant starts `available: true`), zero the source stock via `Emakola.Inventory.adjust(source.id, location.id, -8, :adjustment)`, run `perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})` → reseller variant `available == false`. Also assert the adjust call itself enqueued the job (`assert_enqueued worker: SupplierStockSyncWorker` — seam test).
  - (b) **restock flips back**: from (a), restock +5, perform → reseller variant `available == true`.
  - (c) **paused stays paused**: pause the listing (`ListingImporter.pause_offer_listings!(offer.id)`), restock source, perform → reseller variant still `available == false`.
  - (d) **supplier `available: false` wins**: source has stock but supplier sets `available: false` via `Catalog.update_variant!` → perform → reseller variant `false`. Also assert the update enqueued the job.
  - (e) **no-op for unrelated variants**: a plain own-stock variant with no offer mapping → perform → returns `:ok`, no writes (assert no reseller variant changed).
  - (f) **price-only update does not enqueue**: update only `price` on the source variant → refute_enqueued.
  - (g) **skip-unchanged writes**: perform twice in a row → second run makes no update (assert reseller variant `updated_at` unchanged, or use a change-tracking assertion).
- [ ] **Step 2:** Run new test file → failures (worker missing).
- [ ] **Step 3 (GREEN):** Worker:

```elixir
defmodule Emakola.Suppliers.Workers.SupplierStockSyncWorker do
  @moduledoc """
  Propagates a supplier source variant's live availability
  (`available and in_stock?`) to every ACTIVE reseller listing variant mapped
  to it. Availability only — never title/description/price (that is
  `ListingImporter.sync/2`, deliberately unwired). Recomputes from CURRENT
  state so Oban unique-coalesced bursts are last-write-wins correct.
  """
  use Oban.Worker, queue: :orders, max_attempts: 3, unique: [period: 60, fields: [:args]]

  require Ash.Query
  require Logger

  def enqueue(variant_id) do
    %{"variant_id" => variant_id}
    |> new()
    |> Oban.insert()

    :ok
  rescue
    exception ->
      Logger.error("[SupplierStockSync] enqueue failed: " <> Exception.message(exception))
      :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"variant_id" => variant_id}}) do
    offer_variant_ids =
      Emakola.Suppliers.SupplierOfferVariant
      |> Ash.Query.filter(source_variant_id == ^variant_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    if offer_variant_ids != [] do
      source = Ash.get!(Emakola.Catalog.Variant, variant_id, authorize?: false)
      target = source.available and Emakola.Catalog.Variant.in_stock?(source)

      Emakola.Suppliers.ResellerListingVariant
      |> Ash.Query.filter(offer_variant_id in ^offer_variant_ids)
      |> Ash.Query.load([:reseller_variant, :listing])
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.listing.status == :active))
      |> Enum.each(fn mapping ->
        if mapping.reseller_variant.available != target do
          Emakola.Catalog.update_variant!(mapping.reseller_variant, %{available: target},
            authorize?: false
          )
        end
      end)
    end

    :ok
  end
end
```

  Seams: in `Inventory.adjust` and `decrement_for_sale!`, after the successful transaction, `Emakola.Suppliers.Workers.SupplierStockSyncWorker.enqueue(variant_id)`. Change module for Variant `:update`/`:restock`:

```elixir
defmodule Emakola.Catalog.Changes.EnqueueSupplierStockSync do
  @moduledoc """
  After a variant update that changed `stock_quantity`, `available`, or
  `track_inventory`, enqueue supplier-stock sync so mapped reseller listings
  follow. Cheap no-op in the worker for variants that back no offers.
  """
  use Ash.Resource.Change

  @watched [:stock_quantity, :available, :track_inventory]

  @impl true
  def change(changeset, _opts, _context) do
    if Enum.any?(@watched, &Ash.Changeset.changing_attribute?(changeset, &1)) do
      Ash.Changeset.after_action(changeset, fn _changeset, variant ->
        Emakola.Suppliers.Workers.SupplierStockSyncWorker.enqueue(variant.id)
        {:ok, variant}
      end)
    else
      changeset
    end
  end
end
```

  Check `ResellerListingVariant` has a `:listing` relationship (it has `listing_id`); add the relationship load or filter via a join if the relationship name differs — read the resource first. Confirm `SupplierOfferVariant.source_variant_id` is indexed (grounding says the lookup must be cheap — if no index exists, add a hand-written migration for it).
- [ ] **Step 4:** Run new tests → pass; then `mix test test/emakola/suppliers test/emakola/inventory test/emakola/catalog` → green (watch for existing tests that update variants and now enqueue jobs — Oban unique-conflict returns the ATTEMPTED job; assert counts via `all_enqueued`, never returned ids).
- [ ] **Step 5:** `mix format` + `mix credo --strict` → commit `feat(suppliers): supplier stock changes sync reseller listing availability`

### Task 3: L0 — checkout checks live supplier stock

**Files:**
- Modify: `lib/emakola/orders/checkout_service.ex:416-434` (`validate_stock/2`)
- Test: extend `test/emakola/orders/checkout_service_test.exs` (find the existing `insufficient_stock` cases and add beside them)

**Interfaces — Consumes:** `ResellerListingVariant` mapping chain (as Task 1). No new public functions.

- [ ] **Step 1 (RED):** Tests in the existing checkout suite (reuse its fixtures + the import fixture pattern):
  - (a) imported dropship variant, `available: true`, source stock 2, cart qty 5 → checkout returns `{:error, :insufficient_stock}`.
  - (b) same variant, cart qty 2 → succeeds.
  - (c) flag stale: reseller variant `available: true` but source stock 0 → `{:error, :insufficient_stock}`.
  - (d) unmapped supplier-linked variant (manual off-platform supplier), `available: true` → unaffected, checkout succeeds (flag-only behaviour preserved).
- [ ] **Step 2:** Run → (a)/(c) fail (currently pass validation).
- [ ] **Step 3 (GREEN):** In `validate_stock/2`, batch-load mappings for all supplier-linked variant ids in ONE query, then source variants in ONE query; item check becomes:

```elixir
  defp validate_stock(variants, items) do
    source_by_variant_id = load_source_variants(variants)

    insufficient =
      Enum.any?(items, fn %{variant_id: vid, quantity: qty} ->
        variant = Map.fetch!(variants, vid)

        not available_for_order?(variant, qty) or
          not source_in_stock?(source_by_variant_id, vid, qty)
      end)

    if insufficient, do: {:error, :insufficient_stock}, else: :ok
  end

  # Live supplier check for network-imported variants: the availability flag
  # is synced asynchronously and is boolean — only the live source quantity
  # can answer "customer wants 5, supplier has 2". Unmapped supplier-linked
  # variants (off-platform suppliers) have no source to consult.
  defp source_in_stock?(source_by_variant_id, variant_id, qty) do
    case Map.get(source_by_variant_id, variant_id) do
      nil -> true
      source -> Emakola.Catalog.Variant.in_stock?(source, qty)
    end
  end

  defp load_source_variants(variants) do
    supplier_linked_ids =
      for {id, v} <- variants, not is_nil(v.supplier_id), do: id

    if supplier_linked_ids == [] do
      %{}
    else
      mappings =
        Emakola.Suppliers.ResellerListingVariant
        |> Ash.Query.filter(reseller_variant_id in ^supplier_linked_ids)
        |> Ash.Query.load(offer_variant: :source_variant)
        |> Ash.read!(authorize?: false)

      Map.new(mappings, fn m -> {m.reseller_variant_id, m.offer_variant.source_variant} end)
    end
  end
```

  `require Ash.Query` already present? Check the module top; add if missing. `in_stock?/2` treats untracked sources as available — correct (untracked supplier stock has no number).
- [ ] **Step 4:** Run the checkout suite + `mix test test/emakola/orders` → green.
- [ ] **Step 5:** `mix format` + `mix credo --strict` → commit `feat(orders): checkout validates live supplier stock for network items`

### Task 4: L3 — supplier stock badges

**Files:**
- Modify: `lib/emakola_web/components/admin_components.ex` (add `supplier_stock_badge/1` function component)
- Modify: `lib/emakola_web/live/admin/supply_network_live.ex` (offers tab cards + hustle-listings tab)
- Modify: `lib/emakola_web/live/admin/supply_catalog_live/show.ex` (offer page; add `source_variant` to `load_offer`'s load)
- Modify: `lib/emakola/suppliers/listing_importer.ex` (`list/2` load gains `listing_variants: [offer_variant: :source_variant]` — check current load shape first)
- Test: `test/emakola_web/live/admin/supply_stock_badge_test.exs` (create)

**Interfaces — Consumes:** `Emakola.Inventory.stock_status/1`. **Produces:** `supplier_stock_badge(%{status: :in_stock | :low | :out})` component; `EmakolaWeb.Live.Admin.SupplyStockStatus.aggregate(source_variants) :: :in_stock | :low | :out` helper (put in `lib/emakola_web/live/admin/supply_stock_status.ex`).

**Load `frontend-design` before writing markup.** Match the Makola Admin design language (pill styling like `severity_pill`, `platform_components.ex:96`, but in merchant-admin emerald/amber/rose tones).

- [ ] **Step 1 (RED):** LiveView tests (use `listing_importer_test`-style fixtures + `setup` from existing supply network LiveView tests for merchant auth):
  - (a) offers tab: offer whose source variants are all in stock → rendered card contains "In stock"; drain one variant below 10 → "Low stock"; drain all to 0 → "Out of stock".
  - (b) catalog show page renders the badge for the offer.
  - (c) listings tab renders a per-listing badge from the same aggregation.
  - (d) **privacy**: rendered HTML for all three surfaces NEVER contains the raw source quantity (assert the literal stock numbers from fixtures, e.g. `"8"` as a standalone stock figure, are absent from the badge region — scope the assertion to the badge component's rendered output to avoid false hits on prices).
  - (e) aggregation unit tests: all `:out` → `:out`; mix of `:low` + `:in_stock` → `:low`; mix of `:out` + `:in_stock` → `:in_stock`.
- [ ] **Step 2:** Run → fail (component/helper missing).
- [ ] **Step 3 (GREEN):** Helper:

```elixir
defmodule EmakolaWeb.Live.Admin.SupplyStockStatus do
  @moduledoc """
  Offer-level supplier stock status for reseller-facing badges: statuses of
  the offer's SOURCE variants, aggregated. Status only — callers must never
  render the supplier's raw quantities.
  """

  def aggregate([]), do: :out

  def aggregate(source_variants) do
    statuses = Enum.map(source_variants, &Emakola.Inventory.stock_status/1)

    cond do
      Enum.all?(statuses, &(&1 == :out)) -> :out
      Enum.any?(statuses, &(&1 == :low)) -> :low
      true -> :in_stock
    end
  end
end
```

  Component in `admin_components.ex` (follow the file's `attr`/`def` idiom):

```elixir
  attr :status, :atom, required: true, values: [:in_stock, :low, :out]

  def supplier_stock_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-semibold",
      @status == :in_stock && "bg-emerald-50 text-emerald-700",
      @status == :low && "bg-amber-50 text-amber-700",
      @status == :out && "bg-rose-50 text-rose-700"
    ]}>
      <span class={[
        "size-1.5 rounded-full",
        @status == :in_stock && "bg-emerald-500",
        @status == :low && "bg-amber-500",
        @status == :out && "bg-rose-500"
      ]} />
      {supplier_stock_label(@status)}
    </span>
    """
  end

  defp supplier_stock_label(:in_stock), do: "In stock"
  defp supplier_stock_label(:low), do: "Low stock"
  defp supplier_stock_label(:out), do: "Out of stock"
```

  Wire the three surfaces: offers tab cards already have `offer.offer_variants` with `source_variant` loaded — `aggregate(Enum.map(offer.offer_variants, & &1.source_variant))`. Catalog show: add `:source_variant` to `load_offer`'s existing load list. Listings tab: extend `ListingImporter.list/2`'s load, then aggregate over `listing.listing_variants` source variants. Dark-mode variants for the classes if the file's idiom includes them (check neighbouring components; add `dark:` classes matching).
- [ ] **Step 4:** Run the new test file + `mix test test/emakola_web/live/admin` → green.
- [ ] **Step 5:** `mix format` + `mix credo --strict` → commit `feat(web): supplier stock badges across the supply surfaces`

### Task 5: Gate + QA + PR

- [ ] Full `mix test` — parse the `Result:` line; zero failures. `mix format --check-formatted`; `mix credo --strict`; `touch` edited files then `mix compile --warnings-as-errors` (incremental compile hides warnings).
- [ ] Tripwire: `git diff origin/main -- lib/` contains no mutation touching flagged payment splits and zero changes under `lib/emakola/payments/` beyond the two one-line webhook call additions.
- [ ] Browser QA from the worktree on an alternate `PORT=` (dev service worker caches CSS — unregister first): supply network offers tab, catalog offer page, listings tab — badge in all three states (drain a demo supplier's stock via iex to flip states); screenshots to the SDD workspace `qa/` dir.
- [ ] Whole-branch review (most capable model; lenses: webhook-path safety (never fail/reorder), double-decrement under replay AND under reservation overlap, cross-tenant isolation, clamp semantics, badge privacy, spec line-by-line). ONE fix wave; scoped re-review; adjudicate residuals.
- [ ] Rebase onto latest `origin/main` if #376 has merged (expect trivial or no conflicts — different regions of the webhook handler). Full suite again if rebased.
- [ ] Push; PR to `main` titled `feat(suppliers): the supplier stock truth cycle — network sales move real stock`, body naming: the four layers, the zero-clamp redelivery semantics (documented in NetworkStock's moduledoc), availability-only sync (full sync/2 stays unwired — separate product decision), badge privacy rule, and the out-of-scope list from the spec.
