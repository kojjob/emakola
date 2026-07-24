# Supply-Connection Invite Throttle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rate-limit supply-connection invites to 10/day + 3/min per requesting store so real SMS keys can go live without an invite-spam cost hole.

**Architecture:** One guard function in `Emakola.Suppliers.Network.request/2` using the existing `Emakola.RateLimit` (Hammer/ETS), one new error branch in the LiveView. Spec: `docs/superpowers/specs/2026-07-24-supply-invite-throttle-design.md`.

**Tech Stack:** Elixir, Hammer (via `Emakola.RateLimit.check_rate/3`), ExUnit, Oban.Testing.

## Global Constraints

- TDD: write the failing tests first, watch them fail, then implement.
- ALL commands FOREGROUND — never background, never wait on notifications. Parse the test run's "Result:" line; the exit code lies.
- Flash copy exact: `"Invite limit reached — please try again later."`
- Rate-limit keys exact: `"supply_invite:burst:{store_id}"` (3 per 60_000 ms) and `"supply_invite:day:{store_id}"` (10 per 86_400_000 ms). Burst checked FIRST.
- Error atom exact: `{:error, :invite_rate_limited}`.
- No config/env vars — limits are module attributes.
- `mix format` before committing; conventional commit.

---

### Task 1: Throttle in Network.request/2 + LiveView flash

**Files:**
- Modify: `lib/emakola/suppliers/network.ex` (request/2 `with` chain + new private fn + module attributes)
- Modify: `lib/emakola_web/live/admin/supply_network_live.ex` (~line 108, after the `:stores_must_differ` branch of `request_connection`)
- Test: `test/emakola/suppliers/network_test.exs` (new describe), `test/emakola_web/live/admin/supply_network_live_test.exs` (one new test)

**Interfaces:**
- Consumes: `Emakola.RateLimit.check_rate(key, limit, window_ms)` → `{:allow, n} | {:deny, retry_ms}` (exists).
- Produces: `Network.request/2` may now return `{:error, :invite_rate_limited}`.

- [ ] **Step 1: Write the failing network tests**

Append to `test/emakola/suppliers/network_test.exs` (inside the module; it already imports `Emakola.Factory` and uses `Oban.Testing`):

```elixir
  # Module level, ABOVE the describe — ExUnit raises on defp inside describe.
  # Hammer's :fix_window buckets are epoch-aligned; if the test starts
  # within guard_ms of a boundary, counts split across two windows (PR #174).
  defp await_fresh_window(window_ms, guard_ms) do
    remaining = window_ms - rem(System.system_time(:millisecond), window_ms)
    if remaining < guard_ms, do: Process.sleep(remaining + 10)
  end

  defp request_attrs(ctx, partner) do
    %{
      wholesaler_store_id: partner.id,
      reseller_store_id: ctx.reseller.id,
      requested_by_store_id: ctx.reseller.id,
      terms: %{"currency" => "GHS"}
    }
  end

  describe "invite throttle" do

    test "the 4th request within a minute is denied and creates nothing", ctx do
      await_fresh_window(60_000, 3_000)

      for partner <- [create_store!(), create_store!(), create_store!()] do
        assert {:ok, _} = Network.request(ctx.reseller_actor, request_attrs(ctx, partner))
      end

      fourth = create_store!()

      assert {:error, :invite_rate_limited} =
               Network.request(ctx.reseller_actor, request_attrs(ctx, fourth))

      fourth_id = fourth.id

      assert {:ok, []} =
               Emakola.Suppliers.SupplyConnection
               |> Ash.Query.filter(wholesaler_store_id == ^fourth_id)
               |> Ash.read(authorize?: false)

      assert length(
               all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)
             ) == 3
    end

    test "the 11th request in a day is denied even when the burst window is fresh", ctx do
      for _ <- 1..10 do
        Emakola.RateLimit.check_rate("supply_invite:day:#{ctx.reseller.id}", 10, 86_400_000)
      end

      partner = create_store!()

      assert {:error, :invite_rate_limited} =
               Network.request(ctx.reseller_actor, request_attrs(ctx, partner))
    end
  end
```

