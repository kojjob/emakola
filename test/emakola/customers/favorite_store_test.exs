defmodule Emakola.Customers.FavoriteStoreTest do
  use Emakola.DataCase, async: true

  alias Emakola.Customers.FavoriteStore
  alias Emakola.Factory

  setup do
    # The customer's "home" store — where the customer record lives.
    home_store = Factory.create_store!(%{name: "Home Store", slug: "home-store"})
    customer = Factory.create_customer!(home_store, %{email: "fan@example.com"})

    # Stores the customer can favorite from the marketplace directory.
    store_a = Factory.create_store!(%{name: "Store A", slug: "store-a"})
    store_b = Factory.create_store!(%{name: "Store B", slug: "store-b"})

    %{
      home_store: home_store,
      customer: customer,
      store_a: store_a,
      store_b: store_b
    }
  end

  describe "create (favorite_store)" do
    test "creates a favorite for an authorized customer", %{
      customer: customer,
      store_a: store
    } do
      assert {:ok, fav} =
               FavoriteStore
               |> Ash.Changeset.for_create(
                 :create,
                 %{customer_id: customer.id, store_id: store.id},
                 actor: customer
               )
               |> Ash.create()

      assert fav.customer_id == customer.id
      assert fav.store_id == store.id
    end

    test "is idempotent — same customer + store upserts to the same row", %{
      customer: customer,
      store_a: store
    } do
      {:ok, first} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer.id, store_id: store.id},
          actor: customer
        )

      {:ok, second} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer.id, store_id: store.id},
          actor: customer
        )

      assert first.id == second.id
    end

    test "forbids creating a favorite for another customer", %{
      home_store: home_store,
      store_a: store
    } do
      customer_a = Factory.create_customer!(home_store, %{email: "a@example.com"})
      customer_b = Factory.create_customer!(home_store, %{email: "b@example.com"})

      assert {:error, %Ash.Error.Forbidden{}} =
               Emakola.Customers.favorite_store(
                 %{customer_id: customer_a.id, store_id: store.id},
                 actor: customer_b
               )
    end

    test "forbids creating a favorite without an actor", %{
      customer: customer,
      store_a: store
    } do
      assert {:error, %Ash.Error.Forbidden{}} =
               Emakola.Customers.favorite_store(%{
                 customer_id: customer.id,
                 store_id: store.id
               })
    end
  end

  describe "list_for_customer" do
    test "returns favorites newest-first with :store loaded", %{
      customer: customer,
      store_a: store_a,
      store_b: store_b
    } do
      {:ok, _} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer.id, store_id: store_a.id},
          actor: customer
        )

      # Ensure distinguishable inserted_at (usec precision needs a small gap).
      Process.sleep(20)

      {:ok, _} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer.id, store_id: store_b.id},
          actor: customer
        )

      assert {:ok, [first, second]} =
               Emakola.Customers.list_favorite_stores(customer.id, actor: customer)

      assert first.store_id == store_b.id
      assert second.store_id == store_a.id

      # :store association is loaded
      assert %Emakola.Stores.Store{} = first.store
      assert first.store.id == store_b.id
    end

    test "customer A cannot read customer B's favorites", %{
      home_store: home_store,
      store_a: store
    } do
      customer_a = Factory.create_customer!(home_store, %{email: "alpha@example.com"})
      customer_b = Factory.create_customer!(home_store, %{email: "bravo@example.com"})

      {:ok, _} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer_a.id, store_id: store.id},
          actor: customer_a
        )

      # Customer B asks for Customer A's favorites — policy filters out the row.
      assert {:ok, []} =
               Emakola.Customers.list_favorite_stores(customer_a.id, actor: customer_b)
    end
  end

  describe "destroy (unfavorite_store)" do
    test "owner can destroy their favorite", %{customer: customer, store_a: store} do
      {:ok, fav} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer.id, store_id: store.id},
          actor: customer
        )

      assert :ok = Emakola.Customers.unfavorite_store(fav, actor: customer)

      {:ok, favs} = Emakola.Customers.list_favorite_stores(customer.id, actor: customer)
      assert favs == []
    end

    test "another customer cannot destroy someone else's favorite", %{
      home_store: home_store,
      store_a: store
    } do
      customer_a = Factory.create_customer!(home_store, %{email: "owner@example.com"})
      customer_b = Factory.create_customer!(home_store, %{email: "thief@example.com"})

      {:ok, fav} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer_a.id, store_id: store.id},
          actor: customer_a
        )

      assert {:error, %Ash.Error.Forbidden{}} =
               Emakola.Customers.unfavorite_store(fav, actor: customer_b)
    end
  end
end
