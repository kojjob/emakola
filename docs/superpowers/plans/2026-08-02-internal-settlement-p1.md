# Internal Settlement Phase 1 — Ledger Vocabulary + Transactional Recording

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `PaymentSplit` the vocabulary of a payable internal ledger (settlement method, currency, claim state, no-double-claw fence), make payment+splits recording transactional at both charge sites, and build the dark internal allocation builders — with zero checkout behavior change.

**Architecture:** Additive-only base PR of the "one ledger, two rails" stack (spec: `docs/superpowers/specs/2026-08-02-internal-settlement-design.md`). Everything ships dark: new columns default to today's semantics, new actions/readers have no callers in prod paths, and the two charge sites are refactored behavior-preservingly onto a transactional `persist_payment/2`.

**Tech Stack:** Elixir/Ash 3.x resources, AshPostgres, hand-written Ecto migrations, ExUnit + `Emakola.DataCase` + `Emakola.Factory`.

## Global Constraints

- Work in the worktree `/Users/kojo/Projects/emakola/.claude/worktrees/internal-settlement` on branch `worktree-internal-settlement` (based on `origin/main`). All paths below are relative to the worktree root.
- All money is integer minor units (pesewas). Never floats.
- TDD mandatory: failing test first, minimal implementation, then commit. `mix format` + `mix credo --strict` clean before every commit; `touch` edited files before trusting `mix compile --warnings-as-errors` (incremental compile hides warnings).
- Migrations are HAND-WRITTEN (`mix ash.codegen` is broken repo-wide — missing snapshots). Follow the style of `priv/repo/migrations/20260715114500_add_payment_split_unique_allocation.exs`.
- Ash mutations from system code use `authorize?: false`. Tests: `use Emakola.DataCase, async: true` + `import Emakola.Factory` (`create_store!/1`, `create_payment!/2`).
- These existing suites must stay green UNTOUCHED (they prove the legacy definitions didn't move): `payment_split_test.exs`, `payment_split_integrity_test.exs`, `payment_split_settlement_test.exs`, `refund_liability_test.exs`, `order_settlement_test.exs`, `outstanding_payments_test.exs`, `payout_service_test.exs`.
- Zero checkout behavior change in this phase. `OrderSettlement.prepare/2` routing is NOT touched (that's Phase 3).

---

### Task 1: Migrations — ledger columns on three tables

**Files:**
- Create: `priv/repo/migrations/20260802120000_add_payment_split_internal_ledger_columns.exs`
- Create: `priv/repo/migrations/20260802120100_add_payout_basis_and_supplier_ledger_settlement_source.exs`

**Interfaces:**
- Produces: columns `payment_splits.settlement_method/currency/paid_out_at/payout_id/paid_amount/netted_reversal_amount`, `payouts.basis`, `supplier_ledger_entries.settlement_source/payment_split_id` — consumed by Tasks 2–5 (resource attributes) and Phase 2.

- [ ] **Step 1: One-time worktree setup**

Run: `mix deps.get && mix compile`
Expected: compiles clean (fresh worktree has no `_build`).

- [ ] **Step 2: Write the payment_splits migration**

```elixir
defmodule Emakola.Repo.Migrations.AddPaymentSplitInternalLedgerColumns do
  @moduledoc """
  Internal-rail ledger vocabulary on payment_splits ("one ledger, two rails",
  spec 2026-08-02):

  * settlement_method — :gateway_share (Paystack routed it at charge) vs
    :internal_hold (money stays in the platform account, owed via the ledger).
    Backfill: every historical row with a NULL subaccount_code is a :platform
    row, whose cut always stays in the main account — internal_hold.
  * currency — payouts partition by currency; Payment has it, splits did not.
  * paid_out_at / payout_id — the claim stamp, mirroring Payment's pair.
  * paid_amount — net frozen at claim time (amount - reversed_amount then).
  * netted_reversal_amount — the no-double-claw fence: reversals already
    netted into a claim must not also be recovered from future earnings.

  Hand-written: mix ash.codegen is unusable in this repo (missing snapshots).
  """
  use Ecto.Migration

  def up do
    alter table(:payment_splits) do
      add(:settlement_method, :text, null: false, default: "gateway_share")
      add(:currency, :text, null: false, default: "GHS")
      add(:paid_out_at, :utc_datetime_usec)
      add(:payout_id, :uuid)
      add(:paid_amount, :bigint)
      add(:netted_reversal_amount, :bigint, null: false, default: 0)
    end

    execute("""
    UPDATE payment_splits SET settlement_method = 'internal_hold'
    WHERE subaccount_code IS NULL
    """)

    create(index(:payment_splits, [:recipient_store_id, :settlement_method, :paid_out_at]))
  end

  def down do
    drop(index(:payment_splits, [:recipient_store_id, :settlement_method, :paid_out_at]))

    alter table(:payment_splits) do
      remove(:settlement_method)
      remove(:currency)
      remove(:paid_out_at)
      remove(:payout_id)
      remove(:paid_amount)
      remove(:netted_reversal_amount)
    end
  end
end
```

- [ ] **Step 3: Write the payouts + supplier_ledger_entries migration**

```elixir
defmodule Emakola.Repo.Migrations.AddPayoutBasisAndSupplierLedgerSettlementSource do
  @moduledoc """
  Phase-1 schema for the Phase-2 internal payout engine (spec 2026-08-02):

  * payouts.basis — :payments (legacy: claims Payment rows) vs :allocations
    (internal: claims PaymentSplit rows). Default keeps every existing payout.
  * supplier_ledger_entries.settlement_source + payment_split_id — lets a
    wholesaler obligation be claimed by the platform settlement instead of
    the manual "mark paid" flow, so the same debt never exists twice.

  Hand-written: mix ash.codegen is unusable in this repo.
  """
  use Ecto.Migration

  def change do
    alter table(:payouts) do
      add(:basis, :text, null: false, default: "payments")
    end

    alter table(:supplier_ledger_entries) do
      add(:settlement_source, :text, null: false, default: "manual")
      add(:payment_split_id, :uuid)
    end
  end
end
```

- [ ] **Step 4: Run and verify both directions**

Run: `mix ecto.migrate && mix ecto.rollback -n 2 && mix ecto.migrate && MIX_ENV=test mix ecto.migrate`
Expected: both migrate cleanly, rollback drops cleanly, re-migrate succeeds, test DB updated.

- [ ] **Step 5: Full suite still green (columns are inert)**

Run: `mix test`
Expected: same pass count as bare `origin/main` (run once before Step 2 to record the baseline), 0 failures. Parse the `Result:` line — do NOT trust the exit code if piping.

- [ ] **Step 6: Commit**

```bash
git add priv/repo/migrations/
git commit -m "feat(payments): internal-ledger columns on payment_splits, payouts, supplier_ledger_entries"
```

---

### Task 2: PaymentSplit — ledger attributes

**Files:**
- Modify: `lib/emakola/payments/resources/payment_split.ex` (attributes block ends ~line 137; `:create` accept list at ~186-197)
- Create: `test/emakola/payments/payment_split_internal_ledger_test.exs`

**Interfaces:**
- Produces: `PaymentSplit.settlement_method :: :gateway_share | :internal_hold` (default `:gateway_share`), `currency :: String.t()` (default `"GHS"`), `paid_out_at :: DateTime.t() | nil`, `payout_id :: Ash.UUID.t() | nil`, `paid_amount :: integer() | nil`, `netted_reversal_amount :: integer()` (default 0). `:create` additionally accepts `settlement_method` and `currency`.

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Emakola.Payments.PaymentSplitInternalLedgerTest do
  @moduledoc """
  Internal-rail ledger vocabulary on PaymentSplit ("one ledger, two rails"):
  settlement method, currency, and the paid-out claim state.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.PaymentSplit

  setup do
    store = create_store!()
    payment = create_payment!(store)
    {:ok, store: store, payment: payment}
  end

  defp create_split!(store, payment, attrs) do
    params = Map.merge(%{store_id: store.id, payment_id: payment.id}, Map.new(attrs))

    PaymentSplit
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end

  describe "ledger attributes" do
    test "settlement_method defaults to :gateway_share and accepts :internal_hold", %{
      store: store,
      payment: payment
    } do
      default = create_split!(store, payment, %{role: :platform, amount: 840})
      assert default.settlement_method == :gateway_share

      internal =
        create_split!(store, payment, %{
          role: :merchant,
          recipient_store_id: store.id,
          amount: 41_160,
          settlement_method: :internal_hold,
          currency: "GHS"
        })

      assert internal.settlement_method == :internal_hold
      assert internal.currency == "GHS"
      assert is_nil(internal.paid_out_at)
      assert is_nil(internal.payout_id)
      assert is_nil(internal.paid_amount)
      assert internal.netted_reversal_amount == 0
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/payments/payment_split_internal_ledger_test.exs`
Expected: FAIL — `NoSuchInput` / unknown attribute `settlement_method`.

- [ ] **Step 3: Add the attributes and extend the accept list**

Insert before `timestamps()` in the `attributes do` block:

```elixir
    # Which rail settles this allocation: the gateway routed it at charge
    # (:gateway_share) or the money stays in the platform main account and is
    # owed via this ledger (:internal_hold). Platform rows are always
    # :internal_hold — their cut never leaves the main account on either rail.
    attribute :settlement_method, :atom do
      constraints(one_of: [:gateway_share, :internal_hold])
      default(:gateway_share)
      allow_nil?(false)
      public?(true)
    end

    attribute :currency, :string do
      allow_nil?(false)
      default("GHS")
      public?(true)
    end

    # Claim stamp for internal-rail payouts, mirroring Payment.paid_out_at /
    # payout_id. Nil until a payout claims this allocation.
    attribute :paid_out_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :payout_id, :uuid do
      public?(true)
    end

    # Net frozen at claim time (amount - reversed_amount then). What the payout
    # actually paid, immune to later reversals moving underneath it.
    attribute :paid_amount, :integer do
      public?(true)
    end

    # No-double-claw fence: reversals that were already netted into a claim
    # (payable = amount - reversed) must not ALSO be recovered from future
    # earnings. Frozen at claim, reset on release. Gateway splits keep 0.
    attribute :netted_reversal_amount, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end
```

In the `:create` action, append `:settlement_method` and `:currency` to `accept([...])` (after `:amount`).

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/emakola/payments/payment_split_internal_ledger_test.exs`
Expected: PASS.

- [ ] **Step 5: Guard suites + commit**

Run: `mix test test/emakola/payments/ && mix format && mix credo --strict`
Expected: all green.

```bash
git add lib/emakola/payments/resources/payment_split.ex test/emakola/payments/payment_split_internal_ledger_test.exs
git commit -m "feat(payments): PaymentSplit internal-ledger attributes"
```

---

### Task 3: PaymentSplit — `payable_internal` read

**Files:**
- Modify: `lib/emakola/payments/resources/payment_split.ex` (actions block, after `recoverable_by_recipient`)
- Modify: `lib/emakola/payments/payments.ex` (PaymentSplit resource block, ~line 29-35)
- Test: `test/emakola/payments/payment_split_internal_ledger_test.exs`

**Interfaces:**
- Produces: `read :payable_internal` with nilable arg `recipient_store_id`; domain define `Emakola.Payments.list_payable_internal_splits(recipient_store_id, opts)` → `{:ok, [%PaymentSplit{}]}`. Filter semantics (THE definition of internally-payable, the split-level sibling of `Payment.outstanding_for_payout`): `settlement_method == :internal_hold AND role != :platform AND status in [:settled, :partially_reversed] AND paid_out_at is nil AND amount > reversed_amount`, optionally scoped to a recipient store.

- [ ] **Step 1: Write the failing test** (append inside the module from Task 2)

```elixir
  defp settle!(split) do
    split
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)
  end

  defp payable_internal(recipient_store_id) do
    PaymentSplit
    |> Ash.Query.for_read(:payable_internal, %{recipient_store_id: recipient_store_id})
    |> Ash.read!(authorize?: false)
  end

  describe "payable_internal" do
    test "includes only settled, unclaimed, non-platform internal_hold rows", %{
      store: store,
      payment: payment
    } do
      wholesaler = create_store!(name: "Wholesaler Co")

      payable =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 41_160,
            settlement_method: :internal_hold
          })
        )

      # Each excluded for exactly one reason:
      _platform =
        settle!(
          create_split!(store, payment, %{
            role: :platform,
            amount: 840,
            settlement_method: :internal_hold
          })
        )

      _gateway =
        settle!(
          create_split!(store, payment, %{
            role: :wholesaler,
            recipient_store_id: wholesaler.id,
            supplier_id: Ash.UUID.generate(),
            subaccount_code: "ACCT_w",
            amount: 1_600,
            settlement_method: :gateway_share
          })
        )

      _pending =
        create_split!(store, payment, %{
          role: :dropshipper,
          recipient_store_id: store.id,
          amount: 2_000,
          settlement_method: :internal_hold
        })

      fully_reversed =
        settle!(
          create_split!(store, payment, %{
            role: :wholesaler,
            recipient_store_id: wholesaler.id,
            supplier_id: Ash.UUID.generate(),
            amount: 900,
            settlement_method: :internal_hold
          })
        )

      fully_reversed
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 900})
      |> Ash.update!(authorize?: false)

      assert [found] = payable_internal(nil)
      assert found.id == payable.id

      # Scoped to a recipient with nothing payable → empty.
      assert payable_internal(wholesaler.id) == []
      assert [%{id: _}] = payable_internal(store.id)
    end

    test "a partially reversed split stays payable for its net", %{
      store: store,
      payment: payment
    } do
      split =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 10_000,
            settlement_method: :internal_hold
          })
        )

      split
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 4_000})
      |> Ash.update!(authorize?: false)

      assert [found] = payable_internal(store.id)
      assert found.status == :partially_reversed
      assert found.amount - found.reversed_amount == 6_000
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/payments/payment_split_internal_ledger_test.exs`
Expected: FAIL — no read action `payable_internal`.

- [ ] **Step 3: Add the read action + domain define**

In `payment_split.ex` actions block (after `recoverable_by_recipient`):

```elixir
    # THE definition of internally-payable money — the split-level sibling of
    # Payment.outstanding_for_payout (which owns the legacy :none population;
    # the two can never overlap because a charge is entirely one split_mode).
    # Change it ONLY here.
    read :payable_internal do
      argument(:recipient_store_id, :uuid, allow_nil?: true)

      filter(
        expr(
          settlement_method == :internal_hold and role != :platform and
            status in [:settled, :partially_reversed] and is_nil(paid_out_at) and
            amount > reversed_amount and
            (is_nil(^arg(:recipient_store_id)) or
               recipient_store_id == ^arg(:recipient_store_id))
        )
      )

      prepare(build(sort: [inserted_at: :asc]))
    end
```

In `payments.ex`, inside the `resource Emakola.Payments.PaymentSplit do` block:

```elixir
      define(:list_payable_internal_splits,
        action: :payable_internal,
        args: [:recipient_store_id]
      )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/emakola/payments/payment_split_internal_ledger_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/payments/resources/payment_split.ex lib/emakola/payments/payments.ex test/emakola/payments/payment_split_internal_ledger_test.exs
git commit -m "feat(payments): payable_internal read — the internal-rail payable definition"
```

---

### Task 4: PaymentSplit — claim actions (`mark_paid_out`, `release_from_payout`, `by_payout`)

**Files:**
- Modify: `lib/emakola/payments/resources/payment_split.ex`
- Modify: `lib/emakola/payments/payments.ex`
- Test: `test/emakola/payments/payment_split_internal_ledger_test.exs`

**Interfaces:**
- Produces: `update :mark_paid_out` (accepts `payout_id`; freezes `paid_amount = amount - reversed_amount` and `netted_reversal_amount = reversed_amount`; refuses gateway splits, pending/fully-reversed splits, double claims), `update :release_from_payout` (nils claim fields, resets `netted_reversal_amount` to 0), `read :by_payout` (arg `payout_id`). Domain defines: `Emakola.Payments.mark_payment_split_paid_out(split, %{payout_id: id}, opts)`, `release_payment_split_from_payout(split, opts)`, `list_payment_splits_by_payout(payout_id, opts)`. Phase 2's `prepare_internal_payout` and webhook release path consume all three.

- [ ] **Step 1: Write the failing tests** (append to the same test module)

```elixir
  describe "mark_paid_out / release_from_payout" do
    test "claim freezes paid_amount and the netted fence; release resets them", %{
      store: store,
      payment: payment
    } do
      payout_id = Ash.UUID.generate()

      split =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 10_000,
            settlement_method: :internal_hold
          })
        )

      split
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 4_000})
      |> Ash.update!(authorize?: false)

      claimed =
        split
        |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
        |> Ash.update!(authorize?: false)

      assert claimed.payout_id == payout_id
      assert %DateTime{} = claimed.paid_out_at
      assert claimed.paid_amount == 6_000
      assert claimed.netted_reversal_amount == 4_000

      # Claimed → no longer payable.
      assert payable_internal(store.id) == []

      released =
        claimed
        |> Ash.Changeset.for_update(:release_from_payout, %{})
        |> Ash.update!(authorize?: false)

      assert is_nil(released.paid_out_at)
      assert is_nil(released.payout_id)
      assert is_nil(released.paid_amount)
      assert released.netted_reversal_amount == 0

      # Released → payable again, exactly once.
      assert [%{id: _}] = payable_internal(store.id)
    end

    test "refuses a gateway split, a pending split, and a double claim", %{
      store: store,
      payment: payment
    } do
      payout_id = Ash.UUID.generate()

      gateway =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            subaccount_code: "ACCT_m",
            amount: 1_000,
            settlement_method: :gateway_share
          })
        )

      assert {:error, %Ash.Error.Invalid{}} =
               gateway
               |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
               |> Ash.update(authorize?: false)

      pending =
        create_split!(store, payment, %{
          role: :merchant,
          recipient_store_id: store.id,
          amount: 1_000,
          settlement_method: :internal_hold
        })

      assert {:error, %Ash.Error.Invalid{}} =
               pending
               |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
               |> Ash.update(authorize?: false)

      claimed =
        settle!(
          create_split!(store, payment, %{
            role: :dropshipper,
            recipient_store_id: store.id,
            amount: 2_000,
            settlement_method: :internal_hold
          })
        )
        |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               claimed
               |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
               |> Ash.update(authorize?: false)
    end
  end

  describe "by_payout" do
    test "returns exactly the splits a payout claimed", %{store: store, payment: payment} do
      payout_id = Ash.UUID.generate()

      claimed =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 3_000,
            settlement_method: :internal_hold
          })
        )
        |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
        |> Ash.update!(authorize?: false)

      _other =
        settle!(
          create_split!(store, payment, %{
            role: :dropshipper,
            recipient_store_id: store.id,
            amount: 500,
            settlement_method: :internal_hold
          })
        )

      {:ok, found} = Emakola.Payments.list_payment_splits_by_payout(payout_id, authorize?: false)
      assert [%{id: id}] = found
      assert id == claimed.id
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola/payments/payment_split_internal_ledger_test.exs`
Expected: FAIL — no action `mark_paid_out`.

- [ ] **Step 3: Add the actions** (style matches `Payment.:mark_buyer_protection_hold`'s cond-validate)

```elixir
    # Claims an internal allocation into a payout. Freezes the net at claim
    # time (paid_amount) and fences already-netted reversals out of future
    # recovery (netted_reversal_amount) — see the no-double-claw invariant.
    update :mark_paid_out do
      require_atomic?(false)
      accept([:payout_id])

      validate(fn changeset, _context ->
        cond do
          changeset.data.settlement_method != :internal_hold ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :settlement_method,
               message: "only internal_hold allocations can be paid out via the ledger"
             )}

          changeset.data.status not in [:settled, :partially_reversed] ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :status,
               message: "only a settled allocation can be paid out"
             )}

          not is_nil(changeset.data.paid_out_at) ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :paid_out_at,
               message: "allocation is already claimed by a payout"
             )}

          true ->
            :ok
        end
      end)

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:paid_out_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(
          :paid_amount,
          changeset.data.amount - changeset.data.reversed_amount
        )
        |> Ash.Changeset.change_attribute(
          :netted_reversal_amount,
          changeset.data.reversed_amount
        )
      end)
    end

    # Un-claims after a failed/reversed transfer: nothing was paid, so the
    # netted fence resets and reversals net at source again.
    update :release_from_payout do
      require_atomic?(false)
      accept([])

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:paid_out_at, nil)
        |> Ash.Changeset.change_attribute(:payout_id, nil)
        |> Ash.Changeset.change_attribute(:paid_amount, nil)
        |> Ash.Changeset.change_attribute(:netted_reversal_amount, 0)
      end)
    end

    read :by_payout do
      argument(:payout_id, :uuid, allow_nil?: false)
      filter(expr(payout_id == ^arg(:payout_id)))
    end
```

Domain defines in `payments.ex` (same resource block as Task 3):

```elixir
      define(:mark_payment_split_paid_out, action: :mark_paid_out)
      define(:release_payment_split_from_payout, action: :release_from_payout)
      define(:list_payment_splits_by_payout, action: :by_payout, args: [:payout_id])
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/emakola/payments/payment_split_internal_ledger_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/payments/resources/payment_split.ex lib/emakola/payments/payments.ex test/emakola/payments/payment_split_internal_ledger_test.exs
git commit -m "feat(payments): PaymentSplit claim actions for internal payouts"
```

---

### Task 5: No-double-claw — the netted fence in recovery

**Files:**
- Modify: `lib/emakola/payments/resources/payment_split.ex` (`recoverable_by_recipient` filter, ~line 277-288)
- Modify: `lib/emakola/payments/refund_liability.ex` (`reserve_from_liabilities/4` outstanding math ~line 265-268; `add_to_platform/2` ~line 280-290)
- Create: `test/emakola/payments/refund_liability_no_double_claw_test.exs`

**Interfaces:**
- Consumes: `netted_reversal_amount` (Task 2), `mark_paid_out`/`release_from_payout` (Task 4).
- Produces: recoverable liability = `reversed_amount − netted_reversal_amount − recovered_amount − reserved_recovery_amount` (filter AND consumption math); `add_to_platform/2` synthesizes an internal-hold `:platform` allocation when none exists instead of silently dropping recovered money. Gateway splits (`netted == 0`) behave byte-identically to today — `refund_liability_test.exs` must stay green untouched.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Emakola.Payments.RefundLiabilityNoDoubleClawTest do
  @moduledoc """
  The no-double-claw invariant: an internal-rail reversal that was netted at
  claim time (payable = amount - reversed) must NOT also be recovered from the
  recipient's future earnings. netted_reversal_amount, frozen by mark_paid_out
  and reset by release_from_payout, is the fence.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.{PaymentSplit, RefundLiability}

  setup do
    store = create_store!()
    payment = create_payment!(store)
    {:ok, store: store, payment: payment}
  end

  defp create_split!(store, payment, attrs) do
    params = Map.merge(%{store_id: store.id, payment_id: payment.id}, Map.new(attrs))

    PaymentSplit
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end

  defp settled_internal!(store, payment, amount) do
    create_split!(store, payment, %{
      role: :merchant,
      recipient_store_id: store.id,
      amount: amount,
      settlement_method: :internal_hold
    })
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)
  end

  defp reverse!(split, amount) do
    split
    |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: amount})
    |> Ash.update!(authorize?: false)
  end

  defp reserve_for_new_earning(store, amount) do
    RefundLiability.reserve!([
      %{role: :merchant, recipient_store_id: store.id, amount: amount, subaccount_code: nil},
      %{role: :platform, recipient_store_id: nil, amount: 0, subaccount_code: nil}
    ])
  end

  test "a reversal netted at claim is NOT recovered from future earnings", %{
    store: store,
    payment: payment
  } do
    split = settled_internal!(store, payment, 10_000)
    split = reverse!(split, 4_000)

    # Claim nets the reversal into the payout (pays 6_000, fences 4_000).
    split
    |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
    |> Ash.update!(authorize?: false)

    adjusted = reserve_for_new_earning(store, 5_000)
    merchant = Enum.find(adjusted, &(&1.role == :merchant))

    # Nothing recoverable — the 4_000 was never paid to the merchant.
    assert merchant.amount == 5_000
    assert merchant.recovery_amount == 0
  end

  test "a reversal AFTER claim is recoverable only for the delta", %{
    store: store,
    payment: payment
  } do
    split = settled_internal!(store, payment, 10_000)
    split = reverse!(split, 4_000)

    split =
      split
      |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
      |> Ash.update!(authorize?: false)

    # Refund grows to 7_000 after the payout paid 6_000 → only 3_000 was
    # over-paid and is recoverable.
    reverse!(split, 7_000)

    adjusted = reserve_for_new_earning(store, 5_000)
    merchant = Enum.find(adjusted, &(&1.role == :merchant))

    assert merchant.recovery_amount == 3_000
    assert merchant.amount == 2_000
  end

  test "release_from_payout resets the fence — reversals net at source again", %{
    store: store,
    payment: payment
  } do
    split = settled_internal!(store, payment, 10_000)
    split = reverse!(split, 4_000)

    split =
      split
      |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
      |> Ash.update!(authorize?: false)

    split
    |> Ash.Changeset.for_update(:release_from_payout, %{})
    |> Ash.update!(authorize?: false)

    adjusted = reserve_for_new_earning(store, 5_000)
    merchant = Enum.find(adjusted, &(&1.role == :merchant))

    # Unclaimed again: the 4_000 nets at source (payable 6_000), not recovered.
    assert merchant.recovery_amount == 0
  end

  test "add_to_platform synthesizes a platform row instead of dropping money", %{
    store: store,
    payment: payment
  } do
    split = settled_internal!(store, payment, 10_000)
    split = reverse!(split, 4_000)

    split
    |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: Ash.UUID.generate()})
    |> Ash.update!(authorize?: false)

    # Post-payout the refund grows: 2_000 recoverable.
    reverse!(split, 6_000)

    # Allocation set WITHOUT a platform row.
    adjusted =
      RefundLiability.reserve!([
        %{role: :merchant, recipient_store_id: store.id, amount: 5_000, subaccount_code: nil}
      ])

    merchant = Enum.find(adjusted, &(&1.role == :merchant))
    platform = Enum.find(adjusted, &(&1.role == :platform))

    assert merchant.amount == 3_000
    assert platform.amount == 2_000
    assert platform.settlement_method == :internal_hold
    assert Enum.sum(Enum.map(adjusted, & &1.amount)) == 5_000
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola/payments/refund_liability_no_double_claw_test.exs`
Expected: first three FAIL (recovery ignores the fence — recovers 4_000); fourth FAILS (no platform row in result).

- [ ] **Step 3: Implement the fence + synthesis**

`payment_split.ex` — `recoverable_by_recipient` filter becomes:

```elixir
      filter(
        expr(
          recipient_store_id == ^arg(:recipient_store_id) and role != :platform and
            reversed_amount >
              netted_reversal_amount + recovered_amount + reserved_recovery_amount
        )
      )
