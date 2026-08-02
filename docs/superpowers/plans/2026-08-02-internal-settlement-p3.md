# Internal Settlement Phase 3 — The Flip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the internal rail ON: verification-failure charges route to `prepare_internal` (platform fee always taken — the revenue leak dies), the Earn sell-gate opens fully, merchants see accruing balances — after a hardening batch closing tracked before-P3 debt.

**Architecture:** Branch `internal-settlement-p3` off merged main `4b9e7422` (#372 + #373 in). The ONE deploy where live behavior changes. Production-code footprint is deliberately tiny — verified on main: the flip is one clause replacement in `prepare/2` (own-stock unverified already flows into the same catch-all), the sell-gate is two dropped checks, and charge sites need ZERO changes (`split_mode` is generic; `Paystack.maybe_put_split(body, [])` drops empty shares at paystack.ex:218).

**Tech Stack:** Elixir/Phoenix/Ash 3.x; existing machinery; hand-written migrations.

## Global Constraints (BINDING)

- Worktree `/Users/kojo/Projects/emakola/.claude/worktrees/internal-settlement`, branch `internal-settlement-p3`. Money = integer minor units. TDD RED+GREEN evidence per task. `mix format` + `mix credo --strict` per commit; parse `mix test`'s `Result:` line.
- **KOJO-DECISION RESOLVED: (c) manual remediation** — NO make-whole code anywhere in this phase.
- Sell-gate: **both fully free** (Kojo). Coupon hard-block stays.
- Fee parity is THE invariant: identical order, verified vs unverified store → identical platform fee (own-stock 200 bps `PlatformFee`; dropship 1000 bps `SplitCalculator` margin).
- Grandfathering: existing `:none` payments drain via legacy; genuine failures (`:allocation_sum_mismatch`, `:unrepresentable_split` from either builder) still fall to `:none`; all four `payout_held` escrow reasons unchanged; protection precedence unchanged (protected own-stock → `{:hold, ...}` NEVER internal).
- Legacy suites green untouched except suites a task names with an intentional ruled change (eligibility suite in Task 6).

## Verified facts (merged main = branch base 4b9e7422)

- `order_settlement.ex`: `prepare/2` :36; `{:no_split, :no_dropship_items}` → protection → `prepare_platform_fee` :82-88 (KEEP); **flip edit point = catch-all `{:no_split, reason} -> {:no_split, reason}` at :89-90**; `prepare_platform_fee`'s `{:error, :payout_unverified} -> {:no_split, :payout_unverified}` (:201-202) flows into that catch-all, so own-stock reroutes free. `prepare_internal/2` :102-141 already guards sum/negatives and returns `{:split, %{..., shares: [], mode: :internal}}` or genuine `{:no_split, _}` — composition is clean. `gateway_shares/1` :342-346 filters `&1[:subaccount_code] && &1.amount > 0`.
- `network_checkout_eligibility.ex`: coupon gate :19-20 KEEP; payout checks :22-23 DROP; privates `verify_wholesaler_payouts/1` (:44) + `verified_payout/2` (:56) become orphans — delete (our change orphans them). `network_items?/2` unchanged. 11 tests in its suite; payout-gate tests get INTENTIONAL contract updates.
- Charge sites: `split_mode({:split, %{mode: mode}})` generic (checkout ~:622, pay_link :447); `maybe_attach_split` attaches `split: []` which `Paystack.maybe_put_split(body, [])` (paystack.ex:218) drops. ZERO code changes.
- Formula sites: `payout_service.ex:118-121` (defp `frozen_paid_amount`, used :158/:174), `finance_stats.ex:120` (defp `payable_net`, used :46/:62), `payment_split.ex` `mark_paid_out` change (~:420).
- `payout_worker.ex` `mark_failed/2` :93+ already releases (PR-373 fix B) — Task 2 wraps status-write + release in one `Repo.transaction`.
- `supplier_ledger_entry.ex` has the `Ash.Changeset.filter` conditional-write pattern on `mark_paid`/`claim_for_platform_settlement`/`reopen_platform_paid` (PR-373 fix A) — Task 1 copies it to the two unfitted actions.
- Test fixture authorities: `order_settlement_internal_test.exs` (checkout-service dropship/own-stock fixtures, carve fixture), `internal_payout_service_test.exs` (momo_destination!, settled_internal_split!), `supplier_ledger_unification_test.exs` (webhook job shapes).

---

### Task 1: Conditional filters on `mark_platform_paid` + `void`

**Files:** Modify `lib/emakola/suppliers/resources/supplier_ledger_entry.ex`; Test append `test/emakola/suppliers/supplier_ledger_entry_test.exs`

**Interfaces:** Produces: both actions carry DB-level WHERE preconditions (StaleRecord loser) — completing the 5-of-5 pattern. No signature changes.

- [ ] **Step 1 (RED):** append two stale-struct tests mirroring the file's existing "mark_paid guard" describe (read it first — copy its fixture shape): (a) read a `:paid`+`:platform_payout` entry struct, `reopen_platform_paid` it via a parallel struct, then attempt `mark_platform_paid` with the STALE `:owed`-era struct → wait, invert: create `:owed`+`:platform_payout` entry, hold stale struct, `mark_platform_paid` via fresh path, then attempt `mark_platform_paid` AGAIN with the stale struct → `{:error, %Ash.Error.Invalid{}}` (StaleRecord) and `paid_at` unchanged; (b) same shape for `void`: entry claimed `:platform_payout`/`:owed`, void it, stale-struct second `void` → error, status stays `:voided`. Run: `mix test test/emakola/suppliers/supplier_ledger_entry_test.exs` → the new tests FAIL (second write silently succeeds today).
- [ ] **Step 2 (GREEN):** add to `mark_platform_paid`: `change(fn changeset, _ -> Ash.Changeset.filter(changeset, expr(status == :owed and settlement_source in [:platform_payout, :split_gateway])) end)` (match its existing validation predicate EXACTLY — read the action first and mirror its validations into the filter); to `void`: filter matching ITS validations (`status == :owed and settlement_source == :platform_payout` — verify against the action's actual validate lines). Same `require Ash.Expr`/imports as the file's existing filters.
- [ ] **Step 3:** suite + format/credo → commit `fix(suppliers): complete the conditional-write pattern on ledger transitions`

### Task 2: Transactional `mark_failed` release

**Files:** Modify `lib/emakola/payments/workers/payout_worker.ex` (:93+); Test append `test/emakola/payments/workers/payout_worker_test.exs`

**Interfaces:** Consumes `PayoutService.release_payout_balance/1`. Produces: status-write + release atomic — a release crash leaves the payout NOT `:failed` so Oban retry re-reaches both.

- [ ] **Step 1 (RED):** test: prepared internal payout with claimed split; stub release to raise (simplest deterministic arrangement: pass a payout struct whose store's splits include one deleted mid-test? — if un-arrangeable without heavy mocks, test the observable contract instead: after `mark_failed` completes, payout `:failed` AND split released — both-or-neither. Write the both-or-neither assertion as the contract test; note the arrangement choice in the report).
- [ ] **Step 2 (GREEN):**
```elixir
  defp mark_failed(payout, reason) do
    # Atomic with the release: if releasing raises, the payout stays un-failed
    # and Oban's retry re-runs both — a :failed payout with claims still held
    # would be unreachable by the finance page's retry flow.
    {:ok, _} =
      Emakola.Repo.transaction(fn ->
        {:ok, _} = Payments.mark_payout_failed(payout, %{failure_reason: reason}, authorize?: false)
        Emakola.Payments.PayoutService.release_payout_balance(payout)
      end)
    :ok
  end
```
(Adapt the tail to the current function's return shape — read it first; keep the existing comment.)
- [ ] **Step 3:** worker suite + format/credo → commit `fix(payments): payout failure and claim release are atomic`

### Task 3: `payment_split_id` index + freeze-formula extraction

**Files:** Create `priv/repo/migrations/20260802<HHMMSS>_add_supplier_ledger_payment_split_index.exs`; Modify `payment_split.ex`, `payout_service.ex`, `finance_stats.ex`; Tests: existing formula suites stay green UNTOUCHED (that's the proof).

**Interfaces:** Produces: public `Emakola.Payments.PaymentSplit.frozen_paid_amount(split) :: integer()` — THE single formula authority. `mark_paid_out`'s change, `PayoutService`, `FinanceStats` all call it.

- [ ] **Step 1:** migration `change do create index(:supplier_ledger_entries, [:payment_split_id]) end` (hand-written; moduledoc notes it became a webhook-path query key in P2). `mix ecto.migrate` + test-DB + rollback check.
- [ ] **Step 2:** in `payment_split.ex`, add a public plain function (near the attribute defs, NOT an action):
```elixir
  @doc """
  THE freeze formula — what `mark_paid_out` writes into `paid_amount`:
  the split's amount minus reversals not already collected elsewhere.
  Single authority: PayoutService and FinanceStats delegate here.
  """
  def frozen_paid_amount(split) do
    netted = split.reversed_amount - split.recovered_amount - split.reserved_recovery_amount
    split.amount - netted
  end
```
`mark_paid_out`'s change fn computes via `__MODULE__.frozen_paid_amount(changeset.data)` for `paid_amount` (netted still derived: `changeset.data.amount - frozen` or keep the netted expression and set paid_amount from the function — keep both attributes consistent; read the change first). `payout_service.ex:118-121` body → `defdelegate`-style one-liner or direct call replacement at :158/:174 (`PaymentSplit.frozen_paid_amount/1`) — delete the local defp. `finance_stats.ex` `payable_net/1` → delegates likewise (keep the local name if call sites read better, body = one call).
- [ ] **Step 3:** run internal_payout_service_test + finance_stats suites + payment_split suites UNTOUCHED-green (the discriminating 4-term tests now guard the ONE copy). format/credo → commit `refactor(payments): one freeze formula, indexed supplier linkage`

### Task 4: The flip in `prepare/2` + `gateway_shares` switch

**Files:** Modify `lib/emakola/payments/order_settlement.ex` (:89-90, :342-346); Test append `test/emakola/payments/order_settlement_internal_test.exs`

**Interfaces:** Produces: `prepare/2` returns `{:split, %{mode: :internal, shares: [], ...}}` for the four verification-failure reasons; everything else unchanged.

- [ ] **Step 1 (RED):** tests (checkout-service fixtures per the file's existing patterns): (a) own-stock unverified store → `prepare/2` returns `mode: :internal`, fee == `PlatformFee.calculate(order.total, 200-bps-config)`; (b) dropship with unverified linked wholesaler → `mode: :internal`, sum-exact; (c) PROTECTED own-stock unverified store (`buyer_protection_enabled: true`) → still `{:hold, :buyer_protection}` (precedence unchanged); (d) verified store → `mode: :platform_fee` exactly as before (fee parity pair with (a)); (e) unlinked supplier → `mode: :internal` with fold. All RED (today they return `{:no_split, reason}`).
- [ ] **Step 2 (GREEN):** replace :89-90:
```elixir
      # Verification failures route to the internal rail: the charge settles
      # to the platform account, allocations (incl. the platform fee) are
      # recorded on the ledger, and parties are paid by MoMo transfer once
      # they add a destination. Genuine split failures still fall through to
      # the legacy :none path (no rows, escrow-compatible).
      {:no_split, reason}
      when reason in [
             :payout_unverified,
             :dropshipper_payout_unverified,
             :wholesaler_payout_unverified,
             :supplier_not_linked
           ] ->
        prepare_internal(order_id, store_id)

      {:no_split, reason} ->
        {:no_split, reason}
```
`gateway_shares/1` at :342-346: add the settlement_method term:
```elixir
  defp gateway_shares(allocations) do
    allocations
    |> Enum.filter(fn alloc ->
      # Absent key = gateway rail (gateway builders don't tag); internal
      # builders tag every allocation :internal_hold — never a gateway share.
      Map.get(alloc, :settlement_method, :gateway_share) == :gateway_share and
        alloc[:subaccount_code] && alloc.amount > 0
    end)
    |> Enum.map(&%{subaccount: &1.subaccount_code, share: &1.amount})
  end
```
- [ ] **Step 3:** order_settlement_internal + order_settlement legacy suite (UNTOUCHED green) + format/credo → commit `feat(payments): the flip — verification failures route to the internal rail`

### Task 5: Charge-site pass-through (TEST-ONLY)

**Files:** Test append `test/emakola_web/live/storefront/` checkout flow test (find the suite that drives a full MoMo checkout — likely checkout_live_test.exs; mirror its fixture).

- [ ] **Step 1:** LiveView test: unverified store, MoMo checkout → payment `split_mode: :internal`, PaymentSplit rows recorded (sum == total, all `:internal_hold`), and the gateway request carried NO split key (assert via the Mox gateway expectation's params — `refute Map.has_key?(params, :split)` or params[:split] in [nil, []] per the mock's contract; read how the suite's existing expectations inspect params). Should pass IMMEDIATELY after Task 4 (that's the point — zero code): if it fails, something in the pass-through assumption broke — STOP and report rather than patching.
- [ ] **Step 2:** commit `test(web): unverified checkout lands on the internal rail end-to-end`

### Task 6: Sell-gate opens + SalesTeams parity

**Files:** Modify `lib/emakola/suppliers/network_checkout_eligibility.ex`; Modify its test suite (INTENTIONAL contract change — ledger it); Test append sales-teams parity in `test/emakola/suppliers/` (find sales_teams settlement test file, mirror fixtures).

- [ ] **Step 1 (RED-by-contract):** update the eligibility suite: payout-gate tests flip to assert unverified reseller AND unverified wholesaler both PASS validate/3 now (`:ok`); coupon test unchanged. These fail before the code change.
- [ ] **Step 2 (GREEN):** `validate/3` :19-27 becomes: coupon check → `:ok` (drop both `with` clauses); DELETE orphaned `verify_wholesaler_payouts/1` + `verified_payout/2`. Keep the moduledoc honest — rewrite it: "Enforces coupon launch rules for imported Earn products. Payout verification is no longer a sale gate: unverified parties' shares accrue on the internal ledger (internal-settlement P3)."
- [ ] **Step 3:** SalesTeams parity test: internal-mode charge (unverified store, checkout + webhook settle) with an attributed team member → settlement fires identically to the gateway-rail case (mirror the existing sales-team settlement test's fixture, swapping the store to unverified). No production code change expected — if settlement_base errors, STOP and report.
- [ ] **Step 4:** suites + format/credo → commit `feat(suppliers): the sell-gate opens — earnings accrue before payout onboarding`

### Task 7: Balance visibility + MoMo nudges

**Files:** Modify `lib/emakola_web/live/admin/payout_live.ex` (+ its render); Modify `lib/emakola_web/live/admin/supplier_live/show.ex`; Tests: `test/emakola_web/live/admin/payout_live_test.exs` (find exact name) + supplier_live_test.exs append.

**Interfaces:** Consumes `Emakola.Payments.list_payable_internal_splits(store_id, ...)` + `PaymentSplit.frozen_paid_amount/1` (Task 3) + `PayoutService.momo_destination?/1`.

- [ ] **Step 1 (RED):** LiveView tests: (a) merchant with a payable internal split and NO destination sees the accrued amount AND the nudge copy "waiting — add your mobile money number" (assert on a stable substring); (b) with a destination saved: amount shown, no nudge; (c) zero balance: neither. Supplier page: claimed-unpaid (`:platform_payout`/`:owed`) entries render a "Settling via Makola" state (already exists from P2 — extend only if the accrued-total line is missing; check first) — if P2's UI already covers the supplier side adequately, note it and skip (b)-side changes.
- [ ] **Step 2 (GREEN):** in `payout_live.ex`'s mount: `assign_async(:accrued_balance, fn -> ...sum via list_payable_internal_splits(store.id) |> Enum.map(&PaymentSplit.frozen_paid_amount/1) |> Enum.sum()... end)` (Iron Law: no sync DB in mount — note the page's existing `load_account/1` violates this; do NOT copy it, and do NOT fix it either — surgical). Render: amount via the app's money formatter (find the storefront/admin helper — grep `format_amount|format_money`), nudge shown when balance > 0 and `not PayoutService.momo_destination?(store.id)` (compute in the async result tuple, not in render). Match the page's existing Tailwind card style.
- [ ] **Step 3:** suites + format/credo → commit `feat(web): merchants see internal balances accruing + MoMo nudge`

### Task 8: Phase gate

- [ ] Fee-parity e2e (order_settlement_internal or a dedicated integration test): unverified store checkout → `:internal` payment + rows (one tx) → charge.success settle → payable → `prepare_internal_payout` → transfer.success — sum-exact asserted at EVERY stage; and the twin verified-store run yields the identical platform fee.
- [ ] Grandfathered-`:none` regression: a `:none` success payment still pays via legacy approve (existing outstanding/payout tests should already cover; add the explicit pairing test if not).
- [ ] Full `mix test` (Result line), `mix format --check-formatted`, `mix credo --strict`, `touch`-then-`--warnings-as-errors`; guarded-suite diff proof vs 4b9e7422 (all legacy money suites except the two INTENTIONAL suites named in Tasks 5/6).
- [ ] Whole-branch final review (most capable model) with the ledger's deferred list; ONE fix wave max; push; PR → main. PR body MUST name the live behavior changes: (1) verification-failure charges now settle internally WITH the platform fee (the leak closes), (2) Earn sell-gate fully open, (3) merchant/supplier balance UI. Deploy notes: none beyond the index migration; population starts growing at first unverified checkout.

## Deferred (NOT this phase)

GHS-typed transfer recipient (NGN-gated); release payout-identity guard; unreclaimable-flag false positives; payouts_ready? N+1; cross-currency flash sum; Oban-exhaustion `:pending` claim; admin ledger error-branch reload; partial-reversal full-amount stamp imprecision; payout_live sync-mount pre-existing violation.
