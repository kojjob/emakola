defmodule EmakolaWeb.Storefront.StoreLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

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
  end

  test "emits LocalBusiness JSON-LD derived from the store profile", %{conn: conn} do
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

    assert html =~ ~s("@type":"LocalBusiness")
    assert html =~ ~s("addressLocality":"Accra")
    assert html =~ ~s("addressCountry":"GH")
    assert html =~ ~s("telephone":"+233200000000")
    # JSON-LD is rendered with Jason escape: :html_safe, so "/" becomes "\/".
    assert html =~ ~s("sameAs":["https:\\/\\/instagram.com\\/amakitchen"])
  end
end
