# Single-Rail Settlement P2a — Debts Settle Before Any New Payout: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce spec §3.2's rule "a recipient's balance may go negative via carry-forward
and is settled against future earnings **before any new payout**" — and thereby drain the
`needs_remediation` manual worklist automatically
(spec: `docs/superpowers/specs/2026-08-07-single-rail-settlement-design.md`).

**Architecture:** Today, post-claim reversals become *recoverable liability* that is only
clawed back at the recipient's next **charge** (`RefundLiability.reserve!` at allocation
time). A recipient who stops selling but keeps requesting payouts never repays. P2a adds
the second recovery site: `PayoutService.prepare_internal_payout/1` deducts the
recipient's outstanding liability from the payout inside the same FOR-UPDATE
transaction, recording the recovery on the source splits. The existing three-way
`effective_netted` formula composes cleanly: a freshly-claimed split's outstanding is
exactly 0 (`netted_reversal_amount = reversed − recovered − reserved` at claim), so
netting needs no exclusion logic for the splits being claimed in the same payout.

**Deliberate contract change (reviewers judge against the spec, not discover):**
`Payout.amount` becomes `Σ frozen_paid_amount − liability_deduction`. The old invariant
"payout amount == Σ of its splits' paid_amounts" (pinned by
`internal_payout_service_test.exs` "CONTRACT 1") is deliberately replaced; per-split
`paid_amount` stays the frozen claim value, and the delta is stamped with provenance on
each source liability's `recovery_breakdown["payout_recoveries"]`.

**Context:** P1's routing flip shipped via #401's RailPolicy (config default
`:internal_first`); PR #402 was closed as superseded. This plan builds on
`origin/main` = 79dbbe39, branch `feature/single-rail-settlement-p2a`. §3.3
rows-for-holds is deferred to a separate P2b plan (three of the four hold flows never
touch OrderSettlement, and two are fee-exempt — different blast radius).

**Tech Stack:** Elixir/Phoenix/Ash. Tests: `mix test`. Repo: `/Users/kojo/Projects/emakola`.

## Global Constraints

- Never commit to main; all work on `feature/single-rail-settlement-p2a`.
- `mix format` before every commit; `mix compile --warnings-as-errors` must pass.
- **No changes to when/whether reversals are recorded** — `reconcile!/2` and
  `record_reversal` are untouched. P2a changes only *when recovery is collected*.
- **Charge-time recovery keeps working unchanged** — `reserve!/1` at allocation time
  is untouched; payout-time netting is additive. Both read the same
  `recoverable_by_recipient` population under FOR UPDATE, so double-recovery is
  structurally impossible (each site bumps `recovered_amount`/`reserved_recovery_amount`
  under the lock; `outstanding` self-diminishes).
- The gateway rail (RailPolicy `:gateway_first`) and `SplitPay` pilot are untouched.
- Existing invariant that must SURVIVE: a recipient's lifetime payouts never exceed
  lifetime allocations net of reversals (spec §3.6 invariant 6) — the new deduction only
  strengthens it.
- Sort liabilities by `id` before booking recoveries (matches `apply_recoveries!`'s
  deadlock-avoidance convention).

---

### Task 1: `RefundLiability.outstanding_for_recipient!/1`

**Files:**
- Modify: `lib/emakola/payments/refund_liability.ex` (add public function + extract shared helper)
- Test: `test/emakola/payments/refund_liability_test.exs` (append a describe)

**Interfaces:**
- Consumes: `PaymentSplit.recoverable_by_recipient` read (existing),
  `effective_netted/1` (existing private).
- Produces: `outstanding_for_recipient!(recipient_store_id) :: {[locked_split], non_neg_integer}` —
  FOR-UPDATE-locks the recipient's recoverable splits and returns `{splits, total}` where
  total = `Σ max(reversed − effective_netted − recovered − reserved, 0)`. MUST be called
  inside a transaction (raises outside one, like every locked read in this module).
  Task 2 calls it from `prepare_internal_payout/1`'s transaction.

