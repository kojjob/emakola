defmodule Emakola.Fulfillment.Pipelines.DigitalDownloadTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  require Ash.Query

  alias Emakola.Catalog.DigitalFile
  alias Emakola.Fulfillment.DownloadGrant
  alias Emakola.Fulfillment.Pipelines.DigitalDownload

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

  defp setup_paid_order_for(product_type) do
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

  describe "fulfill/2 — happy path" do
    test "creates one grant per non-preview file on the line item's product" do
      ctx = setup_paid_order_for(:digital_download)
      _f1 = attach_file!(ctx.store, ctx.product, file_name: "a.zip")
      _f2 = attach_file!(ctx.store, ctx.product, file_name: "b.zip")
      _preview = attach_file!(ctx.store, ctx.product, file_name: "preview.pdf", is_preview: true)

      assert {:ok, %{grants: grants}} = DigitalDownload.fulfill(ctx.line_item, %{})

      assert length(grants) == 2
      assert Enum.all?(grants, &(&1.line_item_id == ctx.line_item.id))
      assert Enum.all?(grants, &(&1.customer_id == ctx.customer.id))
      assert Enum.all?(grants, &(&1.store_id == ctx.store.id))
      assert Enum.all?(grants, &(&1.order_id == ctx.order.id))
    end

    test "returns an empty grants list when the product has only preview files" do
      ctx = setup_paid_order_for(:digital_download)
      _preview = attach_file!(ctx.store, ctx.product, is_preview: true)

      assert {:ok, %{grants: []}} = DigitalDownload.fulfill(ctx.line_item, %{})
    end

    test "returns an empty grants list when the product has no files at all" do
      ctx = setup_paid_order_for(:digital_download)

      assert {:ok, %{grants: []}} = DigitalDownload.fulfill(ctx.line_item, %{})
    end

    test "is idempotent — re-running on the same line item does not duplicate grants" do
      ctx = setup_paid_order_for(:digital_download)
      _ = attach_file!(ctx.store, ctx.product)

      {:ok, %{grants: first}} = DigitalDownload.fulfill(ctx.line_item, %{})
      {:ok, %{grants: second}} = DigitalDownload.fulfill(ctx.line_item, %{})

      assert length(first) == 1
      assert length(second) == 1
      assert Enum.map(first, & &1.id) == Enum.map(second, & &1.id)

      total =
        DownloadGrant
        |> Ash.Query.filter(line_item_id == ^ctx.line_item.id)
        |> Ash.read!(authorize?: false)
        |> length()

      assert total == 1
    end

    test "issues grants even for guest orders (customer_id nil)" do
      store = digital_store!()
      product = create_product!(store, product_type: :digital_download)
      variant = create_variant!(product, store)
      order = create_order!(store)

      line_item =
        Emakola.Orders.LineItem
        |> Ash.Changeset.for_create(:create, %{
          order_id: order.id,
          store_id: store.id,
          variant_id: variant.id,
          quantity: 1
        })
        |> Ash.create!(authorize?: false)

      _ = attach_file!(store, product)

      assert {:ok, %{grants: [grant]}} = DigitalDownload.fulfill(line_item, %{})
      assert grant.customer_id == nil
    end
  end

  describe "fulfill/2 — error paths" do
    test "returns {:error, :line_item_not_found} for an unknown line_item struct" do
      fake = %{
        id: Ecto.UUID.generate(),
        order_id: Ecto.UUID.generate(),
        store_id: Ecto.UUID.generate(),
        variant_id: Ecto.UUID.generate()
      }

      assert {:error, :line_item_not_found} = DigitalDownload.fulfill(fake, %{})
    end
  end
end
