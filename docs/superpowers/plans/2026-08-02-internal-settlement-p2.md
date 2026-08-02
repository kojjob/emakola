# Internal Settlement Phase 2 — Internal Payout Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make internal-rail balances actually payable: allocation-basis payouts that claim `payable_internal` splits under FOR UPDATE, webhook release wiring for failed/reversed transfers, supplier-obligation unification, and honest FinanceStats — payable population stays zero until Phase 3 flips checkout.

**Architecture:** Stacks on branch `worktree-internal-settlement` (P1, PR #372). Mirrors the legacy payment-basis payout engine exactly — same destination-first validation, same one-transaction FOR-UPDATE serialization point, same reference-keyed webhook finalization — but claims `PaymentSplit` rows, partitioned by `Payout.basis`.

**Tech Stack:** Elixir/Ash 3.x, AshPostgres, Oban (`PayoutWorker`), Paystack transfers via existing Gateway behaviour, ExUnit + `Emakola.DataCase` + `Emakola.Factory`.

## Global Constraints (BINDING)

- Worktree `/Users/kojo/Projects/emakola/.claude/worktrees/internal-settlement`, branch `worktree-internal-settlement`. All money integer minor units. TDD (RED+GREEN evidence in reports). `mix format` + `mix credo --strict` clean per commit; parse `mix test`'s final `Result:` line (exit codes lie when piping).
- **CONTRACT 1:** payouts transfer `PaymentSplit.paid_amount` as frozen by `mark_paid_out` — NEVER recompute `amount − reversed_amount`. Payout.amount = Σ frozen `paid_amount`s.
- **CONTRACT 4:** claim/release only freshly-read rows: `prepare_internal_payout` reads under `Ash.Query.lock("FOR UPDATE")` inside one `Repo.transaction`; the webhook release path re-reads via `by_payout` (never stale structs).
- **CONTRACT 2** is scoped in Task 4 (guard + decision surface — see the ⚠️ KOJO-DECISION marker).
- Legacy suites green UNTOUCHED: `payout_service_test.exs`, `payout_test.exs`, `paystack_webhook_handler_test.exs`, `finance_stats_test.exs`, plus the seven P1-guarded money suites.
- Zero live-population change (nothing creates `:internal` payments until P3). Manual staff approval only — NO scheduler/cron (Kojo's decision).
- The formula `amount − (reversed_amount − recovered_amount − reserved_recovery_amount)` is what `mark_paid_out` freezes as `paid_amount`; every display/sum of "payable" MUST use it via ONE helper (single authority, spec §4.5) — never inline variants.

## Verified code facts (P1 branch)

- `Payout` (lib/emakola/payments/resources/payout.ex): NO `basis` attribute yet (DB column exists, default 'payments'); `create :create` accepts `[:store_id, :amount, :currency, :transfer_reference, :metadata]` (~line 112); transitions `mark_processing` (pending→, accepts recipient_code/transfer_code), `mark_paid` (pending/processing→, accepts gateway_response), `mark_failed` (accepts failure_reason/gateway_response), `mark_reversed` (the one path out of :paid). Multitenancy `store_id`.
- `PayoutService.prepare_payout/1` (payout_service.ex:56-102): `transfer_destination(store_id)` first; then `Repo.transaction`: `outstanding_for_payout` read + `Ash.Query.lock("FOR UPDATE")`, currency = first payment's (filter claimed to it), `Repo.rollback(:nothing_outstanding)` when empty, `amount = Σ (payable_amount || amount)`, `reference = "po_" <> Ecto.UUID.generate()`, `Payments.create_payout`, then `mark_payment_paid_out` each. `transfer_destination/1` (:23-39) → `{:ok, %{type: "mobile_money", name, account_number, bank_code, currency: "GHS"}}` | `{:error, :no_momo_destination}`.
- Webhook (paystack_webhook_handler.ex): `finalize_payout/2` (~:78) looks up by `transfer_reference`; `reconcile_payout/3` clauses — `:paid`+`:reversed` → mark_reversed + release; `:paid` else terminal; `:failed`/`:reversed` re-run release; pending+`:paid` → mark_paid + `PayoutNotificationWorker.enqueue`; else mark_failed/mark_reversed + release. `release_payout_balance/1` (~:152-160) releases **Payment rows only** via `list_payments_by_payout` → `:release_from_payout`.
- `SupplierLedgerEntry`: attrs `store_id, supplier_id, fulfillment_id, amount_owed, status(:owed|:paid), paid_at` + P1 columns `settlement_source` (text default 'manual') / `payment_split_id` (NOT yet resource attributes); `create` accepts `[:store_id, :supplier_id, :fulfillment_id, :amount_owed, :status]`; `mark_paid` (owed→paid, StatusGuard); `read :list_by_supplier`. `Supplier.outstanding_balance` = `sum :amount_owed where status == :owed` (supplier.ex:98-102).
- `PayoutWorker`: transfer params include `reason: "Makola merchant payout"` (payout_worker.ex:87); guard executes only `:pending` payouts; recipient → transfer → `mark_processing`; `{:paystack_error, msg}` → mark_failed no-retry; else Oban retry.
- FinanceStats: `total_outstanding_payouts` = Σ `payable_amount(payment)` over `unsplit_success_payments()`; `per_store_finance` merges `fees_by_store` + `owed_by_store` (payment.store_id) + `verified_payout_store_ids()` → `payouts_ready?`.
- finance_live.ex: `"approve_payout"` handler (~:57) calls `PayoutService.prepare_payout(store_id)` → `PayoutWorker.enqueue` → `PlatformAudit.log(:payout_approved, ...)` → flash; `:nothing_outstanding` / `:no_momo_destination` error flashes; `"retry_payout"` prepares a FRESH payout.
- PaymentSplit claim API (P1): `mark_paid_out` (accepts payout_id REQUIRED-by-validation; only internal_hold + settled/partially_reversed + unclaimed; freezes `netted = reversed − recovered − reserved`, `paid_amount = amount − netted`), `release_from_payout` (internal_hold-only guard; resets netted to `recovered + reserved`), `read :payable_internal` (nilable recipient arg), `read :by_payout`. Domain defines: `list_payable_internal_splits/2`, `mark_payment_split_paid_out`, `release_payment_split_from_payout`, `list_payment_splits_by_payout/2`.
- `settle_splits/1` (webhook charge.success, ~:314-334): `:pending → :settled` per split, then `RefundLiability.apply_recoveries!`, then `PartnerCredit.record_settlement`.
- Test conventions: `use Emakola.DataCase, async: true`, `import Emakola.Factory` (`create_store!/1`, `create_payment!/2`, `create_supplier!/2`); split fixtures via `Ash.Changeset.for_create(:create, ...)` + `mark_settled` (pattern in `payment_split_internal_ledger_test.exs`). Payout tests: `payout_service_test.exs` (atomic-claim test ~:101 is the concurrency pattern to mirror).

---

### Task 1: `Payout.basis` attribute

**Files:**
- Modify: `lib/emakola/payments/resources/payout.ex` (attributes block; `:create` accept ~line 113)
- Test: `test/emakola/payments/payout_basis_test.exs` (create)

**Interfaces:**
- Produces: `Payout.basis :: :payments | :allocations` (default `:payments`, non-nil, public), accepted on `:create`. Tasks 2/3/6/7 rely on it.

- [ ] **Step 1: Failing test**

```elixir
defmodule Emakola.Payments.PayoutBasisTest do
  @moduledoc "Payout.basis partitions the two payout engines (:payments legacy / :allocations internal)."
  use Emakola.DataCase, async: true
  import Emakola.Factory

  test "defaults to :payments and accepts :allocations" do
    store = create_store!()

    {:ok, legacy} =
      Emakola.Payments.create_payout(
        %{store_id: store.id, amount: 1_000, currency: "GHS", transfer_reference: "po_basis_a"},
        authorize?: false
      )

    assert legacy.basis == :payments

    {:ok, internal} =
      Emakola.Payments.create_payout(
        %{
          store_id: store.id,
          amount: 2_000,
          currency: "GHS",
          transfer_reference: "po_basis_b",
          basis: :allocations
        },
        authorize?: false
      )

    assert internal.basis == :allocations
  end
end
```

- [ ] **Step 2: RED** — `mix test test/emakola/payments/payout_basis_test.exs` → FAIL (NoSuchInput/unknown attribute `basis`).
- [ ] **Step 3: Implement** — in the attributes block (after `:status`):

```elixir
    # Which engine owns this payout: :payments claims un-split Payment rows
    # (legacy); :allocations claims internal-rail PaymentSplit rows. The two
    # populations are disjoint by construction (Payment.split_mode partition).
    attribute :basis, :atom do
      constraints(one_of: [:payments, :allocations])
      default(:payments)
      allow_nil?(false)
      public?(true)
    end
```

Append `:basis` to the `:create` accept list.

- [ ] **Step 4: GREEN** — same command → PASS; also `mix test test/emakola/payments/payout_test.exs test/emakola/payments/payout_service_test.exs` (untouched, green).
- [ ] **Step 5: Commit** — `git add lib/emakola/payments/resources/payout.ex test/emakola/payments/payout_basis_test.exs && git commit -m "feat(payments): Payout.basis partitions the two payout engines"`

---

### Task 2: `PayoutService.prepare_internal_payout/1` + `momo_destination?/1`

**Files:**
- Modify: `lib/emakola/payments/payout_service.ex`
- Test: `test/emakola/payments/internal_payout_service_test.exs` (create)

**Interfaces:**
- Consumes: `payable_internal` read, `mark_payment_split_paid_out` (freezes `paid_amount`), `Payout.basis` (Task 1), `transfer_destination/1`.
- Produces: `prepare_internal_payout(recipient_store_id) :: {:ok, %Payout{basis: :allocations}} | {:error, :no_momo_destination | :nothing_outstanding}`; `momo_destination?(store_id) :: boolean()` (Tasks 6/7 consume).

- [ ] **Step 1: Failing tests**

```elixir
defmodule Emakola.Payments.InternalPayoutServiceTest do
  @moduledoc """
  Allocation-basis payouts: claim payable internal splits under FOR UPDATE and
  pay the Σ of frozen paid_amounts (CONTRACT 1: never amount − reversed).
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.{PaymentSplit, PayoutService}

  defp momo_destination!(store) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      payout_destination: %{
        "method" => "mobile_money",
        "provider" => "mtn",
        "number" => "0244000111",
        "account_name" => "Test Merchant"
      }
    })
    |> Ash.create!(authorize?: false)
  end

  defp settled_internal_split!(store, payment, attrs) do
    %{
      store_id: store.id,
      payment_id: payment.id,
      role: :merchant,
      recipient_store_id: store.id,
      amount: 10_000,
      settlement_method: :internal_hold
    }
    |> Map.merge(Map.new(attrs))
    |> then(&Ash.Changeset.for_create(PaymentSplit, :create, &1))
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:mark_settled, %{})
    |> Ash.update!(authorize?: false)
  end

  test "claims payable splits, pays Σ frozen paid_amount, stamps payout_id" do
    store = create_store!()
    momo_destination!(store)
    payment = create_payment!(store)

    plain = settled_internal_split!(store, payment, %{amount: 10_000})

    partially =
      settled_internal_split!(store, payment, %{role: :dropshipper, amount: 8_000})
      |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 3_000})
      |> Ash.update!(authorize?: false)

    {:ok, payout} = PayoutService.prepare_internal_payout(store.id)

    # CONTRACT 1: 10_000 + (8_000 − 3_000) — frozen paid_amounts, not raw sums.
    assert payout.amount == 15_000
    assert payout.basis == :allocations
    assert payout.currency == "GHS"
    assert payout.status == :pending

    {:ok, claimed} = Emakola.Payments.list_payment_splits_by_payout(payout.id, authorize?: false)
    assert length(claimed) == 2
    assert Enum.sum(Enum.map(claimed, & &1.paid_amount)) == payout.amount
    assert MapSet.new(claimed, & &1.id) == MapSet.new([plain.id, partially.id], & &1)

    # Second approval finds nothing — the claim emptied the payable set.
    assert {:error, :nothing_outstanding} = PayoutService.prepare_internal_payout(store.id)
  end

  test "no MoMo destination stamps nothing" do
    store = create_store!()
    payment = create_payment!(store)
    split = settled_internal_split!(store, payment, %{})

    assert {:error, :no_momo_destination} = PayoutService.prepare_internal_payout(store.id)
    assert is_nil(Ash.get!(Emakola.Payments.PaymentSplit, split.id, authorize?: false).paid_out_at)
  end

  test "nothing outstanding when only pending/platform/gateway splits exist" do
    store = create_store!()
    momo_destination!(store)
    assert {:error, :nothing_outstanding} = PayoutService.prepare_internal_payout(store.id)
  end

  test "currency partition claims one currency per payout" do
    store = create_store!()
    momo_destination!(store)
    ghs = create_payment!(store, currency: "GHS")
    ngn = create_payment!(store, currency: "NGN")
    settled_internal_split!(store, ghs, %{amount: 5_000, currency: "GHS"})
    settled_internal_split!(store, ngn, %{role: :dropshipper, amount: 7_000, currency: "NGN"})

    {:ok, first} = PayoutService.prepare_internal_payout(store.id)
    {:ok, second} = PayoutService.prepare_internal_payout(store.id)

    assert Enum.sort([first.amount, second.amount]) == [5_000, 7_000]
    assert Enum.sort([first.currency, second.currency]) == ["GHS", "NGN"]
  end

  test "momo_destination?/1" do
    with_dest = create_store!()
    momo_destination!(with_dest)
    without = create_store!()

    assert PayoutService.momo_destination?(with_dest.id)
    refute PayoutService.momo_destination?(without.id)
  end
end
```

- [ ] **Step 2: RED** — `mix test test/emakola/payments/internal_payout_service_test.exs` → FAIL (`prepare_internal_payout/1` undefined).
- [ ] **Step 3: Implement** (below `prepare_payout/1`, mirroring its shape line-for-line):

```elixir
  @doc "True when the store has a usable MoMo transfer destination."
  def momo_destination?(store_id) do
    match?({:ok, _}, transfer_destination(store_id))
  end

  @doc """
  Create a pending allocation-basis payout for a store's payable internal
  balance and claim the covered splits. Mirrors `prepare_payout/1`'s
  serialization exactly: one transaction, `FOR UPDATE` on the payable set, so
  a concurrent approval re-reads empty (no double-pay). The payout amount is
  the sum of each split's FROZEN `paid_amount` (never `amount - reversed` —
  they diverge by already-recovered reversal; see the design spec §4.4).
  """
  def prepare_internal_payout(recipient_store_id) do
    with {:ok, _dest} <- transfer_destination(recipient_store_id) do
      Emakola.Repo.transaction(fn ->
        splits =
          Emakola.Payments.PaymentSplit
          |> Ash.Query.for_read(:payable_internal, %{recipient_store_id: recipient_store_id})
          |> Ash.Query.lock("FOR UPDATE")
          |> Ash.read!(authorize?: false)

        currency = splits |> List.first(%{}) |> Map.get(:currency, "GHS")
        claimed = Enum.filter(splits, &(&1.currency == currency))

        if claimed == [] do
          Emakola.Repo.rollback(:nothing_outstanding)
        end

        reference = "po_" <> Ecto.UUID.generate()

        # Claim first: mark_paid_out freezes each split's paid_amount from its
        # freshly-locked row (never stale structs), and the payout is created
        # for exactly the sum of those frozen values.
        frozen =
          Enum.map(claimed, fn split ->
            {:ok, updated} =
              Emakola.Payments.mark_payment_split_paid_out(
                split,
                %{payout_id: nil},
                authorize?: false
              )

            updated
          end)

        amount = frozen |> Enum.map(& &1.paid_amount) |> Enum.sum()

        {:ok, payout} =
          Emakola.Payments.create_payout(
            %{
              store_id: recipient_store_id,
              amount: amount,
              currency: currency,
              transfer_reference: reference,
              basis: :allocations
            },
            authorize?: false
          )

        Enum.each(frozen, fn split ->
          {:ok, _} =
            Emakola.Payments.mark_payment_split_paid_out(split, %{payout_id: payout.id},
              authorize?: false
            )
        end)

        payout
      end)
    else
      {:error, :no_momo_destination} = err -> err
    end
  end
```

**ORDERING PROBLEM the implementer must solve here (do NOT transcribe the sketch blindly):** the sketch above claims with `payout_id: nil` then re-stamps — but P1's `mark_paid_out` REJECTS nil payout_id and rejects already-claimed splits. The correct resolution, matching the legacy engine's shape: create the payout FIRST with `amount: 0`?? No — `Payout.amount` is the transfer amount and must be final at creation (PayoutWorker reads it). Resolve it the way the legacy engine does: compute the sum from the LOCKED rows using the same formula `mark_paid_out` freezes — `amount - (reversed_amount - recovered_amount - reserved_recovery_amount)` — via a private helper `frozen_paid_amount/1` in PayoutService with a comment binding it to `mark_paid_out`'s change (single authority: reference the action, assert equality in tests), create the payout, then claim each split with the real `payout_id` and **assert** each returned `paid_amount` equals the precomputed value (raise on mismatch → transaction rollback — the FOR UPDATE lock makes divergence impossible; the assertion is the tripwire). Test 1's Σ-of-frozen-paid_amount assertion is the proof either way.

- [ ] **Step 4: Generalize the transfer reason** — `lib/emakola/payments/workers/payout_worker.ex:87`: `reason: "Makola merchant payout"` → `reason: "Makola payout"` (the worker now serves both bases; the string is gateway-cosmetic — verify no test asserts the old literal via `grep -rn "Makola merchant payout" test/`).
- [ ] **Step 5: GREEN** — new file passes; then `mix test test/emakola/payments/` (Result line, 0 failures).
- [ ] **Step 6: Commit** — `feat(payments): prepare_internal_payout — allocation-basis claims under FOR UPDATE`

---

### Task 3: Webhook split-release wiring

**Files:**
- Modify: `lib/emakola/payments/workers/paystack_webhook_handler.ex` (`release_payout_balance/1`, ~line 152)
- Test: `test/emakola/payments/internal_payout_webhook_test.exs` (create)

**Interfaces:**
- Consumes: `list_payment_splits_by_payout/2`, `release_payment_split_from_payout/2` (P1), `prepare_internal_payout/1` (Task 2).
- Produces: transfer.failed/reversed on an allocation payout releases every claimed split (re-claimable); transfer.success marks paid + notifies (existing path, verified basis-agnostic).

- [ ] **Step 1: Failing tests**

```elixir
defmodule Emakola.Payments.InternalPayoutWebhookTest do
  @moduledoc """
  Transfer webhooks finalize allocation-basis payouts: failure/reversal
  releases every claimed split back to payable (fresh rows re-read via
  by_payout — CONTRACT 4); success is terminal. Mirrors the legacy
  payment-release semantics exactly.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.{PaymentSplit, PayoutService}
  alias Emakola.Payments.Workers.PaystackWebhookHandler

  defp payable_setup!(amount) do
    store = create_store!()

    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      payout_destination: %{
        "method" => "mobile_money",
        "provider" => "mtn",
        "number" => "0244000222",
        "account_name" => "Webhook Test"
      }
    })
    |> Ash.create!(authorize?: false)

    payment = create_payment!(store)

    split =
      PaymentSplit
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        payment_id: payment.id,
        role: :merchant,
        recipient_store_id: store.id,
        amount: amount,
        settlement_method: :internal_hold
      })
      |> Ash.create!(authorize?: false)
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)

    {:ok, payout} = PayoutService.prepare_internal_payout(store.id)
    {store, split, payout}
  end

  defp transfer_event!(payout, status) do
    PaystackWebhookHandler.perform(%Oban.Job{
      args: %{
        "event" => %{
          "event" => "transfer.#{status}",
          "data" => %{"reference" => payout.transfer_reference, "status" => status}
        }
      }
    })
  end

  test "transfer.failed releases the claimed splits back to payable" do
    {store, split, payout} = payable_setup!(9_000)

    :ok = transfer_event!(payout, "failed")

    assert Ash.get!(Emakola.Payments.Payout, payout.id, authorize?: false).status == :failed

    released = Ash.get!(PaymentSplit, split.id, authorize?: false)
    assert is_nil(released.paid_out_at)
    assert is_nil(released.payout_id)

    # Re-claimable: a fresh approval claims it again, exactly once.
    {:ok, second} = PayoutService.prepare_internal_payout(store.id)
    assert second.amount == 9_000
  end

  test "transfer.success marks paid and leaves claims in place" do
    {_store, split, payout} = payable_setup!(4_000)

    :ok = transfer_event!(payout, "success")

    assert Ash.get!(Emakola.Payments.Payout, payout.id, authorize?: false).status == :paid
    assert Ash.get!(PaymentSplit, split.id, authorize?: false).payout_id == payout.id
  end

  test "webhook replay after release is a no-op (idempotent)" do
    {_store, _split, payout} = payable_setup!(2_500)
    :ok = transfer_event!(payout, "failed")
    :ok = transfer_event!(payout, "failed")
    assert Ash.get!(Emakola.Payments.Payout, payout.id, authorize?: false).status == :failed
  end
end
```

(Adjust the `perform/1` arg shape to match `paystack_webhook_handler_test.exs`'s existing transfer-event fixtures EXACTLY — copy its job-building helper verbatim rather than the sketch above if they differ. That suite is the authority on event-shape.)

- [ ] **Step 2: RED** — failed-release test fails: split still claimed after transfer.failed (legacy release touches Payments only).
- [ ] **Step 3: Implement** — extend `release_payout_balance/1`:

```elixir
  defp release_payout_balance(payout) do
    {:ok, payments} = Emakola.Payments.list_payments_by_payout(payout.id, authorize?: false)

    Enum.each(payments, fn payment ->
      payment
      |> Ash.Changeset.for_update(:release_from_payout, %{})
      |> Ash.update!(authorize?: false)
    end)

    # Allocation-basis payouts claimed PaymentSplit rows instead; release those
    # too. Each list is empty for the other basis, so both loops are safe to
    # run unconditionally — same idempotent-replay contract as above. Rows are
    # re-read fresh via by_payout (never stale structs — see design spec §4.4).
    {:ok, splits} = Emakola.Payments.list_payment_splits_by_payout(payout.id, authorize?: false)

    Enum.each(splits, fn split ->
      {:ok, _} = Emakola.Payments.release_payment_split_from_payout(split, authorize?: false)
    end)
  end
```

- [ ] **Step 4: GREEN** — new file + `mix test test/emakola/payments/paystack_webhook_handler_test.exs` (untouched, green).
- [ ] **Step 5: Commit** — `feat(payments): transfer failure releases allocation-basis claims`

---

### Task 4: Unreclaimable-release guard (CONTRACT 2 — minimal close + decision surface)

**Files:**
- Modify: `lib/emakola/payments/resources/payment_split.ex` (`release_from_payout`)
- Test: `test/emakola/payments/payment_split_internal_ledger_test.exs` (append)

⚠️ **KOJO-DECISION (documented, deliberately NOT auto-built):** full make-whole for a released claim on an unreclaimable split (status `:reversed`) requires returning ALREADY-APPLIED recoveries — a reverse-lookup through earning splits' jsonb `recovery_breakdown`s or a synthetic compensating ledger row, both of which change the ledger's shape. This task ships the safe minimal close: the RESERVED (not-yet-applied) portion is no longer double-exposed (P1's fence already nets it), and the release stamps forensic metadata so the platform can remediate manually. The full design options are recorded here for the decision:
  (a) reverse-lookup unwind of applied recoveries (complex, jsonb scan);
  (b) synthetic platform→merchant adjustment allocation (new ledger row class);
  (c) accept manual remediation from the flagged metadata (current).
Present these to Kojo before P3 ships (the population is zero until then).

- [ ] **Step 1: Failing test** (append to the internal-ledger suite)

```elixir
  describe "release_from_payout on an unreclaimable split" do
    test "stamps remediation metadata when the released split can never be re-claimed", %{
      store: store,
      payment: payment
    } do
      payout_id = Ash.UUID.generate()

      split =
        settle!(
          create_split!(store, payment, %{
            role: :merchant,
            recipient_store_id: store.id,
            amount: 6_000,
            settlement_method: :internal_hold
          })
        )
        |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 2_000})
        |> Ash.update!(authorize?: false)
        |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout_id})
        |> Ash.update!(authorize?: false)

      # Post-claim the refund grows to the FULL amount → :reversed → unreclaimable.
      split =
        split
        |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: 6_000})
        |> Ash.update!(authorize?: false)

      released =
        split
        |> Ash.Changeset.for_update(:release_from_payout, %{})
        |> Ash.update!(authorize?: false)

      assert released.status == :reversed
      assert is_nil(released.paid_out_at)
      # payable_internal must NOT resurface it (amount > reversed is false)...
      assert payable_internal(store.id) == []
      # ...and the forensic flag marks it for manual remediation review.
      assert released.recovery_breakdown["unreclaimable_release"] == true
    end
  end
```

- [ ] **Step 2: RED** — `recovery_breakdown["unreclaimable_release"]` is nil.
- [ ] **Step 3: Implement** — in `release_from_payout`'s change fn, after the existing resets, add:

```elixir
        # An unreclaimable split (fully reversed while claimed) exits the
        # payable population forever; any recovery its claim justified cannot
        # be auto-unwound yet (see P2 plan Task 4 — decision pending). Stamp
        # the release so finance can find and remediate these manually.
        changeset =
          if changeset.data.status == :reversed do
            Ash.Changeset.change_attribute(
              changeset,
              :recovery_breakdown,
              Map.put(changeset.data.recovery_breakdown, "unreclaimable_release", true)
            )
          else
            changeset
          end
```

(Adapt to the actual change-fn structure — the existing fn pipes `change_attribute` calls; thread this conditionally at the end, returning the changeset.)

- [ ] **Step 4: GREEN** + guarded internal-ledger suite green.
- [ ] **Step 5: Commit** — `feat(payments): flag unreclaimable releases for manual remediation`

---

### Task 5: Supplier-ledger unification

**Files:**
- Modify: `lib/emakola/suppliers/resources/supplier_ledger_entry.ex`; `lib/emakola/suppliers/resources/supplier.ex` (aggregate filter ~:99); `lib/emakola/suppliers/suppliers.ex` (domain defines); `lib/emakola/payments/workers/paystack_webhook_handler.ex` (`settle_splits/1` ~:314-334 + allocation-payout `transfer.success` path)
- Test: `test/emakola/suppliers/supplier_ledger_unification_test.exs` (create)

**Interfaces:**
- Consumes: P1 columns `settlement_source`/`payment_split_id`; wholesaler splits carry `supplier_id`; fulfillments resolve via `Emakola.Orders.list_fulfillments_by_order!/2`.
- Produces: attributes `settlement_source :: :manual | :platform_payout | :split_gateway` (default `:manual`) + `payment_split_id`; actions `claim_for_platform_settlement` (owed+manual only; accepts `payment_split_id` + a `source` argument), `mark_platform_paid` (owed/claimed → paid + paid_at); `read :by_fulfillment`; `Supplier.outstanding_balance` counts only `status == :owed and settlement_source == :manual`. `settle_splits/1` claims entries for wholesaler splits: gateway splits → claim `:split_gateway` + mark paid immediately (INTENTIONAL behavior change — today the merchant could double-pay a gateway-settled supplier manually); internal splits → claim `:platform_payout`, marked paid when the allocation payout's `transfer.success` arrives.

- [ ] **Step 1: Failing tests** — cover: (a) gateway wholesaler split settling → its fulfillment's entry becomes `:split_gateway`/`:paid` and drops out of `Supplier.outstanding_balance`; (b) internal wholesaler split settling → entry `:platform_payout`, still unpaid, excluded from outstanding_balance (claimed ≠ manual); then allocation-payout transfer.success → `:paid` with `paid_at`; (c) a `:manual` entry is untouched by unrelated splits; (d) `claim_for_platform_settlement` refuses non-owed and non-manual entries. Build fixtures with `create_supplier!` + a checkout through `CheckoutService.checkout!` (dropship variant pattern from `order_settlement_internal_test.exs`) so real fulfillments + entries exist; drive webhook settlement via the `charge.success` job-shape from `paystack_webhook_handler_test.exs`. Write the four tests fully before implementing; RED on missing action.
- [ ] **Step 2: Implement resource** — attributes:

```elixir
    attribute :settlement_source, :atom do
      constraints(one_of: [:manual, :platform_payout, :split_gateway])
      default(:manual)
      allow_nil?(false)
      public?(true)
    end

    attribute :payment_split_id, :uuid do
      public?(true)
    end
```

Actions:

```elixir
    # The platform settlement claims this obligation so the same supplier debt
    # can never exist twice (manual "mark paid" hides for claimed entries).
    update :claim_for_platform_settlement do
      require_atomic?(false)
      accept([:payment_split_id])
      argument(:source, :atom, allow_nil?: false, constraints: [one_of: [:platform_payout, :split_gateway]])

      validate(attribute_in(:status, [:owed]), message: "only an owed entry can be claimed")
      validate(attribute_equals(:settlement_source, :manual), message: "already claimed")

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(
          changeset,
          :settlement_source,
          Ash.Changeset.get_argument(changeset, :source)
        )
      end)
    end

    update :mark_platform_paid do
      require_atomic?(false)
      accept([])
      validate(attribute_in(:status, [:owed]), message: "already settled")
      change(set_attribute(:status, :paid))
      change(set_attribute(:paid_at, &DateTime.utc_now/0))
    end

    read :by_fulfillment do
      argument(:fulfillment_id, :uuid, allow_nil?: false)
      filter(expr(fulfillment_id == ^arg(:fulfillment_id)))
    end
```

`Supplier.outstanding_balance` filter → `expr(status == :owed and settlement_source == :manual)`. Domain defines in the Suppliers domain module (match its existing define style): `claim_supplier_ledger_entry` (action `:claim_for_platform_settlement`), `mark_supplier_ledger_entry_platform_paid`, `list_supplier_ledger_entries_by_fulfillment` (args `[:fulfillment_id]`).

- [ ] **Step 3: Wire `settle_splits/1`** — after the existing settle loop, for each settled split with `role: :wholesaler and not is_nil(supplier_id)`: resolve `payment.order_id` → `Emakola.Orders.list_fulfillments_by_order!(order_id, authorize?: false)` → the fulfillment with matching `supplier_id` → its entry via `by_fulfillment` → if `:owed`+`:manual`: gateway split (`settlement_method == :gateway_share`) → claim `:split_gateway` then `mark_platform_paid`; internal split → claim `:platform_payout` only. Never raise into the webhook (log-and-continue like `ProtectionHolds.ensure_hold`). On the allocation-payout `transfer.success` path (Task 3's reconcile), after `mark_payout_paid`: for each claimed split's `payment_split_id`-linked entries → `mark_platform_paid` (resolve via a new `read :by_payment_split` — argument `payment_split_id`, filter on it — add alongside `by_fulfillment`).
- [ ] **Step 4: GREEN** — new suite + `mix test test/emakola/suppliers/ test/emakola/payments/` (Result lines).
- [ ] **Step 5: Commit** — `feat(suppliers): one supplier obligation — platform settlement claims ledger entries`

**Refund↔supplier coupling (from PR follow-ups), scoped here:** add ONE more test + wiring — when `reverse_splits/1` (webhook refund.processed) fully reverses a wholesaler split (`status == :reversed`) whose entry is claimed-unpaid (`:platform_payout`, `:owed`), void the entry (`mark_platform_paid` is wrong — add `update :void` setting status `:paid`? NO: add a `:voided` status value ONLY if the enum change is trivial; otherwise mark the entry's metadata and leave status — check the resource's status constraint first and prefer the smallest honest change; if `:voided` requires migrations beyond a text-enum tweak, log + skip with a comment and note it in the report as follow-up). The folded-passthrough/manual case is explicitly OUT (passthrough is settlement-time only — documented in PR #372).

---

### Task 6: FinanceStats — internal balances in money truth

**Files:**
- Modify: `lib/emakola/platform/finance_stats.ex`
- Test: `test/emakola/platform/finance_stats_internal_test.exs` (create)

**Interfaces:**
- Consumes: `list_payable_internal_splits/2`, `momo_destination?/1` (Task 2).
- Produces: `total_outstanding_payouts/0` = legacy sum + Σ payable internal nets; `per_store_finance/0` rows merge internal balances keyed by **`recipient_store_id`**; `payouts_ready?` = `momo_destination?/1`. The payable-net helper is THE single authority formula.

- [ ] **Step 1: Failing tests** — (a) a settled internal split (amount 10_000, reversed 4_000, recovered 1_000) adds exactly `7_000` to `total_outstanding_payouts` (the `paid_amount` formula: `10_000 − (4_000 − 1_000 − 0)`) and appears under the RECIPIENT store's row even when the charge's tenant store differs (create the split with `store_id: seller.id, recipient_store_id: wholesaler.id`); (b) a claimed split contributes nothing; (c) `payouts_ready?` true for a MoMo-destination store without a verified subaccount (the legacy `verified_payout_store_ids` would say false — assert the new behavior). Set `recovered_amount` via `update_recovery_tracking`.
- [ ] **Step 2: RED**, then implement:

```elixir
  # THE payable-net formula — what mark_paid_out freezes as paid_amount.
  # Single authority (design spec §4.5): display, sums, and the payout engine
  # must all agree to the pesewa. Keep in sync with PaymentSplit.mark_paid_out.
  defp payable_net(split) do
    split.amount - (split.reversed_amount - split.recovered_amount - split.reserved_recovery_amount)
  end

  defp payable_internal_splits do
    {:ok, splits} = Emakola.Payments.list_payable_internal_splits(nil, authorize?: false)
    splits
  end
```

`total_outstanding_payouts/0` → existing sum `+ (payable_internal_splits() |> Enum.map(&payable_net/1) |> Enum.sum())`. `per_store_finance/0` → `owed_by_store` merges in `sum_by_store_key(payable_internal_splits(), & &1.recipient_store_id, &payable_net/1)` (add the keyed variant next to `sum_by_store`; merge maps with `Map.merge(_, _, fn _k, a, b -> a + b end)`); `payouts_ready?` per store → `Emakola.Payments.PayoutService.momo_destination?(id)` (replace the `verified_payout_store_ids` MapSet usage; delete that helper if now orphaned — check first).
- [ ] **Step 3: GREEN** + `mix test test/emakola/platform/` and the untouched `finance_stats_test.exs` green (it exercises legacy sums only — if it asserted `payouts_ready?` against subaccount fixtures, those fixtures ALSO have MoMo destinations via `record_subaccount`'s flow — verify; if a fixture breaks, the fixture used a bank-method destination and the assertion change is INTENTIONAL: flag it in the report, don't silently edit).
- [ ] **Step 4: Commit** — `feat(platform): internal balances join the money truth`

---

### Task 7: finance_live dual-basis approve

**Files:**
- Modify: `lib/emakola_web/live/platform/finance_live.ex` (`"approve_payout"` handler ~:57; recent-payouts table render)
- Test: `test/emakola_web/live/platform/finance_live_internal_test.exs` (create; `use Emakola.LiveViewHelpers` + `setup_platform_staff(conn)`)

**Interfaces:**
- Consumes: `prepare_internal_payout/1` (Task 2), `Payout.basis` (Task 1).
- Produces: one approve click drains BOTH bases; table shows basis.

- [ ] **Step 1: Failing test** — platform staff visits `/platform/finance`, a store has BOTH an outstanding un-split payment AND a payable internal split; clicking approve creates TWO payouts (one per basis, both enqueued to PayoutWorker — assert via `all_enqueued`), audits both, and a store with only an internal balance approves cleanly (legacy returns `:nothing_outstanding` and is not an error). Copy the suite-setup shape from the existing finance_live test file.
- [ ] **Step 2: Implement** — in the handler, replace the single `prepare_payout` call with:

```elixir
      results = [
        {:payments, PayoutService.prepare_payout(store_id)},
        {:allocations, PayoutService.prepare_internal_payout(store_id)}
      ]

      queued =
        for {_basis, {:ok, payout}} <- results do
          PayoutWorker.enqueue(payout.id)

          PlatformAudit.log(:payout_approved, socket.assigns.current_user, %{
            "store_id" => store_id,
            "payout_id" => payout.id,
            "amount" => payout.amount,
            "basis" => to_string(payout.basis)
          })

          payout
        end
```

`queued == []` → keep today's `:nothing_outstanding`/`:no_momo_destination` error flashes (derive from the two error tuples — if either is `:no_momo_destination`, show that message); else flash the summed `format_amount(Enum.sum(Enum.map(queued, & &1.amount)))`. Add a small `basis` badge column to the recent-payouts table (find the table render in this module or its template; plain text `payout.basis` is fine — no new component). `retry_payout` gains the same dual-prepare (it already re-prepares fresh).
- [ ] **Step 3: GREEN** + existing finance_live suite untouched and green.
- [ ] **Step 4: Commit** — `feat(platform): approve drains both payout bases`

---

### Task 8: Phase gate

- [ ] `mix test` full suite — Result line, 0 failures; `mix format --check-formatted`; `mix credo --strict`; `touch` all modified lib files then `mix compile --warnings-as-errors`.
- [ ] Guarded-suite proof: `git diff <P2-base-commit> --stat -- test/emakola/payments/payout_service_test.exs test/emakola/payments/payout_test.exs test/emakola/payments/paystack_webhook_handler_test.exs test/emakola/platform/finance_stats_test.exs` → empty (any INTENTIONAL exception from Task 6 documented in the ledger).
- [ ] Whole-branch review (most capable model) over the P2 range; fix wave if needed.
- [ ] Push. PR routing: if #372 is MERGED → new PR targeting `main`; else stacked PR targeting `worktree-internal-settlement` (check `gh pr view 372 --json state,mergeStateStatus` at execution time; remember bottom-up merge order).
