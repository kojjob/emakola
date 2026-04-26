defmodule Emakola.Catalog.ProductCatalogSyncHookTest do
  @moduledoc """
  Pins the contract for the after-action hook that mirrors product
  lifecycle events into the WhatsApp Business Catalog sync queue.

    * Product create enqueues an upsert job
    * Product update enqueues an upsert job
    * Product activate enqueues an upsert job
    * Product archive enqueues a delete job
    * Job carries product_id + store_id (worker needs both)

  We only assert that the job lands in the queue. The worker itself
  short-circuits when the store has no whatsapp_catalog_id, so this
  hook is safe regardless of merchant onboarding state.
  """
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Factory
  alias Emakola.Workers.WhatsappCatalogSyncWorker

  setup do
    store = Factory.create_store!(%{name: "Hook Shop", slug: "hook-shop"})
    {:ok, store: store}
  end

  describe "Product :create after-action" do
    test "enqueues upsert sync job", %{store: store} do
      {:ok, product} =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          title: "New Item"
        })
        |> Ash.create(authorize?: false)

      assert_enqueued(
        worker: WhatsappCatalogSyncWorker,
        args: %{"product_id" => product.id, "store_id" => store.id, "action" => "upsert"}
      )
    end
  end

  describe "Product :update after-action" do
    test "enqueues upsert sync job", %{store: store} do
      product = Factory.create_product!(store, %{title: "Old"})

      {:ok, _updated} =
        product
        |> Ash.Changeset.for_update(:update, %{title: "New"})
        |> Ash.update(authorize?: false)

      assert_enqueued(
        worker: WhatsappCatalogSyncWorker,
        args: %{"product_id" => product.id, "store_id" => store.id, "action" => "upsert"}
      )
    end
  end

  describe "Product :activate after-action" do
    test "enqueues upsert sync job", %{store: store} do
      product = Factory.create_product!(store, %{title: "Pending"})
      _variant = Factory.create_variant!(product, store, %{price: 5_000, stock_quantity: 5})

      {:ok, _activated} =
        product
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update(authorize?: false)

      assert_enqueued(
        worker: WhatsappCatalogSyncWorker,
        args: %{"product_id" => product.id, "store_id" => store.id, "action" => "upsert"}
      )
    end
  end

  describe "Product :archive after-action" do
    test "enqueues delete sync job", %{store: store} do
      product = Factory.create_product!(store, %{title: "Goodbye"})

      {:ok, _archived} =
        product
        |> Ash.Changeset.for_update(:archive, %{})
        |> Ash.update(authorize?: false)

      assert_enqueued(
        worker: WhatsappCatalogSyncWorker,
        args: %{"product_id" => product.id, "store_id" => store.id, "action" => "delete"}
      )
    end
  end
end
