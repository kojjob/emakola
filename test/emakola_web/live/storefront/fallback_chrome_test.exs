defmodule EmakolaWeb.Storefront.FallbackChromeTest do
  @moduledoc """
  Fallback pages (cart, checkout, account, ...) render inside whatever theme
  the store runs. They must use the active theme's own nav/footer when the
  theme provides storefront chrome, instead of hardwiring Atelier's — which
  swapped the store's entire chrome mid-funnel for non-Atelier themes.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  @all_themes ~w(akoma atelier beauty bold electronics fashion fresh heritage
                 home_living market pharmacy spotlight starter vibrant)

  describe "theme-owned chrome on fallback pages" do
    test "a Beauty store's cart renders Beauty's nav and footer", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "beauty"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Beauty nav header (cream, blurred, sand border) and footer (espresso)
      assert html =~ "bg-[#F5EFE5]/95"
      assert html =~ "bg-[#3D2F25]"
    end
  end

  describe "fallback cart smoke across the catalog" do
    for theme <- @all_themes do
      @theme theme
      test "renders without crashing for the #{theme} theme", %{conn: conn} do
        store = Factory.create_store!(%{theme_config: %{"theme" => @theme}})

        {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

        assert html =~ store.name
      end
    end
  end
end