```

`refund_liability.ex` — `reserve_from_liabilities/4` outstanding becomes:

```elixir
    outstanding =
      liability.reversed_amount - liability.netted_reversal_amount -
        liability.recovered_amount - liability.reserved_recovery_amount
```

`refund_liability.ex` — replace `add_to_platform/2`:

```elixir
  defp add_to_platform(allocations, 0), do: allocations

  defp add_to_platform(allocations, recovered_total) do
    if Enum.any?(allocations, &(&1.role == :platform)) do
      Enum.map(allocations, fn
        %{role: :platform} = allocation ->
          %{allocation | amount: allocation.amount + recovered_total}

        allocation ->
          allocation
      end)
    else
      # Recovered money must land somewhere in the same charge (the sum
      # invariant); with no platform row to absorb it, synthesize one rather
      # than silently dropping it.
      allocations ++
        [
          %{
            role: :platform,
            recipient_store_id: nil,
            subaccount_code: nil,
            amount: recovered_total,
            settlement_method: :internal_hold
          }
        ]
    end
  end
```

- [ ] **Step 4: Run new + guarded suites**

Run: `mix test test/emakola/payments/refund_liability_no_double_claw_test.exs test/emakola/payments/refund_liability_test.exs test/emakola/payments/payment_split_integrity_test.exs`
Expected: ALL PASS — the legacy suite green untouched proves gateway behavior is unchanged (`netted == 0` reduces to today's formula).

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/payments/resources/payment_split.ex lib/emakola/payments/refund_liability.ex test/emakola/payments/refund_liability_no_double_claw_test.exs
git commit -m "feat(payments): no-double-claw fence + platform-row synthesis in refund recovery"
```

