defmodule Emakola.Stores.StoreDomainLifecycleTest do
  # async: false — mutates :store_subdomain_base, which ValidStoreHost reads.
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Stores

  setup do
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    on_exit(fn -> Application.delete_env(:emakola, :store_subdomain_base) end)

    {:ok, store: create_store!(%{name: "Kente Kingdom", slug: "kente-kingdom-life"})}
  end

  defp claim!(store, host) do
    {:ok, domain} =
      Stores.claim_custom_domain(%{store_id: store.id, host: host}, authorize?: false)

    domain
  end

  defp verifying!(store, host) do
    {:ok, domain} = store |> claim!(host) |> Stores.request_domain_verification(authorize?: false)
    domain
  end

  defp active!(store, host) do
    {:ok, domain} = store |> verifying!(host) |> Stores.mark_domain_active(authorize?: false)
    domain
  end

  describe "claim_custom_domain/2" do
    test "starts pending, custom, and serving in place", %{store: store} do
      domain = claim!(store, "kentekingdom.com")

      assert domain.host == "kentekingdom.com"
      assert domain.type == :custom
      assert domain.status == :pending
      # serve_in_place? true is structural: a primary custom domain that
      # redirected would 301 to itself once canonical points at it.
      assert domain.serve_in_place? == true
      assert domain.primary? == false
      assert is_nil(domain.verified_at)
    end

    # The accept list is [:store_id, :host] and Ash refuses unknown inputs
    # outright, so there is no path to a live, unverified domain.
    test "refuses an attempt to set status or verified_at directly", %{store: store} do
      for attrs <- [%{status: :active}, %{verified_at: DateTime.utc_now()}] do
        assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Invalid.NoSuchInput{}]}} =
                 Stores.claim_custom_domain(
                   Map.merge(%{store_id: store.id, host: "kentekingdom.com"}, attrs),
                   authorize?: false
                 )
      end
    end
  end

  describe "regression: the subdomain path is untouched" do
    test "plain create_store_domain still goes straight to :active", %{store: store} do
      {:ok, domain} =
        Stores.create_store_domain(%{store_id: store.id, host: "kente-kingdom-life.makola.io"},
          authorize?: false
        )

      assert domain.type == :subdomain
      assert domain.status == :active
    end
  end

  describe "request_domain_verification/2" do
    test "moves pending to verifying and starts the clock", %{store: store} do
      domain = verifying!(store, "kentekingdom.com")

      assert domain.status == :verifying
      assert %DateTime{} = domain.verifying_since
    end

    test "refuses a domain that is already active", %{store: store} do
      domain = active!(store, "kentekingdom.com")
      assert {:error, _} = Stores.request_domain_verification(domain, authorize?: false)
    end
  end

  describe "mark_domain_active/2" do
    test "moves verifying to active and stamps verified_at", %{store: store} do
      domain = active!(store, "kentekingdom.com")

      assert domain.status == :active
      assert %DateTime{} = domain.verified_at
    end

    test "refuses to skip verification", %{store: store} do
      domain = claim!(store, "kentekingdom.com")
      assert {:error, _} = Stores.mark_domain_active(domain, authorize?: false)
    end
  end

  describe "record_domain_check/3" do
    test "records a readable message without changing state", %{store: store} do
      domain = verifying!(store, "kentekingdom.com")

      {:ok, checked} =
        Stores.record_domain_check(domain, %{message: "Awaiting configuration"},
          authorize?: false
        )

      assert checked.status == :verifying
      assert checked.status_reason == "Awaiting configuration"
    end
  end

  describe "expire_store_domain/3" do
    test "clears everything that could keep it live", %{store: store} do
      domain = active!(store, "kentekingdom.com")
      {:ok, domain} = Stores.make_domain_primary(domain, authorize?: false)
      assert domain.primary?

      {:ok, expired} =
        Stores.expire_store_domain(domain, %{reason: "DNS not connected in time"},
          authorize?: false
        )

      assert expired.status == :expired
      assert expired.primary? == false
      assert is_nil(expired.verified_at)
      assert expired.status_reason == "DNS not connected in time"
    end

    # The squatting fix: an unverified reservation must not hold a host hostage.
    test "releases the host for a different store to claim", %{store: store} do
      other = create_store!(%{name: "Other", slug: "other-store-life"})
      domain = claim!(store, "nike.com")

      assert {:error, _} =
               Stores.claim_custom_domain(%{store_id: other.id, host: "nike.com"},
                 authorize?: false
               )

      {:ok, _} = Stores.expire_store_domain(domain, %{reason: "released"}, authorize?: false)

      assert {:ok, reclaimed} =
               Stores.claim_custom_domain(%{store_id: other.id, host: "nike.com"},
                 authorize?: false
               )

      assert reclaimed.store_id == other.id
    end

    test "still rejects a duplicate host while the first is live", %{store: store} do
      _ = claim!(store, "kentekingdom.com")

      assert {:error, _} =
               Stores.claim_custom_domain(%{store_id: store.id, host: "kentekingdom.com"},
                 authorize?: false
               )
    end
  end

  describe "make_domain_primary/2" do
    test "demotes the store's previous primary in the same write", %{store: store} do
      first = active!(store, "kentekingdom.com")
      second = active!(store, "kente-kingdom.org")

      {:ok, _} = Stores.make_domain_primary(first, authorize?: false)
      {:ok, _} = Stores.make_domain_primary(second, authorize?: false)

      {:ok, domains} = Stores.list_store_domains(store.id, authorize?: false)
      primaries = Enum.filter(domains, & &1.primary?)

      assert length(primaries) == 1
      assert hd(primaries).host == "kente-kingdom.org"
    end

    test "refuses a domain that is not live", %{store: store} do
      domain = claim!(store, "kentekingdom.com")
      assert {:error, _} = Stores.make_domain_primary(domain, authorize?: false)
    end
  end

  describe "SafePrimaryDomain guards the merchant-facing update" do
    test "refuses to make a pending domain primary", %{store: store} do
      domain = claim!(store, "kentekingdom.com")

      assert {:error, _} =
               Stores.update_store_domain(domain, %{primary?: true}, authorize?: false)
    end

    # This is the self-301 loop: a primary custom domain that redirects sends
    # traffic to its own canonical, which is itself.
    test "refuses to stop serving a primary custom domain in place", %{store: store} do
      domain = active!(store, "kentekingdom.com")
      {:ok, domain} = Stores.make_domain_primary(domain, authorize?: false)

      assert {:error, _} =
               Stores.update_store_domain(domain, %{serve_in_place?: false}, authorize?: false)
    end
  end

  describe "authorization" do
    test "a merchant cannot claim a domain for someone else's store", %{store: store} do
      intruder = create_merchant!()
      other = create_store!(%{name: "Theirs", slug: "theirs-store-life"})
      create_store_membership!(intruder, other, :owner)

      assert {:error, _} =
               Stores.claim_custom_domain(%{store_id: store.id, host: "kentekingdom.com"},
                 actor: intruder
               )
    end
  end

  describe "read actions" do
    test "list_verifying_domains returns only custom domains being verified", %{store: store} do
      _pending = claim!(store, "pending-one.com")
      verifying = verifying!(store, "verifying-one.com")
      _active = active!(store, "active-one.com")

      {:ok, rows} = Stores.list_verifying_domains(authorize?: false)
      assert Enum.map(rows, & &1.id) == [verifying.id]
    end

    test "get_primary_custom_domain_by_slug finds only a live primary custom host", %{
      store: store
    } do
      domain = active!(store, "kentekingdom.com")

      assert {:ok, nil} =
               Stores.get_primary_custom_domain_by_slug(store.slug,
                 authorize?: false,
                 not_found_error?: false
               )

      {:ok, _} = Stores.make_domain_primary(domain, authorize?: false)

      assert {:ok, found} =
               Stores.get_primary_custom_domain_by_slug(store.slug,
                 authorize?: false,
                 not_found_error?: false
               )

      assert found.host == "kentekingdom.com"
    end
  end
end
