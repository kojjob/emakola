defmodule Emakola.Stores.StoreDomainTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Stores

  # These exercise resource logic (normalization, validation, uniqueness,
  # lookup) with authorize?: false, the way the trusted routing plug resolves a
  # host. Merchant-actor authorization is exercised in the admin LiveView tests.

  setup do
    store = create_store!(%{name: "Ama Kitchen", slug: "ama-kitchen-dom"})
    {:ok, store: store}
  end

  describe "create_store_domain/1" do
    test "creates a subdomain with a normalized host and sensible defaults", %{store: store} do
      {:ok, domain} =
        Stores.create_store_domain(
          %{store_id: store.id, host: "  Ama-Kitchen.Makola.IO "},
          authorize?: false
        )

      assert domain.host == "ama-kitchen.makola.io"
      assert domain.type == :subdomain
      assert domain.status == :active
      assert domain.serve_in_place? == false
      assert domain.store_id == store.id
    end

    test "rejects a duplicate host", %{store: store} do
      {:ok, _} =
        Stores.create_store_domain(%{store_id: store.id, host: "shoppy.makola.io"},
          authorize?: false
        )

      assert {:error, _} =
               Stores.create_store_domain(%{store_id: store.id, host: "shoppy.makola.io"},
                 authorize?: false
               )
    end

    test "rejects a reserved subdomain label", %{store: store} do
      assert {:error, error} =
               Stores.create_store_domain(%{store_id: store.id, host: "admin.makola.io"},
                 authorize?: false
               )

      assert Exception.message(error) =~ "reserved"
    end

    test "rejects a malformed host", %{store: store} do
      assert {:error, _} =
               Stores.create_store_domain(%{store_id: store.id, host: "not a host"},
                 authorize?: false
               )
    end

    test "allows a reserved word that is not the leading label", %{store: store} do
      {:ok, domain} =
        Stores.create_store_domain(%{store_id: store.id, host: "myadmin.makola.io"},
          authorize?: false
        )

      assert domain.host == "myadmin.makola.io"
    end
  end

  describe "get_store_domain_by_host/2" do
    test "finds a domain by its normalized host", %{store: store} do
      {:ok, created} =
        Stores.create_store_domain(%{store_id: store.id, host: "findme.makola.io"},
          authorize?: false
        )

      assert {:ok, found} =
               Stores.get_store_domain_by_host("findme.makola.io",
                 authorize?: false,
                 not_found_error?: false
               )

      assert found.id == created.id
    end

    test "returns {:ok, nil} for an unknown host" do
      assert {:ok, nil} =
               Stores.get_store_domain_by_host("nope.makola.io",
                 authorize?: false,
                 not_found_error?: false
               )
    end
  end

  describe "list_store_domains/1 and update" do
    test "lists domains for a store", %{store: store} do
      {:ok, _} =
        Stores.create_store_domain(%{store_id: store.id, host: "one.makola.io"},
          authorize?: false
        )

      {:ok, _} =
        Stores.create_store_domain(%{store_id: store.id, host: "two.makola.io"},
          authorize?: false
        )

      {:ok, domains} = Stores.list_store_domains(store.id, authorize?: false)
      assert length(domains) == 2
    end

    test "flips serve_in_place?", %{store: store} do
      {:ok, domain} =
        Stores.create_store_domain(%{store_id: store.id, host: "branded.makola.io"},
          authorize?: false
        )

      {:ok, updated} =
        Stores.update_store_domain(domain, %{serve_in_place?: true}, authorize?: false)

      assert updated.serve_in_place? == true
    end
  end
end