---

### Task 6: `record_splits!` persists settlement_method + currency

**Files:**
- Modify: `lib/emakola/payments/order_settlement.ex` (`record_splits!/2`, ~line 158-188)
- Create: `test/emakola/payments/order_settlement_internal_test.exs`

**Interfaces:**
- Consumes: `:create` accepting `settlement_method`/`currency` (Task 2).
- Produces: `record_splits!/2` copies `alloc.settlement_method` (default `:gateway_share`) and stamps `payment.currency` onto every row. Tasks 8/10 and Phase 3 rely on internal allocations persisting their method.

- [ ] **Step 1: Write the failing test**

```elixir
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
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/payments/order_settlement_internal_test.exs`
Expected: FAIL — `settlement_method` is `:gateway_share` on the merchant row (not persisted) or currency mismatch.

Note: platform rows created WITHOUT an explicit method land as `:gateway_share` here; the migration's backfill semantic ("nil subaccount = internal_hold") applies to historical rows only. Builders tag every allocation explicitly from Task 10 on, so this default is only ever exercised by gateway-rail callers.

- [ ] **Step 3: Extend the create call in `record_splits!/2`**

In the `Emakola.Payments.create_payment_split!` params map, after `amount: alloc.amount,` add:

```elixir
          settlement_method: Map.get(alloc, :settlement_method, :gateway_share),
          currency: payment.currency,
```

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola/payments/order_settlement_internal_test.exs test/emakola/payments/order_settlement_test.exs`
Expected: PASS (legacy suite untouched and green).

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/payments/order_settlement.ex test/emakola/payments/order_settlement_internal_test.exs
git commit -m "feat(payments): record_splits! persists settlement_method and currency"
```

