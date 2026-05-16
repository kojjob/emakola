defmodule Emakola.Workers.FulfillmentWorkerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  require Ash.Query

  alias Emakola.Catalog.DigitalFile
  alias Emakola.Fulfillment.DownloadGrant
  alias Emakola.Workers.FulfillmentWorker

  defp digital_store! do
    create_store!()
    |> Ash.Changeset.for_update(:update_settings, %{
      enabled_product_types: [:physical, :digital_download]
    })
    |> Ash.update!(authorize?: false)
  end

  defp attach_file!(store, product, overrides \\ %{}) do
    DigitalFile
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          store_id: store.id,
          product_id: product.id,
          file_name: "asset.zip",
          storage_key: "stores/#{store.id}/files/#{System.unique_integer([:positive])}-asset.zip",
          content_type: "application/zip",
          byte_size: 1_000_000
        },
        Map.new(overrides)
      )
    )
    |> Ash.create!(authorize?: false)
  end

  defp setup_order(product_type) do
    store = digital_store!()
    product = create_product!(store, product_type: product_type)
    variant = create_variant!(product, store)
    customer = create_customer!(store)
    order = create_order!(store, customer_id: customer.id)

    line_item =
      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant.id,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

    %{store: store, product: product, customer: customer, order: order, line_item: line_item}
  end

  describe "perform/1" do
    test "issues download grants for digital_download line items" do
      ctx = setup_order(:digital_download)
      _ = attach_file!(ctx.store, ctx.product, file_name: "a.zip")
      _ = attach_file!(ctx.store, ctx.product, file_name: "b.zip")

      assert :ok = perform_job(FulfillmentWorker, %{"order_id" => ctx.order.id})

      grants =
        DownloadGrant
        |> Ash.Query.filter(order_id == ^ctx.order.id)
        |> Ash.read!(authorize?: false)

      assert length(grants) == 2
    end

    test "is idempotent — re-running on the same order does not duplicate grants" do
      ctx = setup_order(:digital_download)
      _ = attach_file!(ctx.store, ctx.product)

      assert :ok = perform_job(FulfillmentWorker, %{"order_id" => ctx.order.id})
      assert :ok = perform_job(FulfillmentWorker, %{"order_id" => ctx.order.id})

      grants =
        DownloadGrant
        |> Ash.Query.filter(order_id == ^ctx.order.id)
        |> Ash.read!(authorize?: false)

      assert length(grants) == 1
    end

    test "tolerates unwired pipelines (e.g. :physical → :not_implemented) without failing" do
      ctx = setup_order(:physical)

      # No digital files attached; Physical pipeline returns :not_implemented.
      # The worker logs but does not fail — that's the whole point of mixed-type
      # orders during the phased rollout.
      assert :ok = perform_job(FulfillmentWorker, %{"order_id" => ctx.order.id})
    end

    test "handles orders with no line items as a no-op success" do
      store = digital_store!()
      order = create_order!(store)

      assert :ok = perform_job(FulfillmentWorker, %{"order_id" => order.id})
    end

    test "returns {:error, :order_not_found} for a missing order_id" do
      assert {:error, :order_not_found} =
               perform_job(FulfillmentWorker, %{"order_id" => Ecto.UUID.generate()})
    end
  end

  describe "Order.:confirm enqueues the worker" do
    test "confirming an order enqueues a FulfillmentWorker job with the order_id" do
      ctx = setup_order(:digital_download)

      {:ok, _confirmed} =
        ctx.order
        |> Ash.Changeset.for_update(:confirm, %{})
        |> Ash.update(authorize?: false)

      assert_enqueued(worker: FulfillmentWorker, args: %{"order_id" => ctx.order.id})
    end
  end
end
