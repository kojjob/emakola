# Platform Payments & Reconciliation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A read-only `/platform/payments` page: payment success rate, gateway split (Paystack/Hubtel), refunds, and a failed-payments reconciliation worklist — across ALL stores. No schema changes.

**Architecture:** Single LiveView `Platform.PaymentLive.Index` in the `:platform` live_session, gated `RequirePermission(:manage_billing)`, disconnected-mount loading shell, read-only (no events). Platform-wide aggregations added to `Emakola.Platform.Stats` (mirroring `total_gmv/0`). `Payment` has `multitenancy ... global?(true)`, so tenant-less `authorize?: false` reads aggregate across stores; `Store` is global so `load: [:store]` resolves.

**Tech Stack:** Elixir/Phoenix LiveView, Ash 3.x (Payments domain), Tailwind, ExUnit + `Emakola.LiveViewHelpers`.

**Spec:** `docs/superpowers/specs/2026-06-15-platform-payments-design.md` · **Roadmap:** `…-platform-admin-roadmap.md`
**Branch/worktree:** `feature/platform-payments` (already created off origin/main).

**Data:** `Emakola.Payments.Payment` — `status` (:pending/:success/:failed/:refunded), `gateway` (:paystack/:hubtel), `amount` (pesewas), `refunded_amount`, `currency`, `customer_email`, `inserted_at`, `belongs_to :store`. Update actions to drive status in tests: `mark_success`, `mark_failed`, `mark_refunded` (verify accepted args in `payment.ex` ~lines 156-181). Factory `create_payment!(store, attrs)` exists (creates `:pending`).

---

## Task 1: Platform.Stats payment aggregations (TDD)

**Files:** Modify `lib/emakola/platform/stats.ex`; Test `test/emakola/platform/stats_test.exs` (create if missing — check first).

