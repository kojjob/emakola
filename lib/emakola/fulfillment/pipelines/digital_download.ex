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
  def fulfill(%{id: line_item_id}, _context) when is_binary(line_item_id) do
    with {:ok, line_item} <- load_line_item(line_item_id),
         {:ok, product_id} <- product_id_for(line_item),
         files when is_list(files) <- list_paid_files(line_item.store_id, product_id),
         customer_id <- customer_id_for(line_item) do
      grants = Enum.map(files, &issue_or_reuse_grant(line_item, &1, customer_id))
      {:ok, %{grants: grants}}
    end
  end

  defp load_line_item(line_item_id) do
    case Ash.get(LineItem, line_item_id, load: [variant: :product], authorize?: false) do
      {:ok, line_item} -> {:ok, line_item}
      {:error, _} -> {:error, :line_item_not_found}
    end
  end

  defp product_id_for(%{variant: %{product_id: product_id}}) when is_binary(product_id),
    do: {:ok, product_id}

  defp product_id_for(_), do: {:error, :product_unresolved}

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

  defp issue_or_reuse_grant(line_item, file, customer_id) do
    case existing_grant(line_item.id, file.id) do
      nil -> issue_grant!(line_item, file, customer_id)
      grant -> grant
    end
  end

  defp existing_grant(line_item_id, digital_file_id) do
    DownloadGrant
    |> Ash.Query.filter(line_item_id == ^line_item_id and digital_file_id == ^digital_file_id)
    |> Ash.read_one!(authorize?: false)
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
