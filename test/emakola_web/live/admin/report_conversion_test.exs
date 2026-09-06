defmodule EmakolaWeb.Admin.ReportConversionTest do
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  alias Emakola.Analytics.StoreVisits
  alias Emakola.Factory

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  test "people who looked counts product-page visitors, and the rate uses the same window", ctx do
    product = Factory.create_product!(ctx.store, title: "Kente Stole")
    variant = Factory.create_variant!(product, ctx.store, price: 5_000)

    for s <- ~w(s1 s2 s3 s4),
        do: StoreVisits.record(ctx.store.id, s, %{"page" => :product, "product_id" => product.id})

    order =
      Factory.create_order!(ctx.store, %{subtotal: 5_000, total: 5_000, status: :confirmed})

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: ctx.store.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!(authorize?: false)

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/reports")

    assert has_element?(view, "#stat-reports-visitors", "4")
    assert has_element?(view, "#stat-reports-visitors", "25.0% of them bought")
    assert has_element?(view, "#reports-looked-bought", "Kente Stole")
    assert has_element?(view, "#reports-looked-bought", "4 looked")
    assert has_element?(view, "#reports-looked-bought", "1 bought")
  end

  test "another store's product visits never appear in this store's report", ctx do
    product = Factory.create_product!(ctx.store, title: "Kente Stole")

    elsewhere = Factory.create_store!()
    elsewhere_product = Factory.create_product!(elsewhere, title: "Beaded Choker")

    StoreVisits.record(ctx.store.id, "s1", %{"page" => :product, "product_id" => product.id})

    StoreVisits.record(elsewhere.id, "s2", %{
      "page" => :product,
      "product_id" => elsewhere_product.id
    })

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/reports")

    assert has_element?(view, "#stat-reports-visitors", "1")
    assert has_element?(view, "#reports-looked-bought", "Kente Stole")
    refute render(view) =~ "Beaded Choker"
  end
end