---

### Task 7: `persist_payment/2` — payment + splits in one transaction (+ `split_mode: :internal`)

**Files:**
- Modify: `lib/emakola/payments/resources/payment.ex` (`split_mode` one_of, ~line 93)
- Modify: `lib/emakola/payments/order_settlement.ex`
- Test: `test/emakola/payments/order_settlement_internal_test.exs`

**Interfaces:**
- Consumes: `record_splits!/2` (Task 6).
- Produces: `Payment.split_mode` accepts `:internal`; `OrderSettlement.persist_payment(payment_attrs :: map(), settlement) :: {:ok, %Payment{}} | {:error, term()}` where `settlement` is the full `prepare/2` return shape (`{:split, %{allocations: ...}}` records rows; `{:no_split, _}` / `{:hold, _}` record nothing). Task 8 adopts it at both charge sites.

**Failure-mode note for the implementer (do NOT "fix" this):** today a `record_splits!` raise after `create_payment` left an allocation-less payment behind; inside the transaction it now also rolls back the payment. A gateway charge without a local payment row is the pre-existing `create_payment`-failure mode (callers log and continue), and split-create raising is practically DB-level or the unique-allocation backstop under concurrent double-fire. Atomicity of the LEDGER is the invariant this phase buys; leave the trade as designed.

