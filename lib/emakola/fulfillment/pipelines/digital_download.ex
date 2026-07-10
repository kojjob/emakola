defmodule Emakola.Fulfillment.Pipelines.DigitalDownload do
  @moduledoc """
  Fulfillment pipeline for `:digital_download` products (Phase 1).

  Given a paid line item, issues one `Emakola.Fulfillment.DownloadGrant`
  per non-preview `Emakola.Catalog.DigitalFile` attached to the line
  item's product. Preview files (`is_preview: true`) are publicly
  accessible without a grant, so they're skipped here.

  ## Idempotency

  The dispatcher may be invoked more than once for the same line item
  (retried webhook, manual re-fulfillment). Grant creation is guarded
  by the `(line_item_id, digital_file_id)` unique identity on
  `DownloadGrant`: if a grant for the pair already exists, the existing
  row is returned instead of erroring. The result shape is the same
  either way, so callers don't have to special-case "first run" vs
  "retry."

  ## Return shape

      {:ok, %{grants: [%DownloadGrant{}, ...]}}
      {:error, :line_item_not_found}

  The grants list may be empty (product has no files, or all files are
  previews). An empty success is still a success — there's just nothing
  to deliver. Callers that need to surface "no files" to the merchant
  should check `grants == []` explicitly.
  """

  @behaviour Emakola.Fulfillment.Pipeline

  require Ash.Query

  alias Emakola.Catalog.DigitalFile
  alias Emakola.Fulfillment.DownloadGrant
  alias Emakola.Orders.LineItem

  @impl true
  def fulfill(%{id: line_item_id}, context) when is_binary(line_item_id) do
    with {:ok, line_item} <- load_line_item(line_item_id),
         {:ok, {file_store_id, product_id}} <- file_source_for(line_item),
         files when is_list(files) <- list_paid_files(file_store_id, product_id) do
      customer_id = Map.get(context, :customer_id) || customer_id_for(line_item)
      existing_grants = load_existing_grants(line_item.id)
      grants = Enum.map(files, &issue_or_reuse_grant(line_item, &1, customer_id, existing_grants))
      {:ok, %{grants: grants}}
    end
  end

  defp load_line_item(line_item_id) do
    case Ash.get(LineItem, line_item_id, load: [variant: :product], authorize?: false) do
      {:ok, line_item} -> {:ok, line_item}
      {:error, _} -> {:error, :line_item_not_found}
    end
  end

  defp file_source_for(%{variant: %{product_id: product_id}, store_id: store_id})
       when is_binary(product_id) do
    case reseller_source(product_id) do
      {:ok, %{offer: offer}} -> {:ok, {offer.wholesaler_store_id, offer.source_product_id}}
      :not_imported -> {:ok, {store_id, product_id}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp file_source_for(_), do: {:error, :product_unresolved}

  defp reseller_source(product_id) do
    Emakola.Suppliers.ResellerListing
    |> Ash.Query.filter(reseller_product_id == ^product_id)
    |> Ash.Query.load(:offer)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> :not_imported
      {:ok, listing} -> {:ok, listing}
      {:error, reason} -> {:error, reason}
    end
  end

  defp list_paid_files(store_id, product_id) do
    DigitalFile
    |> Ash.Query.filter(
      store_id == ^store_id and product_id == ^product_id and is_preview == false
    )
    |> Ash.Query.sort(position: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp customer_id_for(%{order_id: order_id}) do
    case Ash.get(Emakola.Orders.Order, order_id, authorize?: false) do
      {:ok, order} -> order.customer_id
      {:error, _} -> nil
    end
  end

  # Loads all existing grants for a line_item in one query, keyed by digital_file_id,
  # so the subsequent Enum.map/2 over files needs zero extra round-trips.
  defp load_existing_grants(line_item_id) do
    DownloadGrant
    |> Ash.Query.filter(line_item_id == ^line_item_id)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.digital_file_id, &1})
  end

  defp issue_or_reuse_grant(line_item, file, customer_id, existing_grants) do
    case Map.get(existing_grants, file.id) do
      nil -> issue_grant!(line_item, file, customer_id)
      grant -> grant
    end
  end

  defp issue_grant!(line_item, file, customer_id) do
    DownloadGrant
    |> Ash.Changeset.for_create(:issue, %{
      store_id: line_item.store_id,
      order_id: line_item.order_id,
      line_item_id: line_item.id,
      customer_id: customer_id,
      digital_file_id: file.id
    })
    |> Ash.create!(authorize?: false)
  end
end
