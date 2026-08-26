defmodule EmakolaWeb.Storefront.ContactLiveTest do
  @moduledoc """
  The storefront Contact page reuses the store's own contact details and adds
  an optional per-store note/hours. With nothing customised it still shows a
  neutral, store-name-driven page.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "GET /:slug/contact" do
    test "renders the store's contact details with neutral copy", %{conn: conn} do
      store =
        Factory.create_store!(%{
          name: "Ama Crafts",
          slug: "ama-crafts",
          contact_email: "hello@ama.test",
          contact_phone: "0241234567"
        })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/contact")

      assert html =~ "Ama Crafts"
      assert html =~ "Get in touch"
      assert html =~ "mailto:hello@ama.test"
      assert html =~ "tel:0241234567"

      assert html
             |> LazyHTML.from_fragment()
             |> LazyHTML.query(
               ~s(link[rel="canonical"][href="http://localhost:4000/#{store.slug}/contact"])
             )
             |> Enum.any?()
    end

    test "renders the store's custom contact note and opening hours", %{conn: conn} do
      store = Factory.create_store!(%{name: "Kofi Beans", slug: "kofi-beans-contact"})

      Factory.create_page_content!(store, %{
        contact_note: "We reply within 24 hours.",
        contact_hours: "Mon-Fri 8am-5pm"
      })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/contact")

      assert html =~ "We reply within 24 hours."
      assert html =~ "Mon-Fri 8am-5pm"
    end

    test "does not show the coming-soon empty state when only an address is set", %{conn: conn} do
      store =
        Factory.create_store!(%{
          name: "Location Only",
          slug: "location-only",
          address: "15 Oxford Street",
          city: "Accra"
        })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/contact")

      assert html =~ "15 Oxford Street"
      refute html =~ "coming soon"
    end

    test "does not show the coming-soon empty state when only opening hours are set",
         %{conn: conn} do
      store = Factory.create_store!(%{name: "Hours Only", slug: "hours-only"})
      Factory.create_page_content!(store, %{contact_hours: "Mon-Sat, 10am - 7pm"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/contact")

      assert html =~ "Mon-Sat, 10am - 7pm"
      refute html =~ "coming soon"
    end

    test "shows the coming-soon empty state when the store has no contact methods",
         %{conn: conn} do
      store = Factory.create_store!(%{name: "Bare Store", slug: "bare-store"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/contact")

      assert html =~ "coming soon"
    end
  end
end
