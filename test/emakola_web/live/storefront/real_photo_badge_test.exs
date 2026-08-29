defmodule EmakolaWeb.Storefront.RealPhotoBadgeTest do
  @moduledoc """
  The "Real photo" PDP badge tells a shopper this listing's lead photo was
  taken with the seller's camera, not lifted from a supplier catalog
  (spec: docs/superpowers/specs/2026-08-05-snap-to-shop-design.md). It must
  reflect Product.snap_verified live: present while verified, gone the
  instant an image mutation revokes it (Task 2).
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Themes.ThemeResolver

  # Every registered theme, not a hand-maintained list — the structural test
  # (real_photo_badge_coverage_test.exs) only proves the badge component is
  # referenced in each theme's source; it can't tell a live insertion from
  # one buried in dead code. This proves the badge actually renders.
  @all_themes ThemeResolver.theme_ids()

  describe "every theme renders the badge for a snap-verified product" do
    for theme <- @all_themes do
      @theme theme

      test "#{theme} PDP", %{conn: conn} do
        store = create_store!(%{theme_config: %{"theme" => @theme}})
        product = create_product!(store, %{status: :active, title: "Verified Bowl"})
        create_variant!(product, store, %{price: 5000, stock_quantity: 10})

        {:ok, product} =
          product
          |> Ash.Changeset.for_update(:set_snap_verified, %{snap_verified: true},
            tenant: store.id,
            authorize?: false
          )
          |> Ash.update()

        {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

        assert html =~ "Real photo",
               "the #{@theme} PDP does not render the Real photo badge for a snap-verified product"
      end
    end
  end

  test "a snap-verified product shows the Real photo badge on its PDP", %{conn: conn} do
    store = create_store!()
    product = create_product!(store, %{status: :active, title: "Verified Bowl"})
    create_variant!(product, store, %{price: 5000, stock_quantity: 10})

    {:ok, product} =
      product
      |> Ash.Changeset.for_update(:set_snap_verified, %{snap_verified: true},
        tenant: store.id,
        authorize?: false
      )
      |> Ash.update()

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

    assert html =~ "Real photo"
  end

  test "an unverified product's PDP shows no Real photo badge", %{conn: conn} do
    store = create_store!()
    product = create_product!(store, %{status: :active, title: "Unverified Bowl"})
    create_variant!(product, store, %{price: 5000, stock_quantity: 10})

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

    refute html =~ "Real photo"
  end

  test "revoking the badge after an image mutation removes it from a re-render", %{conn: conn} do
    store = create_store!()
    product = create_product!(store, %{status: :active, title: "Revoked Bowl"})
    create_variant!(product, store, %{price: 5000, stock_quantity: 10})
    image = create_image!(product, store, %{position: 0})

    {:ok, product} =
      product
      |> Ash.Changeset.for_update(:set_snap_verified, %{snap_verified: true},
        tenant: store.id,
        authorize?: false
      )
      |> Ash.update()

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")
    assert html =~ "Real photo"

    # A real image mutation (repositioning) revokes the badge, same as the
    # domain-level guarantee tested in
    # test/emakola/catalog/snap_verified_revocation_test.exs.
    image
    |> Ash.Changeset.for_update(:update, %{position: 1}, tenant: store.id, authorize?: false)
    |> Ash.update!()

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")
    refute html =~ "Real photo"
  end

  describe "badge copy is modest" do
    test "the badge component source pins the exact copy" do
      source = File.read!("lib/emakola/themes/shared/real_photo_badge.ex")

      assert source =~ "Real photo"
      assert source =~ "Photographed by seller"
    end

    test "a verified product's badge makes no claim stronger than 'Real photo'" do
      html =
        render_component(&Emakola.Themes.Shared.RealPhotoBadge.badge/1, %{
          product: %{snap_verified: true}
        })

      assert html =~ "Real photo"

      downcased = String.downcase(html)

      for stronger_claim <- ~w(authentic verified certified guaranteed) do
        refute downcased =~ stronger_claim,
               "the badge claims #{inspect(stronger_claim)} — spec pins the copy to 'Real photo'"
      end
    end
  end
end
