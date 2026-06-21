defmodule EmakolaWeb.Storefront.BlogPostLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Blog Post Shop", slug: "blog-post-shop"})
    {:ok, store: store}
  end

  test "renders a published blog post", %{conn: conn, store: store} do
    post =
      Factory.create_post!(store, %{
        title: "My Great Post",
        type: :blog_post,
        body: "<p>Hello world</p>"
      })

    post |> Ash.Changeset.for_update(:publish) |> Ash.update!(authorize?: false)

    {:ok, _view, html} = live(conn, "/@#{store.slug}/blog/#{post.slug}")
    assert html =~ "My Great Post"
    assert html =~ "Hello world"
  end

  test "redirects when post not found", %{conn: conn, store: store} do
    assert {:error, {:redirect, _}} = live(conn, "/@#{store.slug}/blog/nonexistent")
  end

  test "emits Article JSON-LD, apex canonical, and meta description", %{conn: conn, store: store} do
    post =
      Factory.create_post!(store, %{
        title: "Smoky Jollof Secrets",
        type: :blog_post,
        body: "<p>Tips</p>",
        excerpt: "How to get the smoky flavor.",
        seo_description: "The complete guide to smoky party jollof rice."
      })

    post |> Ash.Changeset.for_update(:publish) |> Ash.update!(authorize?: false)

    {:ok, _view, html} = live(conn, "/@#{store.slug}/blog/#{post.slug}")

    assert html =~
             ~s(<link rel="canonical" href="http://localhost:4000/@#{store.slug}/blog/#{post.slug}")

    assert html =~ ~s("@type":"BlogPosting")
    assert html =~ ~s("headline":"Smoky Jollof Secrets")

    assert html =~
             ~s(<meta name="description" content="The complete guide to smoky party jollof rice.")
  end
end
