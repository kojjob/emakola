defmodule EmakolaWeb.Platform.StoreLive.ShowTest do
  @moduledoc """
  The platform store detail page drives lifecycle management: gated by
  :manage_stores, every action captures a reason, records a platform audit
  entry, and enqueues a merchant notification.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  use Oban.Testing, repo: Emakola.Repo
  import Phoenix.LiveViewTest

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Factory
  alias Emakola.Notifications.Workers.StoreStatusNotificationWorker, as: Worker

  defp audit_entries(store_id) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list_for_store, %{store_id: store_id})
    |> Ash.read!(authorize?: false)
  end

  describe "mount + access" do
    test "an owner sees the store detail", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      store = Factory.create_store!(%{name: "Kente Co"})

      {:ok, _view, html} = live(conn, ~p"/platform/stores/#{store.id}")
      assert html =~ "Kente Co"
      assert html =~ "Active"
    end

    test "staff with :manage_stores can view", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
      store = Factory.create_store!()
      assert {:ok, _view, _html} = live(conn, ~p"/platform/stores/#{store.id}")
    end

    test "staff without :manage_stores is redirected to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:view_audit_log])
      store = Factory.create_store!()

      assert {:error, {:redirect, %{to: "/platform"}}} =
               live(conn, ~p"/platform/stores/#{store.id}")
    end

    test "issues no store query in the disconnected mount (loading shell)", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      store = Factory.create_store!(%{name: "Disconnected Co"})

      html = conn |> get(~p"/platform/stores/#{store.id}") |> html_response(200)
      assert html =~ "Loading store…"
      refute html =~ "Disconnected Co"
    end
  end

  describe "suspend" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      %{conn: conn, user: user, store: Factory.create_store!()}
    end

    test "suspends with a reason, audits, and enqueues a notification", %{
      conn: conn,
      user: user,
      store: store
    } do
      {:ok, view, _html} = live(conn, ~p"/platform/stores/#{store.id}")

      view |> element("button", "Suspend") |> render_click()
      assert has_element?(view, "#store-lifecycle-form")

      view |> form("#store-lifecycle-form", reason: "Chargebacks") |> render_submit()
      assert has_element?(view, "#store-status", "Suspended")

      assert [entry] = audit_entries(store.id)
      assert entry.action == :store_suspended
      assert entry.actor_id == user.id
      assert entry.metadata["store_id"] == store.id
      assert entry.metadata["reason"] == "Chargebacks"

      assert_enqueued(
        worker: Worker,
        args: %{"store_id" => store.id, "event" => "store_suspended"}
      )
    end

    test "rejects a suspend with no reason", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/platform/stores/#{store.id}")

      view |> element("button", "Suspend") |> render_click()
      view |> form("#store-lifecycle-form", reason: "") |> render_submit()

      assert has_element?(view, "#flash-error", "A reason is required")
      assert audit_entries(store.id) == []
    end
  end

  describe "archive then reactivate" do
    test "round-trips and records both events in the history", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      store = Factory.create_store!()

      {:ok, view, _html} = live(conn, ~p"/platform/stores/#{store.id}")

      view |> element("button", "Archive") |> render_click()
      view |> form("#store-lifecycle-form", reason: "Owner request") |> render_submit()
      assert has_element?(view, "#store-status", "Archived")

      view |> element("button", "Reactivate") |> render_click()
      assert has_element?(view, "#store-status", "Active")

      actions = store.id |> audit_entries() |> Enum.map(& &1.action)
      assert :store_archived in actions
      assert :store_reactivated in actions
    end
  end

  describe "case file" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      %{conn: conn, user: user}
    end

    test "shows health tiles, the milestone checklist, and recent orders", %{conn: conn} do
      store = Factory.create_store!(%{name: "Case File Co"})
      product = Factory.create_product!(store, %{title: "Kente Stole", status: :active})
      Factory.create_image!(product, store, %{url: "https://s3.example.com/case/stole.jpg"})
      order = Factory.create_order!(store, %{total: 45_000})

      store
      |> Factory.create_payment!(%{order_id: order.id, amount: 45_000})
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

      {:ok, view, html} = live(conn, ~p"/platform/stores/#{store.id}")

      assert has_element?(view, "#store-orders-count", "1")
      assert has_element?(view, "#store-gmv")
      assert has_element?(view, "#store-holds-count", "0")
      assert has_element?(view, "#store-refunds-count", "0")
      assert has_element?(view, "[data-milestone='products'][data-done]")
      assert has_element?(view, "[data-milestone='first_order'][data-done]")
      refute has_element?(view, "[data-milestone='kyc'][data-done]")
      assert has_element?(view, "#store-recent-orders")
      assert html =~ order.order_number
      # Identity header carries a real product photo
      assert html =~ "https://s3.example.com/case/stole.jpg"
    end

    test "lifecycle history renders as a severity timeline", %{conn: conn, user: user} do
      store = Factory.create_store!(%{name: "Timeline Co"})

      {:ok, _} =
        Emakola.Accounts.PlatformAudit.log(:store_suspended, user, %{
          "store_id" => store.id,
          "store_name" => store.name,
          "store_slug" => store.slug,
          "reason" => "chargeback review"
        })

      {:ok, view, html} = live(conn, ~p"/platform/stores/#{store.id}")

      assert has_element?(view, "#store-lifecycle-history [data-severity='amber']")
      assert html =~ "chargeback review"
    end
  end
end
