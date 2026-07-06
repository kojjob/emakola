defmodule EmakolaWeb.Storefront.BlogListLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Blog Shop", slug: "blog-shop"})
    {:ok, store: store}
  end

  test "renders blog list with published posts", %{conn: conn, store: store} do
    post = Factory.create_post!(store, %{title: "Published Article", type: :blog_post})
    post |> Ash.Changeset.for_update(:publish) |> Ash.update!(authorize?: false)

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/blog")
    assert html =~ "Blog"
    assert html =~ "Published Article"
  end

  test "does not show draft posts", %{conn: conn, store: store} do
    Factory.create_post!(store, %{title: "Secret Draft", type: :blog_post})
    {:ok, _view, html} = live(conn, "/s/#{store.slug}/blog")
    refute html =~ "Secret Draft"
  end

  test "shows empty state when no posts", %{conn: conn, store: store} do
    {:ok, _view, html} = live(conn, "/s/#{store.slug}/blog")
    assert html =~ "Coming soon"
  end

  test "emits apex canonical and a blog-index meta description", %{conn: conn, store: store} do
    {:ok, _view, html} = live(conn, "/s/#{store.slug}/blog")

    assert html =~ ~s(<link rel="canonical" href="http://localhost:4000/s/#{store.slug}/blog")
    assert html =~ ~s(<meta name="description" content="Articles and updates from Blog Shop.")
  end
end
