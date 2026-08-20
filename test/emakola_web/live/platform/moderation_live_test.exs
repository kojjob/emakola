defmodule EmakolaWeb.Platform.ModerationLive.IndexTest do
  @moduledoc """
  Platform Moderation Studio: a split view listing products across stores
  (gated :manage_stores) with a case panel for the selected product —
  inline take down (reason required → hides + audits + notifies),
  reinstate, quick filters, and per-product moderation history.
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

  test "staff without :manage_stores is redirected to /platform", %{conn: conn} do
    {conn, _u, _s} = setup_platform_staff(conn, permissions: [:view_audit_log])
    assert {:error, {:redirect, %{to: "/platform"}}} = live(conn, ~p"/platform/moderation")
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

  test "the first product is selected by default and rows switch the panel", %{
    conn: conn,
    store: store,
    product: product
  } do
    other = Factory.create_product!(store, %{status: :active, title: "Second Listing"})
    Factory.create_image!(product, store, %{url: "https://s3.example.com/test/evidence.jpg"})

    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    view |> element("#moderation-product-#{product.id}") |> render_click()

    assert has_element?(view, "#moderation-product-#{product.id}[data-selected]")
    assert has_element?(view, "#moderation-panel", "Fake Bag")

    # The evidence image must fill its frame, not sit boxed inside it.
    assert has_element?(
             view,
             ~s(#moderation-panel img.object-cover[src="https://s3.example.com/test/evidence.jpg"])
           )

    view |> element("#moderation-product-#{other.id}") |> render_click()

    assert has_element?(view, "#moderation-product-#{other.id}[data-selected]")
    refute has_element?(view, "#moderation-product-#{product.id}[data-selected]")
    assert has_element?(view, "#moderation-panel", "Second Listing")
  end

  test "an empty queue shows an empty state and no panel", %{conn: conn, product: product} do
    :ok = Ash.destroy(product, authorize?: false)

    {:ok, view, html} = live(conn, ~p"/platform/moderation")

    refute has_element?(view, "#moderation-panel")
    assert html =~ "No products found"
  end

  test "inline take down requires a reason, then hides, audits, and enqueues", %{
    conn: conn,
    user: user,
    product: product
  } do
    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    assert has_element?(view, "#moderation-takedown-form")

    view |> form("#moderation-takedown-form", reason: "") |> render_submit()
    assert has_element?(view, "#flash-error", "A reason is required")

    view |> form("#moderation-takedown-form", reason: "Counterfeit") |> render_submit()

    assert {:ok, %{moderation_status: :taken_down}} =
             Catalog.get_product(product.id, authorize?: false)

    assert has_element?(view, "#panel-takedown-banner", "Counterfeit")
    assert has_element?(view, "#panel-reinstate")
    refute has_element?(view, "#moderation-takedown-form")

    assert [entry] = audit(:product_taken_down)
    assert entry.actor_id == user.id
    assert entry.metadata["product_id"] == product.id

    assert_enqueued(
      worker: Worker,
      args: %{"product_id" => product.id, "event" => "product_taken_down"}
    )
  end

  test "reinstate from the panel restores the product", %{conn: conn, product: product} do
    {:ok, _} = Catalog.take_down_product(product, %{reason: "x"}, authorize?: false)

    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    assert has_element?(view, "#panel-takedown-banner")

    view |> element("#panel-reinstate") |> render_click()

    assert {:ok, %{moderation_status: :ok}} = Catalog.get_product(product.id, authorize?: false)
    assert has_element?(view, "#moderation-takedown-form")
    refute has_element?(view, "#panel-takedown-banner")
  end

  test "the taken down filter narrows the queue", %{conn: conn, store: store, product: product} do
    down = Factory.create_product!(store, %{status: :active, title: "Bad Listing"})
    {:ok, _} = Catalog.take_down_product(down, %{reason: "prohibited"}, authorize?: false)

    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    assert has_element?(view, "#moderation-products[data-count='2']")

    view |> element("#moderation-filter-taken_down") |> render_click()

    assert has_element?(view, "#moderation-products[data-count='1']")
    assert has_element?(view, "#moderation-product-#{down.id}")
    refute has_element?(view, "#moderation-product-#{product.id}")
  end

  test "the panel shows the product's moderation history", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    view
    |> form("#moderation-takedown-form", reason: "Counterfeit brand claim")
    |> render_submit()

    assert has_element?(view, "#panel-history", "Taken down")
  end

  test "photo navigation cycles the evidence image", %{
    conn: conn,
    store: store,
    product: product
  } do
    Factory.create_image!(product, store, %{
      url: "https://s3.example.com/test/photo-one.jpg",
      position: 0
    })

    Factory.create_image!(product, store, %{
      url: "https://s3.example.com/test/photo-two.jpg",
      position: 1
    })

    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    assert has_element?(view, ~s(#moderation-panel img[src*="photo-one.jpg"]))

    view |> element("#panel-photo-next") |> render_click()

    assert has_element?(view, ~s(#moderation-panel img[src*="photo-two.jpg"]))
    assert has_element?(view, "#moderation-panel", "2 of 2")

    view |> element("#panel-photo-next") |> render_click()
    assert has_element?(view, ~s(#moderation-panel img[src*="photo-one.jpg"]))

    view |> element("#panel-photo-prev") |> render_click()
    assert has_element?(view, ~s(#moderation-panel img[src*="photo-two.jpg"]))
  end

  test "the panel shows the listing description", %{conn: conn, store: store} do
    _p =
      Factory.create_product!(store, %{
        status: :active,
        title: "Descriptive Listing",
        description: "Genuine leather, imported original stock."
      })

    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    assert has_element?(view, "#moderation-panel", "Genuine leather, imported original stock.")
  end

  test "repeat-offender hint counts other takedowns on the same store", %{conn: conn} do
    repeat_store = Factory.create_store!(%{name: "Repeat Co"})
    bad = Factory.create_product!(repeat_store, %{status: :active, title: "Prior Bad Listing"})
    {:ok, view0, _} = live(conn, ~p"/platform/moderation")
    _ = view0

    {:ok, _} = Catalog.take_down_product(bad, %{reason: "counterfeit"}, authorize?: false)

    Emakola.Accounts.PlatformAudit.log(
      :product_taken_down,
      nil,
      %{"product_id" => bad.id, "store_id" => repeat_store.id, "reason" => "counterfeit"}
    )

    under_review =
      Factory.create_product!(repeat_store, %{status: :active, title: "Under Review Listing"})

    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    view |> element("#moderation-product-#{under_review.id}") |> render_click()

    assert has_element?(view, "#panel-repeat-offender", "1")
  end

  test "a store without takedowns shows no repeat-offender hint", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    refute has_element?(view, "#panel-repeat-offender")
  end

  test "the queue truncates at the configured limit with a notice", %{conn: conn, store: store} do
    Application.put_env(:emakola, :platform_moderation_list_limit, 2)
    on_exit(fn -> Application.delete_env(:emakola, :platform_moderation_list_limit) end)

    for n <- 1..2,
        do: Factory.create_product!(store, %{status: :active, title: "Cap Listing #{n}"})

    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    assert has_element?(view, "#moderation-products[data-count='2']")
    assert has_element?(view, "#moderation-products-truncated")
  end

  test "an uncapped queue shows no truncation notice", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    refute has_element?(view, "#moderation-products-truncated")
  end

  test "j and k walk the queue selection", %{conn: conn, store: store, product: product} do
    newer = Factory.create_product!(store, %{status: :active, title: "Newer Listing"})

    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    # Newest first: `newer` is selected by default at the top of the queue.
    assert has_element?(view, "#moderation-product-#{newer.id}[data-selected]")

    render_click(view, "queue_key", %{"key" => "j"})
    assert has_element?(view, "#moderation-product-#{product.id}[data-selected]")

    # j at the bottom clamps.
    render_click(view, "queue_key", %{"key" => "j"})
    assert has_element?(view, "#moderation-product-#{product.id}[data-selected]")

    render_click(view, "queue_key", %{"key" => "k"})
    assert has_element?(view, "#moderation-product-#{newer.id}[data-selected]")

    # k at the top clamps.
    render_click(view, "queue_key", %{"key" => "k"})
    assert has_element?(view, "#moderation-product-#{newer.id}[data-selected]")
  end

  test "forged events cannot reach a product outside the current filtered queue", %{
    conn: conn,
    store: store
  } do
    outside = Factory.create_product!(store, %{status: :active, title: "Outside Product"})
    {:ok, _} = Catalog.take_down_product(outside, %{reason: "x"}, authorize?: false)

    {:ok, view, _html} = live(conn, ~p"/platform/moderation")

    view
    |> form("#moderation-search-form", %{"search" => "Fake Bag"})
    |> render_change()

    refute has_element?(view, "#moderation-product-#{outside.id}")

    # A forged selection of an out-of-queue product must not switch the panel.
    render_click(view, "select_product", %{"id" => outside.id})
    assert has_element?(view, "#moderation-panel", "Fake Bag")

    # A forged reinstate for an out-of-queue product must not mutate it.
    render_click(view, "reinstate", %{"id" => outside.id})

    assert {:ok, %{moderation_status: :taken_down}} =
             Catalog.get_product(outside.id, authorize?: false)
  end
end
