defmodule Emakola.Suppliers.SalesSharingTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  require Ash.Query

  alias Emakola.Suppliers.{ListingImporter, Network, Offers, SalesSharing}

  setup do
    {wholesaler_actor, wholesaler} = create_merchant_with_store!(%{name: "Sales kit supplier"})
    {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Sales kit reseller"})
    source_product = create_product!(wholesaler, status: :active, title: "Shareable Kente")
    source_variant = create_variant!(source_product, wholesaler, stock_quantity: 10)

    {:ok, offer} =
      Offers.create_draft(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        source_product_id: source_product.id,
        earning_model: :markup
      })

    {:ok, _terms} =
      Offers.add_variant(wholesaler_actor, offer, %{
        source_variant_id: source_variant.id,
        supplier_price: 4_000,
        suggested_retail_price: 5_000,
        max_retail_price: 6_000
      })

    {:ok, published} = Offers.publish(wholesaler_actor, offer)

    {:ok, pending} =
      Network.request(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: wholesaler.id
      })

    {:ok, _active} = Network.approve(reseller_actor, pending)
    {:ok, listing} = ListingImporter.import(reseller_actor, reseller.id, published)

    %{
      reseller_actor: reseller_actor,
      reseller: reseller,
      listing: listing
    }
  end

  test "creates an idempotent three-channel kit with attributed product URLs", context do
    assert {:ok, shares} = SalesSharing.create_kit(context.reseller_actor, context.listing)
    assert Enum.sort(Enum.map(shares, & &1.channel)) == [:copy_link, :facebook, :whatsapp]

    Enum.each(shares, fn share ->
      uri = share |> SalesSharing.url() |> URI.parse()
      params = URI.decode_query(uri.query)

      assert uri.path =~ "/products/"
      assert params["share"] == share.token
      assert params["utm_medium"] == "earn_share"
      assert params["utm_source"] == Atom.to_string(share.channel)
    end)

    assert {:ok, repeated} = SalesSharing.create_kit(context.reseller_actor, context.listing)
    assert Enum.sort(Enum.map(repeated, & &1.id)) == Enum.sort(Enum.map(shares, & &1.id))
  end

  test "records clicks, confirmed-order conversion, and revenue exactly once", context do
    {:ok, [share | _]} = SalesSharing.create_kit(context.reseller_actor, context.listing)
    assert :ok = SalesSharing.record_click(share.token)
    assert :ok = SalesSharing.record_click(share.token)

    order =
      Emakola.Orders.create_order!(
        %{
          store_id: context.reseller.id,
          total: 5_000,
          subtotal: 5_000,
          attribution: %{"share_token" => share.token}
        },
        authorize?: false
      )

    # The order must actually contain the promoted product — a share is
    # credited with sales of the thing it promotes, not with everything the
    # shop sells while its token is in the session.
    [variant | _] =
      Emakola.Catalog.Variant
      |> Ash.Query.filter(product_id == ^share.product_id)
      |> Ash.read!(authorize?: false)

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: context.reseller.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!(authorize?: false)

    assert {:ok, confirmed} = Emakola.Orders.confirm_order(order, authorize?: false)
    assert confirmed.status == :confirmed
    assert :ok = SalesSharing.record_conversion(confirmed)

    [reloaded] =
      Emakola.Suppliers.SalesShare
      |> Ash.Query.filter(id == ^share.id)
      |> Ash.Query.load([:order_count, :revenue])
      |> Ash.read!(authorize?: false)

    assert reloaded.click_count == 2
    assert reloaded.order_count == 1
    assert reloaded.revenue == 5_000

    assert [_conversion] =
             Emakola.Suppliers.SalesShareConversion
             |> Ash.Query.filter(order_id == ^order.id)
             |> Ash.read!(authorize?: false)
  end

  test "does not attribute an order for a product the share never promoted", context do
    # A share token in the session used to attribute ANY order from that store,
    # whatever was actually bought. As analytics that overstated a share; once
    # commission rides on it, it pays an affiliate for someone else's sale.
    {:ok, [share | _]} = SalesSharing.create_kit(context.reseller_actor, context.listing)
    assert :ok = SalesSharing.record_click(share.token)

    unrelated = create_product!(context.reseller, status: :active, title: "Something Else")
    unrelated_variant = create_variant!(unrelated, context.reseller, stock_quantity: 5)

    order =
      Emakola.Orders.create_order!(
        %{
          store_id: context.reseller.id,
          total: 5_000,
          subtotal: 5_000,
          attribution: %{"share_token" => share.token}
        },
        authorize?: false
      )

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: context.reseller.id,
      variant_id: unrelated_variant.id,
      quantity: 1
    })
    |> Ash.create!(authorize?: false)

    {:ok, confirmed} = Emakola.Orders.confirm_order(order, authorize?: false)
    assert :ok = SalesSharing.record_conversion(confirmed)

    assert [] ==
             Emakola.Suppliers.SalesShareConversion
             |> Ash.Query.filter(order_id == ^order.id)
             |> Ash.read!(authorize?: false)
  end

  test "does not attribute a token to an order from another store", context do
    {:ok, [share | _]} = SalesSharing.create_kit(context.reseller_actor, context.listing)
    other_store = create_store!()

    order =
      Emakola.Orders.create_order!(
        %{
          store_id: other_store.id,
          total: 5_000,
          attribution: %{"share_token" => share.token}
        },
        authorize?: false
      )

    assert :ok = SalesSharing.record_conversion(order)

    assert [] ==
             Emakola.Suppliers.SalesShareConversion
             |> Ash.Query.filter(order_id == ^order.id)
             |> Ash.read!(authorize?: false)
  end
end
