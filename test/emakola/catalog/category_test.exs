defmodule Emakola.Catalog.CategoryTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  # ── Creation ──────────────────────────────────────────────────

  describe "create" do
    test "creates a category with valid attributes", %{store: store} do
      category = create_category!(store, name: "Electronics")

      assert category.id
      assert category.name == "Electronics"
      assert category.store_id == store.id
      assert category.slug == "electronics"
      assert category.position == 0
      assert is_nil(category.parent_id)
    end

    test "auto-generates slug from name", %{store: store} do
      category = create_category!(store, name: "Men's Clothing & Accessories")
      assert category.slug == "mens-clothing-accessories"
    end

    test "handles Unicode names for slug generation", %{store: store} do
      category = create_category!(store, name: "Akwaaba Marketplace")
      assert category.slug
      assert is_binary(category.slug)
      assert String.length(category.slug) > 0
    end

    test "rejects blank name", %{store: store} do
      assert {:error, _} =
               Emakola.Catalog.Category
               |> Ash.Changeset.for_create(:create, %{name: "", store_id: store.id})
               |> Ash.create(authorize?: false)
    end

    test "rejects nil name", %{store: store} do
      assert {:error, _} =
               Emakola.Catalog.Category
               |> Ash.Changeset.for_create(:create, %{store_id: store.id})
               |> Ash.create(authorize?: false)
    end

    test "creates category with description", %{store: store} do
      category = create_category!(store, name: "Food", description: "Fresh produce and groceries")
      assert category.description == "Fresh produce and groceries"
    end

    test "creates child category with parent_id", %{store: store} do
      parent = create_category!(store, name: "Clothing")
      child = create_category!(store, name: "Dresses", parent_id: parent.id)

      assert child.parent_id == parent.id
    end
  end

  # ── Slug uniqueness ───────────────────────────────────────────

  describe "slug uniqueness" do
    test "rejects duplicate slug within same store", %{store: store} do
      create_category!(store, name: "Electronics")

      assert {:error, _} =
               Emakola.Catalog.Category
               |> Ash.Changeset.for_create(:create, %{
                 name: "Electronics",
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "allows same slug in different stores" do
      store_a = create_store!(name: "Store A", slug: "store-a")
      store_b = create_store!(name: "Store B", slug: "store-b")

      cat_a = create_category!(store_a, name: "Electronics")
      cat_b = create_category!(store_b, name: "Electronics")

      assert cat_a.slug == "electronics"
      assert cat_b.slug == "electronics"
      assert cat_a.store_id != cat_b.store_id
    end
  end

  # ── Multi-tenancy ─────────────────────────────────────────────

  describe "multi-tenant isolation" do
    test "categories are scoped to store", %{store: store} do
      other_store = create_store!(name: "Other Store", slug: "other-store")

      create_category!(store, name: "My Category")
      create_category!(other_store, name: "Their Category")

      my_cats =
        Emakola.Catalog.Category
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert length(my_cats) == 1
      assert hd(my_cats).name == "My Category"
    end
  end

  # ── Hierarchy ─────────────────────────────────────────────────

  describe "hierarchy" do
    test "creates multi-level category tree", %{store: store} do
      root = create_category!(store, name: "Clothing")
      child = create_category!(store, name: "Men's", parent_id: root.id)
      grandchild = create_category!(store, name: "Shirts", parent_id: child.id)

      assert root.parent_id == nil
      assert child.parent_id == root.id
      assert grandchild.parent_id == child.id
    end

    test "list_roots returns only root categories", %{store: store} do
      root1 = create_category!(store, name: "Electronics", position: 1)
      _root2 = create_category!(store, name: "Clothing", position: 0)
      _child = create_category!(store, name: "Phones", parent_id: root1.id)

      roots = Emakola.Catalog.list_root_categories!(store.id)

      assert length(roots) == 2
      # Should be ordered by position
      assert hd(roots).name == "Clothing"
    end

    test "list_children returns children of a category", %{store: store} do
      parent = create_category!(store, name: "Electronics")
      _child1 = create_category!(store, name: "Phones", parent_id: parent.id, position: 1)
      child2 = create_category!(store, name: "Laptops", parent_id: parent.id, position: 0)
      _other = create_category!(store, name: "Clothing")

      children = Emakola.Catalog.list_child_categories!(parent.id, store.id)

      assert length(children) == 2
      # Should be ordered by position
      assert hd(children).id == child2.id
    end
  end

  # ── Update ────────────────────────────────────────────────────

  describe "update" do
    test "updates name and regenerates slug", %{store: store} do
      category = create_category!(store, name: "Old Name")

      updated =
        category
        |> Ash.Changeset.for_update(:update, %{name: "New Name"})
        |> Ash.update!(authorize?: false)

      assert updated.name == "New Name"
      assert updated.slug == "new-name"
    end

    test "updates position", %{store: store} do
      category = create_category!(store, name: "Test")

      updated =
        category
        |> Ash.Changeset.for_update(:update, %{position: 5})
        |> Ash.update!(authorize?: false)

      assert updated.position == 5
    end

    test "updates description", %{store: store} do
      category = create_category!(store, name: "Test")

      updated =
        category
        |> Ash.Changeset.for_update(:update, %{description: "Updated description"})
        |> Ash.update!(authorize?: false)

      assert updated.description == "Updated description"
    end

    test "can move category to different parent", %{store: store} do
      parent_a = create_category!(store, name: "Parent A")
      parent_b = create_category!(store, name: "Parent B")
      child = create_category!(store, name: "Child", parent_id: parent_a.id)

      updated =
        child
        |> Ash.Changeset.for_update(:update, %{parent_id: parent_b.id})
        |> Ash.update!(authorize?: false)

      assert updated.parent_id == parent_b.id
    end
  end

  # ── Destroy ───────────────────────────────────────────────────

  describe "destroy" do
    test "deletes a leaf category", %{store: store} do
      category = create_category!(store, name: "To Delete")

      assert :ok = Ash.destroy!(category)

      assert [] =
               Emakola.Catalog.Category
               |> Ash.Query.filter(store_id == ^store.id)
               |> Ash.read!(authorize?: false)
    end
  end

  # ── Edge cases ────────────────────────────────────────────────

  describe "edge cases" do
    test "category cannot be its own parent", %{store: store} do
      category = create_category!(store, name: "Self-referencing")

      assert {:error, _} =
               category
               |> Ash.Changeset.for_update(:update, %{parent_id: category.id})
               |> Ash.update(authorize?: false)
    end

    test "whitespace-only name is rejected", %{store: store} do
      assert {:error, _} =
               Emakola.Catalog.Category
               |> Ash.Changeset.for_create(:create, %{name: "   ", store_id: store.id})
               |> Ash.create(authorize?: false)
    end

    test "very long name is handled gracefully", %{store: store} do
      long_name = String.duplicate("a", 255)
      category = create_category!(store, name: long_name)
      assert category.name == long_name
    end
  end
end