- [ ] **Step 1: Write the failing tests** (append to `order_settlement_internal_test.exs`)

```elixir
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola/payments/order_settlement_internal_test.exs`
Expected: FAIL — `persist_payment/2` undefined; the first test also exercises `:internal`, currently rejected by the `one_of`.

- [ ] **Step 3: Implement**

`payment.ex` — extend the `split_mode` constraint (keep the existing comment style):

```elixir
      constraints(one_of: [:none, :dropship_split, :platform_fee, :internal])
```

(Match the existing list order in the file; only ADD `:internal`. `split_mode` is a text column — no migration.)

`order_settlement.ex` — add below `record_splits!/2`:

```elixir
  @doc """
  Creates the payment and records its allocation rows in ONE transaction, so
  the ledger can never observe a payment without its splits (or vice versa).
  Split-less settlements (`{:no_split, _}`, `{:hold, _}`) just create the
  payment. Returns `{:ok, payment}` or `{:error, reason}`.
  """
  def persist_payment(payment_attrs, settlement) do
    Emakola.Repo.transaction(fn ->
      case Emakola.Payments.create_payment(payment_attrs, authorize?: false) do
        {:ok, payment} ->
          persist_allocations!(payment, settlement)
          payment

        {:error, reason} ->
          Emakola.Repo.rollback(reason)
      end
    end)
  end

  defp persist_allocations!(payment, {:split, %{allocations: allocations}}),
    do: record_splits!(payment, allocations)

  defp persist_allocations!(_payment, _settlement), do: :ok
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/emakola/payments/order_settlement_internal_test.exs test/emakola/payments/payment_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/payments/resources/payment.ex lib/emakola/payments/order_settlement.ex test/emakola/payments/order_settlement_internal_test.exs
git commit -m "feat(payments): transactional persist_payment/2 and :internal split mode"
```

