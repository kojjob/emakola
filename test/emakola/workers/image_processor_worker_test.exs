defmodule Emakola.Workers.ImageProcessorWorkerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Mox
  import Emakola.Factory

  alias Emakola.Workers.ImageProcessorWorker

  setup :verify_on_exit!

  setup do
    store = create_store!()
    product = create_product!(store, title: "Test Product")
    {:ok, store: store, product: product}
  end

  # A real (tiny) PNG, generated through the same libvips that decodes it.
  defp png_fixture do
    {:ok, img} = Vix.Vips.Operation.black(64, 48)
    {:ok, bin} = Vix.Vips.Image.write_to_buffer(img, ".png")
    bin
  end

  describe "perform/1" do
    test "writes webp variants next to the original and completes the record", %{
      store: store,
      product: product
    } do
      image = create_image!(product, store)
      assert image.processing_status == :pending

      expect(Emakola.StorageMock, :object_key, fn url ->
        assert url == image.url
        {:ok, "stores/s1/orig.jpg"}
      end)

      expect(Emakola.StorageMock, :get, fn "stores/s1/orig.jpg" -> {:ok, png_fixture()} end)

      expect(Emakola.StorageMock, :upload, 2, fn binary, path, opts ->
        assert <<"RIFF", _::binary-size(4), "WEBP", _::binary>> = binary
        assert path in ["stores/s1/orig_thumb.webp", "stores/s1/orig_medium.webp"]
        assert opts[:content_type] == "image/webp"
        assert opts[:cache_control] =~ "max-age=31536000"
        {:ok, "https://cdn.example.com/#{path}"}
      end)

      assert :ok = perform_job(ImageProcessorWorker, %{"image_id" => image.id})

      updated = Ash.get!(Emakola.Catalog.Image, image.id, authorize?: false)
      assert updated.processing_status == :completed
      assert updated.thumbnail_url == "https://cdn.example.com/stores/s1/orig_thumb.webp"
      assert updated.medium_url == "https://cdn.example.com/stores/s1/orig_medium.webp"
    end

    test "an image hosted elsewhere completes without variants", %{
      store: store,
      product: product
    } do
      image = create_image!(product, store)

      expect(Emakola.StorageMock, :object_key, fn _url -> {:error, :untrusted_source_url} end)

      assert :ok = perform_job(ImageProcessorWorker, %{"image_id" => image.id})

      updated = Ash.get!(Emakola.Catalog.Image, image.id, authorize?: false)
      assert updated.processing_status == :completed
      assert updated.thumbnail_url == nil
      assert updated.medium_url == nil
    end

    test "a storage failure marks the image failed so Oban retries", %{
      store: store,
      product: product
    } do
      image = create_image!(product, store)

      expect(Emakola.StorageMock, :object_key, fn _url -> {:ok, "stores/s1/orig.jpg"} end)
      expect(Emakola.StorageMock, :get, fn _key -> {:error, :timeout} end)

      assert {:error, _} = perform_job(ImageProcessorWorker, %{"image_id" => image.id})

      updated = Ash.get!(Emakola.Catalog.Image, image.id, authorize?: false)
      assert updated.processing_status == :failed
    end

    test "a corrupt original marks the image failed rather than crashing", %{
      store: store,
      product: product
    } do
      image = create_image!(product, store)

      expect(Emakola.StorageMock, :object_key, fn _url -> {:ok, "stores/s1/orig.jpg"} end)
      expect(Emakola.StorageMock, :get, fn _key -> {:ok, "not an image at all"} end)

      assert {:error, _} = perform_job(ImageProcessorWorker, %{"image_id" => image.id})

      updated = Ash.get!(Emakola.Catalog.Image, image.id, authorize?: false)
      assert updated.processing_status == :failed
    end

    test "skips processing if image is already completed", %{store: store, product: product} do
      image = create_image!(product, store)

      image =
        image
        |> Ash.Changeset.for_update(:mark_processed, %{
          thumbnail_url: "https://s3.example.com/thumbs/existing.jpg",
          medium_url: "https://s3.example.com/medium/existing.jpg"
        })
        |> Ash.update!(authorize?: false)

      assert image.processing_status == :completed

      # Running again should be a no-op (idempotent) — no storage calls.
      assert :ok = perform_job(ImageProcessorWorker, %{"image_id" => image.id})

      updated = Ash.get!(Emakola.Catalog.Image, image.id, authorize?: false)
      assert updated.thumbnail_url == "https://s3.example.com/thumbs/existing.jpg"
    end

    test "marks image as failed when image not found" do
      fake_id = Ash.UUID.generate()
      assert {:error, _} = perform_job(ImageProcessorWorker, %{"image_id" => fake_id})
    end
  end

  describe "enqueue on create" do
    test "a newly created image queues its own processing", %{store: store, product: product} do
      image = create_image!(product, store)

      assert_enqueued(worker: ImageProcessorWorker, args: %{"image_id" => image.id})
    end
  end
end
