defmodule EmakolaWeb.Storefront.AdwumaThemeTest do
  @moduledoc """
  The failure modes nothing else catches.

  `pdp_parity_test` seeds a product with no `product_type`, which defaults to
  `:physical` — so it drives the delivery branch and proves that side. Nothing
  in the shared suite ever renders a *digital* product, so without this file the
  branch could silently invert and every theme test would still pass.

  Also pins that the home page renders its sections rather than the blank
  storefront a missing `@sectionized_themes` entry produces.
  """
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest

  defp adwuma_store! do
    create_store!(%{theme_config: %{"theme" => "adwuma"}, currency: "GHS"})
    |> Ash.Changeset.for_update(:update_settings, %{
      enabled_product_types: [:physical, :digital_download]
    })
    |> Ash.update!(authorize?: false)
  end

  defp zone!(store) do
    create_delivery_zone!(store, %{name: "Accra", estimated_days: 1})
  end

  describe "registration" do
    # A theme registered in ThemeResolver but not in @sectionized_themes
    # renders a navigable, completely BLANK home page — no crash, only a log
    # warning nobody reads.
    test "the home page renders sections, not a blank shell", %{conn: conn} do
      store = adwuma_store!()
      product = create_product!(store, %{title: "Highlife Pack", status: :active})
      create_variant!(product, store, %{price: 5000, sku: "ADW-HOME"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "adwuma-content"
      # A section-only string: chrome alone would not produce it.
      assert html =~ "Why buy here"
    end
  end

  describe "the PDP fulfilment line branches on product type" do
    test "a physical product shows the store's real delivery terms", %{conn: conn} do
      store = adwuma_store!()
      zone!(store)

      product = create_product!(store, %{title: "Vinyl Record", status: :active})
      create_variant!(product, store, %{price: 45_000, stock_quantity: 4, sku: "ADW-PHYS"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ "Next day"
      refute html =~ "In your account after payment"
    end

    test "a download says where it actually arrives, and promises no delivery", %{conn: conn} do
      store = adwuma_store!()
      zone!(store)

      product =
        create_product!(store, %{
          title: "Highlife Sample Pack",
          status: :active,
          product_type: :digital_download
        })

      create_variant!(product, store, %{price: 5000, sku: "ADW-DIG"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ "In your account after payment"
      refute html =~ "Next day"
    end
  end
end
