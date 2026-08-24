defmodule Emakola.Stores.DomainResolverTest do
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Cache.StoreCache
  alias Emakola.Stores
  alias Emakola.Stores.DomainResolver

  setup do
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    StoreCache.invalidate_all()

    on_exit(fn ->
      Application.delete_env(:emakola, :store_subdomain_base)
      StoreCache.invalidate_all()
    end)

    {:ok, store: create_store!(%{name: "Kente Kingdom", slug: "kente-kingdom-res"})}
  end

  defp active_domain!(store, host) do
    {:ok, d} = Stores.claim_custom_domain(%{store_id: store.id, host: host}, authorize?: false)
    {:ok, d} = Stores.request_domain_verification(d, authorize?: false)
    {:ok, d} = Stores.mark_domain_active(d, authorize?: false)
    d
  end

  describe "lookup/1" do
    test "returns a minimal map, never a struct with a loaded store", %{store: store} do
      _ = active_domain!(store, "kentekingdom.com")

      assert {:ok, resolved} = DomainResolver.lookup("kentekingdom.com")

      # A cached %StoreDomain{} with a loaded :store would serve stale themes
      # and stale suspension status long after the store changed.
      refute is_struct(resolved)
      assert resolved.store_id == store.id
      assert resolved.slug == store.slug
      assert resolved.status == :active
      assert resolved.serve_in_place? == true
    end

    test "serves the second call from the cache", %{store: store} do
      _ = active_domain!(store, "kentekingdom.com")

      {:ok, _} = DomainResolver.lookup("kentekingdom.com")
      assert {:hit, _} = StoreCache.get("domain_host:kentekingdom.com")
    end

    test "normalizes the host before looking up", %{store: store} do
      _ = active_domain!(store, "kentekingdom.com")
      assert {:ok, _} = DomainResolver.lookup("  KenteKingdom.COM ")
    end

    test "returns :none for an unknown host" do
      assert :none = DomainResolver.lookup("nobody.example")
    end

    # Without this an attacker forces a database read per probe, and
    # check_origin runs on every socket connect.
    test "caches the miss so a repeat probe costs nothing" do
      assert :none = DomainResolver.lookup("nobody.example")
      assert {:hit, :none} = StoreCache.get("domain_host:nobody.example")
    end

    # A miss is what an attacker can force, so it must not squat a hit-length
    # slot. Read the ETS expiry directly: a sleep-based test would be slow and
    # flaky, and this pins the actual lifetime rather than just "it cached".
    test "expires a miss far sooner than a hit", %{store: store} do
      _ = active_domain!(store, "kentekingdom.com")

      {:ok, _} = DomainResolver.lookup("kentekingdom.com")
      :none = DomainResolver.lookup("nobody.example")

      now = System.monotonic_time(:millisecond)
      [{_, _, hit_expiry}] = :ets.lookup(:emakola_store_cache, "domain_host:kentekingdom.com")
      [{_, :none, miss_expiry}] = :ets.lookup(:emakola_store_cache, "domain_host:nobody.example")

      assert miss_expiry - now <= :timer.seconds(60)
      assert hit_expiry - now > :timer.seconds(60)
    end

    test "finds a pending domain but reports it as not active", %{store: store} do
      {:ok, _} =
        Stores.claim_custom_domain(%{store_id: store.id, host: "pending.example"},
          authorize?: false
        )

      assert {:ok, %{status: :pending}} = DomainResolver.lookup("pending.example")
    end
  end

  describe "primary_host/1" do
    test "is nil until a domain is made primary", %{store: store} do
      _ = active_domain!(store, "kentekingdom.com")
      assert is_nil(DomainResolver.primary_host(store.slug))
    end

    test "returns the primary custom host", %{store: store} do
      domain = active_domain!(store, "kentekingdom.com")
      {:ok, _} = Stores.make_domain_primary(domain, authorize?: false)

      assert DomainResolver.primary_host(store.slug) == "kentekingdom.com"
    end

    test "caches the nil so every canonical render is not a query", %{store: store} do
      assert is_nil(DomainResolver.primary_host(store.slug))
      assert {:hit, :none} = StoreCache.get("store_primary_host:#{store.slug}")
    end
  end

  describe "cache invalidation" do
    test "going live clears both keys", %{store: store} do
      {:ok, d} =
        Stores.claim_custom_domain(%{store_id: store.id, host: "kentekingdom.com"},
          authorize?: false
        )

      {:ok, d} = Stores.request_domain_verification(d, authorize?: false)

      # Warm both keys with the pre-activation answer.
      assert {:ok, %{status: :verifying}} = DomainResolver.lookup("kentekingdom.com")
      assert is_nil(DomainResolver.primary_host(store.slug))

      {:ok, d} = Stores.mark_domain_active(d, authorize?: false)
      {:ok, _} = Stores.make_domain_primary(d, authorize?: false)

      assert {:ok, %{status: :active}} = DomainResolver.lookup("kentekingdom.com")
      assert DomainResolver.primary_host(store.slug) == "kentekingdom.com"
    end

    test "expiring clears both keys", %{store: store} do
      domain = active_domain!(store, "kentekingdom.com")
      {:ok, domain} = Stores.make_domain_primary(domain, authorize?: false)

      assert DomainResolver.primary_host(store.slug) == "kentekingdom.com"

      {:ok, _} = Stores.expire_store_domain(domain, %{reason: "revoked"}, authorize?: false)

      assert is_nil(DomainResolver.primary_host(store.slug))
      assert {:ok, %{status: :expired}} = DomainResolver.lookup("kentekingdom.com")
    end

    test "destroying clears both keys", %{store: store} do
      domain = active_domain!(store, "kentekingdom.com")
      {:ok, domain} = Stores.make_domain_primary(domain, authorize?: false)
      assert {:ok, _} = DomainResolver.lookup("kentekingdom.com")

      :ok = Stores.destroy_store_domain(domain, authorize?: false)

      assert :none = DomainResolver.lookup("kentekingdom.com")
      assert is_nil(DomainResolver.primary_host(store.slug))
    end

    # StoreCache.invalidate_store/2 splits keys on ":" into exactly three parts
    # and requires the middle to be the store_id. Neither domain key has that
    # shape, so the blanket invalidation cannot reach them — which is precisely
    # why StoreDomain carries its own explicit invalidation change.
    test "the store-wide invalidation does NOT reach domain keys", %{store: store} do
      domain = active_domain!(store, "kentekingdom.com")
      {:ok, _} = Stores.make_domain_primary(domain, authorize?: false)

      {:ok, _} = DomainResolver.lookup("kentekingdom.com")
      _ = DomainResolver.primary_host(store.slug)

      StoreCache.invalidate_store(store.id)

      assert {:hit, _} = StoreCache.get("domain_host:kentekingdom.com")
      assert {:hit, _} = StoreCache.get("store_primary_host:#{store.slug}")
    end
  end
end