---

### Task 8: Adopt `persist_payment/2` at both charge sites (behavior-preserving)

**Files:**
- Modify: `lib/emakola_web/live/storefront/checkout_live.ex` (the `Emakola.Payments.create_payment` block inside the initiate flow, ~line 530-560, and the `record_splits/2` private helpers ~line 636-640)
- Modify: `lib/emakola_web/live/storefront/pay_link_live.ex` (`initiate_payment/3` ~line 370-393, and `record_splits/2` helpers ~line 459-463)

**Interfaces:**
- Consumes: `OrderSettlement.persist_payment/2` (Task 7).
- Produces: both LiveViews create payment + splits through the domain, atomically. NO functional change — every existing checkout/pay-link test must pass untouched.

- [ ] **Step 1: Refactor CheckoutLive**

Replace the `case Emakola.Payments.create_payment(...)` block (keeping its exact params map, including the `Map.merge(..., payout_hold_attrs(settlement))` wrapper) with:

```elixir
        case Emakola.Payments.OrderSettlement.persist_payment(
               Map.merge(
                 %{
                   store_id: store.id,
                   order_id: order.id,
                   amount: order.total,
                   currency: store.currency || "GHS",
                   gateway: :paystack,
                   gateway_reference: reference,
                   metadata: %{payment_method: method},
                   split_mode: split_mode(settlement)
                 },
                 payout_hold_attrs(settlement)
               ),
               settlement
             ) do
          {:ok, _payment} ->
            :ok

          {:error, reason} ->
            require Logger

            Logger.error(
              "[Checkout] Failed to create payment record for order #{order.order_number}: #{inspect(reason)}"
            )
        end
```

(Copy the CURRENT params map from the file verbatim — the shape above is indicative; only the function call and the removal of the separate `record_splits(payment, settlement)` line are the change.) Then delete the now-unused `record_splits/2` private helper clauses in this module.

- [ ] **Step 2: Refactor PayLinkLive identically**

Same transformation in `initiate_payment/3` (params map stays byte-identical, `record_splits(payment, settlement)` call and the `record_splits/2` helper clauses removed). Keep `release_recovery_reservations/1` — the failure path still needs it.

- [ ] **Step 3: Compile clean + run the web suites**

Run: `touch lib/emakola_web/live/storefront/checkout_live.ex lib/emakola_web/live/storefront/pay_link_live.ex && mix compile --warnings-as-errors && mix test test/emakola_web/live/storefront/ test/emakola/payments/`
Expected: zero warnings (orphaned helpers removed), ALL PASS with no test edits.

- [ ] **Step 4: Commit**

```bash
git add lib/emakola_web/live/storefront/checkout_live.ex lib/emakola_web/live/storefront/pay_link_live.ex
git commit -m "refactor(web): charge sites persist payment + splits through one transaction"
```

---

### Task 9: `DropshipSettlement.prepare_internal/3` — subaccount-free dropship allocations

**Files:**
- Modify: `lib/emakola/payments/dropship_settlement.ex`
- Create: `test/emakola/payments/dropship_settlement_internal_test.exs`

