defmodule Emakola.Catalog.Changes.SyncToWhatsappCatalog do
  @moduledoc """
  After-action change that enqueues a WhatsApp Business Catalog sync
  job for the affected product.

  Attached to `:create`, `:update`, and `:activate` on Product (upsert)
  and to `:archive` (delete). Uses `after_action`, not
  `after_transaction`, so the job is enqueued only after the row is
  committed — that way a failed Oban insert doesn't roll back the
  product write, and a slow catalog sync never holds the row lock.

  The worker itself short-circuits when the store has no
  `whatsapp_catalog_id` set, so this change is safe to fire on every
  product mutation regardless of merchant onboarding state.

  ## Options

    * `:action` — `:upsert` (default) or `:delete`
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    action = Keyword.get(opts, :action, :upsert)

    Ash.Changeset.after_action(changeset, fn _changeset, product ->
      enqueue_sync(product, action)
      {:ok, product}
    end)
  end

  defp enqueue_sync(%{id: product_id, store_id: store_id}, action)
       when is_binary(product_id) and is_binary(store_id) do
    %{"product_id" => product_id, "store_id" => store_id, "action" => to_string(action)}
    |> Emakola.Workers.WhatsappCatalogSyncWorker.new()
    |> Oban.insert()
  end

  defp enqueue_sync(_product, _action), do: :ok
end
