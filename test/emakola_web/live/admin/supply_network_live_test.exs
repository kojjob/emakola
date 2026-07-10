defmodule EmakolaWeb.Admin.SupplyNetworkLiveTest do
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers

  import Emakola.Factory
  import Phoenix.LiveViewTest

  alias Emakola.Suppliers.Network

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    partner = create_store!(name: "Accra Wholesale", slug: "accra-wholesale")
    partner_merchant = create_merchant!()
    create_store_membership!(partner_merchant, partner, :owner)

    %{
      conn: conn,
      merchant: merchant,
      store: store,
      partner: partner,
      partner_merchant: partner_merchant
    }
  end

  test "renders an empty connection inbox with a stable invite form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/settings/supply-network")

    assert has_element?(view, "#supply-network-page")
    assert has_element?(view, "#supply-connection-form")
    assert has_element?(view, "#connections-empty")
    assert has_element?(view, "#connection-count", "0")
  end

  test "requests a reseller connection by partner store slug", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network")

    view
    |> form("#supply-connection-form",
      connection: %{partner_slug: ctx.partner.slug, relationship: "resell"}
    )
    |> render_submit()

    assert has_element?(view, "#connection-count", "1")
    assert has_element?(view, "#supply-connections article", ctx.partner.name)

    assert {:ok, [connection]} = Network.list_for_store(ctx.merchant, ctx.store.id)
    assert connection.wholesaler_store_id == ctx.partner.id
    assert connection.reseller_store_id == ctx.store.id
    assert connection.requested_by_store_id == ctx.store.id
    assert connection.status == :pending
  end

  test "shows a useful error for an unknown store", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/settings/supply-network")

    html =
      view
      |> form("#supply-connection-form",
        connection: %{partner_slug: "does-not-exist", relationship: "resell"}
      )
      |> render_submit()

    assert html =~ "No store was found"
    assert has_element?(view, "#connection-count", "0")
  end

  test "counterparty accepts an incoming invitation", ctx do
    {:ok, pending} =
      Network.request(ctx.partner_merchant, %{
        wholesaler_store_id: ctx.partner.id,
        reseller_store_id: ctx.store.id,
        requested_by_store_id: ctx.partner.id
      })

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network")
    assert has_element?(view, "#approve-connection-#{pending.id}")

    view
    |> element("#approve-connection-#{pending.id}")
    |> render_click()

    assert has_element?(view, "#supply-connections article", "active")
    refute has_element?(view, "#approve-connection-#{pending.id}")

    assert {:ok, updated} = Network.get(ctx.merchant, pending.id)
    assert updated.status == :active
  end

  test "active connection can be paused and reactivated", ctx do
    {:ok, pending} =
      Network.request(ctx.partner_merchant, %{
        wholesaler_store_id: ctx.partner.id,
        reseller_store_id: ctx.store.id,
        requested_by_store_id: ctx.partner.id
      })

    {:ok, active} = Network.approve(ctx.merchant, pending)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network")

    view
    |> element("#suspend-connection-#{active.id}")
    |> render_click()

    assert has_element?(view, "#reactivate-connection-#{active.id}")

    view
    |> element("#reactivate-connection-#{active.id}")
    |> render_click()

    assert has_element?(view, "#suspend-connection-#{active.id}")
  end

  test "active connection can be ended", ctx do
    {:ok, pending} =
      Network.request(ctx.partner_merchant, %{
        wholesaler_store_id: ctx.partner.id,
        reseller_store_id: ctx.store.id,
        requested_by_store_id: ctx.partner.id
      })

    {:ok, active} = Network.approve(ctx.merchant, pending)
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/supply-network")

    view
    |> element("#terminate-connection-#{active.id}")
    |> render_click()

    refute has_element?(view, "#terminate-connection-#{active.id}")
    assert has_element?(view, "#supply-connections article", "terminated")
  end
end
