defmodule EmakolaWeb.Storefront.StoreLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "page-builder home override" do
    test "renders the published home page instead of the theme home", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "market"}})

      {:ok, _page} =
        Emakola.Pages.create_page(
          %{
            store_id: store.id,
            slug: "home",
            title: "Custom Home",
            published: true,
            blocks: [
              %{
                "id" => "b1",
                "type" => "text_section",
                "content" => %{"title" => "Handmade in Accra"}
              }
            ]
          },
          authorize?: false
        )

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "Handmade in Accra"
    end

    test "falls through to the theme home when no page is published", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "market"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ ~r/<header[^>]*role="banner"/
    end
  end

  describe "Market home chrome (theme-owned nav)" do
    test "renders a banner header with cart, search, and category navigation", %{conn: conn} do
      store =
        Factory.create_store!(%{
          name: "Adjoa's Stall",
          slug: "adjoa-stall-nav",
          theme_config: %{"theme" => "market"}
        })

      Factory.create_category!(store, %{name: "Fresh Peppers"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/adjoa-stall-nav\/cart"/
      assert html =~ ~r/aria-label="Search products"/
      assert html =~ ~s(href="/s/adjoa-stall-nav/category/fresh-peppers")
      # Skip link + landmarks floor
      assert html =~ ~s(href="#market-content")
      assert html =~ ~s(id="market-content")
    end

    test "the newsletter section form submits through the platform hook", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "market"}})

      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      html =
        view
        |> form("#market-newsletter-form", %{"email" => "efua@example.com"})
        |> render_submit()

      assert html =~ "Thanks for subscribing"
    end

    test "a store with zero products renders an intentional empty state", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "market"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "The stall is being set up"
      assert html =~ "added any products yet"
    end

    test "sold-out and sale states render from live variant stock", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "market"}})

      gone = Factory.create_product!(store, %{title: "Gone Basket", status: :active})

      Factory.create_variant!(gone, store, %{
        price: 4550,
        stock_quantity: 0,
        track_inventory: true
      })

      deal = Factory.create_product!(store, %{title: "Deal Cloth", status: :active})

      Factory.create_variant!(deal, store, %{
        price: 4550,
        compare_at_price: 6075,
        stock_quantity: 9
      })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "Sold out"
      assert html =~ "GH₵ 60.75"
      assert html =~ "line-through"
    end
  end

  test "emits physical LocalBusiness JSON-LD without guessing a country", %{conn: conn} do
    store =
      Factory.create_store!(%{
        name: "Ama's Kitchen",
        slug: "ama-kitchen-seo",
        city: "Accra",
        region: "Greater Accra",
        address: "12 Oxford Street",
        contact_phone: "+233200000000",
        instagram_url: "https://instagram.com/amakitchen"
      })

    {:ok, _view, html} = live(conn, "/s/#{store.slug}")
    document = LazyHTML.from_fragment(html)

    schema =
      document
      |> LazyHTML.query(~s(script[type="application/ld+json"]))
      |> LazyHTML.text()
      |> Jason.decode!()

    assert schema["@type"] == "LocalBusiness"
    assert schema["address"]["addressLocality"] == "Accra"
    refute Map.has_key?(schema["address"], "addressCountry")
    assert schema["telephone"] == "+233200000000"
    assert schema["sameAs"] == ["https://instagram.com/amakitchen"]
  end
end
