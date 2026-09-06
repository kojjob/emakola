defmodule EmakolaWeb.Admin.ReportRepeatTest do
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  defp backdate!(order, days) do
    at = DateTime.add(DateTime.utc_now(), -days * 86_400, :second)

    Emakola.Repo.query!("update orders set inserted_at = $1 where id = $2", [
      at,
      Ecto.UUID.dump!(order.id)
    ])
  end

  test "bought again: returning buyers against new ones in the window", ctx do
    returning = Factory.create_customer!(ctx.store, %{name: "Returning"})
    fresh = Factory.create_customer!(ctx.store, %{name: "Fresh"})

    ctx.store
    |> Factory.create_order!(%{
      subtotal: 100,
      total: 100,
      status: :confirmed,
      customer_id: returning.id
    })
    |> backdate!(100)

    Factory.create_order!(ctx.store, %{
      subtotal: 100,
      total: 100,
      status: :confirmed,
      customer_id: returning.id
    })

    Factory.create_order!(ctx.store, %{
      subtotal: 100,
      total: 100,
      status: :confirmed,
      customer_id: fresh.id
    })

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/reports")

    assert has_element?(view, "#reports-repeat", "1 came back")
    assert has_element?(view, "#reports-repeat", "1 new")
    assert has_element?(view, "#reports-repeat", "50.0%")
  end

  # Production gate: buyer_ids and the "earlier order" read both come off
  # THIS store's own orders (fetch_orders/3 is already store-scoped, and the
  # repeat query pins store_id itself), so another store's returning buyer
  # must never surface in this store's figures — even when that other store
  # has a genuinely returning customer of its own in the same window.
  test "another store's returning buyer never changes this store's figures", ctx do
    fresh = Factory.create_customer!(ctx.store, %{name: "Fresh"})

    Factory.create_order!(ctx.store, %{
      subtotal: 100,
      total: 100,
      status: :confirmed,
      customer_id: fresh.id
    })

    {_other_merchant, other_store} = Factory.create_merchant_with_store!()
    other_returning = Factory.create_customer!(other_store, %{name: "Other Returning"})

    other_store
    |> Factory.create_order!(%{
      subtotal: 100,
      total: 100,
      status: :confirmed,
      customer_id: other_returning.id
    })
    |> backdate!(100)

    Factory.create_order!(other_store, %{
      subtotal: 100,
      total: 100,
      status: :confirmed,
      customer_id: other_returning.id
    })

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/reports")

    assert has_element?(view, "#reports-repeat", "0 came back")
    assert has_element?(view, "#reports-repeat", "1 new")
    assert has_element?(view, "#reports-repeat", "0.0%")
  end
end
