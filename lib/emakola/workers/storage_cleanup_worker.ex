defmodule Emakola.Workers.StorageCleanupWorker do
  @moduledoc """
  Deletes object-storage files (by key) for images that have been destroyed.

  Enqueued by `Emakola.Catalog.Changes.DeleteImageFiles` when a `Catalog.Image`
  is destroyed. The DB row is already gone by the time this runs; this removes
  the matching files from the bucket so deleted images (and product/store
  cascades) don't leave orphaned objects.

  Idempotent: deleting an already-absent key is a no-op, and a per-key storage
  failure is logged and skipped rather than failing the whole job.
  """
  use Oban.Worker, queue: :images, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"keys" => keys}}) when is_list(keys) do
    Enum.each(keys, fn key ->
      case Emakola.Storage.delete(key) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("StorageCleanupWorker: failed to delete #{key}: #{inspect(reason)}")
      end
    end)

    :ok
  end
end
