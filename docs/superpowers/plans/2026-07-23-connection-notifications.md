# Supply Connection Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Network.request/approve/reject` notify the counterparty on SMS + WhatsApp + push via one idempotent Oban worker.

**Architecture:** Copy in `Templates`, fan-out in a new `ConnectionNotificationWorker` (mirrors `SupplierNotificationWorker`/`PushNotificationWorker`), enqueued from the `Network` service after each successful write. Spec: `docs/superpowers/specs/2026-07-23-connection-notifications-design.md`.

**Tech Stack:** Elixir/Phoenix, Ash 3.x, Oban, Mox.

## Global Constraints

- Branch: `feature/connection-notifications` (created; spec committed).
- TDD: failing tests first; `mix format` before each commit; conventional commits; ALL commands FOREGROUND — never background, never wait on notifications.
- Worker: `queue: :notifications, max_attempts: 3`, Oban `unique` on args `(connection_id, event)` — mirror `SupplierNotificationWorker`'s exact `use Oban.Worker` options shape (check its `unique:` settings and copy the pattern).
- Channel APIs (verified): `Emakola.Notifications.Channels.SMS.send_sms(phone, message, opts \\ [])`; `Emakola.Notifications.Channels.WhatsApp.send_message(to, template_name, params, opts)`; push provider behaviour via `Application.get_env(:emakola, :push_provider, ...)` — mirror how `PushNotificationWorker` invokes it and resolves `device_tokens_for_store/1` (read that worker first; reuse/extract, don't reinvent).
- Test mocks (config/test.exs): `Emakola.SMSProviderMock`, `Emakola.WhatsAppProviderMock`, `Emakola.PushProviderMock`.
- `Network.reject/3` signature is `reject(actor, connection, reason)`.
- Oban service tests assert with `all_enqueued` counts, never returned job ids (unique-conflict returns the attempted job — repo gotcha).
- Events exactly: `"requested"` → wholesaler owners; `"approved"`/`"rejected"` → reseller owners. Owner = `StoreMembership` role `:owner` for the target store.
- One channel failing never blocks the others; job returns `:ok` when fan-out ran; missing connection/recipients → log + `:ok`.
- WhatsApp template name: `"supply_connection_update"`.

---

### Task 1: Templates copy

**Files:**
- Modify: `lib/emakola/notifications/templates.ex`
- Test: `test/emakola/notifications/templates_test.exs` (append; create the file mirroring existing template tests if it does not exist — check first)

**Interfaces:**
- Produces (consumed verbatim by Task 2):
  - `Templates.connection_sms(:requested | :approved | :rejected, counterparty_name :: String.t()) :: String.t()`
  - `Templates.connection_push(:requested | :approved | :rejected, counterparty_name) :: %{title: String.t(), body: String.t()}`
  - `Templates.connection_whatsapp_params(event, counterparty_name) :: map()` and the template name constant via `whatsapp_template_for(:supply_connection)` returning `"supply_connection_update"`.

- [ ] **Step 1: Write the failing tests** (append/create; mirror the file's existing style):

```elixir
  describe "connection notifications copy" do
    test "requested SMS names the reseller and points at the Earn Network page" do
      msg = Emakola.Notifications.Templates.connection_sms(:requested, "Adwoa's Boutique")
      assert msg =~ "Adwoa's Boutique"
      assert msg =~ "wants to stock your products"
      assert msg =~ "/admin/settings/supply-network"
    end

    test "approved SMS names the wholesaler and points at the catalog" do
      msg = Emakola.Notifications.Templates.connection_sms(:approved, "Kumasi Textiles")
      assert msg =~ "Kumasi Textiles"
      assert msg =~ "approved your connection"
      assert msg =~ "/admin/supply/catalog"
    end

    test "rejected SMS is honest and non-dead-end" do
      msg = Emakola.Notifications.Templates.connection_sms(:rejected, "Kumasi Textiles")
      assert msg =~ "declined"
      assert msg =~ "/admin/supply/catalog"
    end

    test "push payloads carry event-appropriate titles" do
      assert %{title: "New supply request", body: body} =
               Emakola.Notifications.Templates.connection_push(:requested, "Adwoa's Boutique")

      assert body =~ "Adwoa's Boutique"

      assert %{title: "Connection approved"} =
               Emakola.Notifications.Templates.connection_push(:approved, "Kumasi Textiles")

      assert %{title: "Connection declined"} =
               Emakola.Notifications.Templates.connection_push(:rejected, "Kumasi Textiles")
    end

    test "whatsapp template name and params" do
      assert Emakola.Notifications.Templates.whatsapp_template_for(:supply_connection) ==
               "supply_connection_update"

      params = Emakola.Notifications.Templates.connection_whatsapp_params(:requested, "Adwoa's Boutique")
      assert is_map(params)
    end
  end
```

- [ ] **Step 2: Run to verify failure** — `mix test test/emakola/notifications/templates_test.exs` → undefined-function failures.

- [ ] **Step 3: Implement** in `templates.ex` (match the module's existing style; compose absolute URLs with the SAME host helper pattern the module already uses for storefront URLs — if only a storefront host helper exists, add an `admin_url/1` private using the endpoint host, mirroring how `storefront_host/0` is built):

```elixir
  def connection_sms(:requested, counterparty) do
    "#{counterparty} wants to stock your products. Review the request on your Earn Network page: #{admin_url("/admin/settings/supply-network")}"
  end

  def connection_sms(:approved, counterparty) do
    "#{counterparty} approved your connection. Wholesale pricing is now visible in your Supplier Catalog: #{admin_url("/admin/supply/catalog")}"
  end

  def connection_sms(:rejected, counterparty) do
    "#{counterparty} declined your connection request. You can browse other suppliers in the Supplier Catalog: #{admin_url("/admin/supply/catalog")}"
  end

  def connection_push(:requested, counterparty),
    do: %{title: "New supply request", body: "#{counterparty} wants to stock your products."}

  def connection_push(:approved, counterparty),
    do: %{title: "Connection approved", body: "#{counterparty} approved your connection — wholesale pricing is unlocked."}

  def connection_push(:rejected, counterparty),
    do: %{title: "Connection declined", body: "#{counterparty} declined your connection request."}

  def whatsapp_template_for(:supply_connection), do: "supply_connection_update"

  def connection_whatsapp_params(event, counterparty) do
    %{
      "counterparty" => counterparty,
      "event" => to_string(event),
      "url" => admin_url(destination_path(event))
    }
  end

  defp destination_path(:requested), do: "/admin/settings/supply-network"
  defp destination_path(_), do: "/admin/supply/catalog"
```

(Place `whatsapp_template_for(:supply_connection)` beside the existing `whatsapp_template_for/1` clauses.)

- [ ] **Step 4: Green + commit**

```bash
mix format && mix test test/emakola/notifications/templates_test.exs
git add -A && git commit -m "feat(notifications): connection notification copy"
```

---

### Task 2: ConnectionNotificationWorker

**Files:**
- Create: `lib/emakola/notifications/workers/connection_notification_worker.ex`
- Test: `test/emakola/notifications/workers/connection_notification_worker_test.exs` (create; mirror the setup style of the existing worker tests in that directory — read one first)

**Interfaces:**
- Consumes: Task 1's Templates functions; `Channels.SMS.send_sms/3`; `Channels.WhatsApp.send_message/4`; the push-provider invocation + device-token resolution pattern from `PushNotificationWorker` (read it; if `device_tokens_for_store/1` is private, replicate its query — do NOT change that worker).
- Produces: `ConnectionNotificationWorker.perform/1` on args `%{"connection_id", "event"}`; `new/1` job changeset used by Task 3.

- [ ] **Step 1: Write the failing tests.** Setup builds (via `Emakola.Factory`): wholesaler merchant+store (owner membership, merchant with `phone: "+233240000001"`), reseller merchant+store likewise, a `SupplyConnection` between them (use `Emakola.Suppliers.Network.request/2` then `approve/2` where the event needs it — requested-event tests use the pending connection). Cases:

```elixir
  test "requested: notifies wholesaler owners on all three channels with reseller name"
  # expect SMSProviderMock delivery to the WHOLESALER merchant's phone, message =~ reseller store name
  # expect WhatsAppProviderMock send with template "supply_connection_update"
  # expect PushProviderMock for the wholesaler store's device token (register one via the device_token resource/factory)

  test "approved: notifies reseller owners, copy names the wholesaler"

  test "rejected: notifies reseller owners with declined copy"

  test "missing phone skips SMS and WhatsApp but still pushes"
  # build the recipient merchant without phone; expect ONLY the push mock

  test "one channel raising does not block the others and the job returns :ok"
  # stub SMS mock to raise; expect WhatsApp + push still called; assert perform returns :ok

  test "missing connection returns :ok and sends nothing"
  # perform with a random uuid; no mock expectations
```

Write real assertions with `Mox.expect` against the three provider mocks — read `config/test.exs:90-92` mock names and ONE existing worker test for the exact provider callback signatures (e.g. what function the SMS provider behaviour defines) before writing expectations; the expectations must be against the PROVIDER behaviours (the channels call through them), not against the channel modules.

- [ ] **Step 2: Run to verify failure** — module undefined.

- [ ] **Step 3: Implement** — `connection_notification_worker.ex`:

```elixir
defmodule Emakola.Notifications.Workers.ConnectionNotificationWorker do
  @moduledoc """
  Notifies the counterparty of a supply-connection lifecycle event on all
  channels, best-effort per channel:

    * "requested" → the wholesaler store's owners (a reseller wants in)
    * "approved" / "rejected" → the reseller store's owners (the decision)

  Enqueued by Emakola.Suppliers.Network after the domain write succeeds.
  Unique per (connection_id, event); missing data logs and returns :ok.
  """
  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [keys: [:connection_id, :event]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.{Channels, Templates}

  @events ~w(requested approved rejected)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"connection_id" => id, "event" => event}})
      when event in @events do
    case load_connection(id) do
      nil ->
        Logger.warning("[ConnectionNotificationWorker] connection #{id} not found; skipping")
        :ok

      connection ->
        deliver(connection, event)
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("[ConnectionNotificationWorker] unknown args: #{inspect(args)}")
    :ok
  end

  defp deliver(connection, event) do
    {target_store_id, counterparty_name} = routing(connection, event)
    event_atom = String.to_existing_atom(event)
    recipients = owner_merchants(target_store_id)

    if recipients == [] do
      Logger.warning(
        "[ConnectionNotificationWorker] no owner recipients for store #{target_store_id}"
      )
    end

    Enum.each(recipients, fn merchant ->
      attempt(fn -> send_sms(merchant, event_atom, counterparty_name) end, "sms")
      attempt(fn -> send_whatsapp(merchant, event_atom, counterparty_name) end, "whatsapp")
    end)

    attempt(fn -> send_push(target_store_id, event_atom, counterparty_name, connection) end, "push")

    :ok
  end

  defp routing(connection, "requested"),
    do: {connection.wholesaler_store_id, connection.reseller_store.name}

  defp routing(connection, _decision),
    do: {connection.reseller_store_id, connection.wholesaler_store.name}

  defp attempt(fun, channel) do
    fun.()
  rescue
    exception ->
      Logger.error(
        "[ConnectionNotificationWorker] #{channel} delivery failed: #{Exception.message(exception)}"
      )
  end

  defp send_sms(%{phone: phone}, event, counterparty) when is_binary(phone) do
    Channels.SMS.send_sms(phone, Templates.connection_sms(event, counterparty))
  end

  defp send_sms(_merchant, _event, _counterparty), do: :ok

  defp send_whatsapp(%{phone: phone}, event, counterparty) when is_binary(phone) do
    Channels.WhatsApp.send_message(
      phone,
      Templates.whatsapp_template_for(:supply_connection),
      Templates.connection_whatsapp_params(event, counterparty),
      []
    )
  end

  defp send_whatsapp(_merchant, _event, _counterparty), do: :ok

  # send_push/4: resolve the store's device tokens and deliver
  # Templates.connection_push(event, counterparty) with data
  # %{"connection_id" => connection.id, "event" => to_string(event)} —
  # MIRROR PushNotificationWorker's provider invocation exactly (read it;
  # same provider lookup, same token iteration, same error handling).

  defp load_connection(id) do
    Emakola.Suppliers.SupplyConnection
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load([:wholesaler_store, :reseller_store])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, connection} -> connection
      _ -> nil
    end
  end

  defp owner_merchants(store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(store_id == ^store_id and role == :owner)
    |> Ash.Query.load(:merchant)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.merchant)
  end
end
```

The `send_push/4` body and the exact `owner_merchants` load (relationship name for merchant on StoreMembership — VERIFY against the resource; adapt if it differs) are the two mirror-points: read the sibling worker/resource first, keep the shown structure.

- [ ] **Step 4: Green + commit**

```bash
mix format && mix test test/emakola/notifications/workers/connection_notification_worker_test.exs
MIX_ENV=test mix compile --warnings-as-errors
git add -A && git commit -m "feat(notifications): connection notification worker fans out all channels"
```

---

### Task 3: Network enqueues

**Files:**
- Modify: `lib/emakola/suppliers/network.ex`
- Test: `test/emakola/suppliers/network_test.exs` (append describe; read its setup first)

**Interfaces:**
- Consumes: Task 2's worker (`ConnectionNotificationWorker.new/1`).
- Produces: `request/2`, `approve/2`, `reject/3` enqueue their event after success; enqueue failure never changes the service result.

- [ ] **Step 1: Write the failing tests** (use `Oban.Testing` — check how other service tests set it up; `use Oban.Testing, repo: Emakola.Repo`):

```elixir
  describe "connection notifications" do
    test "request enqueues a requested notification", ctx do
      {:ok, conn} = Network.request(ctx.reseller_actor, %{...})

      assert [job] =
               all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)

      assert job.args["connection_id"] == conn.id
      assert job.args["event"] == "requested"
    end

    test "approve enqueues approved; reject enqueues rejected", ctx do
      # request, drain/clear, approve → assert exactly one approved job
      # separate connection: request then reject → rejected job
    end

    test "no duplicate jobs for the same connection+event", ctx do
      # request twice (second fails :connection_exists) → still exactly one requested job
    end
  end
```

Fill `%{...}` and ctx from the file's existing setup/fixtures. For "clear" between phases, filter `all_enqueued` by args instead of draining if the harness makes draining awkward.

- [ ] **Step 2: Run to verify failure** — zero jobs enqueued.

- [ ] **Step 3: Implement** — in `network.ex`, add a private and call it in each success path (thread the returned connection through unchanged):

```elixir
  defp notify(connection, event) do
    %{connection_id: connection.id, event: event}
    |> Emakola.Notifications.Workers.ConnectionNotificationWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        require Logger
        Logger.error("[Network] notification enqueue failed: #{inspect(reason)}")
        :ok
    end

    connection
  end
```

Wire: in `request/2`'s success return `{:ok, notify(connection, "requested")}` (adapt to the actual success shape); `approve/2` → `"approved"`; `reject/3` → `"rejected"`. Touch nothing else (suspend/terminate/reactivate stay silent).

- [ ] **Step 4: Green + commit**

```bash
mix format && mix test test/emakola/suppliers/network_test.exs
git add -A && git commit -m "feat(catalog): connection lifecycle enqueues counterparty notifications"
```

---

### Task 4: LiveView seal + full gates

**Files:**
- Test: `test/emakola_web/live/admin/supply_catalog_live_test.exs` (append one test to the existing "catalog show" describe)

- [ ] **Step 1: Write the test** (should pass immediately — integration seal; if it fails, that failure is a real bug: diagnose, fix minimally, document):

```elixir
    test "request_connection enqueues the wholesaler notification", %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      view |> element("button[phx-click=request_connection]") |> render_click()

      assert [job] =
               all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)

      assert job.args["event"] == "requested"
    end
```

(Add `use Oban.Testing, repo: Emakola.Repo` to the test module if absent.)

- [ ] **Step 1b: LAUNCH_TODO** — in `LAUNCH_TODO.md`, find the WhatsApp template submission item (§1, "Submit the 6 WhatsApp templates") and amend it to include the new `supply_connection_update` business-initiated template (e.g. change the count and add it to whatever list/parenthetical enumerates them; read the item first and match its style). One-line change.

- [ ] **Step 2: Full gates (ALL FOREGROUND)**

```bash
mix format --check-formatted
mix credo --strict lib/emakola/notifications/templates.ex lib/emakola/notifications/workers/connection_notification_worker.ex lib/emakola/suppliers/network.ex
MIX_ENV=test mix compile --warnings-as-errors
mix test 2>&1 | tail -3   # parse the Result: line — exit code lies
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "test(catalog): connection request seals the notification pipeline"
```

Do NOT push or open a PR — the controller runs the whole-branch review first.
