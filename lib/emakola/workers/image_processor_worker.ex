defmodule Emakola.Workers.ImageProcessorWorker do
  @moduledoc """
  Oban worker that processes uploaded images to generate thumbnail and medium variants.

  Takes an image_id, downloads the original, generates resized versions, and updates
  the Image resource with the new URLs.

  Currently STUBBED — actual image processing (libvips/ImageMagick) will be added later.
  The worker generates deterministic URLs based on the original URL path.

  Idempotent: skips processing if the image is already in :completed status.
  """

  use Oban.Worker, queue: :images, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"image_id" => image_id}}) do
    case Ash.get(Emakola.Catalog.Image, image_id) do
      {:ok, %{processing_status: :completed} = _image} ->
        Logger.info("Image #{image_id} already processed, skipping")
        :ok

      {:ok, image} ->
        process_image(image)

      {:error, reason} ->
        Logger.error("Image #{image_id} not found: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_image(image) do
    # STUB: In production, this would:
    # 1. Download the original image from image.url
    # 2. Use libvips/ImageMagick to generate thumbnail (150x150) and medium (600x600)
    # 3. Upload resized versions to S3
    # 4. Return the new URLs

    {thumbnail_url, medium_url} = generate_variant_urls(image.url)

    case image
         |> Ash.Changeset.for_update(:mark_processed, %{
           thumbnail_url: thumbnail_url,
           medium_url: medium_url
         })
         |> Ash.update(authorize?: false) do
      {:ok, _updated} ->
        Logger.info("Image #{image.id} processed successfully")
        :ok

      {:error, reason} ->
        Logger.error("Failed to mark image #{image.id} as processed: #{inspect(reason)}")
        mark_failed(image)
        {:error, reason}
    end
  end

  defp mark_failed(image) do
    image
    |> Ash.Changeset.for_update(:mark_failed, %{})
    |> Ash.update(authorize?: false)
  end

  defp generate_variant_urls(original_url) do
    # STUB: Generate deterministic variant URLs from original
    # In production, these would be actual S3 paths after upload
    base = String.replace(original_url, ~r/\.[^.]+$/, "")
    ext = Path.extname(original_url)

    thumbnail_url = "#{base}_thumb#{ext}"
    medium_url = "#{base}_medium#{ext}"

    {thumbnail_url, medium_url}
  end
end
