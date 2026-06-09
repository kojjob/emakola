defmodule Emakola.Catalog.DigitalFileTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  require Ash.Query

  alias Emakola.Catalog.DigitalFile

  setup do
    store = create_store!()
    product = create_product!(store, title: "Sample Product")
    {:ok, store: store, product: product}
  end

  defp valid_attrs(store, product, overrides \\ %{}) do
    Map.merge(
      %{
        store_id: store.id,
        product_id: product.id,
        file_name: "sample.zip",
        storage_key:
          "stores/#{store.id}/products/#{product.id}/files/#{Ecto.UUID.generate()}.zip",
        content_type: "application/zip",
        byte_size: 1_048_576
      },
      Map.new(overrides)
    )
  end

  defp create_file(store, product, overrides \\ %{}) do
    DigitalFile
    |> Ash.Changeset.for_create(:create, valid_attrs(store, product, overrides))
    |> Ash.create(authorize?: false)
  end

  describe ":create" do
    test "creates a digital file with all required fields", %{store: s, product: p} do
      assert {:ok, file} = create_file(s, p)
      assert file.store_id == s.id
      assert file.product_id == p.id
      assert file.file_name == "sample.zip"
      assert file.content_type == "application/zip"
      assert file.byte_size == 1_048_576
    end

    test "defaults :is_preview to false", %{store: s, product: p} do
      assert {:ok, file} = create_file(s, p)
      refute file.is_preview
    end

    test "defaults :position to 0", %{store: s, product: p} do
      assert {:ok, file} = create_file(s, p)
      assert file.position == 0
    end

    test "accepts :is_preview = true", %{store: s, product: p} do
      assert {:ok, file} = create_file(s, p, %{is_preview: true})
      assert file.is_preview
    end

    test "accepts a large byte_size that exceeds 32-bit integer range",
         %{store: s, product: p} do
      # 5 GB — would overflow 32-bit signed int (max ~2.1 GB)
      five_gb = 5 * 1024 * 1024 * 1024
      assert {:ok, file} = create_file(s, p, %{byte_size: five_gb})
      assert file.byte_size == five_gb
    end

    test "rejects blank file_name", %{store: s, product: p} do
      assert {:error, _} = create_file(s, p, %{file_name: ""})
    end

    test "rejects blank storage_key", %{store: s, product: p} do
      assert {:error, _} = create_file(s, p, %{storage_key: ""})
    end

    test "rejects whitespace-only file_name", %{store: s, product: p} do
      assert {:error, _} = create_file(s, p, %{file_name: "   "})
    end

    test "rejects negative byte_size", %{store: s, product: p} do
      assert {:error, _} = create_file(s, p, %{byte_size: -1})
    end

    test "rejects zero byte_size — empty files are a use error", %{store: s, product: p} do
      assert {:error, _} = create_file(s, p, %{byte_size: 0})
    end

    test "rejects missing store_id", %{store: s, product: p} do
      attrs = valid_attrs(s, p) |> Map.delete(:store_id)

      assert {:error, _} =
               DigitalFile
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)
    end

    test "rejects missing product_id", %{store: s, product: p} do
      attrs = valid_attrs(s, p) |> Map.delete(:product_id)

      assert {:error, _} =
               DigitalFile
               |> Ash.Changeset.for_create(:create, attrs)
               |> Ash.create(authorize?: false)
    end

    test "rejects duplicate (store_id, storage_key)", %{store: s, product: p} do
      key = "stores/#{s.id}/products/#{p.id}/files/uniq.zip"

      assert {:ok, _} = create_file(s, p, %{storage_key: key})
      assert {:error, _} = create_file(s, p, %{storage_key: key})
    end

    test "allows the same storage_key in a different store", %{product: p} do
      # Same key string is fine if it lives under a different store's namespace
      key = "shared/path/file.zip"
      store_a = create_store!(name: "A", slug: "a-#{System.unique_integer([:positive])}")
      store_b = create_store!(name: "B", slug: "b-#{System.unique_integer([:positive])}")
      product_a = create_product!(store_a)
      product_b = create_product!(store_b)
      _ = p

      assert {:ok, _} = create_file(store_a, product_a, %{storage_key: key})
      assert {:ok, _} = create_file(store_b, product_b, %{storage_key: key})
    end
  end

  describe ":update" do
    test "can update file_name, position, and is_preview", %{store: s, product: p} do
      {:ok, file} = create_file(s, p)

      assert {:ok, updated} =
               file
               |> Ash.Changeset.for_update(:update, %{
                 file_name: "renamed.zip",
                 position: 3,
                 is_preview: true
               })
               |> Ash.update(authorize?: false)

      assert updated.file_name == "renamed.zip"
      assert updated.position == 3
      assert updated.is_preview == true
    end

    test "rejects storage_key changes via :update (immutable once uploaded)",
         %{store: s, product: p} do
      {:ok, file} = create_file(s, p)

      assert {:error, %Ash.Error.Invalid{} = err} =
               file
               |> Ash.Changeset.for_update(:update, %{storage_key: "different/key.zip"})
               |> Ash.update(authorize?: false)

      assert Exception.message(err) =~ "storage_key"
    end
  end

  describe ":destroy" do
    test "removes the row", %{store: s, product: p} do
      {:ok, file} = create_file(s, p)

      assert :ok =
               file
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy(authorize?: false)

      assert {:error, _} = Ash.get(DigitalFile, file.id, authorize?: false)
    end
  end

  describe "relationships" do
    test "destroying the product cascades and removes its digital files",
         %{store: s, product: p} do
      {:ok, file} = create_file(s, p)

      :ok =
        p
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(authorize?: false)

      assert {:error, _} = Ash.get(DigitalFile, file.id, authorize?: false)
    end
  end

  describe "multitenancy" do
    test "stores cannot see each other's files via filtered read", %{store: s, product: p} do
      {:ok, mine} = create_file(s, p)

      other_store =
        create_store!(name: "Other", slug: "other-#{System.unique_integer([:positive])}")

      other_product = create_product!(other_store)
      {:ok, theirs} = create_file(other_store, other_product)

      ids =
        DigitalFile
        |> Ash.Query.filter(store_id == ^s.id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)

      assert mine.id in ids
      refute theirs.id in ids
    end
  end
end
