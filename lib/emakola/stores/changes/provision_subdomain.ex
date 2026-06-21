defmodule Emakola.Stores.Changes.ProvisionSubdomain do
  @moduledoc """
  After-action that provisions a serve-in-place primary `<slug>.<base>`
  `StoreDomain` for a newly created store.

  Ships dark: only runs when `:store_subdomain_base` is configured (post-DNS
  cutover). A reserved slug (e.g. `admin`) is rejected by `ValidStoreHost`, so
  the create returns `{:error, ...}` — that, and any other failure, is logged
  and swallowed so provisioning is best-effort and never breaks store creation.
  """

  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, store ->
      provision(store)
      {:ok, store}
    end)
  end

  defp provision(store) do
    case Application.get_env(:emakola, :store_subdomain_base) do
      base when is_binary(base) and base != "" ->
        Emakola.Stores.StoreDomain
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          host: "#{store.slug}.#{base}",
          type: :subdomain,
          serve_in_place?: true,
          primary?: true
        })
        |> Ash.create(authorize?: false)
        |> case do
          {:ok, _domain} ->
            :ok

          {:error, reason} ->
            Logger.warning("[subdomains] provision skipped for #{store.slug}: #{inspect(reason)}")
        end

      _ ->
        :ok
    end
  rescue
    e -> Logger.error("[subdomains] provision raised for #{store.slug}: #{Exception.message(e)}")
  end
end
