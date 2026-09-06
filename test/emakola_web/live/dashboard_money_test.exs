defmodule EmakolaWeb.DashboardMoneyTest do
  @moduledoc """
  "Money made" used to sum every non-cancelled order, so money nobody had paid
  sat inside the biggest number a merchant sees. Orders are created pending and
  confirmed by the payment (or by the merchant, for cash on delivery).
  """
  use EmakolaWeb.ConnCase, async: false

  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  defp order!(store, total, status, customer) do
    Factory.create_order!(store, %{
      subtotal: total,
      total: total,
      status: status,
      customer_id: customer && customer.id
    })
  end

  # The dashboard reads its period from a click event, not a query param
  # (`change_period` / `phx-value-period`), so land on "today" by clicking
  # the period control rather than routing with `?period=today`.
  defp visit_today(conn) do
    {:ok, view, _html} = live(conn, ~p"/dashboard")
    view |> element("button[phx-value-period='today']") |> render_click()
    view
  end

  test "money made counts paid orders and names the money still waiting", ctx do
    ama = Factory.create_customer!(ctx.store, %{phone: "+233241111111"})
    kofi = Factory.create_customer!(ctx.store, %{phone: "+233242222222"})

    order!(ctx.store, 10_000, :confirmed, ama)
    order!(ctx.store, 2_500, :delivered, ama)
    order!(ctx.store, 7_000, :pending, kofi)
    order!(ctx.store, 9_999, :cancelled, kofi)

    view = visit_today(ctx.conn)
    html = render_async(view)

    assert has_element?(view, "#money-made", "GHS 125.00")
    assert has_element?(view, "#money-waiting", "GHS 70.00")
    assert has_element?(view, "#money-orders", "2")
    # Two customers exist; one bought.
    assert has_element?(view, "#money-buyers", "1")
    refute html =~ "GHS 195.00"
  end

  test "nothing waiting means no waiting line", ctx do
    order!(ctx.store, 10_000, :confirmed, nil)

    view = visit_today(ctx.conn)
    render_async(view)

    refute has_element?(view, "#money-waiting")
  end

  test "another store's paid order never changes this store's money made", ctx do
    ama = Factory.create_customer!(ctx.store, %{phone: "+233241111111"})
    order!(ctx.store, 10_000, :confirmed, ama)

    {_other_merchant, other_store} = Factory.create_merchant_with_store!()
    other_customer = Factory.create_customer!(other_store, %{phone: "+233249999999"})
    order!(other_store, 500_000, :confirmed, other_customer)

    view = visit_today(ctx.conn)
    html = render_async(view)

    assert has_element?(view, "#money-made", "GHS 100.00")
    assert has_element?(view, "#money-buyers", "1")
    refute html =~ "5,000.00"
    refute html =~ "5,100.00"
  end

  test "see more numbers names the top sources", ctx do
    Factory.create_order!(ctx.store, %{
      subtotal: 100,
      total: 100,
      status: :confirmed,
      attribution: %{"utm_source" => "instagram"}
    })

    # Not `~p"/dashboard?period=today"` as in the brief: mount discards
    # params (see `visit_today/1` above), so that query string is a no-op
    # and would pass on the default "week" period alone.
    view = visit_today(ctx.conn)
    render_async(view)

    assert has_element?(view, "#top-sources", "Instagram")
  end
end