- [ ] **Step 1: Write the failing test**

Append to `test/emakola/payments/refund_liability_test.exs` (crib the split-creation
setup from this file's existing describes — it builds `PaymentSplit` rows inline via
`Ash.Changeset.for_create`; keep that idiom):

```elixir
  describe "outstanding_for_recipient!/1" do
    test "sums outstanding over the recipient's recoverable splits, floored at zero" do
      store = create_store!(name: "Owing Store")
      payment = create_payment!(store)

      # A claimed internal split reversed AFTER its claim: frozen fence 0,
      # reversal 3_000 → outstanding 3_000.
      _owing =
        split_fixture!(payment, store,
          amount: 10_000,
          settlement_method: :internal_hold,
          status: :partially_reversed,
          reversed_amount: 3_000,
          paid_out_at: DateTime.utc_now(),
          netted_reversal_amount: 0
        )

      # An UNCLAIMED internal split with a reversal nets at source:
      # effective_netted = min(amount, reversed) → outstanding 0.
      _self_netting =
        split_fixture!(payment, store,
          amount: 5_000,
          settlement_method: :internal_hold,
          status: :partially_reversed,
          reversed_amount: 2_000
        )

      {:ok, {splits, total}} =
        Emakola.Repo.transaction(fn ->
          Emakola.Payments.RefundLiability.outstanding_for_recipient!(store.id)
        end)

      assert total == 3_000
      assert length(splits) >= 1
    end

    test "a recipient with no liabilities owes zero" do
      store = create_store!(name: "Clean Store")

      {:ok, {splits, total}} =
        Emakola.Repo.transaction(fn ->
          Emakola.Payments.RefundLiability.outstanding_for_recipient!(store.id)
        end)

      assert splits == []
      assert total == 0
    end
  end
```

`split_fixture!/3` does not exist — add it as a file-local `defp` in the test module,
built the same inline way the file's other describes build splits (all required
`PaymentSplit` :create attrs plus the overrides above; check the resource's `:create`
accept list and the file's existing fixtures for the exact required keys —
`store_id`, `payment_id`, `role: :merchant`, `recipient_store_id: store.id` at minimum).
If the `:create` action rejects claim-state attrs like `paid_out_at`/`netted_reversal_amount`
(likely — they are claim-lifecycle fields), write them the way the no-double-claw test
does: create the split, then drive it through `mark_settled`/`record_reversal`/
`mark_paid_out` actions to reach the target state. Copy that file's idiom
(`test/emakola/payments/refund_liability_no_double_claw_test.exs`) rather than
force-writing attributes.

- [ ] **Step 2: Run it to make sure it fails**

Run: `mix test test/emakola/payments/refund_liability_test.exs`
Expected: FAIL — `outstanding_for_recipient!/1 is undefined`.

- [ ] **Step 3: Implement**

In `lib/emakola/payments/refund_liability.ex`, extract the outstanding computation that
`reserve_from_liabilities/4` inlines, and add the public function:

```elixir
  @doc """
  FOR-UPDATE-locks the recipient's recoverable splits and returns
  `{locked_splits, total_outstanding}`. Must run inside a transaction — the
  caller (charge-time reserve or payout-time netting) holds the lock until
  its own bookkeeping commits, which is what makes double-recovery across
  the two sites impossible.
  """
  def outstanding_for_recipient!(recipient_store_id) do
    liabilities =
      PaymentSplit
      |> Ash.Query.for_read(:recoverable_by_recipient, %{
        recipient_store_id: recipient_store_id
      })
      |> Ash.Query.lock("FOR UPDATE")
      |> Ash.read!(authorize?: false)

    {liabilities, liabilities |> Enum.map(&outstanding/1) |> Enum.sum()}
  end

  defp outstanding(liability) do
    max(
      liability.reversed_amount - effective_netted(liability) - liability.recovered_amount -
        liability.reserved_recovery_amount,
      0
    )
  end
```

