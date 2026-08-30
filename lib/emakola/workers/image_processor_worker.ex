defmodule Emakola.Workers.ImageProcessorWorker do
  @moduledoc """
  Oban worker that turns an uploaded image into WebP thumbnail and medium
  variants, stored next to the original.

  The storefront already prefers `thumbnail_url`/`medium_url` with a fallback
  to the original, so every image this worker completes gets lighter on the
  page with no template change. Variants keep an immutable one-year
  Cache-Control: an image row's `url` never changes, so the derived variant
  paths never need to either.

  An image hosted outside this platform's storage (imported listings) is
  marked completed with no variants — the fallback keeps serving it.

  Idempotent: skips processing if the image is already in :completed status.
  """

  use Oban.Worker, queue: :images, max_attempts: 3, unique: [period: 60, fields: [:args]]

  require Logger

  alias Emakola.Storage

  @thumb_px 320
  @medium_px 800
  @webp_quality 80
  @cache_control "public, max-age=31536000, immutable"

  @doc """
  Enqueues processing for an image. Never raises — a queue hiccup must not
  fail the upload that triggered it.
  """
  @spec enqueue(binary()) :: :ok
  def enqueue(image_id) when is_binary(image_id) do
    case %{"image_id" => image_id} |> new() |> Oban.insert() do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error("[ImageProcessorWorker] enqueue failed for #{image_id}: #{inspect(reason)}")
        :ok
    end
  rescue
    exception ->
      Logger.error("[ImageProcessorWorker] enqueue raised: #{Exception.message(exception)}")
      :ok
  end

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
    case Storage.object_key(image.url) do
      {:ok, key} ->
        generate_and_store(image, key)

      {:error, _reason} ->
        # Not ours to optimise; completed-with-nothing keeps the fallback
        # serving the foreign original and stops the job from retrying.
        mark_processed(image, nil, nil)
    end
  end

  defp generate_and_store(image, key) do
    with {:ok, original} <- Storage.get(key),
         {:ok, thumb} <- to_webp(original, @thumb_px),
         {:ok, medium} <- to_webp(original, @medium_px),
         {:ok, thumb_url} <- upload_variant(key, "thumb", thumb),
         {:ok, medium_url} <- upload_variant(key, "medium", medium) do
      mark_processed(image, thumb_url, medium_url)
    else
      {:error, reason} ->
        Logger.error("Image #{image.id} processing failed: #{inspect(reason)}")
        mark_failed(image)
        {:error, reason}
    end
  rescue
    # libvips raises through the NIF on some malformed inputs.
    exception ->
      Logger.error("Image #{image.id} processing raised: #{Exception.message(exception)}")
      mark_failed(image)
      {:error, {:processing_raised, Exception.message(exception)}}
  end

  defp to_webp(binary, max_px) do
    # size: :VIPS_SIZE_DOWN never upscales an original smaller than the target.
    with {:ok, vips_image} <-
           Vix.Vips.Operation.thumbnail_buffer(binary, max_px, size: :VIPS_SIZE_DOWN) do
      Vix.Vips.Image.write_to_buffer(vips_image, ".webp[Q=#{@webp_quality}]")
    end
  end

  defp upload_variant(key, tag, binary) do
    Storage.upload(binary, variant_path(key, tag),
      content_type: "image/webp",
      cache_control: @cache_control
    )
  end

  # Badge-safety invariant (snap-verified "Real photo" badge): the variant
  # path is derived from the image's own immutable storage key, never from
  # externally-supplied input — mark_processed relies on that.
  defp variant_path(key, tag) do
    ext = Path.extname(key)
    base = binary_part(key, 0, byte_size(key) - byte_size(ext))
    "#{base}_#{tag}.webp"
  end

  defp mark_processed(image, thumbnail_url, medium_url) do
    case image
         |> Ash.Changeset.for_update(:mark_processed, %{
           thumbnail_url: thumbnail_url,
           medium_url: medium_url
         })
         |> Ash.update(authorize?: false) do
      {:ok, _updated} ->
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
end
