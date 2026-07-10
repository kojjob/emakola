defmodule Emakola.Suppliers.ListingImporterTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  require Ash.Query

  alias Emakola.Suppliers.{ListingImporter, Network, Offers}

  setup do
    {wholesaler_actor, wholesaler} = create_merchant_with_store!(%{name: "Import wholesaler"})
    {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Import reseller"})

    product =
      create_product!(wholesaler, status: :active, title: "Kente sandals", tags: ["local"])

    color = create_option_type!(product, wholesaler, name: "Color", position: 0)
    red = create_option_value!(color, wholesaler, value: "Red", position: 0)
    blue = create_option_value!(color, wholesaler, value: "Blue", position: 1)

    red_variant =
      create_variant!(product, wholesaler,
        price: 6_000,
        sku: "SANDAL-RED",
        stock_quantity: 8,
        position: 0
      )

    blue_variant =
      create_variant!(product, wholesaler,
        price: 6_500,
        sku: "SANDAL-BLUE",
        stock_quantity: 5,
        position: 1
      )

    create_variant_option_value!(red_variant, red, wholesaler)
    create_variant_option_value!(blue_variant, blue, wholesaler)

    {:ok, offer} =
      Offers.create_draft(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup
      })

    {:ok, red_terms} =
      Offers.add_variant(wholesaler_actor, offer, %{
        source_variant_id: red_variant.id,
        supplier_price: 4_000,
        suggested_retail_price: 5_000,
        max_retail_price: 5_800
      })

    {:ok, blue_terms} =
      Offers.add_variant(wholesaler_actor, offer, %{
        source_variant_id: blue_variant.id,
        supplier_price: 4_500,
        suggested_retail_price: 5_500,
        max_retail_price: 6_200
      })

    {:ok, published} = Offers.publish(wholesaler_actor, offer)

    {:ok,
     wholesaler_actor: wholesaler_actor,
     wholesaler: wholesaler,
     reseller_actor: reseller_actor,
     reseller: reseller,
     offer: published,
     red_terms: red_terms,
     blue_terms: blue_terms}
  end

  test "imports a multi-variant offer into normal checkout-compatible catalog records", context do
    connect!(context)

    assert {:ok, listing} =
             ListingImporter.import(context.reseller_actor, context.reseller.id, context.offer, %{
               context.red_terms.id => 5_400
             })

    assert listing.status == :active
    assert listing.reseller_product.store_id == context.reseller.id
    assert listing.reseller_product.status == :active
    assert listing.reseller_product.title == "Kente sandals"
    assert listing.reseller_product.tags == ["local"]
    assert length(listing.listing_variants) == 2

    variants = Map.new(listing.listing_variants, &{&1.offer_variant_id, &1.reseller_variant})
    red = variants[context.red_terms.id]
    blue = variants[context.blue_terms.id]

    assert red.price == 5_400
    assert red.cost_price == 4_000
    assert blue.price == 5_500
    assert blue.cost_price == 4_500
    assert red.supplier_id == listing.supplier_id
    assert blue.supplier_id == listing.supplier_id
    assert listing.supplier.linked_store_id == context.wholesaler.id
    refute red.track_inventory
    refute blue.track_inventory

    option_types =
      Emakola.Catalog.OptionType
      |> Ash.Query.filter(product_id == ^listing.reseller_product_id)
      |> Ash.Query.load(:option_values)
      |> Ash.read!(authorize?: false)

    assert [%{name: "Color", option_values: values}] = option_types
    assert Enum.sort(Enum.map(values, & &1.value)) == ["Blue", "Red"]

    links =
      Emakola.Catalog.list_variant_option_values_by_variants([red.id, blue.id],
        authorize?: false
      )
      |> elem(1)

    assert length(links) == 2
  end

  test "requires an active supply connection", context do
    assert {:error, :offer_not_available} =
             ListingImporter.import(context.reseller_actor, context.reseller.id, context.offer)
  end

  test "imported variants use the existing supplier fulfillment path at checkout", context do
    connect!(context)

    {:ok, listing} =
      ListingImporter.import(context.reseller_actor, context.reseller.id, context.offer)

    [variant | _] = listing.reseller_product.variants

    assert {:ok, order} =
             Emakola.Orders.CheckoutService.checkout!(
               context.reseller.id,
               [%{variant_id: variant.id, quantity: 1}],
               []
             )

    fulfillments =
      Emakola.Orders.Fulfillment
      |> Ash.Query.filter(order_id == ^order.id)
      |> Ash.read!(authorize?: false, tenant: context.reseller.id)

    assert [%{supplier_id: supplier_id}] = fulfillments
    assert supplier_id == listing.supplier_id
  end

  test "rejects prices outside supplier bounds before creating catalog records", context do
    connect!(context)

    before_count = product_count(context.reseller.id)

    assert {:error, {:invalid_retail_price, variant_id}} =
             ListingImporter.import(context.reseller_actor, context.reseller.id, context.offer, %{
               context.red_terms.id => 8_000
             })

    assert variant_id == context.red_terms.id
    assert product_count(context.reseller.id) == before_count
  end

  test "cannot import the same offer twice", context do
    connect!(context)

    assert {:ok, _} =
             ListingImporter.import(context.reseller_actor, context.reseller.id, context.offer)

    assert {:error, :listing_exists} =
             ListingImporter.import(context.reseller_actor, context.reseller.id, context.offer)
  end

  test "sync refreshes source content and disables listings when the offer pauses", context do
    connect!(context)

    {:ok, listing} =
      ListingImporter.import(context.reseller_actor, context.reseller.id, context.offer)

    source_product =
      Ash.get!(Emakola.Catalog.Product, context.offer.source_product_id, authorize?: false)

    Emakola.Catalog.update_product!(source_product, %{title: "Updated kente sandals"},
      authorize?: false
    )

    source_variant =
      Ash.get!(Emakola.Catalog.Variant, context.red_terms.source_variant_id, authorize?: false)

    Emakola.Catalog.update_variant!(source_variant, %{available: false}, authorize?: false)

    assert {:ok, active} = ListingImporter.sync(context.reseller_actor, listing)
    assert active.status == :active

    updated_product =
      Ash.get!(Emakola.Catalog.Product, listing.reseller_product_id, authorize?: false)

    assert updated_product.title == "Updated kente sandals"

    red_mapping =
      Enum.find(listing.listing_variants, &(&1.offer_variant_id == context.red_terms.id))

    updated_red =
      Ash.get!(Emakola.Catalog.Variant, red_mapping.reseller_variant_id, authorize?: false)

    refute updated_red.available

    {:ok, _paused_offer} = Offers.pause(context.wholesaler_actor, context.offer)

    automatically_paused =
      Ash.get!(Emakola.Suppliers.ResellerListing, listing.id, authorize?: false)

    assert automatically_paused.status == :paused

    assert {:ok, paused} = ListingImporter.sync(context.reseller_actor, listing)
    assert paused.status == :paused

    listing.reseller_product.variants
    |> Enum.each(fn variant ->
      refute Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false).available
    end)
  end

  test "suspending the supply connection immediately disables imported variants", context do
    connection = connect!(context)

    {:ok, listing} =
      ListingImporter.import(context.reseller_actor, context.reseller.id, context.offer)

    assert {:ok, _} = Network.suspend(context.wholesaler_actor, connection, "Quality review")

    updated_listing =
      Ash.get!(Emakola.Suppliers.ResellerListing, listing.id, authorize?: false)

    assert updated_listing.status == :paused

    listing.reseller_product.variants
    |> Enum.each(fn variant ->
      refute Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false).available
    end)
  end

  defp connect!(context) do
    {:ok, connection} =
      Network.request(context.wholesaler_actor, %{
        wholesaler_store_id: context.wholesaler.id,
        reseller_store_id: context.reseller.id,
        requested_by_store_id: context.wholesaler.id
      })

    {:ok, active} = Network.approve(context.reseller_actor, connection)
    active
  end

  defp product_count(store_id) do
    Emakola.Catalog.Product
    |> Ash.Query.filter(store_id == ^store_id)
    |> Ash.count!(authorize?: false)
  end
end