Also add `require Ash.Query` directly under `use Oban.Testing, repo: Emakola.Repo` at the top of the module (needed by the filter above; the module does not have it yet).

- [ ] **Step 2: Run to verify both fail**

Run: `MIX_ENV=test mix test test/emakola/suppliers/network_test.exs 2>&1 | tail -4`
Expected: 2 failures — the 4th/11th requests currently return `{:ok, _}`, not the rate-limit error.

- [ ] **Step 3: Implement the throttle**

In `lib/emakola/suppliers/network.ex`, add under the existing aliases:

```elixir
  alias Emakola.RateLimit

  @invite_burst_limit 3
  @invite_burst_window_ms 60_000
  @invite_day_limit 10
  @invite_day_window_ms 86_400_000
```

Extend the `with` chain in `request/2` — insert one clause between `ensure_connection_absent` and the create:

```elixir
    with :ok <- ensure_distinct(wholesaler_id, reseller_id),
         :ok <- ensure_participant(requester_id, wholesaler_id, reseller_id),
         :ok <- ensure_access(actor, requester_id),
         :ok <- ensure_connection_absent(wholesaler_id, reseller_id),
         :ok <- ensure_invite_quota(requester_id),
         {:ok, connection} <- Suppliers.request_supply_connection(attrs, authorize?: false) do
      {:ok, notify(connection, "requested")}
    end
```

Add the private function next to the other `ensure_*` helpers:

```elixir
  defp ensure_invite_quota(store_id) do
    with {:allow, _} <-
           RateLimit.check_rate(
             "supply_invite:burst:#{store_id}",
             @invite_burst_limit,
             @invite_burst_window_ms
           ),
         {:allow, _} <-
           RateLimit.check_rate(
             "supply_invite:day:#{store_id}",
             @invite_day_limit,
             @invite_day_window_ms
           ) do
      :ok
    else
      {:deny, _} -> {:error, :invite_rate_limited}
    end
  end
```

- [ ] **Step 4: Run network tests to verify they pass**

Run: `MIX_ENV=test mix test test/emakola/suppliers/network_test.exs 2>&1 | tail -4`
Expected: "Result: N passed" (all green, including the pre-existing tests).

- [ ] **Step 5: Write the failing LiveView test**

In `test/emakola_web/live/admin/supply_network_live_test.exs`, find the existing test that submits the `request_connection` form successfully (search `request_connection` or `Send invite`) and mirror its setup/submission exactly in a new test. Before submitting, exhaust the burst counter for the requesting store:

```elixir
      for _ <- 1..3 do
        Emakola.RateLimit.check_rate("supply_invite:burst:#{store.id}", 3, 60_000)
      end
```

(`store` = whatever the mirrored test names the merchant's current store.) Then submit the form with a valid partner slug and assert the flash:

```elixir
      assert render(view) =~ "Invite limit reached"
```

Run it, expect FAIL (the invite currently succeeds and flashes "Invitation sent").

- [ ] **Step 6: Add the LiveView error branch**

In `lib/emakola_web/live/admin/supply_network_live.ex`, in `handle_event("request_connection", ...)`, add a branch after the `:stores_must_differ` one (before the catch-all `{:error, _reason}`):

```elixir
          {:error, :invite_rate_limited} ->
            {:noreply,
             put_flash(socket, :error, "Invite limit reached — please try again later.")}
```

- [ ] **Step 7: Run both suites, format, commit**

Run: `MIX_ENV=test mix test test/emakola/suppliers/network_test.exs test/emakola_web/live/admin/supply_network_live_test.exs 2>&1 | tail -4`
Expected: all green.
Run: `mix format lib/emakola/suppliers/network.ex lib/emakola_web/live/admin/supply_network_live.ex test/emakola/suppliers/network_test.exs test/emakola_web/live/admin/supply_network_live_test.exs`
Run: `MIX_ENV=test mix compile --warnings-as-errors` (touch the four files first)
Commit:

```bash
git add -A
git commit -m "feat(catalog): throttle supply-connection invites to 10/day + 3/min per store"
```
