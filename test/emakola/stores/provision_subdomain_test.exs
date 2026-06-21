defmodule Emakola.Stores.ProvisionSubdomainTest do
  use Emakola.DataCase, async: false

  setup do
    prev = Application.get_env(:emakola, :store_subdomain_base)
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")

    on_exit(fn ->
      if prev,
        do: Application.put_env(:emakola, :store_subdomain_base, prev),
        else: Application.delete_env(:emakola, :store_subdomain_base)
    end)

    :ok
  end

  test "creating a store provisions a serve-in-place primary subdomain" do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()

    domain =
      Emakola.Stores.StoreDomain
      |> Ash.read!(authorize?: false)
      |> Enum.find(&(&1.store_id == store.id))

    assert domain.host == "#{store.slug}.makola.io"
    assert domain.serve_in_place? == true
    assert domain.primary? == true
  end

  test "no subdomain is provisioned when the base is unset (ship-dark)" do
    Application.delete_env(:emakola, :store_subdomain_base)
    {_m, store} = Emakola.Factory.create_merchant_with_store!()

    refute Emakola.Stores.StoreDomain
           |> Ash.read!(authorize?: false)
           |> Enum.any?(&(&1.store_id == store.id))
  end

  test "a reserved slug does not break store creation (logged, not raised)" do
    {_m, store} = Emakola.Factory.create_merchant_with_store!(%{slug: "admin"})

    assert store.slug == "admin"

    refute Emakola.Stores.StoreDomain
           |> Ash.read!(authorize?: false)
           |> Enum.any?(&(&1.store_id == store.id))
  end
end
