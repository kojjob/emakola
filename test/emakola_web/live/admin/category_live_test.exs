defmodule EmakolaWeb.Admin.CategoryLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Catalog.Category
  alias Emakola.Factory

  require Ash.Query

  setup %{conn: conn} do
    {merchant, store} = Factory.create_merchant_with_store!(%{name: "Local Category Store"})

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn, merchant: merchant, store: store}
  end

  describe "tenant isolation" do
    test "a crafted delete event cannot delete another store's category", %{
      conn: conn
    } do
      {_other_merchant, other_store} =
        Factory.create_merchant_with_store!(%{name: "Foreign Delete Store"})

      foreign_category = Factory.create_category!(other_store, name: "Do Not Delete")
      {:ok, view, _html} = live(conn, ~p"/admin/categories")

      render_click(view, "delete_category", %{"id" => foreign_category.id})

      assert Ash.get!(Category, foreign_category.id, authorize?: false).name == "Do Not Delete"
      assert has_element?(view, "#categories-page")
    end

    test "a crafted edit flow cannot update another store's category", %{
      conn: conn,
      store: store
    } do
      {_other_merchant, other_store} =
        Factory.create_merchant_with_store!(%{name: "Foreign Update Store"})

      foreign_category = Factory.create_category!(other_store, name: "Original Foreign Name")
      {:ok, view, _html} = live(conn, ~p"/admin/categories")

      render_click(view, "open_edit_modal", %{"id" => foreign_category.id})

      view
      |> form("#category-form", %{
        "name" => "Attempted Foreign Rename",
        "description" => "",
        "parent_id" => ""
      })
      |> render_submit()

      assert Ash.get!(Category, foreign_category.id, authorize?: false).name ==
               "Original Foreign Name"

      assert [%{store_id: store_id}] =
               Category
               |> Ash.Query.filter(name == "Attempted Foreign Rename")
               |> Ash.read!(authorize?: false)

      assert store_id == store.id
    end

    test "a crafted create cannot attach a category to another store's parent", %{
      conn: conn,
      store: store
    } do
      {_other_merchant, other_store} =
        Factory.create_merchant_with_store!(%{name: "Foreign Parent Store"})

      foreign_parent = Factory.create_category!(other_store, name: "Foreign Parent")
      {:ok, view, _html} = live(conn, ~p"/admin/categories")

      render_submit(view, "save_category", %{
        "name" => "Cross-store Child",
        "description" => "",
        "parent_id" => foreign_parent.id
      })

      refute category_named?(store.id, "Cross-store Child")
      assert Ash.get!(Category, foreign_parent.id, authorize?: false).store_id == other_store.id
    end

    test "a crafted update cannot attach a local category to another store's parent", %{
      conn: conn,
      store: store
    } do
      local_category = Factory.create_category!(store, name: "Local Root")

      {_other_merchant, other_store} =
        Factory.create_merchant_with_store!(%{name: "Foreign Update Parent Store"})

      foreign_parent = Factory.create_category!(other_store, name: "Foreign Update Parent")
      {:ok, view, _html} = live(conn, ~p"/admin/categories")

      view
      |> element("#edit-category-#{local_category.id}")
      |> render_click()

      render_submit(view, "save_category", %{
        "name" => "Local Root",
        "description" => "",
        "parent_id" => foreign_parent.id
      })

      assert Ash.reload!(local_category, authorize?: false).parent_id == nil
    end

    test "authorized create, update, and delete use the merchant actor and current store tenant",
         %{
           conn: conn,
           store: store
         } do
      {:ok, view, _html} = live(conn, ~p"/admin/categories")

      view
      |> form("#category-form", %{
        "name" => "Authorized Category",
        "description" => "Owned locally",
        "parent_id" => ""
      })
      |> render_submit()

      assert category_named?(store.id, "Authorized Category")

      category =
        Category
        |> Ash.Query.filter(store_id == ^store.id and name == "Authorized Category")
        |> Ash.read_one!(authorize?: false)

      view
      |> element("#edit-category-#{category.id}")
      |> render_click()

      view
      |> form("#category-form", %{
        "name" => "Updated Category",
        "description" => "Still owned locally",
        "parent_id" => ""
      })
      |> render_submit()

      assert category_named?(store.id, "Updated Category")

      render_click(view, "delete_category", %{"id" => category.id})

      refute category_named?(store.id, "Updated Category")
    end
  end

  test "category mutations cannot silently reintroduce an authorization bypass" do
    source_path =
      Path.expand(
        "../../../../lib/emakola_web/live/admin/category_live/index.ex",
        __DIR__
      )

    source = File.read!(source_path)

    refute source =~ "authorize?: false"
    refute source =~ "Catalog.get_category(id)"
    assert source =~ "actor: socket.assigns[:current_merchant]"
    assert source =~ "tenant: socket.assigns.store_id"
    assert source =~ "Catalog.get_category_for_store(id, store_id, opts)"
  end

  defp category_named?(store_id, name) do
    Category
    |> Ash.Query.filter(store_id == ^store_id and name == ^name)
    |> Ash.exists?(authorize?: false)
  end
end
