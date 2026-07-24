# Dispatch Fees at Checkout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Supplier per-area dispatch fees are charged to the customer at checkout (stacked on the merchant delivery fee), snapshotted per fulfillment, and settled 100% to the supplier through the splits engine — with today's fee-less math byte-identical.

**Architecture:** Region param canonicalization in `GhanaRegions`; fee computation + snapshots inside `CheckoutService.run_checkout`'s transaction (server-side, never a client-passed amount); `SplitCalculator` folds a per-supplier fee map into wholesaler allocations; checkout UI gains one itemized line. Spec: `docs/superpowers/specs/2026-07-24-dispatch-fee-checkout-design.md`.

**Tech Stack:** Elixir/Phoenix LiveView, Ash 3.x, Oban, ExUnit.

## Global Constraints

- Branch: `feature/dispatch-fee-checkout` (created; spec committed).
- ALL money integer pesewas. TDD everywhere: failing test first. ALL commands FOREGROUND — never background, never wait on notifications; the full suite takes ~5 min, run it and wait.
- **Locked decisions:** stack both fees; unquoted region (or "other") → 0; 100% pass-through (platform fee stays margin-only); MAX per supplier across that supplier's offers in the cart, charged once.
- **Wire-format decision (amends spec §1, Task 1 commits the amendment):** region params stay snake_case (`"greater_accra"`); the select extends to all 16 regions (+`"other"`); `Emakola.Suppliers.GhanaRegions.from_param/1` maps param → canonical title-case string (`"greater_accra"` → `"Greater Accra"`), returning `nil` for `"other"`/unknown. `dispatch_fees` lookup uses the canonical string.
- The fee is computed INSIDE `run_checkout`'s transaction from region + offers — the LiveView passes `region` (a param string), never a fee amount.
- Sum invariant: `Σ split allocations == order.total` must hold by construction; a zero-fee order's split output must be BYTE-IDENTICAL to today's (regression tests enforce both).
- Hand-written reversible migrations (`ash.codegen` unusable).
- Verified anchors: totals math at `checkout_service.ex` ~248-287 (`total = subtotal + delivery_fee - discount_amount`); `create_fulfillments/4` ~396-413 groups by `variants[vid].supplier_id`; `create_ledger_entries/4` ~420-448; `SplitCalculator.calculate(line_items, opts)` builds wholesaler allocations from cost sums; `OrderSettlement.prepare/2` ~27-60 folds `delivery_fee - discount` into the dropshipper share via `adjust_dropshipper`; `ResellerListingVariant` has `reseller_variant_id`/`listing_id`; `ResellerListing` has `offer_id` + `supplier_id`; checkout region flows: `checkout_live.ex` assigns `:region` (default `"greater_accra"`), `update_delivery_fee/1` ~633, `CheckoutService.checkout!(store.id, items, opts)` call ~433 with `delivery_fee:` in opts; region `<select>` in `lib/emakola/themes/default_renderers/checkout.ex` ~284-297; `@default_region_fees` map ~626 (7 snake_case keys, `@default_region_fee 3500` fallback covers new regions — leave the map as-is).

---

### Task 1: Region param canonicalization + 16-region select

**Files:**
- Modify: `lib/emakola/suppliers/ghana_regions.ex`
- Modify: `lib/emakola/themes/default_renderers/checkout.ex` (region select ~284-297)
- Modify: `docs/superpowers/specs/2026-07-24-dispatch-fee-checkout-design.md` (§1: one paragraph — params stay snake_case, `from_param/1` canonicalizes)
- Test: `test/emakola/suppliers/offers_test.exs` (GhanaRegions describe) + `test/emakola_web/live/storefront/checkout_live_test.exs` (find the checkout LV test file — if named differently, locate the file testing `/checkout` and append there)

**Interfaces:**
- Produces: `GhanaRegions.from_param("greater_accra") == "Greater Accra"`; `from_param("other") == nil`; `from_param(<unknown/non-binary>) == nil`; `GhanaRegions.select_options() :: [{label, param}]` — 16 canonical regions as `{"Greater Accra", "greater_accra"}` tuples + `{"Other", "other"}` (param = downcased, spaces→underscores).

