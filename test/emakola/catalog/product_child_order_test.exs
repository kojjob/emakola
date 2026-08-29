defmodule Emakola.Catalog.ProductChildOrderTest do
  @moduledoc """
  A product's variants and images come back in the order the merchant set.

  The product page picks its default variant with `List.first(product.variants)`
  and its opening photo with `Enum.at(product.images, 0)`. Neither relationship
  declared a sort, so both were whatever order Postgres happened to return —
  which is not a promise, and changes after an update or a plan change.

  What that costs: the price, the stock badge and the SKU a shopper sees on
  first load are all taken from that variant. A two-variant product could show
  a sold-out variant's badge over an in-stock variant's price, and a merchant
  reporting "the price changed by itself" would be right.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Catalog
  alias Emakola.Factory

  setup do
    store = Factory.create_store!()
    product = Factory.create_product!(store, %{status: :active, title: "Adinkra Pyjamas"})
    {:ok, store: store, product: product}
  end

  describe "variants" do
    test "come back by position, whatever order they were created in", ctx do
      # Deliberately created out of order: insertion order is the thing that
      # used to decide this.
      Factory.create_variant!(ctx.product, ctx.store, %{price: 3000, position: 2, sku: "POS-2"})
      Factory.create_variant!(ctx.product, ctx.store, %{price: 1000, position: 0, sku: "POS-0"})
      Factory.create_variant!(ctx.product, ctx.store, %{price: 2000, position: 1, sku: "POS-1"})

      {:ok, loaded} =
        Catalog.get_product_by_slug(ctx.store.id, ctx.product.slug, authorize?: false)

      assert Enum.map(loaded.variants, & &1.sku) == ["POS-0", "POS-1", "POS-2"]
      assert List.first(loaded.variants).sku == "POS-0"
    end

    test "share a position without the order going unstable", ctx do
      first = Factory.create_variant!(ctx.product, ctx.store, %{price: 1000, sku: "FIRST"})
      second = Factory.create_variant!(ctx.product, ctx.store, %{price: 2000, sku: "SECOND"})

      {:ok, loaded} =
        Catalog.get_product_by_slug(ctx.store.id, ctx.product.slug, authorize?: false)

      # Both sit at the default position, so creation order breaks the tie
      # rather than leaving it to the database.
      assert Enum.map(loaded.variants, & &1.id) == [first.id, second.id]
    end
  end

  describe "images" do
    test "come back by position, whatever order they were created in", ctx do
      Factory.create_variant!(ctx.product, ctx.store, %{price: 1000})

      last = Factory.create_image!(ctx.product, ctx.store, %{position: 2})
      opening = Factory.create_image!(ctx.product, ctx.store, %{position: 0})
      middle = Factory.create_image!(ctx.product, ctx.store, %{position: 1})

      {:ok, loaded} =
        Catalog.get_product_by_slug(ctx.store.id, ctx.product.slug, authorize?: false)

      assert Enum.map(loaded.images, & &1.id) == [opening.id, middle.id, last.id]
    end

    test "the gallery's opening photo is the one the cart would use", ctx do
      Factory.create_variant!(ctx.product, ctx.store, %{price: 1000})

      Factory.create_image!(ctx.product, ctx.store, %{position: 1})
      opening = Factory.create_image!(ctx.product, ctx.store, %{position: 0})

      {:ok, loaded} =
        Catalog.get_product_by_slug(ctx.store.id, ctx.product.slug, authorize?: false)

      # The gallery opens on Enum.at(images, 0); add_to_cart picks its thumbnail
      # with Enum.sort_by(& &1.position) |> List.first(). Those two must agree,
      # or the cart shows a different photo than the shopper was looking at.
      gallery_opens_on = Enum.at(loaded.images, 0)
      cart_would_use = loaded.images |> Enum.sort_by(& &1.position) |> List.first()

      assert gallery_opens_on.id == opening.id
      assert gallery_opens_on.id == cart_would_use.id
    end
  end
end