Refactor `reserve_from_liabilities/4`'s inline computation to call `outstanding/1`
(behaviour-identical: it already applies `max(outstanding, 0)` via
`min(max(outstanding, 0), available)`).

- [ ] **Step 4: Run the module's tests**

Run: `mix test test/emakola/payments/refund_liability_test.exs test/emakola/payments/refund_liability_no_double_claw_test.exs`
Expected: PASS (new describe green; refactor changes no behaviour).

- [ ] **Step 5: Commit**

```bash
mix format && git add lib/emakola/payments/refund_liability.ex test/emakola/payments/
git commit -m "feat(payments): P2a — expose a recipient's outstanding refund liability"
```

---

### Task 2: Payout-time netting in `prepare_internal_payout/1`

**Files:**
- Modify: `lib/emakola/payments/payout_service.ex:131-185` (`prepare_internal_payout/1`)
- Modify: `lib/emakola/payments/refund_liability.ex` (add `collect_at_payout!/3`)
- Test: `test/emakola/payments/internal_payout_service_test.exs`

**Interfaces:**
- Consumes: `outstanding_for_recipient!/1` from Task 1.
- Produces: `RefundLiability.collect_at_payout!(liabilities, deduction, payout_id) :: :ok`
  — books `deduction` across the (already-locked) liabilities in `id` order:
  per split, `applied = min(outstanding(split), remaining)`; bumps `recovered_amount`
  by `applied` and appends `%{"payout_id" => payout_id, "amount" => applied}` to
  `recovery_breakdown["payout_recoveries"]` via the module's `update_tracking!/2`.
  And: `prepare_internal_payout/1` returns a Payout whose `amount` is
  `Σ frozen_paid_amount − deduction`, rolling back `:nothing_outstanding` when the
  deduction consumes everything.

- [ ] **Step 1: Write the failing tests**

Append to `test/emakola/payments/internal_payout_service_test.exs` (crib recipient/split
setup from its existing describes — it already builds payable `internal_hold` splits and
a MoMo transfer destination; reuse those helpers verbatim):

```elixir
  describe "payout-time liability netting (P2a)" do
    test "outstanding liability is deducted from the payout and booked on the source splits" do
      # Setup A: a recipient with 10_000 payable (fresh settled internal split)
      # and 3_000 outstanding liability (an older claimed split, fully claimed
      # at frozen value, then reversed 3_000 after claim). Build the liability
      # via the action path: create → mark_settled → mark_paid_out(payout) →
      # record_reversal(3_000) — same idiom as refund_liability_no_double_claw_test.

      # (setup produces: store, payable_split amount: 10_000, owing_split as above)

      assert {:ok, payout} = PayoutService.prepare_internal_payout(store.id)

      # 10_000 earned − 3_000 owed = 7_000 transferred.
      assert payout.amount == 7_000

      # The claimed split keeps its frozen paid_amount — the deduction is NOT
      # hidden inside the claim value.
      claimed = reload_split!(payable_split)
      assert claimed.paid_amount == 10_000

      # The debt is booked on the SOURCE liability with payout provenance.
      owing = reload_split!(owing_split)
      assert owing.recovered_amount == 3_000
      assert [%{"payout_id" => pid, "amount" => 3_000}] =
               owing.recovery_breakdown["payout_recoveries"]
      assert pid == payout.id

      # And the liability is extinguished: a second payout with new earnings
      # deducts nothing.
    end

    test "a payout fully consumed by debt is not created" do
      # Setup B: payable 2_000, outstanding 5_000 → deduction consumes all.
      assert {:error, :nothing_outstanding} = PayoutService.prepare_internal_payout(store.id)

      # No splits were claimed — the earnings stay payable (they'll be
      # consumed by charge-time recovery or a later, larger payout).
      assert reload_split!(payable_split).paid_out_at == nil
      # Partial recovery DID happen: the withheld 2_000 reduced the debt.
      assert reload_split!(owing_split).recovered_amount == 2_000
    end

    test "a recipient with no liability pays out gross, byte-identical to before" do
      # Setup C: payable 10_000, no liabilities → amount == 10_000, no
      # payout_recoveries stamped anywhere.
      assert {:ok, payout} = PayoutService.prepare_internal_payout(store.id)
      assert payout.amount == 10_000
    end
  end
```