**Interfaces:**
- Consumes: `SplitCalculator.calculate/2` (tolerates `subaccounts: %{}` / `dropshipper_subaccount: nil` — allocations come back with nil subaccounts).
- Produces: `prepare_internal(line_items, dropshipper_store_id, opts) :: {:split, %{total: integer, allocations: [map]}} | {:no_split, :no_dropship_items}` — same opts contract as `prepare/3` (`:fee_rate_bps` required, `:dispatch_fees` optional). Linked suppliers keep their wholesaler allocation with `recipient_store_id`; unlinked suppliers' cost+dispatch folds into the dropshipper allocation. Task 10 consumes this.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Emakola.Payments.DropshipSettlementInternalTest do
  @moduledoc """
  Internal-rail dropship allocations: same SplitCalculator math as the gateway
  rail, but no subaccount requirement. Linked wholesalers become payable ledger
  recipients; unlinked ones fold into the dropshipper (who still owes them
  manually via SupplierLedgerEntry).
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.DropshipSettlement

  # 1000 bps margin fee, same as the gateway-rail tests.
  @fee_rate_bps 1_000

  defp line_item(supplier_id, unit_price, cost_price, quantity) do
    %{supplier_id: supplier_id, unit_price: unit_price, cost_price: cost_price, quantity: quantity}
  end

  test "linked suppliers get recipient allocations; totals stay sum-exact" do
    dropshipper = create_store!()
    wholesaler_store = create_store!(name: "Wholesaler Co")

    supplier =
      create_supplier!(dropshipper, linked_store_id: wholesaler_store.id)

    {:split, %{total: total, allocations: allocations}} =
      DropshipSettlement.prepare_internal(
        [line_item(supplier.id, 5_000, 3_000, 2)],
        dropshipper.id,
        fee_rate_bps: @fee_rate_bps
      )

    assert total == 10_000
    assert Enum.sum(Enum.map(allocations, & &1.amount)) == total

    wholesaler = Enum.find(allocations, &(&1.role == :wholesaler))
    assert wholesaler.recipient_store_id == wholesaler_store.id
    assert wholesaler.amount == 6_000
    assert is_nil(wholesaler.subaccount_code)

    platform = Enum.find(allocations, &(&1.role == :platform))
    # 10% of the 4_000 margin.
    assert platform.amount == 400

    dropshipper_alloc = Enum.find(allocations, &(&1.role == :dropshipper))
    assert dropshipper_alloc.amount == 3_600
    assert dropshipper_alloc.recipient_store_id == dropshipper.id
  end

  test "an unlinked supplier's cost and dispatch fee fold into the dropshipper" do
    dropshipper = create_store!()
    unlinked = create_supplier!(dropshipper, linked_store_id: nil)

    {:split, %{total: total, allocations: allocations}} =
      DropshipSettlement.prepare_internal(
        [line_item(unlinked.id, 5_000, 3_000, 1)],
        dropshipper.id,
        fee_rate_bps: @fee_rate_bps,
        dispatch_fees: %{unlinked.id => 700}
      )

    # Retail 5_000 + dispatch 700.
    assert total == 5_700
    assert Enum.sum(Enum.map(allocations, & &1.amount)) == total

    refute Enum.any?(allocations, &(&1.role == :wholesaler))

    dropshipper_alloc = Enum.find(allocations, &(&1.role == :dropshipper))
    # Own margin net (1_800) + folded wholesaler cost (3_000) + dispatch (700).
    assert dropshipper_alloc.amount == 5_500

    platform = Enum.find(allocations, &(&1.role == :platform))
    assert platform.amount == 200
  end

  test "no dropship items falls through" do
    dropshipper = create_store!()

    assert {:no_split, :no_dropship_items} =
             DropshipSettlement.prepare_internal(
               [line_item(nil, 5_000, nil, 1)],
               dropshipper.id,
               fee_rate_bps: @fee_rate_bps
             )
  end
end
```

(`create_supplier!/2` is confirmed at `test/support/factory.ex:496`; it takes the owning store plus attrs incl. `linked_store_id`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola/payments/dropship_settlement_internal_test.exs`
Expected: FAIL — `prepare_internal/3` undefined.

- [ ] **Step 3: Implement**

Add to `dropship_settlement.ex`:

```elixir
  @doc """
  Internal-rail variant of `prepare/3`: same SplitCalculator math, NO
  subaccount requirement. Linked suppliers keep their wholesaler allocation
  (payable to their store via the ledger); unlinked suppliers' cost and
  dispatch fee fold into the dropshipper, who still owes them manually via
  SupplierLedgerEntry. Dark until Phase 3 routes fallbacks here.
  """
  def prepare_internal(line_items, dropshipper_store_id, opts) do
    fee_rate_bps = Keyword.fetch!(opts, :fee_rate_bps)
    dispatch_fees = Keyword.get(opts, :dispatch_fees, %{})

    supplier_ids =
      line_items |> Enum.map(& &1.supplier_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    if supplier_ids == [] do
      {:no_split, :no_dropship_items}
    else
      linked = resolve_linked(supplier_ids, dropshipper_store_id)

      %{total: total, allocations: allocations} =
        SplitCalculator.calculate(line_items,
          fee_rate_bps: fee_rate_bps,
          subaccounts: %{},
          dropshipper_subaccount: nil,
          dispatch_fees: dispatch_fees
        )

      {:split, %{total: total, allocations: internalize(allocations, linked, dropshipper_store_id)}}
    end
  end

  defp resolve_linked(supplier_ids, dropshipper_store_id) do
    Enum.reduce(supplier_ids, %{}, fn supplier_id, acc ->
      case Ash.get(Supplier, supplier_id, tenant: dropshipper_store_id, authorize?: false) do
        {:ok, %{linked_store_id: linked}} when not is_nil(linked) ->
          Map.put(acc, supplier_id, linked)

        _ ->
          acc
      end
    end)
  end

  # Linked wholesalers keep their allocation; unlinked ones fold into the
  # dropshipper so the money to pay them manually reaches the merchant.
  defp internalize(allocations, linked, dropshipper_store_id) do
    {folded, kept} =
      Enum.reduce(allocations, {0, []}, fn
        %{role: :wholesaler, supplier_id: sid} = alloc, {folded, acc} ->
          case Map.fetch(linked, sid) do
            {:ok, store_id} ->
              {folded, [Map.put(alloc, :recipient_store_id, store_id) | acc]}

            :error ->
              {folded + alloc.amount, acc}
          end

        %{role: :dropshipper} = alloc, {folded, acc} ->
          {folded, [Map.put(alloc, :recipient_store_id, dropshipper_store_id) | acc]}

        %{role: :platform} = alloc, {folded, acc} ->
          {folded, [Map.put(alloc, :recipient_store_id, nil) | acc]}
      end)

    kept
    |> Enum.reverse()
    |> Enum.map(fn
      %{role: :dropshipper} = alloc -> %{alloc | amount: alloc.amount + folded}
      alloc -> alloc
    end)
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/emakola/payments/dropship_settlement_internal_test.exs test/emakola/payments/dropship_settlement_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/payments/dropship_settlement.ex test/emakola/payments/dropship_settlement_internal_test.exs
git commit -m "feat(payments): subaccount-free internal dropship allocations"
```

---

### Task 10: `OrderSettlement.prepare_internal/2` — the dark internal builder

**Files:**
- Modify: `lib/emakola/payments/order_settlement.ex`
- Test: `test/emakola/payments/order_settlement_internal_test.exs`

**Interfaces:**
- Consumes: `DropshipSettlement.prepare_internal/3` (Task 9), `PlatformFee.calculate/2`, `PartnerCredit.carve_sales_proceeds/2`, `RefundLiability.reserve!/1`, `sum_matches_total?/2`, `adjust_dropshipper/2` — all existing.
- Produces: `prepare_internal(order_id, store_id) :: {:split, %{total, allocations, shares: [], mode: :internal}} | {:no_split, :allocation_sum_mismatch | :unrepresentable_split}` — every allocation tagged `settlement_method: :internal_hold`, `subaccount_code: nil`, a `:platform` row always present. Phase 3 wires `prepare/2`'s verification-failure fallbacks to this function; NOTHING calls it in this phase.

- [ ] **Step 1: Write the failing tests** (append to `order_settlement_internal_test.exs`). Orders with line items are built through the REAL checkout service — the exact pattern `order_settlement_test.exs:30-54` uses (product → variant → `CheckoutService.checkout!`); no `create_order!` shortcuts.

```elixir
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola/payments/order_settlement_internal_test.exs`
Expected: FAIL — `prepare_internal/2` undefined.

- [ ] **Step 3: Implement** (below `prepare/2` in `order_settlement.ex`)

```elixir
  @doc """
  Internal-rail settlement for a charge that cannot be split at the gateway
  (unverified parties, unlinked suppliers). Same allocation math and fee rates
  as the gateway rail; every allocation is tagged `settlement_method:
  :internal_hold` with no subaccount, and a `:platform` row is always present.
  Returns `shares: []` — nothing is attached to the gateway charge. Dark until
  Phase 3 routes `prepare/2`'s verification-failure fallbacks here.
  """
  def prepare_internal(order_id, store_id) do
    order = Ash.get!(Emakola.Orders.Order, order_id, authorize?: false, tenant: store_id)
    line_items = load_line_items(order_id, store_id)
    dispatch_fees = load_dispatch_fees(order_id)

    case DropshipSettlement.prepare_internal(line_items, store_id,
           fee_rate_bps: fee_rate_bps(),
           dispatch_fees: dispatch_fees
         ) do
      {:split, %{allocations: allocations}} ->
        # Same delivery-fee fold as the gateway dropship rail.
        adjustment = (order.delivery_fee || 0) - (order.discount_amount || 0)
        finalize_internal(order, store_id, adjust_dropshipper(allocations, adjustment))

      {:no_split, :no_dropship_items} ->
        %{fee: fee, net: net} = PlatformFee.calculate(order.total, platform_fee_rate_bps())

        finalize_internal(order, store_id, [
          %{role: :merchant, recipient_store_id: store_id, amount: net, subaccount_code: nil},
          %{role: :platform, recipient_store_id: nil, amount: fee, subaccount_code: nil}
        ])
    end
  end

  defp finalize_internal(order, store_id, allocations) do
    allocations =
      allocations
      |> Emakola.Suppliers.PartnerCredit.carve_sales_proceeds(store_id)
      |> RefundLiability.reserve!()
      |> Enum.map(&internal_hold/1)

    cond do
      not sum_matches_total?(order, allocations) ->
        {:no_split, :allocation_sum_mismatch}

      # An aggressive discount can drive a non-platform allocation negative;
      # the payable ledger must stay non-negative (mirror of valid_shares?).
      Enum.any?(allocations, &(&1.role != :platform and &1.amount < 0)) ->
        {:no_split, :unrepresentable_split}

      true ->
        {:split, %{total: order.total, allocations: allocations, shares: [], mode: :internal}}
    end
  end

  # The internal rail holds everything in the platform account: no allocation
  # carries a subaccount (this also overrides the partner-credit carve, which
  # sets the creditor's subaccount unconditionally).
  defp internal_hold(alloc) do
    Map.merge(alloc, %{settlement_method: :internal_hold, subaccount_code: nil})
  end
```

- [ ] **Step 4: Run tests + full payments suite**

Run: `mix test test/emakola/payments/`
Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/payments/order_settlement.ex test/emakola/payments/order_settlement_internal_test.exs
git commit -m "feat(payments): dark internal settlement builder with gateway-rail fee parity"
```

---

### Task 11: Phase gate — full verification

**Files:** none (verification only)

- [ ] **Step 1: Full suite, formatted, credo**

Run: `mix test && mix format --check-formatted && mix credo --strict`
Expected: 0 failures (parse the `Result:` line), no formatting drift, credo clean.

- [ ] **Step 2: Guarded-suite proof**

Run: `git diff origin/main --stat -- test/emakola/payments/payment_split_test.exs test/emakola/payments/payment_split_integrity_test.exs test/emakola/payments/payment_split_settlement_test.exs test/emakola/payments/refund_liability_test.exs test/emakola/payments/order_settlement_test.exs test/emakola/payments/outstanding_payments_test.exs test/emakola/payments/payout_service_test.exs`
Expected: EMPTY — the legacy money suites were not edited; their green runs prove legacy semantics didn't move.

- [ ] **Step 3: Push and open the stacked-base PR**

```bash
git push -u origin worktree-internal-settlement
```

PR targets `main`, title `feat(payments): internal settlement P1 — ledger vocabulary + transactional recording`. Body: link the spec (`docs/superpowers/specs/2026-08-02-internal-settlement-design.md`), note "ships dark — zero checkout behavior change", list the six invariant tests. Phases 2/3 stack on this branch.
