defmodule Emakola.Fulfillment.DownloadGrantTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  require Ash.Query

  alias Emakola.Catalog.DigitalFile
  alias Emakola.Fulfillment.DownloadGrant

  setup do
    store =
      create_store!()
      |> Ash.Changeset.for_update(:update_settings, %{
        enabled_product_types: [:physical, :digital_download]
      })
      |> Ash.update!(authorize?: false)

    product = create_product!(store, product_type: :digital_download)
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

    {:ok, file} =
      DigitalFile
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        product_id: product.id,
        file_name: "asset.zip",
        storage_key: "stores/#{store.id}/files/asset-#{System.unique_integer([:positive])}.zip",
        content_type: "application/zip",
        byte_size: 2_000_000
      })
      |> Ash.create(authorize?: false)

    {:ok,
     store: store,
     product: product,
     customer: customer,
     order: order,
     line_item: line_item,
     digital_file: file}
  end

  defp valid_attrs(ctx, overrides) do
    Map.merge(
      %{
        store_id: ctx.store.id,
        order_id: ctx.order.id,
        line_item_id: ctx.line_item.id,
        customer_id: ctx.customer.id,
        digital_file_id: ctx.digital_file.id
      },
      Map.new(overrides)
    )
  end

  defp issue(ctx, overrides \\ %{}) do
    DownloadGrant
    |> Ash.Changeset.for_create(:issue, valid_attrs(ctx, overrides))
    |> Ash.create(authorize?: false)
  end

  describe ":issue" do
    test "creates a grant for a customer, line item, and file", ctx do
      assert {:ok, grant} = issue(ctx)
      assert grant.store_id == ctx.store.id
      assert grant.order_id == ctx.order.id
      assert grant.line_item_id == ctx.line_item.id
      assert grant.customer_id == ctx.customer.id
      assert grant.digital_file_id == ctx.digital_file.id
    end

    test "defaults downloaded_count to 0", ctx do
      assert {:ok, grant} = issue(ctx)
      assert grant.downloaded_count == 0
    end

    test "download_limit and expires_at default to nil (unlimited / never expires)", ctx do
      assert {:ok, grant} = issue(ctx)
      assert grant.download_limit == nil
      assert grant.expires_at == nil
    end

    test "accepts an explicit download_limit", ctx do
      assert {:ok, grant} = issue(ctx, %{download_limit: 5})
      assert grant.download_limit == 5
    end

    test "accepts an explicit expires_at", ctx do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      assert {:ok, grant} = issue(ctx, %{expires_at: future})
      assert grant.expires_at != nil
    end

    test "allows nil customer_id (guest checkout flow)", ctx do
      assert {:ok, grant} = issue(ctx, %{customer_id: nil})
      assert grant.customer_id == nil
    end

    test "rejects negative download_limit", ctx do
      assert {:error, _} = issue(ctx, %{download_limit: -1})
    end

    test "rejects zero download_limit (use nil for unlimited)", ctx do
      assert {:error, _} = issue(ctx, %{download_limit: 0})
    end

    test "enforces unique (line_item_id, digital_file_id)", ctx do
      assert {:ok, _} = issue(ctx)
      assert {:error, _} = issue(ctx)
    end

    test "two different files on the same line item produce two grants", ctx do
      {:ok, _first} = issue(ctx)

      {:ok, other_file} =
        DigitalFile
        |> Ash.Changeset.for_create(:create, %{
          store_id: ctx.store.id,
          product_id: ctx.product.id,
          file_name: "extras.zip",
          storage_key:
            "stores/#{ctx.store.id}/files/extras-#{System.unique_integer([:positive])}.zip",
          content_type: "application/zip",
          byte_size: 500_000
        })
        |> Ash.create(authorize?: false)

      assert {:ok, second} = issue(ctx, %{digital_file_id: other_file.id})
      assert second.digital_file_id == other_file.id
    end
  end

  describe ":increment_download_count" do
    test "atomically increments downloaded_count by 1", ctx do
      {:ok, grant} = issue(ctx)

      assert {:ok, after_first} =
               grant
               |> Ash.Changeset.for_update(:increment_download_count, %{})
               |> Ash.update(authorize?: false)

      assert after_first.downloaded_count == 1

      assert {:ok, after_second} =
               after_first
               |> Ash.Changeset.for_update(:increment_download_count, %{})
               |> Ash.update(authorize?: false)

      assert after_second.downloaded_count == 2
    end
  end

  describe "relationships" do
    test "destroying the digital_file cascades to its grants", ctx do
      {:ok, grant} = issue(ctx)

      :ok =
        ctx.digital_file
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(authorize?: false)

      assert {:error, _} = Ash.get(DownloadGrant, grant.id, authorize?: false)
    end

    # Note: Order has no public :destroy action (orders are canceled, not
    # deleted). The FK cascade on order_id exists as a DB safety net for
    # admin-level data deletion; it's not part of the public Ash API.
  end

  describe "multitenancy" do
    test "a grant in store A is not visible in store-B-filtered reads", ctx do
      {:ok, mine} = issue(ctx)

      other = create_store!(name: "Other", slug: "other-#{System.unique_integer([:positive])}")

      ids =
        DownloadGrant
        |> Ash.Query.filter(store_id == ^other.id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)

      refute mine.id in ids
    end
  end
end
