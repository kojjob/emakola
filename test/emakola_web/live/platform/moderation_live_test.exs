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
    {:ok, view, _html} = live(conn, ~p"/platform/moderation")
    assert has_element?(view, "#moderation-search-form")
    assert has_element?(view, "#moderation-products[phx-update='stream'][data-count='1']")
    assert has_element?(view, "[id^='moderation-product-']", "Fake Bag")
    assert has_element?(view, "[id^='moderation-product-']", "Kente Co")
  end

  test "search resets the product stream", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/platform/moderation")
    assert has_element?(view, "#moderation-product-#{product.id}")

    view
    |> form("#moderation-search-form", %{"search" => "does-not-exist"})
    |> render_change()

    assert has_element?(view, "#moderation-products[data-count='0']")
    assert has_element?(view, "#moderation-products-empty")
    refute has_element?(view, "#moderation-product-#{product.id}")
  end

  test "forged events cannot mutate a product outside the current filtered queue", %{
    conn: conn,
    store: store
  } do
    outside = Factory.create_product!(store, %{status: :active, title: "Outside Product"})
    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    view
    |> form("#moderation-search-form", %{"search" => "Fake Bag"})
    |> render_change()

    refute has_element?(view, "#moderation-product-#{outside.id}")
    render_click(view, "open_takedown_modal", %{"id" => outside.id})

    view
    |> form("#moderation-takedown-form", %{"reason" => "forged"})
    |> render_submit()

    assert {:ok, %{moderation_status: :ok}} = Catalog.get_product(outside.id, authorize?: false)
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

    assert has_element?(view, "#moderation-takedown-form")

    view |> form("#moderation-takedown-form", reason: "") |> render_submit()
    assert has_element?(view, "#flash-error", "A reason is required")

    view |> form("#moderation-takedown-form", reason: "Counterfeit") |> render_submit()

    assert has_element?(
             view,
             "#moderation-product-#{product.id} button[phx-click='reinstate']"
           )

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

    assert has_element?(
             view,
             "#moderation-product-#{product.id} button[phx-click='open_takedown_modal']"
           )

    assert {:ok, %{moderation_status: :ok}} = Catalog.get_product(product.id, authorize?: false)
  end
end
