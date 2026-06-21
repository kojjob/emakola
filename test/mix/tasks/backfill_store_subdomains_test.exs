defmodule Mix.Tasks.Emakola.BackfillStoreSubdomainsTest do
  use Emakola.DataCase, async: false

  alias Emakola.Stores.StoreDomain

  setup do
    Mix.shell(Mix.Shell.Process)
    prev = Application.get_env(:emakola, :store_subdomain_base)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)

      if prev,
        do: Application.put_env(:emakola, :store_subdomain_base, prev),
        else: Application.delete_env(:emakola, :store_subdomain_base)
    end)

    :ok
  end

  defp domains_for(store_id) do
    StoreDomain
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&(&1.store_id == store_id))
  end

  test "provisions a primary serve-in-place subdomain for every store lacking one" do
    # Create stores while the base is unset so the create-time provisioning
    # ships dark — leaving them for the backfill to handle.
    Application.delete_env(:emakola, :store_subdomain_base)
    store_a = Emakola.Factory.create_store!()
    store_b = Emakola.Factory.create_store!()

    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    Mix.Tasks.Emakola.BackfillStoreSubdomains.backfill()

    assert [domain_a] = domains_for(store_a.id)
    assert domain_a.host == "#{store_a.slug}.makola.io"
    assert domain_a.primary? == true
    assert domain_a.serve_in_place? == true

    assert [domain_b] = domains_for(store_b.id)
    assert domain_b.host == "#{store_b.slug}.makola.io"
  end

  test "is idempotent — running twice provisions no duplicates" do
    Application.delete_env(:emakola, :store_subdomain_base)
    store = Emakola.Factory.create_store!()

    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    Mix.Tasks.Emakola.BackfillStoreSubdomains.backfill()
    Mix.Tasks.Emakola.BackfillStoreSubdomains.backfill()

    assert [_only_one] = domains_for(store.id)
  end

  test "does nothing when the base is unset (ship-dark)" do
    Application.delete_env(:emakola, :store_subdomain_base)
    store = Emakola.Factory.create_store!()

    Mix.Tasks.Emakola.BackfillStoreSubdomains.backfill()

    assert domains_for(store.id) == []
  end

  test "skips reserved slugs without crashing" do
    Application.delete_env(:emakola, :store_subdomain_base)
    reserved = Emakola.Factory.create_store!(%{slug: "admin"})
    normal = Emakola.Factory.create_store!()

    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    Mix.Tasks.Emakola.BackfillStoreSubdomains.backfill()

    assert domains_for(reserved.id) == []
    assert [_one] = domains_for(normal.id)
  end
end
