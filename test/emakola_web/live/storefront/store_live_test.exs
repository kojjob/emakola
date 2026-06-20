defmodule EmakolaWeb.Storefront.StoreLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

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
