# Single-Rail Settlement P1 — The Flip: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route every new charge onto the internal settlement rail so gateway subaccount
splits are no longer produced — Phase 1 (§3.5) of
`docs/superpowers/specs/2026-08-07-single-rail-settlement-design.md`.

**Architecture:** One surgical change to `OrderSettlement.prepare/2`: the two gateway
outcomes (`:dropship_split`, `:platform_fee`) reroute to the existing, shipped
`prepare_internal/2`. Allocation math, fees, escrow holds, charge sites, and the payout
rail are all untouched — `prepare_internal` already handles dropship and own-stock
orders and both charge sites are mode-agnostic (they copy `mode` into
`Payment.split_mode` and pass `shares` through; `shares: []` is already a live path).

**Tech Stack:** Elixir/Phoenix/Ash. Tests: ExUnit via `mix test`. Repo:
`/Users/kojo/Projects/emakola`, branch `feature/single-rail-settlement-spec`.

## Global Constraints

- Never commit to `main` — all work on `feature/single-rail-settlement-spec`.
- `mix format` before every commit; `mix compile --warnings-as-errors` must pass
  (unused private functions are warnings → must be deleted in the task that orphans them).
- Allocation **amounts must not change** on any path: the flip changes *where money
  settles*, never *how much each party gets*. Any test amount that needs editing is a
  bug in the change, not the test.
- TC-2 buyer-protection precedence is behaviour-frozen: dropship beats hold; hold beats
  own-stock settlement. The `describe "prepare/2 — buyer protection hold (TC-2)"` block
  in `test/emakola/payments/order_settlement_test.exs` must pass **unmodified**.
- The legacy `{:no_split, :allocation_sum_mismatch | :unrepresentable_split}` escape
  stays reachable (pathological discounts) — do not remove those clauses.

**Existing-test update rule (used by Tasks 1–2).** Gateway-expectation tests keep their
setup and their money assertions verbatim; only settlement-surface assertions change,
by this exact mapping and nothing else:

| Old assertion | New assertion |
|---|---|
| `mode: :dropship_split` or `mode: :platform_fee` | `mode: :internal` |
| destructured `shares: shares` + any `... in shares` / `refute ... shares` | `shares: []` (assert the literal empty list) |
| `subaccount_code == "ACCT_..."` on an allocation | `subaccount_code == nil` |
| *(none)* | add once per test that binds `allocs`: `assert Enum.all?(allocs, &(&1.settlement_method == :internal_hold))` |

Factory helpers available (all used in `order_settlement_test.exs` today):
`create_store!/1`, `create_product!/2`, `create_variant!/3`, `create_payment!/2`,
`Emakola.Orders.CheckoutService.checkout!/3`, and the file-local `verified_payout!/2`.

---

### Task 1: Own-stock orders settle internal

**Files:**
- Create: `test/emakola/payments/single_rail_flip_test.exs`
- Modify: `lib/emakola/payments/order_settlement.ex:87-101` (the `{:no_split, :no_dropship_items}` branch)
- Modify: `test/emakola/payments/order_settlement_test.exs:186-296` (`describe "prepare/2 — platform fee on normal orders"`)

**Interfaces:**
- Consumes: `OrderSettlement.prepare/2`, `OrderSettlement.prepare_internal/2` (both existing).
- Produces: `prepare/2` returns `{:split, %{mode: :internal, shares: [], ...}}` for a
  verified own-stock merchant. Tasks 2–4 rely on exactly this shape.

- [ ] **Step 1: Write the failing test**

Create `test/emakola/payments/single_rail_flip_test.exs`:

```elixir
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
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `mix test test/emakola/payments/single_rail_flip_test.exs`
Expected: FAIL — `prepare/2` currently returns `mode: :platform_fee` with a
`%{subaccount: "ACCT_verified", share: 9_800}` gateway share.

- [ ] **Step 3: Implement the flip for own-stock**

In `lib/emakola/payments/order_settlement.ex`, replace the body of the
`{:no_split, :no_dropship_items}` clause of `prepare/2` (currently the
`protected?`-then-`prepare_platform_fee` block at lines ~87–101) with:

```elixir
      # A normal own-stock order (no dropship items — dropship always wins,
      # matched above): buyer protection (TC-2), if it applies, still wins —
      # the charge settles with no allocation rows and the payment is flagged
      # payout_held for a later release. Everything else settles internal
      # (single rail, P1): same fee math, rows on the ledger, paid out by
      # MoMo transfer — verification no longer selects a settlement path.
      {:no_split, :no_dropship_items} ->
        if protected?(order, store_id) do
          {:hold, :buyer_protection}
        else
          prepare_internal(order_id, store_id)
        end
