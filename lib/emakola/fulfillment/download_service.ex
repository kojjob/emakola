defmodule Emakola.Fulfillment.DownloadService do
  @moduledoc """
  Issues short-lived signed download URLs against the configured
  `Emakola.Storage` adapter for a customer's `Emakola.Fulfillment.DownloadGrant`.

  ## Validation pipeline

      load grant + digital_file
        ├─ expired?       → {:error, :expired}
        ├─ limit reached? → {:error, :limit_reached}
        ├─ storage call   → {:error, {:storage, reason}}
        └─ atomic counter increment → {:ok, url}

  ## Limit enforcement is atomic

  The `increment_download_count` action uses a CAS-style WHERE clause:
  the increment only commits when `downloaded_count < download_limit`
  (or `download_limit` is nil). If the row is already at its limit the
  update returns 0 rows and Ash raises an error, which `bump_counter/1`
  maps to `{:error, :limit_reached}`. This closes the soft-race window
  that existed when the check was a separate read followed by an update.

  ## The counter increments only on storage success

  We call `Storage.presigned_url/2` before incrementing. A failed
  storage call leaves the grant's `downloaded_count` untouched — the
  buyer can retry without it eating a download. The cost is one extra
  storage call on rare failures vs. the alternative of "increment first,
  decrement on failure" which has its own race window.
  """

  alias Emakola.Fulfillment.DownloadGrant

  @url_ttl_seconds 15 * 60

  @spec issue_url(DownloadGrant.t() | binary()) ::
          {:ok, String.t()}
          | {:error, :not_found | :expired | :limit_reached | {:storage, term()}}
  def issue_url(grant_id) when is_binary(grant_id) do
    case Ash.get(DownloadGrant, grant_id, load: [:digital_file], authorize?: false) do
      {:ok, grant} -> issue_url(grant)
      {:error, _} -> {:error, :not_found}
    end
  end

  def issue_url(%DownloadGrant{} = grant) do
    grant = ensure_loaded(grant)

    with :ok <- check_expiry(grant),
         :ok <- check_limit(grant),
         {:ok, url} <- call_storage(grant),
         :ok <- bump_counter(grant) do
      {:ok, url}
    end
  end

  defp ensure_loaded(%DownloadGrant{digital_file: %Ash.NotLoaded{}} = grant) do
    Ash.load!(grant, :digital_file, authorize?: false)
  end

  defp ensure_loaded(grant), do: grant

  defp check_expiry(%DownloadGrant{expires_at: nil}), do: :ok

  defp check_expiry(%DownloadGrant{expires_at: expires_at}) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
      :ok
    else
      {:error, :expired}
    end
  end

  defp check_limit(%DownloadGrant{download_limit: nil}), do: :ok

  defp check_limit(%DownloadGrant{download_limit: limit, downloaded_count: count})
       when count >= limit do
    {:error, :limit_reached}
  end

  defp check_limit(_), do: :ok

  defp call_storage(%DownloadGrant{digital_file: file}) do
    case Emakola.Storage.presigned_url(file.storage_key, ttl: @url_ttl_seconds) do
      {:ok, url} -> {:ok, url}
      {:error, reason} -> {:error, {:storage, reason}}
    end
  end

  defp bump_counter(grant) do
    case grant
         |> Ash.Changeset.for_update(:increment_download_count, %{})
         |> Ash.update(authorize?: false) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :limit_reached}
    end
  end
end
