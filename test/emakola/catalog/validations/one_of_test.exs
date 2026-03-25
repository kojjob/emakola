defmodule Emakola.Catalog.Validations.OneOfTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Catalog.Validations.OneOf

  @allowed_content_types ["image/jpeg", "image/png", "image/webp"]

  setup do
    store = create_store!()
    product = create_product!(store)
    {:ok, store: store, product: product}
  end

  describe "validate/3" do
    test "passes when value is in allowed list", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.jpg",
          content_type: "image/jpeg",
          file_size_bytes: 500_000,
          product_id: product.id,
          store_id: store.id
        })

      assert :ok ==
               OneOf.validate(
                 changeset,
                 [attribute: :content_type, values: @allowed_content_types],
                 %{}
               )
    end

    test "passes for each allowed value", %{store: store, product: product} do
      for content_type <- @allowed_content_types do
        changeset =
          Emakola.Catalog.Image
          |> Ash.Changeset.for_create(:create, %{
            url: "https://example.com/img.jpg",
            content_type: content_type,
            file_size_bytes: 500_000,
            product_id: product.id,
            store_id: store.id
          })

        assert :ok ==
                 OneOf.validate(
                   changeset,
                   [attribute: :content_type, values: @allowed_content_types],
                   %{}
                 ),
               "Expected #{content_type} to be accepted"
      end
    end

    test "rejects when value is not in allowed list", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.gif",
          content_type: "image/gif",
          file_size_bytes: 500_000,
          product_id: product.id,
          store_id: store.id
        })

      assert {:error, error} =
               OneOf.validate(
                 changeset,
                 [attribute: :content_type, values: @allowed_content_types],
                 %{}
               )

      assert error.field == :content_type
      assert error.message =~ "must be one of"
      assert error.message =~ "image/jpeg"
    end

    test "passes when value is nil", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.jpg",
          file_size_bytes: 500_000,
          product_id: product.id,
          store_id: store.id
        })

      assert :ok ==
               OneOf.validate(
                 changeset,
                 [attribute: :content_type, values: @allowed_content_types],
                 %{}
               )
    end

    test "is case-sensitive", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.jpg",
          content_type: "IMAGE/JPEG",
          file_size_bytes: 500_000,
          product_id: product.id,
          store_id: store.id
        })

      assert {:error, error} =
               OneOf.validate(
                 changeset,
                 [attribute: :content_type, values: @allowed_content_types],
                 %{}
               )

      assert error.field == :content_type
    end

    test "rejects empty string when not in allowed list" do
      # Ash coerces "" to nil on typed attributes, so we bypass coercion
      # by setting the attribute directly on the changeset struct.
      cs = Ash.Changeset.new(Emakola.Catalog.Image)
      cs = %{cs | attributes: Map.put(cs.attributes, :content_type, "")}

      assert {:error, error} =
               OneOf.validate(
                 cs,
                 [attribute: :content_type, values: @allowed_content_types],
                 %{}
               )

      assert error.field == :content_type
    end

    test "error message includes all allowed values", %{store: store, product: product} do
      changeset =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://example.com/img.bmp",
          content_type: "image/bmp",
          file_size_bytes: 500_000,
          product_id: product.id,
          store_id: store.id
        })

      {:error, error} =
        OneOf.validate(
          changeset,
          [attribute: :content_type, values: @allowed_content_types],
          %{}
        )

      for allowed <- @allowed_content_types do
        assert error.message =~ allowed
      end
    end

    test "integration: creating image with invalid content type fails", %{
      store: store,
      product: product
    } do
      assert {:error, _} =
               Emakola.Catalog.Image
               |> Ash.Changeset.for_create(:create, %{
                 url: "https://example.com/img.gif",
                 content_type: "image/gif",
                 file_size_bytes: 500_000,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create()
    end

    test "integration: creating image with valid content type succeeds", %{
      store: store,
      product: product
    } do
      assert {:ok, image} =
               Emakola.Catalog.Image
               |> Ash.Changeset.for_create(:create, %{
                 url: "https://example.com/img.png",
                 content_type: "image/png",
                 file_size_bytes: 500_000,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create()

      assert image.content_type == "image/png"
    end
  end
end