Write the setups concretely from the file's existing helpers; `reload_split!/1` =
`Ash.get!(Emakola.Payments.PaymentSplit, split.id, authorize?: false)` (add as a local
helper if the file lacks one). Decide test-by-test expectations EXACTLY as written —
they are the contract.

Design note for the fully-consumed case (test 2): the claim is abandoned (rollback) but
the recovery booking must still commit — so the deduction bookkeeping happens in a
SEPARATE transaction BEFORE the claim transaction (see Step 3's structure). The withheld
recovery is real money the platform keeps either way; abandoning the claim must not
abandon the debt collection.

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/payments/internal_payout_service_test.exs`
Expected: the three new tests FAIL (no netting exists); "CONTRACT 1" tests still pass.

- [ ] **Step 3: Implement**

Add to `lib/emakola/payments/refund_liability.ex` (public, transaction-required, mirrors
`collect` semantics of `reserve_from_liabilities` but books recovery directly —
the money is certain, it is being withheld from a payout in-flight):

```elixir
  @doc """
  Books `deduction` of payout-withheld recovery across `liabilities` (already
  FOR-UPDATE-locked by `outstanding_for_recipient!/1`) in `id` order, with
  payout provenance. Called inside the payout's own transaction.
  """
  def collect_at_payout!(_liabilities, 0, _payout_ref), do: :ok

  def collect_at_payout!(liabilities, deduction, payout_ref) do
    liabilities
    |> Enum.sort_by(& &1.id)
    |> Enum.reduce(deduction, fn
      _liability, 0 ->
        0

      liability, remaining ->
        applied = min(outstanding(liability), remaining)

        if applied > 0 do
          recoveries = Map.get(liability.recovery_breakdown, "payout_recoveries", [])

          update_tracking!(liability, %{
            recovered_amount: liability.recovered_amount + applied,
            recovery_breakdown:
              Map.put(
                liability.recovery_breakdown,
                "payout_recoveries",
                recoveries ++ [%{"payout_ref" => payout_ref, "amount" => applied}]
              )
          })
        end

        remaining - applied
    end)

    :ok
  end
```

(If `update_tracking!/2` does not accept `recovery_breakdown`, extend it the way it
already accepts `reserved_recovery_amount` — check its definition and the PaymentSplit
action it drives; the no-double-claw test exercises this path.)

Rework `prepare_internal_payout/1` in `payout_service.ex` to two phases:

```elixir
  def prepare_internal_payout(recipient_store_id) do
    with {:ok, _dest} <- transfer_destination(recipient_store_id) do
      # Phase 1 — collect the debt. Separate transaction: the collection must
      # survive even when the claim below aborts (fully-consumed payout), and
      # the FOR UPDATE inside outstanding_for_recipient!/1 serializes against
      # charge-time reserve!/1 so the two sites can never double-collect.
      {:ok, deduction} =
        Emakola.Repo.transaction(fn ->
          {liabilities, outstanding} =
            RefundLiability.outstanding_for_recipient!(recipient_store_id)

          gross = payable_gross(recipient_store_id)
          deduction = min(gross, outstanding)
          :ok = RefundLiability.collect_at_payout!(liabilities, deduction, recipient_store_id)
          deduction
        end)

      # Phase 2 — the claim, exactly as before, minus the deduction.
      ...existing transaction, with two changes:
        amount = Σ frozen_paid_amount − deduction
        if amount <= 0, do: Emakola.Repo.rollback(:nothing_outstanding)
    end
  end

  # Gross payable WITHOUT locking (Phase 1 sizing only; Phase 2 re-reads under
  # its own FOR UPDATE and the final amount uses Phase 2's Σ).
  defp payable_gross(recipient_store_id) do
    Emakola.Payments.PaymentSplit
    |> Ash.Query.for_read(:payable_internal, %{recipient_store_id: recipient_store_id})
    |> Ash.read!(authorize?: false)
    |> Enum.map(&Emakola.Payments.PaymentSplit.frozen_paid_amount/1)
    |> Enum.sum()
  end
```

Two-phase subtlety the implementer must preserve: Phase 2's final `amount` is
`Σ frozen (from ITS locked read) − deduction`; if the payable set shrank between phases
(concurrent claim), amount may go ≤ 0 → rollback — the collected debt stays collected,
which is correct (debt collection is never conditional on this payout existing). Replace
`payout_ref` with the real `payout.id` where Phase 2 creates the Payout? NO — the payout
does not exist in Phase 1; stamp `payout_ref = recipient_store_id`-scoped reference:
generate `reference = "po_" <> Ecto.UUID.generate()` BEFORE Phase 1, pass it as
`payout_ref`, and reuse the same string as the Payout's `transfer_reference` in Phase 2 —
provenance then links breakdown → payout via `transfer_reference`. Update the Task 2
Step 1 test assertion accordingly: match on `%{"payout_ref" => ref}` and
`assert ref == payout.transfer_reference`.

- [ ] **Step 4: Run the file's suite**

Run: `mix test test/emakola/payments/internal_payout_service_test.exs test/emakola/payments/refund_liability_test.exs test/emakola/payments/refund_liability_no_double_claw_test.exs test/emakola/payments/internal_payout_webhook_test.exs`
Expected: new tests PASS. "CONTRACT 1" (`Payout.amount == Σ frozen paid_amounts`) now
FAILS BY DESIGN for netted cases — update that test's assertion to the new contract
(`Σ frozen − deduction`, with the no-liability case still equal to Σ frozen) and retitle
it "CONTRACT 1 (P2a): payout amount is Σ frozen paid_amounts minus liability deduction".
If `internal_payout_webhook_test.exs` or `release_payout_balance` assert the old
equality anywhere, apply the same contract update — report anything that resists as a
finding rather than bodging.

- [ ] **Step 5: Commit**

```bash
mix format && git add lib/emakola/payments/ test/emakola/payments/
git commit -m "feat(payments): P2a — debts settle before any new payout"
```

---

### Task 3: The unreclaimable-release path drains automatically

**Files:**
- Modify: `lib/emakola/payments/resources/payment_split.ex:509-524` (comment only)
- Test: `test/emakola/payments/internal_payout_service_test.exs` (append one E2E test)

**Interfaces:**
- Consumes: Tasks 1–2. No new interfaces produced — this task PROVES the mechanism
  closes the "decision pending" hole and updates the code's own claim about it.

- [ ] **Step 1: Write the E2E test (expected to pass — it verifies, not drives)**

```elixir
  describe "unreclaimable release drains via payout netting (P2a)" do
    test "a split fully reversed while claimed is recovered by the next payout" do
      # 1. Recipient earns: split A (10_000) settles payable.
      # 2. Payout 1 claims A (paid_amount 10_000, netted fence 0).
      # 3. Full reversal lands on A (refund after payout) → reversed 10_000.
      # 4. Payout 1 FAILS pre-webhook → mark_failed → release_payout_balance →
      #    release_from_payout: A exits payable (amount ≤ reversed), stamped
      #    recovery_breakdown["unreclaimable_release"] == true, netted reset to
      #    recovered+reserved. A's outstanding = 10_000.
      # 5. Recipient earns again: split B (6_000) settles payable.
      # 6. prepare_internal_payout → {:error, :nothing_outstanding}: the 6_000
      #    is fully consumed by the 10_000 debt; A.recovered_amount == 6_000.
      # 7. Recipient earns split C (5_000): next payout nets the remaining
      #    4_000 → payout.amount == 1_000; A.recovered_amount == 10_000;
      #    needs_remediation still lists A (the stamp is historical) but its
      #    outstanding is now 0.
      #
      # Build steps 1-5 through the real actions (create/mark_settled/
      # prepare_internal_payout/record_reversal/mark_failed) — NOT by writing
      # attributes — mirroring refund_liability_no_double_claw_test's idiom
      # and payout_worker_test's mark_failed usage.
    end
  end
```

The numbered comments are the test body's contract — implement each as code with the
exact amounts shown, asserting at steps 6 and 7.

- [ ] **Step 2: Run it**

Run: `mix test test/emakola/payments/internal_payout_service_test.exs`
Expected: PASS with Tasks 1–2 in place. If it fails, the mechanism has a real hole —
report the failing step number as a finding; do not adjust the amounts to force green.

- [ ] **Step 3: Retire the "decision pending" comment**

In `payment_split.ex`'s `release_from_payout`, replace the stamp's comment:

```elixir
        # An unreclaimable split (fully reversed while claimed) exits the
        # payable population forever; its outstanding liability is collected
        # automatically by payout-time netting (RefundLiability.collect_at_payout!,
        # P2a) and by charge-time reserve!. The stamp remains as finance's
        # audit trail of the event — needs_remediation is a historical record,
        # not a to-do list.
```

Also update the `needs_remediation` read's comment ("finance's manual-remediation
worklist" → "finance's audit trail of unreclaimable releases; recovery is automatic
since P2a").

- [ ] **Step 4: Verify and commit**

Run: `mix test test/emakola/payments && mix compile --warnings-as-errors`
Expected: all green.

```bash
mix format && git add lib/emakola/payments/resources/payment_split.ex test/emakola/payments/
git commit -m "test(payments): P2a — unreclaimable releases drain automatically; retire the decision-pending comment"
```

---

### Task 4: Full verification and PR

**Files:** none new.

- [ ] **Step 1: mix precommit**

Run: `mix precommit` (full gate, ~6–8 min). Expected: green. Failures outside
`test/emakola/payments` that assert the old payout contract get the Task 2 Step 4
treatment; anything else is a reported finding.

- [ ] **Step 2: Commit any stragglers, push, PR**

```bash
git push -u origin feature/single-rail-settlement-p2a
gh pr create --base main \
  --title "Single-rail settlement P2a — debts settle before any new payout" \
  --body "Implements the payout-half of spec §3.2 (docs/superpowers/specs/2026-08-07-single-rail-settlement-design.md): a recipient's outstanding refund liability is deducted inside prepare_internal_payout's own transaction and booked on the source splits with payout provenance. Deliberate contract change: Payout.amount = Σ frozen paid_amounts − liability deduction (CONTRACT 1 test updated). The fully-reversed-while-claimed release path — previously a 'decision pending' manual worklist — now drains automatically (E2E-tested); needs_remediation becomes an audit trail. Charge-time recovery (reserve!) unchanged; both collection sites serialize on the same FOR-UPDATE population, so double-collection is structurally impossible. Rows-for-holds is P2b; the one-formula collapse and gateway deletion remain P3."
```

---

## Self-review (done at write time)

- **Spec coverage:** §3.2's payout-half fully covered (Tasks 1–2); the unresolved
  claimed-then-reversed case closed and proven (Task 3); §3.2's charge-time half already
  existed (reserve!) and is constraint-frozen. §3.3 explicitly deferred to P2b with
  reasons recorded in the header.
- **Placeholders:** Task 3 Step 1's numbered-comment contract carries exact amounts and
  action names; Task 1's fixture instruction names the exact donor file for the idiom.
  Task 2 Step 3's `...existing transaction` elision names the two exact changes made to
  it. No TBDs.
- **Type consistency:** `outstanding_for_recipient!/1` returns `{splits, total}` and is
  consumed as such in Task 2; `collect_at_payout!/3`'s `payout_ref` is the
  `transfer_reference` string in both the implementation note and the (corrected) test
  assertion; `outstanding/1` is shared by both call sites.
