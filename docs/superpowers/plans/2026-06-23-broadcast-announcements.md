# Broadcast Announcements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let platform staff broadcast a scheduled, multi-channel (in-app banner + email + SMS + WhatsApp), status-targeted announcement to merchants.

**Architecture:** Two new platform-owned resources in the `Notifications` domain (`Announcement`, `AnnouncementDismissal`). A scheduled `AnnouncementPublishWorker` flips status at `publish_at` and fans out one `AnnouncementDeliveryWorker` per target store for external channels; the in-app banner is query-driven (derived "active" — no expiry cron). A merchant `on_mount` hook (mirroring `NotificationHandler`) assigns active, non-dismissed announcements and handles the dismiss event; a platform LiveView creates/cancels them.

**Tech Stack:** Elixir 1.18, Ash 3.x + AshPostgres, Oban, Phoenix LiveView, Mox, ExUnit, TailwindCSS.

**Spec:** `docs/superpowers/specs/2026-06-23-broadcast-announcements-design.md`

**Conventions to honor:** TDD (test first); platform-only writes = `forbid_if(always())` policy + call with `authorize?: false`; never `String.to_atom`/`to_existing_atom` on user input (use `Emakola.SafeAtom.to_atom_in/3` or explicit string→atom maps); `require Ash.Query` wherever the `filter` macro is used; commit messages end with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`; stage only this feature's files with explicit `git add <paths>` (a concurrent session's WIP is parked in `git stash`).

---

## File Structure

**Create:**
- `lib/emakola/notifications/resources/announcement.ex` — the broadcast record (content, schedule, targeting, status; derived `:active_for_store` read).
- `lib/emakola/notifications/resources/announcement_dismissal.ex` — per-merchant banner dismissal (idempotent upsert).
- `lib/emakola/notifications/workers/announcement_publish_worker.ex` — scheduled publish + per-store delivery fan-out.
- `lib/emakola/notifications/workers/announcement_delivery_worker.ex` — per-store external channel send.
- `lib/emakola_web/hooks/merchant_announcements.ex` — `on_mount` hook: assigns active announcements + handles dismiss.
- `lib/emakola_web/live/platform/announcement_live/index.ex` — platform create/list/cancel page.
- Tests mirroring each of the above under `test/`.

**Modify:**
- `lib/emakola/notifications/notifications.ex` — register the two resources + code interfaces.
- `lib/emakola/accounts/platform_permissions.ex` — add `:manage_announcements`.
- `lib/emakola/accounts/resources/platform_audit_log.ex` — add `:announcement_published`, `:announcement_canceled`.
- `lib/emakola_web/components/layouts/audit_log_components.ex` — severity colors for the two atoms.
- `lib/emakola/notifications/channels/whatsapp.ex` — add `"announcement" => [:title]` to `@template_param_order`.
- `lib/emakola_web/router.ex` — route in `:platform`; add `MerchantAnnouncements` hook to `:app`.
- `lib/emakola_web/components/layouts/app.html.heex` — banner component.
- `lib/emakola_web/components/layouts/platform.html.heex` — "Announcements" nav link.

---

## Task 1: `Announcement` + `AnnouncementDismissal` resources + interfaces

**Files:**
- Create: `lib/emakola/notifications/resources/announcement.ex`
- Create: `lib/emakola/notifications/resources/announcement_dismissal.ex`
- Modify: `lib/emakola/notifications/notifications.ex`
- Test: `test/emakola/notifications/announcement_test.exs`

- [ ] **Step 1: Write the failing resource test**

Create `test/emakola/notifications/announcement_test.exs`:

```elixir
defmodule Emakola.Notifications.AnnouncementTest do
  @moduledoc """
  Platform broadcast announcement: scheduling, the derived `:active_for_store`
  window/audience query, cancel, and idempotent per-merchant dismissal.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Notifications

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        title: "Scheduled maintenance",
        body: "We will be down Sunday 2am.",
        channels: [:banner, :email],
        audience: :all,
        publish_at: ~U[2026-06-20 00:00:00Z]
      },
      overrides
    )
  end

  defp create!(overrides \\ %{}) do
    {:ok, ann} = Notifications.create_announcement(valid_attrs(overrides), authorize?: false)
    ann
  end

  describe "create_announcement" do
    test "defaults to :scheduled status and :info severity" do
      ann = create!()
      assert ann.status == :scheduled
      assert ann.severity == :info
      assert ann.channels == [:banner, :email]
    end

    test "requires at least one channel" do
      assert {:error, _} =
               Notifications.create_announcement(valid_attrs(%{channels: []}), authorize?: false)
    end
  end

  describe "publish / cancel" do
    test "publish flips status to :published" do
      ann = create!()
      {:ok, published} = Notifications.publish_announcement(ann, authorize?: false)
      assert published.status == :published
    end

    test "cancel flips status to :canceled" do
      ann = create!()
      {:ok, canceled} = Notifications.cancel_announcement(ann, authorize?: false)
      assert canceled.status == :canceled
    end
  end

  describe "active_for_store (derived window + audience)" do
    @now ~U[2026-06-23 12:00:00Z]

    defp publish!(overrides) do
      overrides |> create!() |> then(&elem(Notifications.publish_announcement(&1, authorize?: false), 1))
    end

    defp active_ids(store_live) do
      {:ok, list} =
        Notifications.list_active_announcements(store_live, @now, authorize?: false)

      Enum.map(list, & &1.id)
    end

    test "includes a published, in-window, audience :all announcement" do
      ann = publish!(%{audience: :all, publish_at: ~U[2026-06-22 00:00:00Z]})
      assert ann.id in active_ids(false)
    end

    test "excludes scheduled (not yet published) announcements" do
      ann = create!(%{publish_at: ~U[2026-06-22 00:00:00Z]})
      refute ann.id in active_ids(true)
    end

    test "excludes announcements whose expires_at has passed" do
      ann =
        publish!(%{publish_at: ~U[2026-06-20 00:00:00Z], expires_at: ~U[2026-06-22 00:00:00Z]})

      refute ann.id in active_ids(true)
    end

    test "audience :active shows only when the store is live" do
      ann = publish!(%{audience: :active, publish_at: ~U[2026-06-22 00:00:00Z]})
      refute ann.id in active_ids(false)
      assert ann.id in active_ids(true)
    end
  end

  describe "dismissals" do
    test "dismiss is an idempotent upsert; ids are listed per merchant" do
      ann = create!()
      merchant_id = Ash.UUID.generate()

      {:ok, _} =
        Notifications.dismiss_announcement(
          %{announcement_id: ann.id, merchant_id: merchant_id},
          authorize?: false
        )

      {:ok, _} =
        Notifications.dismiss_announcement(
          %{announcement_id: ann.id, merchant_id: merchant_id},
          authorize?: false
        )

      {:ok, ids} =
        Notifications.list_dismissed_announcement_ids(merchant_id, authorize?: false)

      assert ids == [ann.id]
    end
  end
end
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `mix test test/emakola/notifications/announcement_test.exs`
Expected: FAIL — `Notifications.create_announcement/2` undefined.

- [ ] **Step 3: Create the `Announcement` resource**

Create `lib/emakola/notifications/resources/announcement.ex`:

```elixir
defmodule Emakola.Notifications.Announcement do
  @moduledoc """
  A platform→merchant broadcast: shown to merchants as a dismissible in-app
  banner and optionally pushed over email / SMS / WhatsApp.

  Platform-owned (NOT tenant-scoped). Created by platform staff; merchants only
  read it (banner) and dismiss it. "Active for a store" is DERIVED from status +
  the publish/expiry window + audience, so no expiry job is needed.

  Distinct from `Emakola.Notifications.Notification` (the per-user notification
  bell): this is a broadcast, not a per-recipient row.
  """
  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("announcements")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 200)
    end

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 2000)
    end

    attribute :severity, :atom do
      allow_nil?(false)
      default(:info)
      constraints(one_of: [:info, :warning, :critical])
      public?(true)
    end

    attribute :channels, {:array, :atom} do
      allow_nil?(false)
      constraints(min_length: 1, items: [one_of: [:banner, :email, :sms, :whatsapp]])
      public?(true)
    end

    attribute :audience, :atom do
      allow_nil?(false)
      default(:all)
      constraints(one_of: [:all, :active])
      public?(true)
    end

    attribute :publish_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
    end

    attribute :expires_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :status, :atom do
      allow_nil?(false)
      default(:scheduled)
      constraints(one_of: [:scheduled, :published, :canceled])
      public?(true)
    end

    timestamps()
  end

  policies do
    # Reads run with authorize?: false (banner hook, workers, platform admin).
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    # All writes are platform-only — callable solely via authorize?: false from
    # the gated platform admin / workers.
    policy action_type([:create, :update]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:title, :body, :severity, :channels, :audience, :publish_at, :expires_at])
    end

    update :publish do
      accept([])
      change(set_attribute(:status, :published))
    end

    update :cancel do
      accept([])
      change(set_attribute(:status, :canceled))
    end

    # Derived "active for a viewing store": published, inside the publish/expiry
    # window at `as_of`, and either audience :all or (audience :active and the
    # viewing store is live). `as_of` is passed in (testable; no `now()`).
    read :active_for_store do
      argument :store_live, :boolean, allow_nil?: false
      argument :as_of, :utc_datetime_usec, allow_nil?: false

      filter(
        expr(
          status == :published and
            publish_at <= ^arg(:as_of) and
            (is_nil(expires_at) or expires_at > ^arg(:as_of)) and
            (audience == :all or (audience == :active and ^arg(:store_live)))
        )
      )

      prepare(build(sort: [publish_at: :desc]))
    end

    read :list_for_admin do
      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
```

- [ ] **Step 4: Create the `AnnouncementDismissal` resource**

Create `lib/emakola/notifications/resources/announcement_dismissal.ex`:

```elixir
defmodule Emakola.Notifications.AnnouncementDismissal do
  @moduledoc """
  Records that a merchant dismissed an announcement banner. One row per
  (announcement, merchant) — re-dismissing is an idempotent upsert. Writes run
  with authorize?: false from the merchant banner hook (merchant_id is taken
  from the server-side session, never from request params).
  """
  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("announcement_dismissals")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :announcement_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :merchant_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_dismissal, [:announcement_id, :merchant_id])
  end

  policies do
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    policy action_type([:create, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :dismiss do
      upsert?(true)
      upsert_identity(:unique_dismissal)
      accept([:announcement_id, :merchant_id])
    end

    read :dismissed_ids_for_merchant do
      argument :merchant_id, :uuid, allow_nil?: false
      filter(expr(merchant_id == ^arg(:merchant_id)))
    end
  end
end
```

- [ ] **Step 5: Register resources + code interfaces**

In `lib/emakola/notifications/notifications.ex`, inside the `resources do` block (after the `EmailLog` resource block, before the closing `end`), add:

```elixir
    resource Emakola.Notifications.Announcement do
      define(:create_announcement, action: :create)
      define(:publish_announcement, action: :publish)
      define(:cancel_announcement, action: :cancel)
      define(:get_announcement, action: :read, get_by: [:id])
      define(:list_announcements_for_admin, action: :list_for_admin)
      define(:list_active_announcements, action: :active_for_store, args: [:store_live, :as_of])
    end

    resource Emakola.Notifications.AnnouncementDismissal do
      define(:dismiss_announcement, action: :dismiss)

      define(:list_dismissed_announcement_ids,
        action: :dismissed_ids_for_merchant,
        args: [:merchant_id]
      )
    end
```

Note: `list_dismissed_announcement_ids` returns full records; the test maps `& &1.id`. To return ids directly is optional — keep it returning records for simplicity (the hook maps ids in memory).

- [ ] **Step 6: Generate and trim the migration**

Run: `mix ash.codegen add_announcements`

Then **trim the generated migration** to ONLY the two new tables (`announcements`, `announcement_dismissals`) and their indexes/constraints. Per `[[emakola-codegen-migration-format]]`: if codegen bundles unrelated snapshot drift (e.g. `phone_otps`, `merchant_identities`), delete those hunks from the migration and `git checkout priv/resource_snapshots/<foreign resources>` so only the new snapshots remain. Also split any `references(...), null: false` one-liner so `null: false` sits on its own line (Elixir-1.18 formatter).

Run: `mix ecto.migrate`
Expected: creates `announcements` + `announcement_dismissals`.

- [ ] **Step 7: Run the test to confirm it passes**

Run: `mix test test/emakola/notifications/announcement_test.exs`
Expected: PASS (all cases).

- [ ] **Step 8: Format + commit**

```bash
mix format lib/emakola/notifications/resources/announcement.ex lib/emakola/notifications/resources/announcement_dismissal.ex lib/emakola/notifications/notifications.ex test/emakola/notifications/announcement_test.exs
git add lib/emakola/notifications/resources/announcement.ex \
        lib/emakola/notifications/resources/announcement_dismissal.ex \
        lib/emakola/notifications/notifications.ex \
        test/emakola/notifications/announcement_test.exs \
        priv/repo/migrations/*_add_announcements.exs \
        priv/resource_snapshots/repo/announcements/ \
        priv/resource_snapshots/repo/announcement_dismissals/
git commit -m "feat(notifications): announcement + dismissal resources

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Publish + delivery workers

**Files:**
- Create: `lib/emakola/notifications/workers/announcement_publish_worker.ex`
- Create: `lib/emakola/notifications/workers/announcement_delivery_worker.ex`
- Test: `test/emakola/notifications/workers/announcement_publish_worker_test.exs`
- Test: `test/emakola/notifications/workers/announcement_delivery_worker_test.exs`

- [ ] **Step 1: Write the failing publish-worker test**

Create `test/emakola/notifications/workers/announcement_publish_worker_test.exs`:

```elixir
defmodule Emakola.Notifications.Workers.AnnouncementPublishWorkerTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Factory
  alias Emakola.Notifications
  alias Emakola.Notifications.Workers.AnnouncementDeliveryWorker
  alias Emakola.Notifications.Workers.AnnouncementPublishWorker, as: Worker

  defp announcement!(overrides) do
    {:ok, ann} =
      Notifications.create_announcement(
        Map.merge(
          %{
            title: "Hi",
            body: "Body",
            channels: [:banner, :sms],
            audience: :all,
            publish_at: ~U[2026-06-20 00:00:00Z]
          },
          overrides
        ),
        authorize?: false
      )

    ann
  end

  test "enqueue schedules a job at publish_at" do
    {:ok, _} = Worker.enqueue("abc", ~U[2026-07-01 00:00:00Z])
    assert_enqueued(worker: Worker, args: %{"announcement_id" => "abc"})
  end

  test "perform publishes a scheduled announcement and enqueues one delivery per target store" do
    store_a = Factory.create_store!()
    store_b = Factory.create_store!()
    ann = announcement!(%{channels: [:sms], audience: :all})

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id})

    {:ok, reloaded} = Notifications.get_announcement(ann.id, authorize?: false)
    assert reloaded.status == :published

    assert_enqueued(worker: AnnouncementDeliveryWorker, args: %{"announcement_id" => ann.id, "store_id" => store_a.id})
    assert_enqueued(worker: AnnouncementDeliveryWorker, args: %{"announcement_id" => ann.id, "store_id" => store_b.id})
  end

  test "audience :active skips non-live stores" do
    live = Factory.create_store!()
    archived = Factory.create_store!(%{status: :archived})
    ann = announcement!(%{channels: [:sms], audience: :active})

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id})

    assert_enqueued(worker: AnnouncementDeliveryWorker, args: %{"announcement_id" => ann.id, "store_id" => live.id})
    refute_enqueued(worker: AnnouncementDeliveryWorker, args: %{"announcement_id" => ann.id, "store_id" => archived.id})
  end

  test "banner-only announcements enqueue no delivery jobs" do
    Factory.create_store!()
    ann = announcement!(%{channels: [:banner]})

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id})
    refute_enqueued(worker: AnnouncementDeliveryWorker)
  end

  test "a canceled announcement is a no-op" do
    Factory.create_store!()
    ann = announcement!(%{channels: [:sms]})
    {:ok, _} = Notifications.cancel_announcement(ann, authorize?: false)

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id})
    refute_enqueued(worker: AnnouncementDeliveryWorker)
    {:ok, reloaded} = Notifications.get_announcement(ann.id, authorize?: false)
    assert reloaded.status == :canceled
  end
end
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `mix test test/emakola/notifications/workers/announcement_publish_worker_test.exs`
Expected: FAIL — module `AnnouncementPublishWorker` undefined.

- [ ] **Step 3: Implement the publish worker**

Create `lib/emakola/notifications/workers/announcement_publish_worker.ex`:

```elixir
defmodule Emakola.Notifications.Workers.AnnouncementPublishWorker do
  @moduledoc """
  Publishes a scheduled announcement at its `publish_at`: flips status to
  :published and fans out one `AnnouncementDeliveryWorker` per target store for
  the external channels. The in-app banner is query-driven and needs no job.

  Idempotent: a :canceled or already-:published announcement is a no-op.
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3, unique: [period: 600, fields: [:args]]

  require Ash.Query

  alias Emakola.Notifications
  alias Emakola.Notifications.Workers.AnnouncementDeliveryWorker

  @external_channels [:email, :sms, :whatsapp]

  @spec enqueue(binary(), DateTime.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(announcement_id, %DateTime{} = publish_at) when is_binary(announcement_id) do
    %{"announcement_id" => announcement_id}
    |> new(scheduled_at: publish_at)
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"announcement_id" => id}}) do
    case Notifications.get_announcement(id, authorize?: false) do
      {:ok, %{status: :scheduled} = ann} ->
        {:ok, published} = Notifications.publish_announcement(ann, authorize?: false)
        enqueue_deliveries(published)
        :ok

      {:ok, _other_status} ->
        :ok

      {:error, _} ->
        {:error, :announcement_not_found}
    end
  end

  defp enqueue_deliveries(%{channels: channels} = ann) do
    if Enum.any?(channels, &(&1 in @external_channels)) do
      Enum.each(target_store_ids(ann), &AnnouncementDeliveryWorker.enqueue(ann.id, &1))
    end

    :ok
  end

  defp target_store_ids(%{audience: :active}) do
    Emakola.Stores.Store
    |> Ash.Query.filter(active == true and status == :active)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  defp target_store_ids(%{audience: :all}) do
    Emakola.Stores.Store
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end
end
```

- [ ] **Step 4: Write the failing delivery-worker test**

Create `test/emakola/notifications/workers/announcement_delivery_worker_test.exs`:

```elixir
defmodule Emakola.Notifications.Workers.AnnouncementDeliveryWorkerTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo
  import Mox

  alias Emakola.Factory
  alias Emakola.Notifications
  alias Emakola.Notifications.Workers.AnnouncementDeliveryWorker, as: Worker

  setup :verify_on_exit!

  defp announcement!(channels) do
    {:ok, ann} =
      Notifications.create_announcement(
        %{
          title: "Heads up",
          body: "Big news for your store.",
          channels: channels,
          audience: :all,
          publish_at: ~U[2026-06-20 00:00:00Z]
        },
        authorize?: false
      )

    ann
  end

  test "sends SMS to a store with a contact phone" do
    store = Factory.create_store!(%{contact_phone: "+233201234567"})
    ann = announcement!([:sms])

    expect(Emakola.SMSProviderMock, :send_sms, fn to, message, _opts ->
      assert to == "+233201234567"
      assert message =~ "Big news"
      {:ok, %{}}
    end)

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id, "store_id" => store.id})
  end

  test "skips SMS when the store has no contact phone" do
    store = Factory.create_store!(%{contact_phone: nil, contact_email: nil})
    ann = announcement!([:sms])
    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id, "store_id" => store.id})
  end

  test "treats an unknown WhatsApp template as a skipped channel (no job failure)" do
    store = Factory.create_store!(%{whatsapp_number: "+233201234567"})
    ann = announcement!([:whatsapp])

    expect(Emakola.WhatsAppProviderMock, :send_message, fn _to, "announcement", _params, _opts ->
      {:error, {:unknown_template, "announcement"}}
    end)

    assert :ok = perform_job(Worker, %{"announcement_id" => ann.id, "store_id" => store.id})
  end

  test "fails the job when an attempted channel errors transiently (so Oban retries)" do
    store = Factory.create_store!(%{contact_phone: "+233201234567"})
    ann = announcement!([:sms])

    expect(Emakola.SMSProviderMock, :send_sms, fn _to, _msg, _opts -> {:error, :provider_down} end)

    assert {:error, _} =
             perform_job(Worker, %{"announcement_id" => ann.id, "store_id" => store.id})
  end
