defmodule EmakolaWeb.Storefront.ContactLiveTest do
  @moduledoc """
  The storefront Contact page reuses the store's own contact details and adds
  an optional per-store note/hours. With nothing customised it still shows a
  neutral, store-name-driven page.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "GET /s/:slug/contact" do
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
  end
end
