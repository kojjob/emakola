defmodule Emakola.Catalog.ImageOrphanCleanupTest do
  @moduledoc """
  Destroying a Catalog.Image must enqueue storage cleanup so the underlying
  file in object storage is removed too — otherwise deleted images (and any
  product/store cascade) leave orphaned files in the bucket forever.
  """
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo
  import Emakola.Factory

  setup do
    store = create_store!()
    product = create_product!(store, title: "Test Product")
    {:ok, store: store, product: product}
  end

  test "destroying an image enqueues a storage cleanup job for its file key",
       %{store: store, product: product} do
    image =
      create_image!(product, store, %{
        url: "https://emakola-uploads.example.dev/stores/s1/products/p1.webp"
      })

    Emakola.Catalog.destroy_image!(image, authorize?: false)

    assert_enqueued(
      worker: Emakola.Workers.StorageCleanupWorker,
      args: %{"keys" => ["stores/s1/products/p1.webp"]}
    )
  end

  test "cleanup includes thumbnail + medium variants, in order, de-duplicated",
       %{store: store, product: product} do
    image =
      create_image!(product, store, %{
        url: "https://cdn.example.dev/stores/s1/products/p2.jpg"
      })

    {:ok, image} =
      image
      |> Ash.Changeset.for_update(:mark_processed, %{
        thumbnail_url: "https://cdn.example.dev/stores/s1/products/p2_thumb.jpg",
        medium_url: "https://cdn.example.dev/stores/s1/products/p2_med.jpg"
      })
      |> Ash.update(authorize?: false)

    Emakola.Catalog.destroy_image!(image, authorize?: false)

    assert_enqueued(
      worker: Emakola.Workers.StorageCleanupWorker,
      args: %{
        "keys" => [
          "stores/s1/products/p2.jpg",
          "stores/s1/products/p2_thumb.jpg",
          "stores/s1/products/p2_med.jpg"
        ]
      }
    )
  end
end