```

Do NOT delete `prepare_platform_fee/2` yet — the dropship branch is still gateway in
this task and Task 3 owns the deletions (single concern per commit).
`prepare_platform_fee/2` is now uncalled, so add a `# P1: dead — deleted in Task 3`
comment ONLY if the compiler warns; if `mix compile --warnings-as-errors` fails on the
unused function, move Task 3's deletion of `prepare_platform_fee/2` and
`verified_subaccount/1` into this task's Step 3 instead and note it in the commit.

- [ ] **Step 4: Update the existing platform-fee describe**

In `test/emakola/payments/order_settlement_test.exs`,
`describe "prepare/2 — platform fee on normal orders"`: apply the Global-Constraints
mapping table to every test in the block — `mode: :platform_fee` → `mode: :internal`,
share destructures/assertions → `shares: []` (as a literal match in the `{:split, ...}`
pattern), `subaccount_code == "ACCT_drop"` → `subaccount_code == nil`, and add the
`settlement_method == :internal_hold` blanket assertion wherever `allocs` is bound.
Money assertions (`9_800`, `200`, sums) stay byte-identical. Rename the describe to
`"prepare/2 — own-stock orders settle internal (P1)"`.

- [ ] **Step 5: Run the file and the flip test**

Run: `mix test test/emakola/payments/order_settlement_test.exs test/emakola/payments/single_rail_flip_test.exs`
Expected: the platform-fee describe and the new test PASS. The dropship describes
("linked wholesaler", "reconciles to order total", "dispatch fees in splits") still
PASS — their branch is untouched until Task 2.

- [ ] **Step 6: Commit**

```bash
mix format
git add lib/emakola/payments/order_settlement.ex test/emakola/payments/
git commit -m "feat(payments): P1 flip — own-stock charges settle internal"
```

---

### Task 2: Dropship orders settle internal

**Files:**
- Modify: `lib/emakola/payments/order_settlement.ex:50-86` (the `{:split, ...}` gateway branch)
- Modify: `test/emakola/payments/single_rail_flip_test.exs` (add the dropship test)
- Modify: `test/emakola/payments/order_settlement_test.exs` describes
  `"prepare/2 — linked wholesaler"` (29–148), `"prepare/2 — reconciles to order total"`
  (149–185), `"dispatch fees in splits"` (396–621)

**Interfaces:**
- Consumes: `prepare_internal/2` — already folds delivery-fee adjustment and dispatch
  fees for dropship allocations (verified: `order_settlement.ex:140-153`).
- Produces: `prepare/2` returns `mode: :internal, shares: []` for dropship orders too;
  after this task NO caller can receive `:dropship_split` or `:platform_fee`.

- [ ] **Step 1: Write the failing test**

Append to the `describe "own-stock orders"` sibling level in
`test/emakola/payments/single_rail_flip_test.exs` (setup for a linked wholesaler is
involved — copy the setup lines VERBATIM from the first test of
`describe "prepare/2 — linked wholesaler"` in `order_settlement_test.exs`, which
builds wholesaler + dropshipper + imported listing via `ListingImporter`/`Network`/
`Offers`; keep every amount it uses), then assert on the settlement surface only:

```elixir
  describe "dropship orders" do
    test "a fully-verified dropship charge settles internal — no gateway shares" do
      # (setup copied verbatim from order_settlement_test.exs "linked wholesaler",
      #  first test — producing `order`, `dropshipper`, and the expected
      #  wholesaler/dropshipper amounts it asserts)

      assert {:split, %{mode: :internal, shares: [], allocations: allocs}} =
               OrderSettlement.prepare(order.id, dropshipper.id)

      assert Enum.any?(allocs, &(&1.role == :platform and &1.amount > 0))
      assert Enum.all?(allocs, &(&1.settlement_method == :internal_hold))
      assert Enum.all?(allocs, &is_nil(&1.subaccount_code))
    end
  end
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `mix test test/emakola/payments/single_rail_flip_test.exs`
Expected: FAIL — dropship orders still return `mode: :dropship_split` with shares.

- [ ] **Step 3: Implement the flip for dropship**

In `prepare/2`, replace the entire `{:split, %{allocations: allocations}} ->` branch
body (the delivery-fee fold, `valid_shares?` check, carve, reserve, and
`:dropship_split` return — lines ~50–79) with:

```elixir
      {:split, _gateway} ->
        # Single rail (P1): the gateway computed a valid dropship split, which
        # proves this is a dropship order — but nothing settles at the gateway
        # any more. prepare_internal re-runs the SAME allocation math
        # (delivery-fee fold, dispatch fees, carve, reserve) on the internal
        # rail. P3 removes this double computation with the gateway path itself.
        prepare_internal(order_id, store_id)
