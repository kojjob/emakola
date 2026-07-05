defmodule Emakola.Catalog.Changes.DeleteImageFiles do
  @moduledoc """
  After a `Catalog.Image` is destroyed, enqueues a `StorageCleanupWorker` to
  delete its file(s) from object storage.

  The DB destroy does not touch the bucket, so without this every deleted image
  — and any product/store cascade — orphans its underlying files. Storage keys
  are derived from the stored `url` / `thumbnail_url` / `medium_url` (the path
  portion of each URL).

  Uses `after_action` (matching the Oban-side-effect pattern used elsewhere in
  the catalog) so a failed Oban insert never rolls back the delete.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, image ->
      enqueue_cleanup(image)
      {:ok, image}
    end)
  end

  defp enqueue_cleanup(image) do
    keys =
      [image.url, image.thumbnail_url, image.medium_url]
      |> Enum.map(&storage_key/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if keys != [] do
      %{"keys" => keys}
      |> Emakola.Workers.StorageCleanupWorker.new()
      |> Oban.insert()
    end

    :ok
  end

  # The storage key is the path portion of the public URL, e.g.
  # "https://bucket.host/stores/x/products/y.webp" -> "stores/x/products/y.webp".
  defp storage_key(url) when is_binary(url) do
    case URI.parse(url).path do
      nil -> nil
      path -> path |> String.trim_leading("/") |> nil_if_blank()
    end
  end

  defp storage_key(_), do: nil

  defp nil_if_blank(""), do: nil
  defp nil_if_blank(key), do: key
end
