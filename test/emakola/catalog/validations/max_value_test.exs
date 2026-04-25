defmodule Emakola.Catalog.Validations.MaxValueTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Catalog.Validations.MaxValue

  setup do
    store = create_store!()
    product = create_product!(store)
    {:ok, store: store, product: product}
  end

  describe "validate/3" do
    test "passes when value is below max", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.jpg",
          content_type: "image/jpeg",
          file_size_bytes: 5_000_000,
          product_id: product.id,
          store_id: store.id
        })

      assert :ok ==
               MaxValue.validate(changeset, [attribute: :file_size_bytes, max: 10_000_000], %{})
    end

    test "passes when value is exactly at max", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.jpg",
          content_type: "image/jpeg",
          file_size_bytes: 10_000_000,
          product_id: product.id,
          store_id: store.id
        })

      assert :ok ==
               MaxValue.validate(changeset, [attribute: :file_size_bytes, max: 10_000_000], %{})
    end

    test "rejects when value exceeds max", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.jpg",
          content_type: "image/jpeg",
          file_size_bytes: 10_000_001,
          product_id: product.id,
          store_id: store.id
        })

      assert {:error, error} =
               MaxValue.validate(changeset, [attribute: :file_size_bytes, max: 10_000_000], %{})

      assert error.field == :file_size_bytes
      assert error.message =~ "must be at most"
    end

    test "passes when value is zero", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.jpg",
          content_type: "image/jpeg",
          file_size_bytes: 0,
          product_id: product.id,
          store_id: store.id
        })

      assert :ok ==
               MaxValue.validate(changeset, [attribute: :file_size_bytes, max: 10_000_000], %{})
    end

    test "passes when value is nil", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.jpg",
          content_type: "image/jpeg",
          product_id: product.id,
          store_id: store.id
        })

      assert :ok ==
               MaxValue.validate(changeset, [attribute: :file_size_bytes, max: 10_000_000], %{})
    end

    test "passes when value is negative", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.jpg",
          content_type: "image/jpeg",
          file_size_bytes: -100,
          product_id: product.id,
          store_id: store.id
        })

      assert :ok ==
               MaxValue.validate(changeset, [attribute: :file_size_bytes, max: 10_000_000], %{})
    end

    test "rejects value one over the max", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.jpg",
          content_type: "image/jpeg",
          file_size_bytes: 101,
          product_id: product.id,
          store_id: store.id
        })

      assert {:error, error} =
               MaxValue.validate(changeset, [attribute: :file_size_bytes, max: 100], %{})

      assert error.field == :file_size_bytes
      assert error.message == "must be at most 100"
    end

    test "integration: creating an image with file size over limit fails", %{
      store: store,
      product: product
    } do
      assert {:error, _} =
               Emakola.Catalog.Image
               |> Ash.Changeset.for_create(:create, %{
                 url: "https://example.com/huge.jpg",
                 content_type: "image/jpeg",
                 file_size_bytes: 15_000_000,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "integration: creating an image with file size at limit succeeds", %{
      store: store,
      product: product
    } do
      assert {:ok, image} =
               Emakola.Catalog.Image
               |> Ash.Changeset.for_create(:create, %{
                 url: "https://example.com/exact.jpg",
                 content_type: "image/jpeg",
                 file_size_bytes: 10_000_000,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)

      assert image.file_size_bytes == 10_000_000
    end
  end
end
