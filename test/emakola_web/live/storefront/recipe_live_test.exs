defmodule EmakolaWeb.Storefront.RecipeLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Recipe Shop", slug: "recipe-shop"})
    {:ok, store: store}
  end

  test "emits Recipe JSON-LD with ingredients, canonical, and meta description", %{
    conn: conn,
    store: store
  } do
    post =
      Factory.create_post!(store, %{
        title: "Ghana Jollof Rice",
        type: :recipe,
        body: "<p>Cook it</p>",
        excerpt: "Smoky party jollof.",
        seo_description: "Authentic smoky Ghana jollof rice recipe."
      })

    post |> Ash.Changeset.for_update(:publish) |> Ash.update!(authorize?: false)
    Factory.create_recipe_meta!(post, %{prep_time: 20, cook_time: 40, servings: 6})

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/recipes/#{post.slug}")

    assert html =~ ~s("@type":"Recipe")
    assert html =~ ~s("name":"Ghana Jollof Rice")
    assert html =~ ~s("recipeIngredient":["2 cups Rice")
    assert html =~ ~s("prepTime":"PT20M")

    assert html =~
             ~s(<link rel="canonical" href="http://localhost:4000/s/#{store.slug}/recipes/#{post.slug}")

    assert html =~
             ~s(<meta name="description" content="Authentic smoky Ghana jollof rice recipe.")
  end

  test "redirects when recipe not found", %{conn: conn, store: store} do
    assert {:error, {:redirect, _}} = live(conn, "/s/#{store.slug}/recipes/nonexistent")
  end
end