- [ ] **Step 1: Failing tests** — append to the GhanaRegions describe:

```elixir
    test "from_param canonicalizes snake_case params" do
      assert Emakola.Suppliers.GhanaRegions.from_param("greater_accra") == "Greater Accra"
      assert Emakola.Suppliers.GhanaRegions.from_param("bono_east") == "Bono East"
      assert Emakola.Suppliers.GhanaRegions.from_param("other") == nil
      assert Emakola.Suppliers.GhanaRegions.from_param("atlantis") == nil
      assert Emakola.Suppliers.GhanaRegions.from_param(nil) == nil
    end

    test "select_options covers all 16 regions plus Other" do
      options = Emakola.Suppliers.GhanaRegions.select_options()
      assert length(options) == 17
      assert {"Greater Accra", "greater_accra"} in options
      assert {"Western North", "western_north"} in options
      assert List.last(options) == {"Other", "other"}
    end
```

LV test (append to the checkout LV test file): render the checkout page and assert the region select contains `option value="bono_east"` and 17 options total (count `<option` occurrences within the region select's HTML, or assert a few new regions plus `"other"`).

- [ ] **Step 2: Verify RED** — `mix test test/emakola/suppliers/offers_test.exs` → undefined `from_param/1`.

- [ ] **Step 3: Implement** — in `ghana_regions.ex`:

```elixir
  @spec from_param(term()) :: String.t() | nil
  def from_param(param) when is_binary(param) do
    Enum.find(@regions, fn region -> param_for(region) == param end)
  end

  def from_param(_), do: nil

  @spec param_for(String.t()) :: String.t()
  def param_for(region), do: region |> String.downcase() |> String.replace(" ", "_")

  @spec select_options() :: [{String.t(), String.t()}]
  def select_options, do: Enum.map(@regions, &{&1, param_for(&1)}) ++ [{"Other", "other"}]
```

In `default_renderers/checkout.ex`, replace the hardcoded 8-option select body with a comprehension over `Emakola.Suppliers.GhanaRegions.select_options()` (keep the surrounding select attributes/classes byte-identical; each option `value={param}` label `{label}`, preserving the currently-selected logic the template uses).

- [ ] **Step 4: Spec amendment** — §1: replace the "Option values become the canonical strings" sentence with the snake-case-param + `from_param/1` decision.

- [ ] **Step 5: GREEN + commit** — `mix format && mix test test/emakola/suppliers/offers_test.exs <checkout LV test file>` → green. `git add -A && git commit -m "feat(catalog): checkout region select covers all 16 regions"`

---

### Task 2: Fee computation + snapshots in CheckoutService

**Files:**
- Create: `priv/repo/migrations/20260724090000_add_dispatch_fee_snapshots.exs`
- Modify: `lib/emakola/orders/resources/fulfillment.ex` (attribute + create accept), `lib/emakola/orders/resources/order.ex` (attribute + update accept — find the `:update` action the checkout uses and add `:dispatch_fee_total` to its accept), `lib/emakola/orders/checkout_service.ex`, `lib/emakola_web/live/storefront/checkout_live.ex` (pass `region:` in checkout opts, ~line 417-433)
- Test: `test/emakola/orders/checkout_service_test.exs` (append describe; its existing dropship fixtures show how to build supplier-backed variants — read them first)

**Interfaces:**
- Consumes: `GhanaRegions.from_param/1`; `ResellerListingVariant.reseller_variant_id/listing_id`; `ResellerListing.offer_id/supplier_id`; `SupplierOffer.dispatch_fees`.
- Produces: `Fulfillment.dispatch_fee` (pesewas, default 0) and `Order.dispatch_fee_total` (pesewas, default 0), both snapshotted in the checkout transaction; `total = subtotal + delivery_fee + dispatch_fee_total - discount_amount`; `SupplierLedgerEntry.amount_owed` includes the fee; `checkout!/3` accepts `region:` in opts (param string, optional — absent → all fees 0). A public pure helper `CheckoutService.dispatch_fees_for(items, variants, region_param) :: %{supplier_id => fee}` (Task 4 reuses it for the live preview).

- [ ] **Step 1: Failing tests** — append (mirror the file's existing dropship fixture style; the fixture must create a supplier offer WITH `dispatch_fees` — e.g. `%{"Greater Accra" => 1_500, "Ashanti" => 2_500}` — via `Offers.update_terms`, and import it so the reseller variant carries `supplier_id`):

```elixir
  describe "dispatch fees" do
    test "charges the max fee per supplier for the customer's region and snapshots it" do
      # fixture: ONE supplier, TWO offers in cart (fees 1_500 and 2_500 for "Greater Accra")
      # checkout! with region: "greater_accra", delivery_fee: 1_000
      # assert order.dispatch_fee_total == 2_500 (max, once)
      # assert order.total == order.subtotal + 1_000 + 2_500 - 0
      # assert the supplier's fulfillment.dispatch_fee == 2_500
      # assert the supplier's ledger entry amount_owed == cost_sum + 2_500
    end

    test "unquoted region and merchant-owned lines charge zero" do
      # same fixture, region: "volta" (unquoted) → dispatch_fee_total == 0
      # plus a merchant-owned (nil supplier) item → contributes nothing
      # and region: "other" → 0; opts without :region → 0
    end

    test "multi-supplier carts compose per supplier" do
      # two suppliers, fees 1_500 and 3_000 for the region
      # dispatch_fee_total == 4_500; each fulfillment carries its own fee
    end

    test "later offer edits do not change the snapshot" do
      # checkout, then Offers.update_terms the offer's fee to 9_900
      # reload order + fulfillment: amounts unchanged
    end
  end
```

Write these as REAL tests with the file's fixtures — the comments above are the required assertions, not placeholders to leave.

- [ ] **Step 2: Verify RED** — `mix test test/emakola/orders/checkout_service_test.exs` → `dispatch_fee_total` unknown attribute / assertions fail.

- [ ] **Step 3: Migration**

```elixir
defmodule Emakola.Repo.Migrations.AddDispatchFeeSnapshots do
  use Ecto.Migration

  # Snapshot of the supplier dispatch fee charged at checkout, integer
  # pesewas. Lives on the fulfillment (one per supplier per order) with the
  # order-level sum denormalized for totals math and display.
  def change do
    alter table(:fulfillments) do
      add :dispatch_fee, :integer, null: false, default: 0
    end

    alter table(:orders) do
      add :dispatch_fee_total, :integer, null: false, default: 0
    end
  end
end
```

- [ ] **Step 4: Resources** — `Fulfillment`: `attribute(:dispatch_fee, :integer, allow_nil?: false, default: 0, public?: true)` + add `:dispatch_fee` to the `:create` action's accept list. `Order`: `attribute(:dispatch_fee_total, :integer, allow_nil?: false, default: 0, public?: true)` + add to the checkout-used `:update` accept list.

- [ ] **Step 5: CheckoutService** — add the pure helper + wire it:

```elixir
  @doc """
  Per-supplier dispatch fees for a cart, pesewas. MAX across the supplier's
  offers in the cart (one parcel per supplier per order — locked decision),
  0 for unquoted regions, "other", or unresolvable listings. Pure: region
  resolution via GhanaRegions.from_param/1.
  """
  def dispatch_fees_for(items, variants, region_param) do
    case Emakola.Suppliers.GhanaRegions.from_param(region_param) do
      nil ->
        %{}

      region ->
        supplier_variant_ids =
          items
          |> Enum.map(& &1.variant_id)
          |> Enum.filter(fn vid -> Map.fetch!(variants, vid).supplier_id != nil end)

        fees_by_supplier(supplier_variant_ids, region)
    end
  end

  defp fees_by_supplier([], _region), do: %{}

  defp fees_by_supplier(variant_ids, region) do
    require Ash.Query

    listing_variants =
      Emakola.Suppliers.ResellerListingVariant
      |> Ash.Query.filter(reseller_variant_id in ^variant_ids)
      |> Ash.Query.load(listing: :offer)
      |> Ash.read!(authorize?: false)

    listing_variants
    |> Enum.group_by(& &1.listing.supplier_id)
    |> Map.new(fn {supplier_id, lvs} ->
      max_fee =
        lvs
        |> Enum.map(fn lv -> Map.get(lv.listing.offer.dispatch_fees || %{}, region, 0) end)
        |> Enum.max(fn -> 0 end)

      {supplier_id, max_fee}
    end)
  end
```

(VERIFY the `listing: :offer` load path against the `ResellerListing` relationships — if the offer relationship has a different name, adapt and report.) Then inside `run_checkout`:
- Compute `dispatch_fees = dispatch_fees_for(items, variants, Keyword.get(opts, :region))` before `create_fulfillments`.
- `create_fulfillments` gains the map and writes `dispatch_fee: Map.get(dispatch_fees, supplier_id, 0)` per fulfillment (nil-supplier group → 0).
- `create_ledger_entries` adds the supplier's fee once to `amount_owed` (entry now created when `cost_sum + fee > 0`).
- Totals: `dispatch_fee_total = dispatch_fees |> Map.values() |> Enum.sum()`; `total = subtotal + delivery_fee + dispatch_fee_total - discount_amount`; add `dispatch_fee_total:` to the order update map.
- `checkout_live.ex` ~417-433: add `region: socket.assigns.region` to the opts passed to `checkout!`.

- [ ] **Step 6: GREEN + commit** — `MIX_ENV=test mix ecto.migrate && mix format && mix test test/emakola/orders/checkout_service_test.exs` → green. `MIX_ENV=test mix compile --warnings-as-errors`. `git add -A && git commit -m "feat(payments): checkout charges and snapshots supplier dispatch fees"`

---

### Task 3: Splits carry the fee

**Files:**
- Modify: `lib/emakola/payments/split_calculator.ex`, `lib/emakola/payments/order_settlement.ex`, `lib/emakola/payments/dropship_settlement.ex` (opts pass-through)
- Test: `test/emakola/payments/order_settlement_test.exs` + `test/emakola/payments/split_calculator_test.exs` (if it exists; else the settlement test file covers both — check)

**Interfaces:**
- Consumes: Task 2's snapshots (`Fulfillment.dispatch_fee` per supplier).
- Produces: `SplitCalculator.calculate(line_items, opts)` honors `opts[:dispatch_fees] :: %{supplier_id => pesewas}` (default `%{}`): each wholesaler allocation's amount += its fee; the returned `total` += Σ fees. `OrderSettlement.prepare/2` loads the order's fulfillments and threads the fee map through `DropshipSettlement.prepare/3` opts.

- [ ] **Step 1: Failing tests** — the CRITICAL suite. Append, mirroring the file's existing fixture style:

```elixir
  describe "dispatch fees in splits" do
    test "wholesaler share = cost + dispatch fee; platform fee base unchanged; sum invariant holds"
    # dropship order w/ fee (build via checkout! with region) →
    #   OrderSettlement.prepare returns allocations where:
    #   wholesaler.amount == cost_sum + fee
    #   platform.amount == same as an identical order WITHOUT the fee (margin bps only)
    #   Σ allocations.amount == order.total

    test "multi-supplier: each wholesaler gets exactly their own fee; sum invariant holds"

    test "coupon discount: sum invariant still holds with fee + discount"

    test "zero-fee order split output is byte-identical to the pre-fee math"
    # order via checkout! WITHOUT region → assert full allocations list
    # (roles, amounts, subaccounts) exactly equals the value the existing
    # tests pin — reuse an existing test's expected values if one asserts
    # exact allocations; otherwise compute expected by hand in the test.
  end
```

Real tests, real assertions — the comment lines are the required properties.

- [ ] **Step 2: Verify RED** — wholesaler amounts miss the fee → assertions fail.

- [ ] **Step 3: Implement** —
- `split_calculator.ex`: `dispatch_fees = Keyword.get(opts, :dispatch_fees, %{})`; in `wholesaler_allocations/2` (now /3) add `+ Map.get(dispatch_fees, supplier_id, 0)` to each amount; `total:` becomes `Enum.sum(retails) + Enum.sum(Map.values(dispatch_fees))`. Keep the function pure.
- `order_settlement.ex` `prepare/2`: load the order's fulfillments (`Ash.Query.filter(order_id == ^order_id)` on `Emakola.Orders.Fulfillment`, `authorize?: false`, tenant as the order load does) → `dispatch_fees = for f <- fulfillments, f.supplier_id, into: %{}, do: {f.supplier_id, f.dispatch_fee}`; pass `dispatch_fees: dispatch_fees` through `DropshipSettlement.prepare(line_items, store_id, fee_rate_bps: ..., dispatch_fees: ...)`.
- `dropship_settlement.ex`: thread the opt through to `SplitCalculator.calculate/2` untouched otherwise.
- Do NOT touch `adjust_dropshipper`, `valid_shares?`, `PlatformFee`, webhook handling, or `mark_settled`.

- [ ] **Step 4: GREEN + commit** — `mix format && mix test test/emakola/payments/ 2>&1 | tail -3` → green. `git add -A && git commit -m "feat(payments): dispatch fees pass through to wholesaler splits"`

---

### Task 4: Checkout UI line + live preview

**Files:**
- Modify: `lib/emakola_web/live/storefront/checkout_live.ex` (assign + recompute on region change), `lib/emakola/themes/default_renderers/checkout.ex` (totals box), `lib/emakola/themes/default_renderers/order_confirmation.ex` (totals, only if it itemizes delivery — read it first; skip with a report note if it shows only the total)
- Test: the checkout LV test file (append)

**Interfaces:**
- Consumes: `CheckoutService.dispatch_fees_for/3` (pure, Task 2); the LV's existing `items`/`variants`-shaped data — read how `update_delivery_fee/1` gets its inputs and mirror; the cart items in the LV may need the same `%{variant_id, quantity}` shape + a variants map (check what the LV already holds; if it only has cart-store items, build the minimal inputs the helper needs — adapt and report).
- Produces: assign `:dispatch_fee_total` recomputed wherever `update_delivery_fee/1` runs (same lifecycle points); an order-summary line "Supplier dispatch" rendered only when > 0; displayed total includes it.

- [ ] **Step 1: Failing tests** —

```elixir
    test "supplier dispatch line appears for dropship carts and updates with region"
    # cart with a dropship item (fee 1_500 Greater Accra, 2_500 Ashanti):
    # checkout page shows "Supplier dispatch" + format_price(1_500);
    # change region to ashanti (drive the real region input/event) →
    # line shows format_price(2_500); displayed total tracks it

    test "no dispatch line for merchant-only carts"
    # refute "Supplier dispatch" in html
```

- [ ] **Step 2: Verify RED**, **Step 3: Implement** (mirror `update_delivery_fee/1`'s placement for a sibling `update_dispatch_fees/1`; totals renderer adds the `:if={@dispatch_fee_total > 0}` row using the existing delivery-fee row's markup as the pattern; effective total display includes the fee — find where the template sums/displays the payable total and include the assign), **Step 4: GREEN + commit** — `mix format && mix test <checkout LV test file>` → green. `git add -A && git commit -m "feat(web): checkout itemizes supplier dispatch fees live"`

---

### Task 5: End-to-end seal + full gates

**Files:**
- Test: the checkout LV test file (append one seal test)

- [ ] **Step 1: Seal test** (should pass immediately; a failure is a real integration bug — diagnose, fix minimally, document):

```elixir
    test "full checkout charges the fee and the splits carry it"
    # drive the real checkout UI to completion for a dropship cart with a fee
    # (region greater_accra), then:
    #   order.dispatch_fee_total == fee; order.total includes it
    #   OrderSettlement.prepare(order.id, store.id) → wholesaler allocation
    #   amount == cost + fee and Σ allocations == order.total
```

- [ ] **Step 2: Full gates (ALL FOREGROUND)** — `mix format --check-formatted`; `mix credo --strict` on the five touched lib files; `MIX_ENV=test mix compile --warnings-as-errors` (touch edited files first); FULL `mix test 2>&1 | tail -3` — parse the Result line.

- [ ] **Step 3: Commit** — `git add -A && git commit -m "test(payments): dispatch fee charged end-to-end through checkout and splits"`

Do NOT push or open a PR — the controller runs the whole-branch review first (this branch touches the most consequential money code in the repo; the final review must empirically probe the split math, the RefundLiability.reserve! interaction, and the byte-identical zero-fee regression).
