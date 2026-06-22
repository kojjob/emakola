defmodule EmakolaWeb.Helpers.StoreResolverTest do
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Stores
  alias EmakolaWeb.Helpers.StoreResolver

  describe "resolve/1" do
    test "returns {:ok, store} for valid slug" do
      store = Factory.create_store!(%{slug: "my-shop", name: "My Shop"})

      assert {:ok, resolved} = StoreResolver.resolve("my-shop")
      assert resolved.id == store.id
      assert resolved.name == "My Shop"
    end

    test "returns {:error, :not_found} for non-existent slug" do
      assert {:error, :not_found} = StoreResolver.resolve("does-not-exist")
    end

    test "returns {:error, :not_found} for empty slug" do
      assert {:error, :not_found} = StoreResolver.resolve("")
    end
  end

  describe "resolve/1 — lifecycle status" do
    test "a suspended store is unavailable" do
      {:ok, store} =
        Stores.suspend_store(Factory.create_store!(), %{reason: "x"}, authorize?: false)

      assert {:error, :unavailable} = StoreResolver.resolve(store.slug)
    end

    test "a blocked store is unavailable" do
      {:ok, store} =
        Stores.block_store(Factory.create_store!(), %{reason: "x"}, authorize?: false)

      assert {:error, :unavailable} = StoreResolver.resolve(store.slug)
    end

    test "a merchant-deactivated store is unavailable" do
      store = Factory.create_store!(%{active: false})
      assert {:error, :unavailable} = StoreResolver.resolve(store.slug)
    end

    test "an archived store is hidden as not found" do
      {:ok, store} = Stores.archive_store(Factory.create_store!(), %{}, authorize?: false)
      assert {:error, :not_found} = StoreResolver.resolve(store.slug)
    end
  end
end
