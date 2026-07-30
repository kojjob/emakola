defmodule EmakolaWeb.Admin.PayLinkLiveTest do
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  use Emakola.LiveViewHelpers

  setup %{conn: conn} do
    {conn, user, store} = setup_authenticated_merchant(conn)
    %{conn: conn, user: user, store: store}
  end

  test "lists links with funnel columns and empty state", %{conn: conn, store: store} do
    {:ok, _view, html} = live(conn, "/admin/pay-links")
    assert html =~ "Pay Links"

    Emakola.Orders.PayLink
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      type: :custom,
      title: "Deal",
      amount: 25_000
    })
    |> Ash.create!(authorize?: false)

    {:ok, _view, html} = live(conn, "/admin/pay-links")
    assert html =~ "Deal"
    assert html =~ "250"
  end

  test "creates a custom link from the modal and shows the share URL", %{conn: conn} do
    {:ok, view, _} = live(conn, "/admin/pay-links")

    view |> element("button", "New pay link") |> render_click()

    html =
      view
      |> form("#pay-link-create-form", %{
        "pay_link" => %{"type" => "custom", "title" => "Kente", "amount_ghs" => "250"}
      })
      |> render_submit()

    assert html =~ "/pay/"
    assert html =~ "wa.me"
  end

  test "cancels an active link", %{conn: conn, store: store} do
    link =
      Emakola.Orders.PayLink
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        type: :custom,
        title: "Deal",
        amount: 25_000
      })
      |> Ash.create!(authorize?: false)

    {:ok, view, _} = live(conn, "/admin/pay-links")
    view |> element("#cancel-link-#{link.id}") |> render_click()

    assert Ash.get!(Emakola.Orders.PayLink, link.id, authorize?: false, tenant: store.id).status ==
             :cancelled
  end

  test "another store's merchant cannot see the link", %{conn: _conn, store: store} do
    Emakola.Orders.PayLink
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      type: :custom,
      title: "Secret",
      amount: 25_000
    })
    |> Ash.create!(authorize?: false)

    other_conn = build_conn()
    {other_conn, _user, _other_store} = setup_authenticated_merchant(other_conn)

    {:ok, _view, html} = live(other_conn, "/admin/pay-links")
    refute html =~ "Secret"
  end
end
