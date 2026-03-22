defmodule EmakolaWeb.Helpers.StoreResolverTest do
  use Emakola.DataCase, async: true

  alias EmakolaWeb.Helpers.StoreResolver
  alias Emakola.Factory

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
end
