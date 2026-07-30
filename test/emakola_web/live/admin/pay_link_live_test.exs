defmodule EmakolaWeb.Admin.PayLinkLiveTest do
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  use Emakola.LiveViewHelpers

  alias Emakola.Factory

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

  test "creates a custom link with an optional expiry and note", %{conn: conn} do
    {:ok, view, _} = live(conn, "/admin/pay-links")

    view |> element("button", "New pay link") |> render_click()

    view
    |> form("#pay-link-create-form", %{
      "pay_link" => %{
        "type" => "custom",
        "title" => "Kente",
        "amount_ghs" => "250",
        "expires_at" => "2026-08-15",
        "note" => "VIP customer deal"
      }
    })
    |> render_submit()

    link =
      Emakola.Orders.PayLink
      |> Ash.read!(authorize?: false)
      |> Enum.find(&(&1.title == "Kente"))

    assert link.note == "VIP customer deal"
    assert DateTime.to_date(link.expires_at) == ~D[2026-08-15]
  end

  test "creates a catalog link from the product picker", %{conn: conn, store: store} do
    product = Factory.create_product!(store, %{status: :active})
    variant = Factory.create_variant!(product, store, %{price: 12_000})

    {:ok, view, _} = live(conn, "/admin/pay-links")

    view |> element("button", "New pay link") |> render_click()
    view |> element("button", "From catalog") |> render_click()

    html =
      view
      |> form("#pay-link-create-form", %{
        "pay_link" => %{"type" => "catalog", "variant_id" => variant.id, "quantity" => "2"}
      })
      |> render_submit()

    assert html =~ "/pay/"
    assert html =~ "wa.me"

    link =
      Emakola.Orders.PayLink
      |> Ash.read!(authorize?: false)
      |> Enum.find(&(&1.variant_id == variant.id))

    assert link.type == :catalog
    assert link.quantity == 2
  end

  test "the product picker only lists this store's own variants, and a foreign variant_id is rejected",
       %{conn: conn, store: store} do
    other_store = Factory.create_store!()

    other_product =
      Factory.create_product!(other_store, %{status: :active, title: "Foreign Product"})

    other_variant = Factory.create_variant!(other_product, other_store, %{price: 5_000})

    _own_product = Factory.create_product!(store, %{status: :active, title: "Own Product"})

    {:ok, view, _} = live(conn, "/admin/pay-links")

    html = view |> element("button", "New pay link") |> render_click()
    refute html =~ "Foreign Product"

    view |> element("button", "From catalog") |> render_click()

    # The <select> legitimately has no option for a foreign store's variant —
    # `form/3` would refuse to build this submission (proving the picker is
    # scoped). Push the event directly to simulate a crafted request that
    # bypasses the rendered UI entirely, and confirm the handler itself
    # rejects it too (defense in depth, not just an absent option).
    html2 =
      render_submit(view, "create", %{
        "pay_link" => %{"type" => "catalog", "variant_id" => other_variant.id, "quantity" => "1"}
      })

    refute html2 =~ "wa.me"

    refute Emakola.Orders.PayLink
           |> Ash.read!(authorize?: false)
           |> Enum.any?(&(&1.variant_id == other_variant.id))
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
