defmodule Mix.Tasks.Emakola.BackfillStoreSubdomains do
  @moduledoc """
  Backfills a serve-in-place primary `<slug>.<base>` `StoreDomain` for every
  existing store that doesn't already have one.

  Usage: mix emakola.backfill_store_subdomains

  Ships dark: does nothing unless `:store_subdomain_base` (env
  `STORE_SUBDOMAIN_BASE`) is configured. Idempotent — stores that already have a
  primary subdomain are skipped, and the `:unique_host` constraint is the final
  backstop. Reserved slugs (rejected by `ValidStoreHost`) are logged and skipped
  so one bad store never aborts the run.
  """
  use Mix.Task

  require Logger

  @shortdoc "Provision serve-in-place subdomains for existing stores"

  def run(_args) do
    Mix.Task.run("app.start")
    backfill()
  end

  @doc false
  def backfill do
    case Application.get_env(:emakola, :store_subdomain_base) do
      base when is_binary(base) and base != "" ->
        run_backfill(base)

      _ ->
        Mix.shell().info("STORE_SUBDOMAIN_BASE not set — nothing to backfill")
    end
  end

  defp run_backfill(base) do
    stores = Ash.read!(Emakola.Stores.Store, authorize?: false)

    {provisioned, skipped} =
      Enum.reduce(stores, {0, 0}, fn store, {provisioned, skipped} ->
        case provision(store, base) do
          :provisioned -> {provisioned + 1, skipped}
          :skipped -> {provisioned, skipped + 1}
        end
      end)

    Mix.shell().info("Backfill complete: #{provisioned} provisioned, #{skipped} skipped")
  end

  defp provision(store, base) do
    if has_primary_subdomain?(store.id) do
      :skipped
    else
      create_subdomain(store, base)
    end
  end

  defp has_primary_subdomain?(store_id) do
    Emakola.Stores.StoreDomain
    |> Ash.Query.for_read(:list_for_store, %{store_id: store_id})
    |> Ash.read!(authorize?: false)
    |> Enum.any?(&(&1.type == :subdomain and &1.primary?))
  end

  defp create_subdomain(store, base) do
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
        :provisioned

      {:error, reason} ->
        Logger.warning("[subdomains] backfill skipped for #{store.slug}: #{inspect(reason)}")
        :skipped
    end
  end
end
