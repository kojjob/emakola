defmodule EmakolaWeb.Storefront.TrackingHonestyTest do
  @moduledoc """
  Two defects on the customer tracking page.

  The tracking number was write-only: merchants can record one at both order
  and fulfilment level, notifications link the buyer to this page, and the
  number appeared nowhere on it.

  And the page rendered an SVG grid of road-like lines labelled
  `aria-label="Map showing delivery route"`. No location data exists anywhere
  in this system. A grey grid with no caption is a texture; the same graphic
  labelled as a route makes a factual claim — to exactly the users least able
  to check it.
  """
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest

  defp shipped_order!(tracking_number, courier \\ nil) do
    store = create_store!()
    product = create_product!(store)
    variant = create_variant!(product, store, price: 20_000, sku: "TRK-H", stock_quantity: 5)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 1}],
        shipping_address: %{"phone" => "+233240000011", "name" => "Ama"}
      )

    order =
      order
      |> Ash.Changeset.for_update(:confirm, %{})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:start_processing, %{})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:mark_shipped, %{
        tracking_number: tracking_number,
        courier: courier
      })
      |> Ash.update!(authorize?: false)

    %{store: store, order: order}
  end

  test "the buyer can see the tracking number the merchant recorded" do
    ctx = shipped_order!("GH-TRACK-4471")

    {:ok, _view, html} =
      live(build_conn(), "/s/#{ctx.store.slug}/track/#{ctx.order.order_number}")

    assert html =~ "GH-TRACK-4471"
  end

  test "no graphic claims to show a delivery route" do
    ctx = shipped_order!("GH-TRACK-4472")

    {:ok, _view, html} =
      live(build_conn(), "/s/#{ctx.store.slug}/track/#{ctx.order.order_number}")

    refute html =~ "Map showing delivery route"
  end

  test "a courier with a known tracking URL makes the number clickable" do
    ctx = shipped_order!("GH-TRACK-4473", :dhl)

    {:ok, _view, html} =
      live(build_conn(), "/s/#{ctx.store.slug}/track/#{ctx.order.order_number}")

    assert html =~ "dhl.com"
    assert html =~ "GH-TRACK-4473"
  end

  # A guessed link lands the buyer on someone else's 404 and reads as the
  # shop's mistake.
  test "a courier with no known URL shows the number as plain text" do
    ctx = shipped_order!("GH-TRACK-4474", :local_rider)

    {:ok, _view, html} =
      live(build_conn(), "/s/#{ctx.store.slug}/track/#{ctx.order.order_number}")

    assert html =~ "GH-TRACK-4474"
    refute html =~ "dhl.com"
  end
end
