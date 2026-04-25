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

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/blog/#{post.slug}")
    assert html =~ "My Great Post"
    assert html =~ "Hello world"
  end

  test "redirects when post not found", %{conn: conn, store: store} do
    assert {:error, {:redirect, _}} = live(conn, "/s/#{store.slug}/blog/nonexistent")
  end
end
