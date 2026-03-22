defmodule Emakola.Catalog.ImageTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    product = create_product!(store, title: "Test Product")
    {:ok, store: store, product: product}
  end

  # ── Creation ──────────────────────────────────────────────────

  describe "create" do
    test "creates an image with valid attributes", %{store: store, product: product} do
      image = create_image!(product, store)

      assert image.id
      assert image.store_id == store.id
      assert image.product_id == product.id
      assert image.content_type == "image/jpeg"
      assert image.file_size_bytes == 500_000
      assert image.processing_status == :pending
      assert image.position == 0
      assert is_nil(image.variant_id)
      assert is_nil(image.thumbnail_url)
      assert is_nil(image.medium_url)
      assert String.starts_with?(image.url, "https://s3.example.com/test/")
    end

    test "creates an image with all optional fields", %{store: store, product: product} do
      variant = create_variant!(product, store)

      image =
        create_image!(product, store, %{
          variant_id: variant.id,
          alt_text: "A beautiful product photo",
          content_type: "image/png",
          file_size_bytes: 1_000_000
        })

      assert image.variant_id == variant.id
      assert image.alt_text == "A beautiful product photo"
      assert image.content_type == "image/png"
      assert image.file_size_bytes == 1_000_000
    end
  end

  # ── Content Type Validation ─────────────────────────────────

  describe "content_type validation" do
    test "accepts image/jpeg", %{store: store, product: product} do
      image = create_image!(product, store, %{content_type: "image/jpeg"})
      assert image.content_type == "image/jpeg"
    end

    test "accepts image/png", %{store: store, product: product} do
      image = create_image!(product, store, %{content_type: "image/png"})
      assert image.content_type == "image/png"
    end

    test "accepts image/webp", %{store: store, product: product} do
      image = create_image!(product, store, %{content_type: "image/webp"})
      assert image.content_type == "image/webp"
    end

    test "rejects application/pdf", %{store: store, product: product} do
      assert {:error, _} =
               Emakola.Catalog.Image
               |> Ash.Changeset.for_create(:create, %{
                 url: "https://s3.example.com/test/file.pdf",
                 content_type: "application/pdf",
                 file_size_bytes: 500_000,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create()
    end

    test "rejects text/html", %{store: store, product: product} do
      assert {:error, _} =
               Emakola.Catalog.Image
               |> Ash.Changeset.for_create(:create, %{
                 url: "https://s3.example.com/test/page.html",
                 content_type: "text/html",
                 file_size_bytes: 500_000,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create()
    end
  end

  # ── File Size Validation ────────────────────────────────────

  describe "file_size_bytes validation" do
    test "accepts file at exactly 10MB", %{store: store, product: product} do
      image = create_image!(product, store, %{file_size_bytes: 10_000_000})
      assert image.file_size_bytes == 10_000_000
    end

    test "rejects file over 10MB", %{store: store, product: product} do
      assert {:error, _} =
               Emakola.Catalog.Image
               |> Ash.Changeset.for_create(:create, %{
                 url: "https://s3.example.com/test/large.jpg",
                 content_type: "image/jpeg",
                 file_size_bytes: 11_000_000,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create()
    end
  end

  # ── Mark Processed ──────────────────────────────────────────

  describe "mark_processed" do
    test "sets thumbnail_url, medium_url, and status to completed", %{
      store: store,
      product: product
    } do
      image = create_image!(product, store)
      assert image.processing_status == :pending

      updated =
        image
        |> Ash.Changeset.for_update(:mark_processed, %{
          thumbnail_url: "https://s3.example.com/thumbs/img.jpg",
          medium_url: "https://s3.example.com/medium/img.jpg"
        })
        |> Ash.update!()

      assert updated.processing_status == :completed
      assert updated.thumbnail_url == "https://s3.example.com/thumbs/img.jpg"
      assert updated.medium_url == "https://s3.example.com/medium/img.jpg"
    end
  end

  # ── Mark Failed ─────────────────────────────────────────────

  describe "mark_failed" do
    test "sets status to failed", %{store: store, product: product} do
      image = create_image!(product, store)
      assert image.processing_status == :pending

      updated =
        image
        |> Ash.Changeset.for_update(:mark_failed, %{})
        |> Ash.update!()

      assert updated.processing_status == :failed
    end
  end

  # ── Update ──────────────────────────────────────────────────

  describe "update" do
    test "updates alt_text", %{store: store, product: product} do
      image = create_image!(product, store)

      updated =
        image
        |> Ash.Changeset.for_update(:update, %{alt_text: "Updated alt text"})
        |> Ash.update!()

      assert updated.alt_text == "Updated alt text"
    end

    test "updates position", %{store: store, product: product} do
      image = create_image!(product, store)

      updated =
        image
        |> Ash.Changeset.for_update(:update, %{position: 3})
        |> Ash.update!()

      assert updated.position == 3
    end
  end

  # ── Destroy ─────────────────────────────────────────────────

  describe "destroy" do
    test "deletes the image", %{store: store, product: product} do
      image = create_image!(product, store)

      assert :ok =
               image
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy()

      assert {:error, %Ash.Error.Invalid{}} =
               Emakola.Catalog.Image
               |> Ash.get(image.id)
    end
  end

  # ── Multi-Tenant Isolation ──────────────────────────────────

  describe "multi-tenant isolation" do
    test "images are scoped to their store", %{store: store, product: product} do
      other_store = create_store!(name: "Other Store", slug: "other-store")
      other_product = create_product!(other_store, title: "Other Product")

      _image1 = create_image!(product, store, %{alt_text: "Store 1 image"})
      _image2 = create_image!(other_product, other_store, %{alt_text: "Store 2 image"})

      store_images =
        Emakola.Catalog.Image
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!()

      other_store_images =
        Emakola.Catalog.Image
        |> Ash.Query.filter(store_id == ^other_store.id)
        |> Ash.read!()

      assert length(store_images) == 1
      assert length(other_store_images) == 1
      assert hd(store_images).alt_text == "Store 1 image"
      assert hd(other_store_images).alt_text == "Store 2 image"
    end
  end
end
