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

    test "an Akoma store's cart renders Akoma's chrome", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "akoma"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Akoma nav/footer sage border
      assert html =~ "border-[#E8EAE7]"
    end

    test "a Bold store's cart renders Bold's chrome", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "bold"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Bold slate-900 nav/footer background
      assert html =~ "bg-[#0F172A]"
    end

    test "an Electronics store's cart renders Electronics' chrome", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "electronics"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Electronics midnight footer
      assert html =~ "bg-[#0A0F1F]"
    end

    test "a Fashion store's cart renders Fashion's chrome", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "fashion"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Fashion violet footer
      assert html =~ "bg-[#5B21B6]"
    end

    test "a Fresh store's cart renders Fresh's chrome", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "fresh"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Fresh lemon-cream footer
      assert html =~ "bg-[#FEFCE8]"
    end

    test "a Heritage store's cart renders Heritage's chrome", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "heritage"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Heritage oxblood footer
      assert html =~ "bg-[#7A1F1F]"
    end

    test "a Home & Living store's cart renders Home & Living's chrome", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "home_living"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Home & Living heading class used by its nav wordmark and footer
      assert html =~ "home-living-heading"
    end

    test "a Pharmacy store's cart renders Pharmacy's chrome", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "pharmacy"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Pharmacy deep-green footer
      assert html =~ "bg-[#14543E]"
    end

    test "a Spotlight store's cart renders Spotlight's chrome", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "spotlight"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Spotlight heading class used by its nav wordmark and footer
      assert html =~ "spot-heading"
    end

    test "a Starter store's cart renders Starter's chrome", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "starter"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Starter footer link hover with theme-primary CSS variable
      assert html =~ "hover:text-[var(--theme-primary,#6366F1)]"
    end

    test "a Vibrant store's cart renders Vibrant's nav", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "vibrant"}})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      # Vibrant nav amber border (footer intentionally falls back to Atelier)
      assert html =~ "border-[#FDE68A]/60"
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
