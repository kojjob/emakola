defmodule EmakolaWeb.Platform.ModerationLive.IndexTest do
  @moduledoc """
  Platform moderation queue: lists products (gated :manage_stores), take down
  (reason required → hides + audits + notifies) and reinstate.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  use Oban.Testing, repo: Emakola.Repo
  import Phoenix.LiveViewTest
  require Ash.Query

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Catalog
  alias Emakola.Factory
  alias Emakola.Notifications.Workers.ProductModerationNotificationWorker, as: Worker

  defp audit(event) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> Ash.Query.filter(action == ^event)
    |> Ash.read!(authorize?: false, page: [limit: 200])
    |> Map.get(:results)
  end

  setup %{conn: conn} do
    {conn, user, _s} = setup_platform_staff(conn)
    store = Factory.create_store!(%{name: "Kente Co"})
    product = Factory.create_product!(store, %{status: :active, title: "Fake Bag"})
    %{conn: conn, user: user, store: store, product: product}
  end

  test "lists products across stores", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/platform/moderation")
    assert html =~ "Fake Bag"
    assert html =~ "Kente Co"
  end

  test "staff without :manage_stores is redirected to /platform", %{conn: conn} do
    {conn, _u, _s} = setup_platform_staff(conn, permissions: [:view_audit_log])
    assert {:error, {:redirect, %{to: "/platform"}}} = live(conn, ~p"/platform/moderation")
  end

  test "take down requires a reason, then hides, audits, and enqueues", %{
    conn: conn,
    user: user,
    product: product
  } do
    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    view
    |> element("button[phx-click='open_takedown_modal'][phx-value-id='#{product.id}']")
    |> render_click()

    assert view
           |> form("form[phx-submit='confirm_takedown']", reason: "")
           |> render_submit() =~ "A reason is required"

    assert view
           |> form("form[phx-submit='confirm_takedown']", reason: "Counterfeit")
           |> render_submit() =~ "Taken down"

    assert {:ok, %{moderation_status: :taken_down}} =
             Catalog.get_product(product.id, authorize?: false)

    assert [entry] = audit(:product_taken_down)
    assert entry.actor_id == user.id
    assert entry.metadata["product_id"] == product.id

    assert_enqueued(
      worker: Worker,
      args: %{"product_id" => product.id, "event" => "product_taken_down"}
    )
  end

  test "reinstate restores a taken-down product", %{conn: conn, product: product} do
    {:ok, _} = Catalog.take_down_product(product, %{reason: "x"}, authorize?: false)

    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    view
    |> element("button[phx-click='reinstate'][phx-value-id='#{product.id}']")
    |> render_click()

    assert {:ok, %{moderation_status: :ok}} = Catalog.get_product(product.id, authorize?: false)
  end
end
