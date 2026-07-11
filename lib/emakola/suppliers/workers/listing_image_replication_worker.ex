defmodule Emakola.Suppliers.Workers.ListingImageReplicationWorker do
  @moduledoc "Replicates supplier images into reseller-owned storage and catalog rows."

  use Oban.Worker,
    queue: :images,
    max_attempts: 5,
    unique: [period: 300, fields: [:args]]

  require Ash.Query

  alias Emakola.Suppliers.ResellerListingImage

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"listing_id" => listing_id}}) do
    listing_id
    |> pending_mappings()
    |> Enum.reduce_while(:ok, fn mapping, :ok ->
      case replicate(mapping) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp pending_mappings(listing_id) do
    ResellerListingImage
    |> Ash.Query.filter(listing_id == ^listing_id and status != :completed)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.Query.load([:source_image, listing: :reseller_product])
    |> Ash.read!(authorize?: false)
  end

  defp replicate(mapping) do
    source = mapping.source_image

    case Emakola.Storage.replicate(source.url, mapping.storage_key,
           content_type: source.content_type
         ) do
      {:ok, url} -> complete(mapping, url)
      {:error, reason} -> fail(mapping, reason)
    end
  end

  defp complete(mapping, url) do
    image = find_or_create_image!(mapping, url)

    mapping
    |> Ash.Changeset.for_update(:complete, %{reseller_image_id: image.id})
    |> Ash.update!(authorize?: false)

    :ok
  end

  defp find_or_create_image!(mapping, url) do
    product = mapping.listing.reseller_product

    case Emakola.Catalog.Image
         |> Ash.Query.filter(product_id == ^product.id and url == ^url)
         |> Ash.Query.limit(1)
         |> Ash.read_one(authorize?: false, tenant: product.store_id) do
      {:ok, %{} = image} ->
        image

      _ ->
        source = mapping.source_image

        Emakola.Catalog.create_image!(
          %{
            store_id: product.store_id,
            product_id: product.id,
            url: url,
            alt_text: source.alt_text,
            content_type: source.content_type,
            file_size_bytes: source.file_size_bytes
          },
          authorize?: false,
          tenant: product.store_id
        )
    end
  end

  defp fail(mapping, reason) do
    mapping
    |> Ash.Changeset.for_update(:fail, %{failure_reason: inspect(reason)})
    |> Ash.update!(authorize?: false)

    {:error, reason}
  end
end
