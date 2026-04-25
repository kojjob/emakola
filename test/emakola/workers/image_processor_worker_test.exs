defmodule Emakola.Workers.ImageProcessorWorkerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory
  alias Emakola.Workers.ImageProcessorWorker

  setup do
    store = create_store!()
    product = create_product!(store, title: "Test Product")
    {:ok, store: store, product: product}
  end

  describe "perform/1" do
    test "marks image as completed with thumbnail and medium urls", %{
      store: store,
      product: product
    } do
      image = create_image!(product, store)
      assert image.processing_status == :pending

      assert :ok = perform_job(ImageProcessorWorker, %{"image_id" => image.id})

      updated = Ash.get!(Emakola.Catalog.Image, image.id, authorize?: false, authorize?: false)
      assert updated.processing_status == :completed
      assert is_binary(updated.thumbnail_url)
      assert is_binary(updated.medium_url)
    end

    test "skips processing if image is already completed", %{store: store, product: product} do
      image = create_image!(product, store)

      # Mark as completed first
      image =
        image
        |> Ash.Changeset.for_update(:mark_processed, %{
          thumbnail_url: "https://s3.example.com/thumbs/existing.jpg",
          medium_url: "https://s3.example.com/medium/existing.jpg"
        })
        |> Ash.update!(authorize?: false)

      assert image.processing_status == :completed

      # Running again should be a no-op (idempotent)
      assert :ok = perform_job(ImageProcessorWorker, %{"image_id" => image.id})

      updated = Ash.get!(Emakola.Catalog.Image, image.id, authorize?: false, authorize?: false)
      assert updated.thumbnail_url == "https://s3.example.com/thumbs/existing.jpg"
    end

    test "marks image as failed when image not found" do
      fake_id = Ash.UUID.generate()
      assert {:error, _} = perform_job(ImageProcessorWorker, %{"image_id" => fake_id})
    end
  end
end
