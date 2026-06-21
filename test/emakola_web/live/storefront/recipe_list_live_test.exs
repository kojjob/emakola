defmodule EmakolaWeb.Storefront.RecipeListLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

  test "emits apex canonical and a recipe-index meta description", %{conn: conn} do
    store = Factory.create_store!(%{name: "Recipe List Shop", slug: "recipe-list-seo"})

    {:ok, _view, html} = live(conn, "/@#{store.slug}/recipes")

    assert html =~ ~s(<link rel="canonical" href="http://localhost:4000/@#{store.slug}/recipes")
    assert html =~ ~s(<meta name="description" content="Recipes from Recipe List Shop.")
  end
end
