defmodule EmakolaWeb.Admin.CartLiveTest do
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  alias Emakola.Orders.AbandonedCheckouts

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn, %{name: "Ama's Shop"})
    %{conn: conn, merchant: merchant, store: store}
  end

  defp left!(store, session) do
    {:ok, checkout} =
      AbandonedCheckouts.touch(store.id, session, %{
        phone: "0241234567",
        name: "Kojo",
        items: [%{"title" => "Kente stole", "quantity" => 1, "unit_price" => 5_000}],
        cart_total: 5_000
      })

    at = DateTime.add(DateTime.utc_now(), -3 * 3600, :second)

    Emakola.Repo.query!("update abandoned_checkouts set last_seen_at = $1 where id = $2", [
      at,
      Ecto.UUID.dump!(checkout.id)
    ])

    checkout
  end

  test "lists carts with a WhatsApp link, and the dashboard counts them", ctx do
    checkout = left!(ctx.store, "cart-1")

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/carts")

    assert has_element?(view, "#cart-#{checkout.id}", "Kojo")
    assert has_element?(view, "#cart-#{checkout.id}", "Kente stole")
    assert has_element?(view, "#cart-#{checkout.id}", "GH₵ 50")

    assert has_element?(
             view,
             ~s{#cart-#{checkout.id} a[href^="https://wa.me/233241234567?text="]}
           )

    {:ok, dash, _html} = live(ctx.conn, ~p"/dashboard")
    render_async(dash)
    assert has_element?(dash, "#work-queue-carts", "1")
  end

  test "an empty list says so", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/admin/carts")
    assert html =~ "No carts left behind"
  end

  test "another store's cart never appears in this store's list or count", ctx do
    other_store = Emakola.Factory.create_store!()
    leaked = left!(other_store, "cart-other")
    checkout = left!(ctx.store, "cart-1")

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/carts")

    assert has_element?(view, "#cart-#{checkout.id}")
    refute has_element?(view, "#cart-#{leaked.id}")
    assert AbandonedCheckouts.count_left_behind(ctx.store.id) == 1
  end
end
