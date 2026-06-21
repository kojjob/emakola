defmodule EmakolaWeb.Storefront.AboutLiveTest do
  @moduledoc """
  The storefront About page must read per-store content. When a store has not
  filled anything in, it falls back to NEUTRAL, store-name-driven copy — never
  the old shared "West African artisan / Preserving Heritage" prose.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "GET /s/:slug/about with no content row" do
    test "renders neutral, store-name-driven copy", %{conn: conn} do
      store = Factory.create_store!(%{name: "Adwoa Threads", slug: "adwoa-threads"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/about")

      assert html =~ "Adwoa Threads"
      assert html =~ "Welcome to Adwoa Threads"
    end

    test "does not leak the old hardcoded artisan/heritage prose", %{conn: conn} do
      store = Factory.create_store!(%{name: "Volta Electronics", slug: "volta-electronics"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/about")

      refute html =~ "West African artisans"
      refute html =~ "Preserving Heritage"
      refute html =~ "From Artisan Hands to Yours"
    end
  end

  describe "GET /s/:slug/about with custom content" do
    test "renders the store's own headline, story, steps and values", %{conn: conn} do
      store = Factory.create_store!(%{name: "Kofi Beans", slug: "kofi-beans"})

      Factory.create_page_content!(store, %{
        about_headline: "Roasted in Kumasi",
        about_intro: "Single-origin Ghanaian coffee.",
        about_story: "We roast in small batches.\n\nFreshness is everything.",
        about_steps: [
          %{"title" => "Pick your roast", "description" => "Light, medium or dark."}
        ],
        about_values: [
          %{"title" => "Bean transparency", "description" => "We name every farm."}
        ],
        about_cta_heading: "Taste the difference",
        about_cta_text: "Order a bag today."
      })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/about")

      assert html =~ "Roasted in Kumasi"
      assert html =~ "Single-origin Ghanaian coffee."
      assert html =~ "Freshness is everything."
      assert html =~ "Pick your roast"
      assert html =~ "Bean transparency"
      assert html =~ "Taste the difference"
      refute html =~ "Preserving Heritage"
    end

    test "custom content renders under a non-default theme too", %{conn: conn} do
      store =
        Factory.create_store!(%{
          name: "Market Mart",
          slug: "market-mart",
          theme_config: %{"theme" => "market"}
        })

      Factory.create_page_content!(store, %{about_headline: "Your neighbourhood grocer"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/about")

      assert html =~ "Your neighbourhood grocer"
    end
  end
end
