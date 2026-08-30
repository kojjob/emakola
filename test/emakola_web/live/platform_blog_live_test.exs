defmodule EmakolaWeb.PlatformBlogLiveTest do
  @moduledoc """
  Tests for the apex marketing blog at makola.io/blog — platform-level
  posts (nil store_id) for merchant acquisition SEO.
  """

  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp published_platform_post!(attrs) do
    attrs
    |> Emakola.Factory.create_platform_post!()
    |> Ash.Changeset.for_update(:publish, %{})
    |> Ash.update!(authorize?: false)
  end

  describe "blog index (/blog)" do
    test "lists published platform posts with SEO meta", %{conn: conn} do
      published_platform_post!(%{
        title: "How to Sell Online in Ghana",
        excerpt: "A practical guide for Ghanaian merchants."
      })

      {:ok, _view, html} = live(conn, "/blog")

      assert html =~ "How to Sell Online in Ghana"
      assert html =~ "A practical guide for Ghanaian merchants."
      assert html =~ ~s(<link rel="canonical" href="http://localhost:4000/blog")
    end

    test "does not list drafts or store-scoped posts", %{conn: conn} do
      Emakola.Content.Post
      |> Ash.Changeset.for_create(:create, %{
        type: :blog_post,
        title: "Hidden Platform Draft",
        body: "<p>draft</p>"
      })
      |> Ash.create!(authorize?: false)

      store = Emakola.Factory.create_store!()
      merchant_post = Emakola.Factory.create_post!(store, %{title: "Merchant Store Post"})

      merchant_post
      |> Ash.Changeset.for_update(:publish, %{})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, "/blog")

      refute html =~ "Hidden Platform Draft"
      refute html =~ "Merchant Store Post"
    end

    test "renders an empty state when no posts are published", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/blog")

      assert html =~ "No posts yet"
    end
  end

  describe "blog post (/blog/:post_slug)" do
    test "renders the post body with article JSON-LD", %{conn: conn} do
      published_platform_post!(%{
        title: "Accept MoMo Payments Online",
        body: "<h2>Why MoMo matters</h2><p>Most buyers in Ghana pay with mobile money.</p>",
        excerpt: "MoMo guide for merchants."
      })

      {:ok, _view, html} = live(conn, "/blog/accept-momo-payments-online")

      assert html =~ "Accept MoMo Payments Online"
      assert html =~ "Why MoMo matters"
      assert html =~ ~s("@type":"BlogPosting")

      assert html =~
               ~s(<link rel="canonical" href="http://localhost:4000/blog/accept-momo-payments-online")
    end

    test "sanitizes script tags out of the body", %{conn: conn} do
      published_platform_post!(%{
        title: "Sanitized Post",
        body: "<p>Safe</p><script>alert('xss')</script>"
      })

      {:ok, _view, html} = live(conn, "/blog/sanitized-post")

      assert html =~ "Safe"
      refute html =~ "<script>alert"
    end

    test "redirects an unknown slug to /blog", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/blog"}}} = live(conn, "/blog/does-not-exist")
    end

    test "renders a tap-to-play video when a clip ships for the slug", %{conn: conn} do
      # priv/static/videos/blog/how-to-sell-online-in-ghana.mp4 ships with the repo.
      published_platform_post!(%{title: "How to Sell Online in Ghana"})

      {:ok, _view, html} = live(conn, "/blog/how-to-sell-online-in-ghana")

      assert html =~ "<video"
      assert html =~ "/videos/blog/how-to-sell-online-in-ghana.mp4"
      assert html =~ ~s(preload="none")
    end

    test "renders no video element when no clip ships for the slug", %{conn: conn} do
      published_platform_post!(%{title: "Post Without Any Clip"})

      {:ok, _view, html} = live(conn, "/blog/post-without-any-clip")

      refute html =~ "<video"
    end
  end
end