- [ ] **Step 1: Failing tests.** Add a `describe "payments"` that seeds payments in **TWO** stores (proves cross-tenant `global?(true)`), driving statuses via the Payment update actions. Cover:
  - `total_payments/0` counts across both stores.
  - `successful_payment_count/0`, `failed_payment_count/0`.
  - `total_refunded/0` sums `refunded_amount` across stores.
  - `payment_gateway_breakdown/0` → `%{paystack: %{success_count, failed_count, success_volume}, hubtel: %{...}}`.
  - `recent_failed_payments/1` → only `:failed`, newest first, `.store` preloaded (assert `hd().store.name`).
  - `recent_refunded_payments/1` → only `:refunded`.

  Example seed helper inside the test:
  ```elixir
  defp pay!(store, gateway, status, attrs \\ %{}) do
    p = Factory.create_payment!(store, Map.merge(%{gateway: gateway, amount: 10_000}, attrs))
    case status do
      :success -> p |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)
      :failed -> p |> Ash.Changeset.for_update(:mark_failed, %{}) |> Ash.update!(authorize?: false)
      :refunded ->
        p
        |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)
        |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 10_000}) |> Ash.update!(authorize?: false)
      _ -> p
    end
  end
  ```
  (Adjust action names/args to the real `payment.ex`. If `create_payment!` doesn't accept `gateway`/`amount`, set them via the create attrs it does accept — read the factory + resource first.)

- [ ] **Step 2: Run — confirm fail.** `mix test test/emakola/platform/stats_test.exs`

- [ ] **Step 3: Implement** in `lib/emakola/platform/stats.ex` (module already has `require Ash.Query`; mirror `total_gmv/0` exactly — `authorize?: false`, no tenant):
  ```elixir
  def total_payments do
    case Emakola.Payments.Payment |> Ash.count(authorize?: false) do
      {:ok, n} -> n
      _ -> 0
    end
  end

  def successful_payment_count, do: count_by_status(:success)
  def failed_payment_count, do: count_by_status(:failed)

  defp count_by_status(status) do
    case Emakola.Payments.Payment |> Ash.Query.filter(status == ^status) |> Ash.count(authorize?: false) do
      {:ok, n} -> n
      _ -> 0
    end
  end

  def total_refunded do
    case Emakola.Payments.Payment |> Ash.sum(:refunded_amount, authorize?: false) do
      {:ok, s} -> s || 0
      _ -> 0
    end
  end

  @payment_gateways [:paystack, :hubtel]
  def payment_gateway_breakdown do
    Map.new(@payment_gateways, fn gw -> {gw, gateway_stats(gw)} end)
  end

  defp gateway_stats(gw) do
    %{
      success_count: count_gateway(gw, :success),
      failed_count: count_gateway(gw, :failed),
      success_volume: sum_gateway_success(gw)
    }
  end

  defp count_gateway(gw, status) do
    case Emakola.Payments.Payment
         |> Ash.Query.filter(gateway == ^gw and status == ^status)
         |> Ash.count(authorize?: false) do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp sum_gateway_success(gw) do
    case Emakola.Payments.Payment
         |> Ash.Query.filter(gateway == ^gw and status == :success)
         |> Ash.sum(:amount, authorize?: false) do
      {:ok, s} -> s || 0
      _ -> 0
    end
  end

  def recent_failed_payments(limit \\ 20), do: recent_by_status(:failed, limit)
  def recent_refunded_payments(limit \\ 10), do: recent_by_status(:refunded, limit)

  defp recent_by_status(status, limit) do
    Emakola.Payments.Payment
    |> Ash.Query.filter(status == ^status)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.Query.load([:store])
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end
  ```
  `@payment_gateways` is a compile-time literal list (no `String.to_atom`). `^status`/`^gw` are pinned atoms from literal sources, not user input.

- [ ] **Step 4: Run — confirm pass.** Then `mix format` the two files.

- [ ] **Step 5: Commit.** `git add lib/emakola/platform/stats.ex test/emakola/platform/stats_test.exs && git commit -m "feat(platform): cross-store payment aggregations in Platform.Stats"`

---

## Task 2: Route + skeleton + access tests (TDD)

**Files:** Modify `lib/emakola_web/router.ex`; Create `lib/emakola_web/live/platform/payment_live/index.ex`; Test `test/emakola_web/live/platform/payment_live_test.exs`.

- [ ] **Step 1: Failing access test** (mirror `billing_live_test.exs`): `use EmakolaWeb.ConnCase, async: true`, `use Emakola.LiveViewHelpers`, `alias Emakola.Factory`. Three permission-gating tests at `~p"/platform/payments"`: owner mounts (asserts "Payments"); staff `[:manage_billing]` mounts; staff `[:manage_team]` → `{:error, {:redirect, %{to: "/platform", flash: flash}}}`, `flash["error"] =~ "permission"`.

- [ ] **Step 2: Run — confirm fail** (no route).

- [ ] **Step 3: Route** — in `router.ex` inside `live_session :platform`, after `/platform/billing` (if present on this branch — it is NOT, billing is a separate branch; just add alongside stores/team/etc.):
  ```elixir
  live "/platform/payments", Platform.PaymentLive.Index
  ```

- [ ] **Step 4: Skeleton** `lib/emakola_web/live/platform/payment_live/index.ex`:
  ```elixir
  defmodule EmakolaWeb.Platform.PaymentLive.Index do
    @moduledoc "Read-only platform payments & reconciliation overview."
    use EmakolaWeb, :live_view

    on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

    @impl true
    def mount(_params, _session, socket) do
      {:ok, socket |> assign(:page_title, "Payments") |> assign(:active_nav, :payments)}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div class="p-6 lg:p-8 max-w-7xl mx-auto">
        <h1 class="text-2xl font-bold text-gray-900">Payments</h1>
        <p class="text-sm text-gray-500 mt-1">Payments &amp; reconciliation across all stores</p>
      </div>
      """
    end
  end
  ```

- [ ] **Step 5: Run — confirm pass** (3 tests). `mix format`.

- [ ] **Step 6: Commit.** `git add lib/emakola_web/router.ex lib/emakola_web/live/platform/payment_live/index.ex test/emakola_web/live/platform/payment_live_test.exs && git commit -m "feat(platform): add /platform/payments route, skeleton, access tests"`

---

## Task 3: Behavior tests (red)

**Files:** Modify `test/emakola_web/live/platform/payment_live_test.exs`.

- [ ] **Step 1:** Append (reuse the `pay!/4` helper from Task 1's test, or inline equivalent):
  - `describe "disconnected mount"`: seed a payment with a unique `customer_email`; `get(conn, ~p"/platform/payments")`; `html_response(conn, 200)` =~ "Loading"; refute the email.
  - `describe "content"` (setup: two stores, success+failed for both gateways, one refunded): assert stat labels ("Total payments", "Success rate", "GMV", "Refunds"), gateway labels ("Paystack", "Hubtel"), the failed payment's `customer_email` + its `store.name`, and a formatted amount (e.g. "GHS").
  - stat value: with 1 success + 1 failed assert success-rate text "50%".
  - `describe "empty state"`: a store with only successful payments → assert "No failed payments" copy.

- [ ] **Step 2: Run — confirm new tests fail** (skeleton). **Step 3: Commit** the red tests.

---

## Task 4: Full LiveView (green)

**Files:** Modify `lib/emakola_web/live/platform/payment_live/index.ex` (full); Modify `lib/emakola_web/components/layouts/platform.html.heex` (nav).

- [ ] **Step 1:** Implement the full module (copy structure from `billing_live.ex` — `@stat_colors`, `stat/1`, loading shell, `format_amount/1` → `"GHS #{div(cents,100)}"` nil-safe, `date_str/1`, `humanize/1` for gateway/status labels). `mount`: assign base, then `if connected?(socket), do: load(socket), else: assign(loaded: false, stats: nil, gateways: [], failed: nil, refunds: nil)`. `load/1`: build `stats` (total/success/failed/gmv via `Stats.total_gmv`/refunded), `success_rate` (guard `success+failed==0 -> nil`), `gateways: Stats.payment_gateway_breakdown()`, `failed: Stats.recent_failed_payments(20)`, `refunds: Stats.recent_refunded_payments(10)`. NO `handle_event`.
  Render: 4-card stat strip (Total payments, Success rate, GMV, Refunds); gateway breakdown table (Gateway / Success / Failed / Volume) for `[:paystack, :hubtel]`; failed worklist table (Store / Customer / Amount / Gateway / Date) with `:if={@failed == []}` empty state "No failed payments — nothing to reconcile."; recent refunds table with its own empty state. Use `pay.store && pay.store.name || "—"`. Success-rate render: `"#{round(rate * 100)}%"` or `"—"` when nil.

- [ ] **Step 2: Run** `mix test test/emakola_web/live/platform/payment_live_test.exs` → all green. `mix format` + `mix compile --warnings-as-errors`.

- [ ] **Step 3: Nav** — in `platform.html.heex`, add after the Stores (or in the Finance section) a permission-gated link:
  ```heex
  <.sidebar_link
    :if={Emakola.Accounts.PlatformPermissions.allowed?(@current_user, :manage_billing)}
    href="/platform/payments"
    title="Payments"
    icon="payments"
    active={@active_nav == :payments}
  />
  ```
  Confirm `"payments"` (or `"currency"`/`"chart"`) is a real icon in `sidebar_components.ex`.

- [ ] **Step 4: Commit.** `git add lib/emakola_web/live/platform/payment_live/index.ex lib/emakola_web/components/layouts/platform.html.heex && git commit -m "feat(platform): payments & reconciliation overview (success rate, gateways, failed worklist)"`

---

## Task 5: Quality gates
- [ ] `mix format --check-formatted` → clean.
- [ ] `mix credo --strict lib/emakola/platform/stats.ex lib/emakola_web/live/platform/payment_live/index.ex` → no issues.
- [ ] `mix test` → full suite green (no regressions).

## Self-review notes
- Cross-tenant reads confirmed safe by `Payment` `global?(true)` + global `Store` (verified by the Plan agent). The two-store Stats test is the load-bearing proof.
- Permission reuses `:manage_billing` (Finance section) — no catalog churn. Read-only ⇒ no per-event re-auth.
- Money in GHS minor units via `format_amount` (Payments are GHS/Paystack-Hubtel — unlike Billing's USD).
