defmodule Emakola.Workers.WhatsappCatalogSyncWorkerTest do
  @moduledoc """
  Pins the worker contract for WhatsApp Catalog sync:

    * upsert action loads the product + store, builds the channel payload,
      dispatches via the configured provider
    * Stores without a whatsapp_catalog_id are skipped silently (returns :ok)
    * Stores with empty-string catalog_id are skipped silently
    * Provider receives the expected payload shape
    * Unknown action atoms cancel the job (no retry)
  """
  use Emakola.DataCase, async: false

  alias Emakola.Factory
  alias Emakola.Workers.WhatsappCatalogSyncWorker

  # Use the LogWhatsappCatalog stub provider for the duration of these tests.
  setup do
    original = Application.get_env(:emakola, :whatsapp_catalog_provider)

    Application.put_env(
      :emakola,
      :whatsapp_catalog_provider,
      Emakola.Notifications.Channels.LogWhatsappCatalog
    )

    on_exit(fn ->
      if original do
        Application.put_env(:emakola, :whatsapp_catalog_provider, original)
      else
        Application.delete_env(:emakola, :whatsapp_catalog_provider)
      end
    end)

    :ok
  end

  describe "perform/1 — upsert action" do
    test "skips silently when store has no whatsapp_catalog_id" do
      store = Factory.create_store!(%{name: "No Catalog Shop", slug: "no-catalog"})
      product = Factory.create_product!(store, %{title: "Item"})
      _variant = Factory.create_variant!(product, store, %{price: 5_000, stock_quantity: 10})

      job = %Oban.Job{args: %{"product_id" => product.id, "action" => "upsert"}}

      assert :ok = WhatsappCatalogSyncWorker.perform(job)
    end

    test "skips silently when store has empty-string whatsapp_catalog_id" do
      store =
        Factory.create_store!(%{name: "Empty Catalog Shop", slug: "empty-catalog"})

      {:ok, store} =
        store
        |> Ash.Changeset.for_update(:update_settings, %{whatsapp_catalog_id: ""})
        |> Ash.update(authorize?: false)

      product = Factory.create_product!(store, %{title: "Item"})
      _variant = Factory.create_variant!(product, store, %{price: 5_000, stock_quantity: 10})

      job = %Oban.Job{args: %{"product_id" => product.id, "action" => "upsert"}}

      assert :ok = WhatsappCatalogSyncWorker.perform(job)
    end

    test "dispatches to provider when catalog_id is set" do
      store = Factory.create_store!(%{name: "Catalog Shop", slug: "catalog-shop"})

      {:ok, store} =
        store
        |> Ash.Changeset.for_update(:update_settings, %{whatsapp_catalog_id: "123456789"})
        |> Ash.update(authorize?: false)

      product = Factory.create_product!(store, %{title: "Hand-woven Bag"})
      _variant = Factory.create_variant!(product, store, %{price: 8_500, stock_quantity: 5})

      job = %Oban.Job{args: %{"product_id" => product.id, "action" => "upsert"}}

      assert {:ok, %{logged: true, retailer_id: retailer_id}} =
               WhatsappCatalogSyncWorker.perform(job)

      assert retailer_id == product.id
    end

    test "returns error when product not found" do
      job = %Oban.Job{args: %{"product_id" => Ecto.UUID.generate(), "action" => "upsert"}}
      assert {:error, :product_not_found} = WhatsappCatalogSyncWorker.perform(job)
    end
  end

  describe "perform/1 — delete action" do
    test "delete without store_id logs warning and returns :ok (back-compat)" do
      job =
        %Oban.Job{
          args: %{"product_id" => Ecto.UUID.generate(), "action" => "delete"}
        }

      assert :ok = WhatsappCatalogSyncWorker.perform(job)
    end

    test "delete with store_id + catalog_id dispatches to provider" do
      store = Factory.create_store!(%{name: "Del Catalog Shop", slug: "del-catalog"})

      {:ok, store} =
        store
        |> Ash.Changeset.for_update(:update_settings, %{whatsapp_catalog_id: "987654321"})
        |> Ash.update(authorize?: false)

      job =
        %Oban.Job{
          args: %{
            "product_id" => Ecto.UUID.generate(),
            "store_id" => store.id,
            "action" => "delete"
          }
        }

      assert :ok = WhatsappCatalogSyncWorker.perform(job)
    end

    test "delete with store_id but no catalog_id skips silently" do
      store = Factory.create_store!(%{name: "No Cat Del Shop", slug: "no-cat-del"})

      job =
        %Oban.Job{
          args: %{
            "product_id" => Ecto.UUID.generate(),
            "store_id" => store.id,
            "action" => "delete"
          }
        }

      assert :ok = WhatsappCatalogSyncWorker.perform(job)
    end
  end

  describe "perform/1 — unknown action" do
    test "cancels job for unknown action" do
      job = %Oban.Job{args: %{"product_id" => Ecto.UUID.generate(), "action" => "explode"}}
      assert {:cancel, _msg} = WhatsappCatalogSyncWorker.perform(job)
    end
  end
end