```

- [ ] **Step 4: Update the three dropship describes**

Apply the Global-Constraints mapping table to every test in
`"prepare/2 — linked wholesaler"`, `"prepare/2 — reconciles to order total"`, and
`"dispatch fees in splits"`. Wholesaler/dropshipper/platform *amounts* stay
byte-identical (prepare_internal folds delivery and dispatch fees the same way — any
amount difference is a regression, stop and investigate). Rename
`"prepare/2 — linked wholesaler"` → `"prepare/2 — dropship orders settle internal (P1)"`.

- [ ] **Step 5: Run the payments suite**

Run: `mix test test/emakola/payments`
Expected: PASS. Tests elsewhere in this suite that assert `:dropship_split` /
`:platform_fee` / gateway shares (e.g. `internal_settlement_e2e_test.exs`,
`payment_split_settlement_test.exs`) will surface here — update each strictly by the
mapping table; anything that can't be fixed by the table alone is a finding to report,
not to bodge.

- [ ] **Step 6: Commit**

```bash
mix format
git add lib/emakola/payments/order_settlement.ex test/emakola/payments/
git commit -m "feat(payments): P1 flip — dropship charges settle internal"
```

---

### Task 3: Delete the dead gateway path; freeze hold precedence

**Files:**
- Modify: `lib/emakola/payments/order_settlement.ex` — delete `prepare_platform_fee/2`,
  `verified_subaccount/1`, `valid_shares?/1`, `gateway_shares/1`,
  `adjust_dropshipper/2` **only if** now unused (it is still called by
  `prepare_internal` — keep it); rewrite the moduledoc
- Test: `test/emakola/payments/order_settlement_test.exs` (TC-2 describe — must be untouched and green)

**Interfaces:**
- Consumes: the flipped `prepare/2` from Tasks 1–2.
- Produces: a module whose only settlement outcomes are `{:split, %{mode: :internal}}`,
  `{:hold, :buyer_protection}`, `{:no_split, legacy_escape}`.

- [ ] **Step 1: Confirm the hold-precedence tests still pass unmodified**

Run: `mix test test/emakola/payments/order_settlement_test.exs --only describe:"prepare/2 — buyer protection hold (TC-2)"`
(if `--only describe:` is unsupported in this ExUnit version, run the file and confirm
the four TC-2 tests in the output). Expected: PASS with zero edits to that describe —
this is the escrow-precedence freeze from the Global Constraints. If any TC-2 test
fails, Tasks 1–2 broke precedence: STOP and fix before deleting anything.

- [ ] **Step 2: Delete the dead private functions**

Remove from `order_settlement.ex`: `prepare_platform_fee/2`, `verified_subaccount/1`,
`valid_shares?/1`, `gateway_shares/1` (each is uncalled after Task 2 — verify with
`grep -n "prepare_platform_fee\|verified_subaccount\|valid_shares\|gateway_shares" lib/ test/`
and delete any test that targeted them directly). Keep `adjust_dropshipper/2`,
`internal_hold/1`, `default_settlement_method/1`, `record_splits!/2` — all still used.

- [ ] **Step 3: Rewrite the moduledoc**

Replace the moduledoc's split-modes bullet list with:

```elixir
  @moduledoc """
  Order-aware glue between a placed order and the payment ledger.

  Single rail (P1, spec 2026-08-07): every charge settles to the platform
  account. `prepare/2` returns:

    * `{:split, %{total, allocations, shares: [], mode: :internal}}` — the
      normal outcome for own-stock AND dropship orders alike. Allocation math
      (fees, delivery fold, dispatch fees, partner-credit carve, refund
      reserve) is unchanged from the gateway era; only the settlement changed.
    * `{:hold, :buyer_protection}` (TC-2) — own-stock only; the charge is
      payout-held and gains no rows until release (rows-at-charge is P2).
    * `{:no_split, reason}` — pathological escapes (allocation_sum_mismatch,
      unrepresentable_split) kept as the legacy fail-safe.

  `record_splits!/2` and `persist_payment/2` are unchanged.
  """
