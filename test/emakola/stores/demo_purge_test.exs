defmodule Emakola.Stores.DemoPurgeTest do
  @moduledoc """
  The demo-store purge deletes exactly the stores it is told to, and nothing else.

  This exists to clean seeded/demo data out of PRODUCTION before real customers
  arrive, so the tests are paranoid in one specific direction: a keeper store
  with an identical object graph must come through completely untouched, a
  merchant who owns both a purged and a kept store must survive, and any
  unknown slug must abort the whole run before a single row is deleted.

  Images are destroyed through Ash (never raw SQL) because the destroy action
  carries a side effect: `DeleteImageFiles` enqueues `StorageCleanupWorker` to
  delete the bucket files. A SQL delete would orphan the files in object
  storage.
  """
  use Emakola.DataCase, async: false

  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Stores.DemoPurge

  defp seed_store_graph!(slug) do
    merchant = Emakola.Factory.create_merchant!(%{email: "owner-#{slug}@example.com"})
    store = Emakola.Factory.create_store!(%{slug: slug, name: slug})
    Emakola.Factory.create_store_membership!(merchant, store, :owner)

    category = Emakola.Factory.create_category!(store, %{name: "Fruit"})
    product = Emakola.Factory.create_product!(store, %{title: "Mango", status: :active})
    variant = Emakola.Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 5})
    image = Emakola.Factory.create_image!(product, store)

    customer = Emakola.Factory.create_customer!(store)
    Emakola.Factory.create_address!(customer, store)

    order = Emakola.Factory.create_order!(store)
    payment = Emakola.Factory.create_payment!(store)
    Emakola.Factory.create_delivery_zone!(store)
    Emakola.Factory.create_page_content!(store)

    %{
      merchant: merchant,
      store: store,
      category: category,
      product: product,
      variant: variant,
      image: image,
      customer: customer,
      order: order,
      payment: payment
    }
  end

  defp table_count(table, store_id) do
    %{rows: [[n]]} =
      Ecto.Adapters.SQL.query!(
        Emakola.Repo,
        "select count(*) from #{table} where store_id = $1",
        [Ecto.UUID.dump!(store_id)]
      )

    n
  end

  describe "preview/1" do
    test "reports what would be deleted without deleting anything" do
      purge = seed_store_graph!("purge-me")

      {:ok, report} = DemoPurge.preview(["purge-me"])

      assert [%{slug: "purge-me"}] = report.stores
      assert report.row_counts["products"] == 1
      assert report.row_counts["orders"] == 1
      assert report.row_counts["payments"] == 1

      # Nothing was actually removed.
      assert table_count("products", purge.store.id) == 1
      assert table_count("orders", purge.store.id) == 1
    end

    test "refuses a slug that does not exist" do
      seed_store_graph!("real-store")

      assert {:error, {:unknown_slugs, ["no-such-store"]}} =
               DemoPurge.preview(["real-store", "no-such-store"])
    end
  end

  describe "execute/2" do
    test "removes the purge store's entire graph and leaves the keeper untouched" do
      purge = seed_store_graph!("purge-me")
      keeper = seed_store_graph!("keep-me")

      {:ok, report} = DemoPurge.execute(["purge-me"])

      assert [%{slug: "purge-me"}] = report.stores

      # The purged store and every tenant row is gone.
      for table <- ~w(stores products variants images categories customers
                      addresses orders payments delivery_zones store_page_contents
                      store_memberships) do
        column = if table == "stores", do: "id", else: "store_id"

        %{rows: [[n]]} =
          Ecto.Adapters.SQL.query!(
            Emakola.Repo,
            "select count(*) from #{table} where #{column} = $1",
            [Ecto.UUID.dump!(purge.store.id)]
          )

        assert n == 0, "expected #{table} to be emptied for the purged store, found #{n} rows"
      end

      # The keeper's graph is completely intact.
      assert table_count("products", keeper.store.id) == 1
      assert table_count("orders", keeper.store.id) == 1
      assert table_count("payments", keeper.store.id) == 1
      assert table_count("images", keeper.store.id) == 1
      assert table_count("store_memberships", keeper.store.id) == 1
    end

    test "image deletion goes through Ash so bucket cleanup is enqueued" do
      seed_store_graph!("purge-me")

      {:ok, _report} = DemoPurge.execute(["purge-me"])

      assert_enqueued(worker: Emakola.Workers.StorageCleanupWorker)
    end

    test "a merchant owning only purged stores goes; one with another store survives" do
      purge = seed_store_graph!("purge-me")
      keeper = seed_store_graph!("keep-me")

      # The keeper's merchant ALSO owns the purge store — they must survive even
      # though one of their stores is purged.
      Emakola.Factory.create_store_membership!(keeper.merchant, purge.store, :staff)

      {:ok, report} = DemoPurge.execute(["purge-me"])

      merchant_ids =
        Ecto.Adapters.SQL.query!(Emakola.Repo, "select id from merchants", []).rows
        |> List.flatten()
        |> MapSet.new(&Ecto.UUID.cast!/1)

      refute MapSet.member?(merchant_ids, purge.merchant.id),
             "the merchant who owned only the purged store should be gone"

      assert MapSet.member?(merchant_ids, keeper.merchant.id),
             "a merchant with a membership in a kept store must never be deleted"

      assert report.merchants_deleted == 1
    end

    test "an unknown slug aborts before anything is deleted" do
      purge = seed_store_graph!("purge-me")

      assert {:error, {:unknown_slugs, ["typo-store"]}} =
               DemoPurge.execute(["purge-me", "typo-store"])

      assert table_count("products", purge.store.id) == 1
      assert table_count("orders", purge.store.id) == 1
    end

    test "an empty slug list is refused" do
      assert {:error, :no_slugs} = DemoPurge.execute([])
    end
  end
end
