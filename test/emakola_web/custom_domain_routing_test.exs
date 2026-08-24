defmodule EmakolaWeb.CustomDomainRoutingTest do
  @moduledoc """
  Routing and canonical behaviour for merchant custom domains.

  Deliberately runs with `:store_subdomain_base` UNSET for most cases: a custom
  domain has nothing to do with the platform's subdomain base, and until now
  the resolver bailed out on a nil base before ever reaching the explicit
  StoreDomain lookup.
  """
  use EmakolaWeb.ConnCase, async: false

  import Emakola.Factory

  alias Emakola.Stores
  alias EmakolaWeb.Plugs.ResolveStoreHost
  alias EmakolaWeb.SEO.Canonical

  setup do
    Application.delete_env(:emakola, :store_subdomain_base)
    Emakola.Cache.StoreCache.invalidate_all()

    on_exit(fn ->
      Application.delete_env(:emakola, :store_subdomain_base)
      Emakola.Cache.StoreCache.invalidate_all()
    end)

    {:ok, store: create_store!(%{name: "Kente Kingdom", slug: "kente-kingdom-route"})}
  end

  defp live_domain!(store, host, opts \\ []) do
    {:ok, d} = Stores.claim_custom_domain(%{store_id: store.id, host: host}, authorize?: false)
    {:ok, d} = Stores.request_domain_verification(d, authorize?: false)
    {:ok, d} = Stores.mark_domain_active(d, authorize?: false)

    if Keyword.get(opts, :primary?, false) do
      {:ok, d} = Stores.make_domain_primary(d, authorize?: false)
      d
    else
      d
    end
  end

  describe "resolution no longer depends on the subdomain base" do
    test "an active custom domain resolves with no base configured", %{store: store} do
      _ = live_domain!(store, "kentekingdom.com")

      assert {:ok, resolved} = ResolveStoreHost.resolve_store("kentekingdom.com")
      assert resolved.id == store.id
    end

    test "a pending custom domain does not resolve", %{store: store} do
      {:ok, _} =
        Stores.claim_custom_domain(%{store_id: store.id, host: "pending.example"},
          authorize?: false
        )

      assert :error = ResolveStoreHost.resolve_store("pending.example")
    end

    test "an expired custom domain does not resolve", %{store: store} do
      domain = live_domain!(store, "kentekingdom.com")
      {:ok, _} = Stores.expire_store_domain(domain, %{reason: "revoked"}, authorize?: false)

      assert :error = ResolveStoreHost.resolve_store("kentekingdom.com")
    end

    test "an unknown host still does not resolve" do
      assert :error = ResolveStoreHost.resolve_store("nobody.example")
    end

    test "the implicit <slug>.<base> path still needs a base", %{store: store} do
      assert :error = ResolveStoreHost.resolve_store("#{store.slug}.makola.io")

      Application.put_env(:emakola, :store_subdomain_base, "makola.io")
      assert {:ok, _} = ResolveStoreHost.resolve_store("#{store.slug}.makola.io")
    end
  end

  describe "canonical URL" do
    test "falls back to the apex subfolder with no custom domain", %{store: store} do
      assert Canonical.store_url(store) =~ "/s/#{store.slug}"
    end

    test "becomes the primary custom domain", %{store: store} do
      _ = live_domain!(store, "kentekingdom.com", primary?: true)

      assert Canonical.store_url(store) == "http://kentekingdom.com"
    end

    test "carries through product, category and path URLs", %{store: store} do
      _ = live_domain!(store, "kentekingdom.com", primary?: true)

      assert Canonical.path(store, "/products") =~ "kentekingdom.com/products"
      assert Canonical.product_url(store, %{slug: "kente-cloth"}) =~ "kentekingdom.com/products/"
      assert Canonical.category_url(store, %{slug: "cloth"}) =~ "kentekingdom.com/category/"
    end

    test "ignores a domain that is live but not primary", %{store: store} do
      _ = live_domain!(store, "kentekingdom.com")
      assert Canonical.store_url(store) =~ "/s/#{store.slug}"
    end

    test "ignores a domain that is primary but no longer live", %{store: store} do
      domain = live_domain!(store, "kentekingdom.com", primary?: true)
      {:ok, _} = Stores.expire_store_domain(domain, %{reason: "revoked"}, authorize?: false)

      assert Canonical.store_url(store) =~ "/s/#{store.slug}"
    end

    # Scope limit: StoreAddressLive marks subdomain claims primary?, so without
    # the type == :custom filter every existing merchant's canonical would move.
    test "a primary SUBDOMAIN row does not change the canonical", %{store: store} do
      Application.put_env(:emakola, :store_subdomain_base, "makola.io")

      {:ok, domain} =
        Stores.create_store_domain(
          %{store_id: store.id, host: "vanity-label.makola.io", primary?: true},
          authorize?: false
        )

      assert domain.primary?

      # The canonical stays the SLUG subdomain, not the merchant's vanity
      # label. Without the `type == :custom` filter on the primary lookup,
      # every existing merchant's canonical would move to their vanity host.
      assert Canonical.store_url(store) == "http://#{store.slug}.makola.io"
    end

    test "reflects activation immediately, not after the cache TTL", %{store: store} do
      assert Canonical.store_url(store) =~ "/s/#{store.slug}"

      _ = live_domain!(store, "kentekingdom.com", primary?: true)

      assert Canonical.store_url(store) =~ "kentekingdom.com"
    end
  end

  describe "the endpoint redirect never loops" do
    # Once canonical IS the custom domain, a redirecting row would 301 to its
    # own canonical — itself.
    test "a primary custom domain is served, never redirected", %{conn: conn, store: store} do
      _ = live_domain!(store, "kentekingdom.com", primary?: true)

      conn = %{conn | host: "kentekingdom.com"}
      conn = EmakolaWeb.Plugs.ResolveStoreByHost.call(conn, [])

      refute conn.halted
      assert is_nil(Plug.Conn.get_resp_header(conn, "location") |> List.first())
    end

    test "the www alias redirects to the apex, preserving path and query", %{
      conn: conn,
      store: store
    } do
      _ = live_domain!(store, "kentekingdom.com", primary?: true)

      {:ok, alias_row} =
        Stores.claim_custom_domain_alias(
          %{store_id: store.id, host: "www.kentekingdom.com"},
          authorize?: false
        )

      {:ok, alias_row} = Stores.request_domain_verification(alias_row, authorize?: false)
      {:ok, _} = Stores.mark_domain_active(alias_row, authorize?: false)

      conn =
        %{conn | host: "www.kentekingdom.com", request_path: "/products", query_string: "page=2"}
        |> EmakolaWeb.Plugs.ResolveStoreByHost.call([])

      assert conn.halted
      assert conn.status == 301
      [location] = Plug.Conn.get_resp_header(conn, "location")
      assert location == "http://kentekingdom.com/products?page=2"
    end
  end
end
