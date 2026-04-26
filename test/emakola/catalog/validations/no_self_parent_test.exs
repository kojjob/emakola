defmodule Emakola.Catalog.Validations.NoSelfParentTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Catalog.Validations.NoSelfParent

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  describe "validate/3" do
    test "passes when parent_id is nil (root category)", %{store: store} do
      category = create_category!(store, name: "Root Category")

      changeset =
        category
        |> Ash.Changeset.for_update(:update, %{parent_id: nil})

      assert :ok == NoSelfParent.validate(changeset, [], %{})
    end

    test "passes when parent_id is a different category", %{store: store} do
      parent = create_category!(store, name: "Parent")
      child = create_category!(store, name: "Child")

      changeset =
        child
        |> Ash.Changeset.for_update(:update, %{parent_id: parent.id})

      assert :ok == NoSelfParent.validate(changeset, [], %{})
    end

    test "rejects when parent_id references itself", %{store: store} do
      category = create_category!(store, name: "Self Referencing")

      changeset =
        category
        |> Ash.Changeset.for_update(:update, %{parent_id: category.id})

      assert {:error, error} = NoSelfParent.validate(changeset, [], %{})
      assert error.field == :parent_id
      assert error.message =~ "cannot be its own parent"
    end

    test "integration: updating category to reference itself fails", %{store: store} do
      category = create_category!(store, name: "Test Category")

      assert {:error, _} =
               category
               |> Ash.Changeset.for_update(:update, %{parent_id: category.id})
               |> Ash.update(authorize?: false)
    end

    test "integration: setting a valid parent succeeds", %{store: store} do
      parent = create_category!(store, name: "Electronics")
      child = create_category!(store, name: "Phones")

      assert {:ok, updated} =
               child
               |> Ash.Changeset.for_update(:update, %{parent_id: parent.id})
               |> Ash.update(authorize?: false)

      assert updated.parent_id == parent.id
    end

    test "integration: creating a child category with valid parent works", %{store: store} do
      parent = create_category!(store, name: "Clothing")
      child = create_category!(store, name: "Dresses", parent_id: parent.id)

      assert child.parent_id == parent.id
    end
  end
end
