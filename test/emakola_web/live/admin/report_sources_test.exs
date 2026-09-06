defmodule EmakolaWeb.Admin.ReportSourcesTest do
  @moduledoc """
  Attribution was written on every order and read nowhere; visit sources were
  computed on every load and never rendered. A merchant buying ads could not
  see which ones brought orders.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  alias Emakola.Analytics.StoreVisits
  alias Emakola.Factory

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  test "orders and visits by source", ctx do
    Factory.create_order!(ctx.store, %{
      subtotal: 3_000,
      total: 3_000,
      status: :confirmed,
      attribution: %{"utm_source" => "instagram"}
    })

    Factory.create_order!(ctx.store, %{
      subtotal: 1_000,
      total: 1_000,
      status: :confirmed,
      attribution: %{"click_to_whatsapp" => true}
    })

    StoreVisits.record(ctx.store.id, "s1", %{"utm_source" => "tiktok"})
    StoreVisits.record(ctx.store.id, "s2", %{"utm_source" => "tiktok"})

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/reports")

    assert has_element?(view, "#reports-order-sources", "Instagram")
    assert has_element?(view, "#reports-order-sources", "GH₵ 30.00")
    assert has_element?(view, "#reports-order-sources", "WhatsApp")
    assert has_element?(view, "#reports-visit-sources", "TikTok")
    assert has_element?(view, "#reports-visit-sources", "2")
  end

  test "no orders means no source table, not an empty one", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/reports")

    refute has_element?(view, "#reports-order-sources")
    refute has_element?(view, "#reports-visit-sources")
  end

  test "another store's orders and visits never appear in this store's source tables", ctx do
    Factory.create_order!(ctx.store, %{
      subtotal: 500,
      total: 500,
      status: :confirmed,
      attribution: %{"utm_source" => "instagram"}
    })

    other = Factory.create_store!()

    Factory.create_order!(other, %{
      subtotal: 900_000,
      total: 900_000,
      status: :confirmed,
      attribution: %{"utm_source" => "facebook"}
    })

    StoreVisits.record(other.id, "other-visitor", %{"utm_source" => "tiktok"})

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/reports")

    assert has_element?(view, "#reports-order-sources", "Instagram")
    refute has_element?(view, "#reports-order-sources", "Facebook")
    refute render(view) =~ "9,000.00"
    refute has_element?(view, "#reports-visit-sources", "TikTok")
  end
end
