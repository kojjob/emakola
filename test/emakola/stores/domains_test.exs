defmodule Emakola.Stores.DomainsTest do
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Stores
  alias Emakola.Stores.Domains

  setup do
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    on_exit(fn -> Application.delete_env(:emakola, :store_subdomain_base) end)

    {:ok, store: create_store!(%{name: "Kente Kingdom", slug: "kente-kingdom-svc"})}
  end

  describe "claim/3 on an apex domain" do
    test "creates the apex and its www sibling", %{store: store} do
      assert {:ok, [apex, alias_row]} = Domains.claim(store, "kentekingdom.com")

      assert apex.host == "kentekingdom.com"
      assert apex.serve_in_place? == true

      # Without this row a merchant who wires only the apex ends up with a dead
      # www., and will not diagnose it.
      assert alias_row.host == "www.kentekingdom.com"
      assert alias_row.serve_in_place? == false

      assert Enum.all?([apex, alias_row], &(&1.status == :pending and &1.type == :custom))
    end

    test "treats a www. host as its apex", %{store: store} do
      assert {:ok, [apex, alias_row]} = Domains.claim(store, "www.kentekingdom.com")

      assert apex.host == "kentekingdom.com"
      assert alias_row.host == "www.kentekingdom.com"
    end

    # The apex is free but its www. sibling is already taken, so the pair must
    # fail as a unit rather than leaving a half-wired domain behind.
    test "rolls the apex back when the sibling cannot be created", %{store: store} do
      other = create_store!(%{name: "Other", slug: "other-store-svc"})

      {:ok, _} =
        Stores.claim_custom_domain(%{store_id: other.id, host: "www.kentekingdom.com"},
          authorize?: false
        )

      assert {:error, _} = Domains.claim(store, "kentekingdom.com")

      {:ok, mine} = Stores.list_store_domains(store.id, authorize?: false)
      assert mine == []
    end
  end

  describe "claim/3 on a subdomain" do
    test "creates a single row", %{store: store} do
      assert {:ok, [only]} = Domains.claim(store, "shop.kentekingdom.com")

      assert only.host == "shop.kentekingdom.com"
      assert only.serve_in_place? == true
      assert only.status == :pending
    end
  end

  describe "claim/3 rejects" do
    test "a host already claimed by another store", %{store: store} do
      other = create_store!(%{name: "Other", slug: "other-store-svc2"})
      {:ok, _} = Domains.claim(other, "kentekingdom.com")

      assert {:error, _} = Domains.claim(store, "kentekingdom.com")
    end

    test "leaves nothing behind when it rejects", %{store: store} do
      other = create_store!(%{name: "Other", slug: "other-store-svc3"})
      {:ok, _} = Domains.claim(other, "kentekingdom.com")

      _ = Domains.claim(store, "kentekingdom.com")

      {:ok, mine} = Stores.list_store_domains(store.id, authorize?: false)
      assert mine == []
    end
  end
end
