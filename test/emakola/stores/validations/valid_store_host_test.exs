defmodule Emakola.Stores.Validations.ValidStoreHostTest do
  # async: false — these mutate :store_subdomain_base and :canonical_redirect_hosts,
  # which the validation reads at runtime.
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Stores
  alias Emakola.Stores.Validations.ValidStoreHost

  setup do
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    Application.put_env(:emakola, :canonical_redirect_hosts, ["legacy.example.com"])

    on_exit(fn ->
      Application.delete_env(:emakola, :store_subdomain_base)
      Application.delete_env(:emakola, :canonical_redirect_hosts)
    end)

    {:ok, store: create_store!(%{name: "Kente Kingdom", slug: "kente-kingdom-host"})}
  end

  defp claim(store, host) do
    Stores.create_store_domain(
      %{store_id: store.id, host: host, type: :custom},
      authorize?: false
    )
  end

  describe "custom hosts that belong to the platform" do
    # Each of these would let a merchant 301 a platform host to their own store,
    # because ResolveStoreByHost runs in the endpoint BEFORE the router's
    # @apex_hosts scope can protect it.
    for host <- [
          "emakola.fly.dev",
          "makola.io",
          "www.makola.io",
          "emakola.com",
          "www.emakola.com",
          "127.0.0.1"
        ] do
      test "rejects #{host} as a custom domain", %{store: store} do
        assert {:error, error} = claim(store, unquote(host))
        assert Exception.message(error) =~ "is not available"
      end
    end

    test "rejects a host in :canonical_redirect_hosts", %{store: store} do
      assert {:error, error} = claim(store, "legacy.example.com")
      assert Exception.message(error) =~ "is not available"
    end

    test "rejects the store subdomain base itself", %{store: store} do
      Application.put_env(:emakola, :store_subdomain_base, "shops.example.com")
      assert {:error, error} = claim(store, "shops.example.com")
      assert Exception.message(error) =~ "is not available"
    end

    test "rejects anything under the store subdomain base", %{store: store} do
      assert {:error, error} = claim(store, "kente-kingdom.makola.io")
      assert Exception.message(error) =~ "is not available"
    end
  end

  describe "custom hosts a merchant may legitimately claim" do
    test "accepts an apex domain", %{store: store} do
      assert {:ok, domain} = claim(store, "kentekingdom.com")
      assert domain.host == "kentekingdom.com"
      assert domain.type == :custom
    end

    test "accepts a subdomain of the merchant's own domain", %{store: store} do
      assert {:ok, domain} = claim(store, "shop.kentekingdom.com")
      assert domain.host == "shop.kentekingdom.com"
    end

    # The reserved-label list guards labels on OUR base. Applying it to a domain
    # the merchant owns would reject shop./store./blog./pay. prefixes — and
    # "shop.mybrand.com" is the most common custom-domain shape there is.
    test "accepts a reserved word as a label on the merchant's own domain", %{store: store} do
      assert {:ok, _} = claim(store, "shop.kente-kingdom-two.com")
      assert {:ok, _} = claim(store, "store.kente-kingdom-three.com")
      assert {:ok, _} = claim(store, "admin.kente-kingdom-four.com")
    end

    test "normalizes case and whitespace before validating", %{store: store} do
      assert {:ok, domain} = claim(store, "  KenteKingdom.COM ")
      assert domain.host == "kentekingdom.com"
    end
  end

  describe "platform_host?/1" do
    test "covers the compile-time apex list" do
      assert ValidStoreHost.platform_host?("emakola.fly.dev")
      assert ValidStoreHost.platform_host?("makola.io")
    end

    test "reads :canonical_redirect_hosts at runtime" do
      refute ValidStoreHost.platform_host?("later.example.com")
      Application.put_env(:emakola, :canonical_redirect_hosts, ["later.example.com"])
      assert ValidStoreHost.platform_host?("later.example.com")
    end

    test "reads :store_subdomain_base at runtime" do
      refute ValidStoreHost.platform_host?("anything.other.example")
      Application.put_env(:emakola, :store_subdomain_base, "other.example")
      assert ValidStoreHost.platform_host?("anything.other.example")
    end

    test "is false for a merchant's own domain" do
      refute ValidStoreHost.platform_host?("kentekingdom.com")
    end
  end

  describe "regression: the subdomain path is unchanged" do
    test "a subdomain claim under the base still succeeds", %{store: store} do
      assert {:ok, domain} =
               Stores.create_store_domain(
                 %{store_id: store.id, host: "kente-kingdom.makola.io"},
                 authorize?: false
               )

      assert domain.type == :subdomain
      assert domain.status == :active
    end

    test "a reserved subdomain label still reports 'reserved'", %{store: store} do
      assert {:error, error} =
               Stores.create_store_domain(
                 %{store_id: store.id, host: "admin.makola.io"},
                 authorize?: false
               )

      assert Exception.message(error) =~ "reserved"
    end
  end
end