```

- [ ] **Step 4: Compile with warnings as errors, run the suite**

Run: `mix compile --warnings-as-errors && mix test test/emakola/payments`
Expected: clean compile (no unused-function warnings — the point of the deletions), PASS.

- [ ] **Step 5: Commit**

```bash
mix format
git add lib/emakola/payments/order_settlement.ex test/emakola/payments/
git commit -m "refactor(payments): P1 — delete the dead gateway settlement path"
```

---

### Task 4: Persistence invariant, full verification, PR

**Files:**
- Modify: `test/emakola/payments/single_rail_flip_test.exs` (add the persistence test)

**Interfaces:**
- Consumes: `OrderSettlement.persist_payment/2` (existing — one transaction, payment + rows).
- Produces: the P1 exit criterion from spec §3.5, as a test.

- [ ] **Step 1: Write the persistence invariant test**

Append to `single_rail_flip_test.exs`:

```elixir
  describe "P1 exit invariant — persisted charges" do
    test "a persisted charge has rows that sum to it, including the platform fee" do
      merchant = create_store!(name: "Persist Flip")
      verified_payout!(merchant, "ACCT_persist")
      product = create_product!(merchant, title: "Persist Product")
      own = create_variant!(product, merchant, price: 7_500, sku: "FLIP-PERSIST", stock_quantity: 5)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          merchant.id,
          [%{variant_id: own.id, quantity: 1}],
          []
        )

      settlement = OrderSettlement.prepare(order.id, merchant.id)
      assert {:split, %{mode: :internal}} = settlement

      {:ok, payment} =
        OrderSettlement.persist_payment(
          %{
            store_id: merchant.id,
            order_id: order.id,
            amount: order.total,
            currency: "GHS",
            reference: "flip-#{order.id}",
            gateway: :paystack,
            status: :pending,
            split_mode: :internal
          },
          settlement
        )

      {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)

      assert order.total == Enum.sum(Enum.map(splits, & &1.amount))
      assert Enum.any?(splits, &(&1.role == :platform and &1.amount > 0))
      assert Enum.all?(splits, &(&1.settlement_method == :internal_hold))
    end
  end
```

If `create_payment` requires different attrs than shown (check
`test/emakola/payments/order_settlement_test.exs`'s use of `create_payment!/2` and the
`Payment` resource's `:create` accept list), mirror the factory's attrs — the
assertions are the contract, the attrs are plumbing.

- [ ] **Step 2: Run it**

Run: `mix test test/emakola/payments/single_rail_flip_test.exs`
Expected: PASS (this one is green-on-arrival — it proves existing plumbing under the
new routing; if it fails, the failure is a real P1 defect).

- [ ] **Step 3: Full verification**

Run: `mix precommit`
(alias = compile --warnings-as-errors, deps.unlock --unused, format, deps.audit, test —
full suite is ~6 min.) Expected: everything green. Any failing test outside
`test/emakola/payments` gets the mapping-table treatment if it asserts settlement
surface, and is a reported finding otherwise.

- [ ] **Step 4: Commit, push, open the PR**

```bash
git add -A && git commit -m "test(payments): P1 exit invariant — persisted internal charges"
git push -u origin feature/single-rail-settlement-spec
gh pr create --base main \
  --title "Single-rail settlement P1 — every new charge settles internal" \
  --body "Implements Phase 1 of docs/superpowers/specs/2026-08-07-single-rail-settlement-design.md: OrderSettlement.prepare/2 routes all charges to the internal rail; gateway split outcomes and their dead helpers are deleted; allocation amounts and TC-2/escrow precedence are behaviour-frozen by test. P2 (one reversal rule, rows for holds) and P3 (delete settlement_method and the recovery formulas) follow in separate plans."
```

---

## Self-review (done at write time)

- **Spec coverage:** §3.5 P1 fully covered (flip: Tasks 1–2; exit test: Task 4;
  routing-only scope respected — no reversal/hold-row work, that's P2). §3.3 escrow
  freeze enforced via the untouched TC-2 describe + Global Constraints.
- **Placeholders:** none. The two "copy verbatim from X" instructions point at exact,
  named describes in an existing file — deliberate DRY against drift, with the
  assertion contract spelled out in full.
- **Type consistency:** `prepare/2` and `prepare_internal/2` return shapes quoted from
  the live module; `settlement_method: :internal_hold` matches `internal_hold/1`;
  `list_payment_splits/2` usage matches `record_splits!/2`'s own idempotency read.