end
```

- [ ] **Step 5: Run it to confirm it fails**

Run: `mix test test/emakola/notifications/workers/announcement_delivery_worker_test.exs`
Expected: FAIL — module `AnnouncementDeliveryWorker` undefined.

- [ ] **Step 6: Implement the delivery worker**

Create `lib/emakola/notifications/workers/announcement_delivery_worker.ex`:

```elixir
defmodule Emakola.Notifications.Workers.AnnouncementDeliveryWorker do
  @moduledoc """
  Delivers one announcement to one store over its selected external channels
  (email / SMS / WhatsApp), skipping a channel the store hasn't filled in.

  Mirrors `StoreStatusNotificationWorker`: per-store retry isolation, no
  double-sends. A permanently-unknown WhatsApp template is treated as a SKIPPED
  channel (logged, :ok) so the job never wedges; a transient channel error fails
  the job so Oban retries.
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3, unique: [period: 600, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications

  @spec enqueue(binary(), binary()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(announcement_id, store_id) when is_binary(announcement_id) and is_binary(store_id) do
    %{"announcement_id" => announcement_id, "store_id" => store_id}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"announcement_id" => ann_id, "store_id" => store_id}}) do
    with {:ok, ann} <- Notifications.get_announcement(ann_id, authorize?: false),
         {:ok, store} <- load_store(store_id) do
      results = Enum.map(ann.channels, &send_channel(&1, ann, store))

      if Enum.any?(results, &match?({:error, _}, &1)) do
        Logger.error(
          "[AnnouncementDeliveryWorker] delivery failed for store #{store_id}: #{inspect(results)}"
        )

        {:error, :announcement_delivery_failed}
      else
        :ok
      end
    else
      {:error, _} -> {:error, :delivery_target_not_found}
    end
  end

  defp load_store(store_id) do
    case Emakola.Stores.get_store(store_id, authorize?: false) do
      {:ok, store} -> {:ok, store}
      _ -> {:error, :store_not_found}
    end
  end

  defp send_channel(:email, ann, store), do: maybe_send_email(ann, store)
  defp send_channel(:sms, ann, store), do: maybe_send_sms(ann, store)
  defp send_channel(:whatsapp, ann, store), do: maybe_send_whatsapp(ann, store)
  # :banner has no external send.
  defp send_channel(_other, _ann, _store), do: :ok

  defp maybe_send_sms(ann, %{contact_phone: phone} = store)
       when is_binary(phone) and phone != "" do
    sms_provider().send_sms(phone, ann.body, store_id: store.id)
  end

  defp maybe_send_sms(_ann, _store), do: :ok

  defp maybe_send_email(ann, %{contact_email: email} = store)
       when is_binary(email) and email != "" do
    Swoosh.Email.new()
    |> Swoosh.Email.to({store.name || "", email})
    |> Swoosh.Email.from(Emakola.Mailer.from_address("Makola"))
    |> Swoosh.Email.subject(ann.title)
    |> Swoosh.Email.text_body(ann.body)
    |> Emakola.Mailer.deliver()
  end

  defp maybe_send_email(_ann, _store), do: :ok

  defp maybe_send_whatsapp(ann, %{whatsapp_number: number} = store)
       when is_binary(number) and number != "" do
    case whatsapp_provider().send_message(number, "announcement", %{title: ann.title},
           store_id: store.id
         ) do
      {:ok, _} ->
        :ok

      {:error, {:unknown_template, _}} ->
        Logger.info(
          "[AnnouncementDeliveryWorker] whatsapp 'announcement' template not live; skipping store #{store.id}"
        )

        :ok

      {:error, _} = err ->
        err
    end
  end

  defp maybe_send_whatsapp(_ann, _store), do: :ok

  defp sms_provider,
    do: Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)

  defp whatsapp_provider,
    do:
      Application.get_env(
        :emakola,
        :whatsapp_provider,
        Emakola.Notifications.Providers.LogWhatsApp
      )
end
```

- [ ] **Step 7: Run both worker tests to confirm they pass**

Run: `mix test test/emakola/notifications/workers/announcement_publish_worker_test.exs test/emakola/notifications/workers/announcement_delivery_worker_test.exs`
Expected: PASS.

- [ ] **Step 8: Format + commit**

```bash
mix format lib/emakola/notifications/workers/announcement_publish_worker.ex lib/emakola/notifications/workers/announcement_delivery_worker.ex test/emakola/notifications/workers/announcement_publish_worker_test.exs test/emakola/notifications/workers/announcement_delivery_worker_test.exs
git add lib/emakola/notifications/workers/announcement_publish_worker.ex \
        lib/emakola/notifications/workers/announcement_delivery_worker.ex \
        test/emakola/notifications/workers/announcement_publish_worker_test.exs \
        test/emakola/notifications/workers/announcement_delivery_worker_test.exs
git commit -m "feat(notifications): announcement publish + delivery workers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Permission + audit atoms + WhatsApp template

**Files:**
- Modify: `lib/emakola/accounts/platform_permissions.ex`
- Modify: `lib/emakola/accounts/resources/platform_audit_log.ex`
- Modify: `lib/emakola_web/components/layouts/audit_log_components.ex`
- Modify: `lib/emakola/notifications/channels/whatsapp.ex`
- Test: `test/emakola/accounts/platform_permissions_test.exs` (add a case if the file exists; else assert inline in Task 5's LiveView test)

- [ ] **Step 1: Add the `:manage_announcements` permission**

In `lib/emakola/accounts/platform_permissions.ex`, add `:manage_announcements` to the `@permissions` module attribute list (after `:manage_settings`):

```elixir
  @permissions [
    :manage_stores,
    :manage_merchants,
    :manage_team,
    :manage_billing,
    :manage_settings,
    :manage_announcements
  ]
```

- [ ] **Step 2: Add audit atoms**

In `lib/emakola/accounts/resources/platform_audit_log.ex`, add the two atoms to the `one_of` list in the `:action` attribute constraints (after `:product_reinstated`):

```elixir
          :product_taken_down,
          :product_reinstated,
          :announcement_published,
          :announcement_canceled
```

- [ ] **Step 3: Add audit severity colors**

In `lib/emakola_web/components/layouts/audit_log_components.ex`, add `:announcement_published` to `@green_actions` and `:announcement_canceled` to `@amber_actions`:

```elixir
  @amber_actions [
    :session_revoked,
    :invite_revoked,
    :totp_disabled,
    :store_suspended,
    :impersonation_started,
    :announcement_canceled
  ]
  @green_actions [
    :sign_in_succeeded,
    :invite_accepted,
    :totp_enabled,
    :staff_reactivated,
    :store_reactivated,
    :verification_approved,
    :impersonation_ended,
    :product_reinstated,
    :announcement_published
  ]
```

- [ ] **Step 4: Register the WhatsApp `announcement` template**

In `lib/emakola/notifications/channels/whatsapp.ex`, add `"announcement" => [:title]` to the `@template_param_order` map (after `"auth_code" => [:code]`):

```elixir
  @template_param_order %{
    "order_placed" => @order_param_order,
    "order_confirmed" => @order_param_order,
    "order_shipped" => @order_param_order,
    "order_delivered" => @order_param_order,
    "order_cancelled" => @order_param_order,
    "supplier_fulfillment" => [:order_number, :supplier_name, :items, :ship_to],
    "auth_code" => [:code],
    "announcement" => [:title]
  }
```

- [ ] **Step 5: Verify compile + format**

Run: `mix compile --warnings-as-errors 2>&1 | tail -5`
Expected: compiles (no warnings from these files).

Run: `mix format lib/emakola/accounts/platform_permissions.ex lib/emakola/accounts/resources/platform_audit_log.ex lib/emakola_web/components/layouts/audit_log_components.ex lib/emakola/notifications/channels/whatsapp.ex`

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/accounts/platform_permissions.ex \
        lib/emakola/accounts/resources/platform_audit_log.ex \
        lib/emakola_web/components/layouts/audit_log_components.ex \
        lib/emakola/notifications/channels/whatsapp.ex
git commit -m "feat(notifications): announcement permission, audit atoms, whatsapp template

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Merchant banner hook + banner component

**Files:**
- Create: `lib/emakola_web/hooks/merchant_announcements.ex`
- Modify: `lib/emakola_web/router.ex` (add hook to `:app` live_session `on_mount`)
- Modify: `lib/emakola_web/components/layouts/app.html.heex` (banner)
- Test: `test/emakola_web/hooks/merchant_announcements_test.exs`

- [ ] **Step 1: Write the failing hook/banner LiveView test**

Create `test/emakola_web/hooks/merchant_announcements_test.exs`:

```elixir
defmodule EmakolaWeb.Hooks.MerchantAnnouncementsTest do
  @moduledoc """
  Merchant in-app announcement banner: an active announcement shows; dismissing
  it persists and hides it; scheduled/expired ones never show.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Notifications

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  defp publish!(overrides) do
    {:ok, ann} =
      Notifications.create_announcement(
        Map.merge(
          %{
            title: "Welcome to Payouts",
            body: "You can now add your payout details.",
            channels: [:banner],
            audience: :all,
            publish_at: ~U[2026-06-20 00:00:00Z]
          },
          overrides
        ),
        authorize?: false
      )

    {:ok, published} = Notifications.publish_announcement(ann, authorize?: false)
    published
  end

  test "an active banner announcement is shown", %{conn: conn} do
    publish!(%{title: "Active notice"})
    {:ok, _view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Active notice"
  end

  test "dismissing the banner hides it and persists", %{conn: conn, merchant: merchant} do
    ann = publish!(%{title: "Dismiss me"})

    {:ok, view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Dismiss me"

    html =
      view
      |> element("button[phx-value-id='#{ann.id}'][phx-click='dismiss_announcement']")
      |> render_click()

    refute html =~ "Dismiss me"

    {:ok, dismissals} =
      Notifications.list_dismissed_announcement_ids(merchant.id, authorize?: false)

    assert ann.id in Enum.map(dismissals, & &1.announcement_id)
  end

  test "a scheduled (unpublished) announcement is not shown", %{conn: conn} do
    {:ok, _scheduled} =
      Notifications.create_announcement(
        %{
          title: "Future notice",
          body: "Later.",
          channels: [:banner],
          audience: :all,
          publish_at: ~U[2026-06-20 00:00:00Z]
        },
        authorize?: false
      )

    {:ok, _view, html} = live(conn, ~p"/dashboard")
    refute html =~ "Future notice"
  end
end
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `mix test test/emakola_web/hooks/merchant_announcements_test.exs`
Expected: FAIL — the announcement text is not rendered (no banner/hook yet).

- [ ] **Step 3: Create the `MerchantAnnouncements` hook**

Create `lib/emakola_web/hooks/merchant_announcements.ex`:

```elixir
defmodule EmakolaWeb.Hooks.MerchantAnnouncements do
  @moduledoc """
  LiveView on_mount hook (merchant `:app` session) that assigns the active,
  non-dismissed platform announcements for the current store's banner and
  handles the `dismiss_announcement` event across all merchant LiveViews.

  Mounted after AssignDefaults (which sets current_merchant + current_store).
  Reads/writes use authorize?: false — merchant_id comes from the server-side
  session, never from request params.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  alias Emakola.Notifications
  alias Emakola.Stores.Store

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:announcements, load_announcements(socket))
      |> attach_hook(:merchant_announcements, :handle_event, &handle_dismiss/3)

    {:cont, socket}
  end

  defp handle_dismiss("dismiss_announcement", %{"id" => id}, socket) do
    merchant = socket.assigns[:current_merchant]

    if merchant do
      Notifications.dismiss_announcement(
        %{announcement_id: id, merchant_id: merchant.id},
        authorize?: false
      )
    end

    remaining = Enum.reject(socket.assigns.announcements, &(&1.id == id))
    {:halt, assign(socket, :announcements, remaining)}
  end

  defp handle_dismiss(_event, _params, socket), do: {:cont, socket}

  defp load_announcements(socket) do
    merchant = socket.assigns[:current_merchant]
    store = socket.assigns[:current_store]

    if merchant && store do
      store_live = Store.live?(store)

      with {:ok, active} <-
             Notifications.list_active_announcements(store_live, DateTime.utc_now(),
               authorize?: false
             ),
           {:ok, dismissed} <-
             Notifications.list_dismissed_announcement_ids(merchant.id, authorize?: false) do
        # dismissed are AnnouncementDismissal records — key by announcement_id,
        # NOT the dismissal row's own id.
        dismissed_ids = MapSet.new(dismissed, & &1.announcement_id)

        active
        |> Enum.filter(&(:banner in &1.channels))
        |> Enum.reject(&MapSet.member?(dismissed_ids, &1.id))
      else
        _ -> []
      end
    else
      []
    end
  end
end
```

- [ ] **Step 4: Register the hook in the `:app` live_session**

In `lib/emakola_web/router.ex`, add the hook to the `:app` live_session `on_mount` list (after `NotificationHandler`):

```elixir
    live_session :app,
      layout: {EmakolaWeb.Layouts, :app},
      on_mount: [
        {EmakolaWeb.Hooks.AssignDefaults, :default},
        {EmakolaWeb.Hooks.RequireAuth, :default},
        {EmakolaWeb.Hooks.RequireActiveStore, :default},
        {EmakolaWeb.Hooks.NotificationHandler, :default},
        {EmakolaWeb.Hooks.MerchantAnnouncements, :default}
      ] do
```

- [ ] **Step 5: Add the banner component to the app layout**

In `lib/emakola_web/components/layouts/app.html.heex`, immediately AFTER the impersonation banner block (the `<div :if={@impersonator} …>…</div>` ending near line 416), add:

```heex
      <div
        :for={announcement <- assigns[:announcements] || []}
        id={"announcement-#{announcement.id}"}
        class={[
          "flex items-start gap-3 px-4 py-3 text-sm border-b",
          announcement_classes(announcement.severity)
        ]}
      >
        <div class="flex-1 min-w-0">
          <p class="font-semibold">{announcement.title}</p>
          <p class="opacity-90">{announcement.body}</p>
        </div>
        <button
          type="button"
          phx-click="dismiss_announcement"
          phx-value-id={announcement.id}
          class="shrink-0 rounded-md px-2 py-1 text-xs font-medium hover:bg-black/10"
          aria-label="Dismiss announcement"
        >
          Dismiss
        </button>
      </div>
```

Then define the severity-class helper. `app.html.heex` is embedded by `EmakolaWeb.Layouts` (`lib/emakola_web/components/layouts.ex` — `embed_templates "layouts/*"`), so a bare local call like `announcement_classes(...)` in that template resolves to a function in `EmakolaWeb.Layouts`. Add it to that module:

```elixir
  @doc false
  def announcement_classes(:critical), do: "bg-red-50 text-red-800 border-red-200"
  def announcement_classes(:warning), do: "bg-amber-50 text-amber-800 border-amber-200"
  def announcement_classes(_info), do: "bg-blue-50 text-blue-800 border-blue-200"
```

- [ ] **Step 6: Run the test to confirm it passes**

Run: `mix test test/emakola_web/hooks/merchant_announcements_test.exs`
Expected: PASS.

- [ ] **Step 7: Format + commit**

```bash
mix format lib/emakola_web/hooks/merchant_announcements.ex lib/emakola_web/router.ex lib/emakola_web/components/layouts/app.html.heex lib/emakola_web/components/layouts.ex test/emakola_web/hooks/merchant_announcements_test.exs
git add lib/emakola_web/hooks/merchant_announcements.ex \
        lib/emakola_web/router.ex \
        lib/emakola_web/components/layouts/app.html.heex \
        lib/emakola_web/components/layouts.ex \
        test/emakola_web/hooks/merchant_announcements_test.exs
git commit -m "feat(web): merchant announcement banner + dismiss hook

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Platform announcements page + route + nav

**Files:**
- Create: `lib/emakola_web/live/platform/announcement_live/index.ex`
- Modify: `lib/emakola_web/router.ex` (route in `:platform`)
- Modify: `lib/emakola_web/components/layouts/platform.html.heex` (nav link)
- Test: `test/emakola_web/live/platform/announcement_live/index_test.exs`

- [ ] **Step 1: Write the failing platform LiveView test**

Create `test/emakola_web/live/platform/announcement_live/index_test.exs`:

```elixir
defmodule EmakolaWeb.Platform.AnnouncementLive.IndexTest do
  @moduledoc """
  Platform announcements page: create (persists + enqueues publish worker +
  audits), permission gating, and cancel.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  use Oban.Testing, repo: Emakola.Repo
  import Phoenix.LiveViewTest

  alias Emakola.Notifications
  alias Emakola.Notifications.Workers.AnnouncementPublishWorker

  test "staff without :manage_announcements is redirected", %{conn: conn} do
    {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
    assert {:error, {:redirect, _}} = live(conn, ~p"/platform/announcements")
  end

  describe "as an owner" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      %{conn: conn, user: user}
    end

    test "creating an announcement persists it and enqueues the publish worker", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/announcements")

      view
      |> form("#announcement-form", %{
        "announcement" => %{
          "title" => "Scheduled maintenance",
          "body" => "Down Sunday 2am.",
          "severity" => "warning",
          "channels" => ["banner", "email"],
          "audience" => "all",
          "publish_at" => "2026-07-01T02:00",
          "expires_at" => ""
        }
      })
      |> render_submit()

      {:ok, [ann]} = Notifications.list_announcements_for_admin(authorize?: false)
      assert ann.title == "Scheduled maintenance"
      assert ann.severity == :warning
      assert ann.channels == [:banner, :email]
      assert ann.status == :scheduled

      assert_enqueued(worker: AnnouncementPublishWorker, args: %{"announcement_id" => ann.id})
    end

    test "canceling a scheduled announcement flips it to :canceled", %{conn: conn} do
      {:ok, ann} =
        Notifications.create_announcement(
          %{
            title: "Cancel me",
            body: "x",
            channels: [:banner],
            audience: :all,
            publish_at: ~U[2026-07-01 00:00:00Z]
          },
          authorize?: false
        )

      {:ok, view, _html} = live(conn, ~p"/platform/announcements")

      view
      |> element("button[phx-value-id='#{ann.id}'][phx-click='cancel']")
      |> render_click()

      {:ok, reloaded} = Notifications.get_announcement(ann.id, authorize?: false)
      assert reloaded.status == :canceled
    end
  end
end
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `mix test test/emakola_web/live/platform/announcement_live/index_test.exs`
Expected: FAIL — route `/platform/announcements` not found.

- [ ] **Step 3: Create the platform LiveView**

Create `lib/emakola_web/live/platform/announcement_live/index.ex`:

```elixir
defmodule EmakolaWeb.Platform.AnnouncementLive.Index do
  @moduledoc """
  Platform broadcast announcements: list all, create (scheduled + multi-channel
  + status-targeted), and cancel. Gated by RequirePermission
  (:manage_announcements). No DB on disconnected mount. Create/cancel run with
  authorize?: false (the resource forbids actor-based writes), re-check the
  permission per event, enqueue the publish worker, and audit.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_announcements}

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Notifications
  alias Emakola.Notifications.Workers.AnnouncementPublishWorker

  @channels [:banner, :email, :sms, :whatsapp]
  @channel_atoms %{
    "banner" => :banner,
    "email" => :email,
    "sms" => :sms,
    "whatsapp" => :whatsapp
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Announcements")
      |> assign(:active_nav, :announcements)
      |> assign(:announcements, nil)

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  @impl true
  def handle_event("create", %{"announcement" => params}, socket) do
    authorized(socket, fn socket ->
      attrs = %{
        title: String.trim(params["title"] || ""),
        body: String.trim(params["body"] || ""),
        severity: Emakola.SafeAtom.to_atom_in(params["severity"], [:info, :warning, :critical], :info),
        channels: parse_channels(params["channels"]),
        audience: Emakola.SafeAtom.to_atom_in(params["audience"], [:all, :active], :all),
        publish_at: parse_datetime(params["publish_at"]) || DateTime.utc_now(),
        expires_at: parse_datetime(params["expires_at"])
      }

      case Notifications.create_announcement(attrs, authorize?: false) do
        {:ok, ann} ->
          AnnouncementPublishWorker.enqueue(ann.id, ann.publish_at)

          PlatformAudit.log(:announcement_published, socket.assigns.current_user, %{
            "announcement_id" => ann.id,
            "title" => ann.title
          })

          {:noreply, socket |> load() |> put_flash(:info, "Announcement scheduled.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not create the announcement. Check the fields.")}
      end
    end)
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      with {:ok, ann} <- Notifications.get_announcement(id, authorize?: false),
           {:ok, _} <- Notifications.cancel_announcement(ann, authorize?: false) do
        PlatformAudit.log(:announcement_canceled, socket.assigns.current_user, %{
          "announcement_id" => ann.id,
          "title" => ann.title
        })

        {:noreply, socket |> load() |> put_flash(:info, "Announcement canceled.")}
      else
        _ -> {:noreply, put_flash(socket, :error, "Could not cancel.")}
      end
    end)
  end

  defp parse_channels(list) when is_list(list) do
    Enum.flat_map(list, fn c -> if a = @channel_atoms[c], do: [a], else: [] end)
  end

  defp parse_channels(_), do: []

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(str) when is_binary(str) do
    # datetime-local sends "YYYY-MM-DDTHH:MM" — treat as UTC.
    case NaiveDateTime.from_iso8601(str <> ":00") do
      {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
      _ -> nil
    end
  end

  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_announcements) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to manage announcements.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  defp load(socket) do
    announcements =
      case Notifications.list_announcements_for_admin(authorize?: false) do
        {:ok, list} -> list
        _ -> []
      end

    assign(socket, :announcements, announcements)
  end

  defp display_state(%{status: :canceled}), do: "Canceled"
  defp display_state(%{status: :scheduled}), do: "Scheduled"
  defp display_state(%{status: :published, expires_at: exp}) do
    if exp && DateTime.compare(exp, DateTime.utc_now()) == :lt, do: "Expired", else: "Live"
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :all_channels, @channels)

    ~H"""
    <div class="p-6 lg:p-8 max-w-5xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Announcements</h1>
        <p class="text-sm text-gray-500 mt-1">Broadcast to merchants via banner, email, SMS, WhatsApp.</p>
      </div>

      <form id="announcement-form" phx-submit="create" class="bg-white rounded-xl border border-gray-200 p-6 mb-8 space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Title</label>
          <input name="announcement[title]" required class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Message</label>
          <textarea name="announcement[body]" rows="3" required class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm"></textarea>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Severity</label>
            <select name="announcement[severity]" class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm">
              <option value="info">Info</option>
              <option value="warning">Warning</option>
              <option value="critical">Critical</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Audience</label>
            <select name="announcement[audience]" class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm">
              <option value="all">All stores</option>
              <option value="active">Active stores only</option>
            </select>
          </div>
        </div>
        <div>
          <span class="block text-sm font-medium text-gray-700 mb-1">Channels</span>
          <div class="flex flex-wrap gap-4">
            <label :for={c <- @all_channels} class="inline-flex items-center gap-1.5 text-sm text-gray-700">
              <input type="checkbox" name="announcement[channels][]" value={c} checked={c == :banner} />
              {c |> to_string() |> String.capitalize()}
            </label>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Publish at (UTC)</label>
            <input type="datetime-local" name="announcement[publish_at]" class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Expires at (UTC, optional)</label>
            <input type="datetime-local" name="announcement[expires_at]" class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" />
          </div>
        </div>
        <button type="submit" class="rounded-lg bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-800">
          Schedule announcement
        </button>
      </form>

      <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
              <th class="px-6 py-3">Title</th>
              <th class="px-6 py-3">Audience</th>
              <th class="px-6 py-3">State</th>
              <th class="px-6 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr :if={is_nil(@announcements)}>
              <td colspan="4" class="px-6 py-12 text-center text-gray-400">Loading…</td>
            </tr>
            <tr :if={@announcements == []}>
              <td colspan="4" class="px-6 py-12 text-center text-gray-400">No announcements yet</td>
            </tr>
            <tr :for={a <- @announcements || []} class="hover:bg-gray-50">
              <td class="px-6 py-4 font-medium text-gray-900">{a.title}</td>
              <td class="px-6 py-4 text-gray-600">{a.audience}</td>
              <td class="px-6 py-4 text-gray-600">{display_state(a)}</td>
              <td class="px-6 py-4 text-right">
                <button
                  :if={a.status == :scheduled}
                  type="button"
                  phx-click="cancel"
                  phx-value-id={a.id}
                  class="px-3 py-1.5 rounded-lg text-xs font-medium bg-red-100 text-red-700 hover:bg-red-200"
                >
                  Cancel
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 4: Add the route**

In `lib/emakola_web/router.ex`, inside the `live_session :platform` block, add (after the moderation line):

```elixir
      live "/platform/announcements", Platform.AnnouncementLive.Index
```

- [ ] **Step 5: Add the platform nav link**

In `lib/emakola_web/components/layouts/platform.html.heex`, mirror an existing `<.sidebar_link …>` (e.g. the moderation one) and add after it. The `<.sidebar_link>` component (`EmakolaWeb.SidebarComponents`, shared by both layouts) already has a `megaphone` icon in its map:

```heex
      <.sidebar_link
        href="/platform/announcements"
        title="Announcements"
        icon="megaphone"
        active={@active_nav == :announcements}
      />
```

- [ ] **Step 6: Run the test to confirm it passes**

Run: `mix test test/emakola_web/live/platform/announcement_live/index_test.exs`
Expected: PASS.

- [ ] **Step 7: Format + commit**

```bash
mix format lib/emakola_web/live/platform/announcement_live/index.ex lib/emakola_web/router.ex lib/emakola_web/components/layouts/platform.html.heex test/emakola_web/live/platform/announcement_live/index_test.exs
git add lib/emakola_web/live/platform/announcement_live/index.ex \
        lib/emakola_web/router.ex \
        lib/emakola_web/components/layouts/platform.html.heex \
        test/emakola_web/live/platform/announcement_live/index_test.exs
git commit -m "feat(web): platform announcements page + route + nav

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Full verification

- [ ] **Step 1: Run the full suite**

Run: `mix test`
Expected: all pass (including the new files; no regressions in admin/platform/notifications suites).

- [ ] **Step 2: Format check**

Run: `mix format --check-formatted`
Expected: clean (no output).

- [ ] **Step 3: Credo (changed files)**

Run: `mix credo --strict lib/emakola/notifications/resources/announcement.ex lib/emakola/notifications/resources/announcement_dismissal.ex lib/emakola/notifications/workers/announcement_publish_worker.ex lib/emakola/notifications/workers/announcement_delivery_worker.ex lib/emakola_web/hooks/merchant_announcements.ex lib/emakola_web/live/platform/announcement_live/index.ex`
Expected: no issues.

- [ ] **Step 4: Confirm own files compile warning-clean**

Run: `mix compile --force --warnings-as-errors 2>&1 | tail -10`
Expected: no warnings originating in the new files. (Per `[[emakola-elixir-version-warnings]]`, ignore pre-existing repo-wide warnings under local Elixir versions; ensure none come from your files.)

- [ ] **Step 5: Push + open PR**

```bash
git push -u origin feature/broadcast-announcements
gh pr create --base main --head feature/broadcast-announcements \
  --title "feat(notifications): platform broadcast announcements" \
  --body "Implements docs/superpowers/specs/2026-06-23-broadcast-announcements-design.md. See plan docs/superpowers/plans/2026-06-23-broadcast-announcements.md.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 6: Watch CI green**

Run: `gh pr checks <PR#> --watch`
Expected: Test → pass. Then hand to the user to merge.

---

## Verification (acceptance)

- Resource: defaults, channel-required validation, derived `:active_for_store` (window + audience), cancel, idempotent dismissal — **Task 1 tests**.
- Workers: scheduled enqueue, publish flips + per-store fan-out, audience filtering, banner-only no-send, canceled no-op, per-channel send/skip, unknown-WhatsApp-template tolerated, transient-error retry — **Task 2 tests**.
- Permission/audit/template wiring — **Task 3** (+ exercised in Task 5).
- Merchant banner: shown when active, dismiss persists + hides, scheduled hidden — **Task 4 tests**.
- Platform page: create persists + enqueues + audits, permission gating, cancel — **Task 5 tests**.
- Suite green + format + credo — **Task 6**.

## Edge cases captured in code

- Unknown WhatsApp template → skipped channel (`maybe_send_whatsapp` matches `{:error, {:unknown_template, _}}` → `:ok`), so a perpetually-dark template never dead-letters the job.
- `publish_at` in the past → Oban runs the publish worker immediately (fine).
- Missing `current_store`/`current_merchant` in the hook → `[]` announcements (no crash).
- Banner assign missing on non-`:app` layouts → `assigns[:announcements] || []` renders nothing.
- Datetime parse failure / blank expiry → `nil` (no publish/expiry constraint violation; `publish_at` falls back to now).
```
