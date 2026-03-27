defmodule EmakolaWeb.Admin.Content.PostLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "PostLive.Index" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      {:ok, conn: conn, store: store, merchant: merchant}
    end

    test "renders empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/content/posts")
      assert html =~ "Content"
      assert html =~ "No posts yet"
    end

    test "lists posts for the store", %{conn: conn, store: store} do
      Factory.create_post!(store, %{title: "My Blog Post"})
      {:ok, _view, html} = live(conn, ~p"/admin/content/posts")
      assert html =~ "My Blog Post"
    end

    test "has new post button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/content/posts")
      assert html =~ "New Post"
    end

    test "filters by type", %{conn: conn, store: store} do
      Factory.create_post!(store, %{title: "Blog Entry", type: :blog_post})
      Factory.create_post!(store, %{title: "Store Page", type: :page})

      {:ok, view, _html} = live(conn, ~p"/admin/content/posts")

      html = view |> element("button", "Blog Posts") |> render_click()
      assert html =~ "Blog Entry"
      refute html =~ "Store Page"
    end

    test "filters by status", %{conn: conn, store: store} do
      post = Factory.create_post!(store, %{title: "Published One"})
      post |> Ash.Changeset.for_update(:publish) |> Ash.update!()
      Factory.create_post!(store, %{title: "Draft One"})

      {:ok, view, _html} = live(conn, ~p"/admin/content/posts")

      html = view |> element("button", "Published") |> render_click()
      assert html =~ "Published One"
      refute html =~ "Draft One"
    end
  end

  # ── Helpers ──

  defp setup_authenticated_merchant(conn, store_attrs \\ %{}) do
    {merchant, store} = Factory.create_merchant_with_store!(store_attrs)
    token = AshAuthentication.user_to_subject(merchant)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, merchant, store}
  end
end
