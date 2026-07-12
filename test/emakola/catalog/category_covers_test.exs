defmodule Emakola.Catalog.CategoryCoversTest do
  @moduledoc """
  Category cover images — one representative photograph per category, so a
  storefront's category tiles are not empty boxes.

  The home page only ever loads a capped preview of products, so tiles that
  source their photo from that preview go empty for any category outside it.
  These covers are queried per store instead, and are strictly scoped: a
  category's cover always comes from a product really in that category.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  describe "category_covers/2" do
    test "returns one photograph per category, taken from a product in that category" do
      {_merchant, store} = create_merchant_with_store!()
      apparel = create_category!(store, %{name: "Apparel"})
      food = create_category!(store, %{name: "Food"})

      dress =
        create_product!(store, %{title: "Wrap Dress", status: :active, category_id: apparel.id})

      create_image!(dress, store, %{url: "/uploads/dress.jpg"})

      shito = create_product!(store, %{title: "Shito", status: :active, category_id: food.id})
      create_image!(shito, store, %{url: "/uploads/shito.jpg"})

      covers = Emakola.Catalog.category_covers(store.id, [apparel.id, food.id])

      assert covers[apparel.id] == "/uploads/dress.jpg"
      assert covers[food.id] == "/uploads/shito.jpg"
    end

    test "a category whose products have no photograph gets no cover, never a borrowed one" do
      # A Food tile wearing a photo of a dress is a lie the shopper acts on.
      {_merchant, store} = create_merchant_with_store!()
      apparel = create_category!(store, %{name: "Apparel"})
      food = create_category!(store, %{name: "Food"})

      dress =
        create_product!(store, %{title: "Wrap Dress", status: :active, category_id: apparel.id})

      create_image!(dress, store, %{url: "/uploads/dress.jpg"})

      create_product!(store, %{title: "Shito", status: :active, category_id: food.id})

      covers = Emakola.Catalog.category_covers(store.id, [apparel.id, food.id])

      assert covers[apparel.id] == "/uploads/dress.jpg"
      refute Map.has_key?(covers, food.id)
    end

    test "a draft product never lends its photograph to a category the shopper can browse" do
      {_merchant, store} = create_merchant_with_store!()
      apparel = create_category!(store, %{name: "Apparel"})

      draft =
        create_product!(store, %{title: "Unreleased", status: :draft, category_id: apparel.id})

      create_image!(draft, store, %{url: "/uploads/unreleased.jpg"})

      covers = Emakola.Catalog.category_covers(store.id, [apparel.id])

      refute Map.has_key?(covers, apparel.id)
    end

    test "covers never cross the tenant boundary" do
      {_merchant_a, store_a} = create_merchant_with_store!()
      {_merchant_b, store_b} = create_merchant_with_store!()

      cat_a = create_category!(store_a, %{name: "Apparel"})
      cat_b = create_category!(store_b, %{name: "Apparel"})

      product_b =
        create_product!(store_b, %{
          title: "Other Shop Dress",
          status: :active,
          category_id: cat_b.id
        })

      create_image!(product_b, store_b, %{url: "/uploads/other-shop.jpg"})

      covers = Emakola.Catalog.category_covers(store_a.id, [cat_a.id, cat_b.id])

      assert covers == %{}
    end

    test "no categories means no query and no covers" do
      {_merchant, store} = create_merchant_with_store!()

      assert Emakola.Catalog.category_covers(store.id, []) == %{}
    end
  end
end
