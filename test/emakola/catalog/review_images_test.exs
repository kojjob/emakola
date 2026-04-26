defmodule Emakola.Catalog.ReviewImagesTest do
  @moduledoc """
  Pins the contract for Review.images (Phase 3):

    * Defaults to []
    * Accepts an array of image maps in :create
    * Empty list and missing key both result in []
  """
  use Emakola.DataCase, async: false

  alias Emakola.Catalog.Review
  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Reviews Shop", slug: "reviews-shop"})
    customer = Factory.create_customer!(store)
    product = Factory.create_product!(store, %{title: "Reviewed Item"})
    variant = Factory.create_variant!(product, store, %{price: 5_000, stock_quantity: 5})

    # Need a delivered order so the review verified-purchase eligibility check passes.
    {:ok, order} =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        customer_id: customer.id
      })
      |> Ash.create(authorize?: false)

    _line_item =
      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant.id,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

    {:ok, store: store, product: product, customer: customer, order: order}
  end

  describe "Review.create with images" do
    test "stores images verbatim", %{
      store: store,
      product: product,
      customer: customer,
      order: order
    } do
      images = [
        %{
          "url" => "https://e.x/r1.jpg",
          "thumbnail_url" => "https://e.x/r1-thumb.jpg",
          "alt" => "front"
        },
        %{
          "url" => "https://e.x/r2.jpg",
          "thumbnail_url" => "https://e.x/r2-thumb.jpg",
          "alt" => "back"
        }
      ]

      {:ok, review} =
        Review
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer.id,
          order_id: order.id,
          rating: 5,
          title: "Great",
          body: "Loved it",
          images: images
        })
        |> Ash.create(authorize?: false)

      assert length(review.images) == 2
      assert hd(review.images)["url"] == "https://e.x/r1.jpg"
    end

    test "defaults to [] when not supplied", %{
      store: store,
      product: product,
      customer: customer,
      order: order
    } do
      {:ok, review} =
        Review
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer.id,
          order_id: order.id,
          rating: 4,
          title: "OK",
          body: "Decent"
        })
        |> Ash.create(authorize?: false)

      assert review.images == []
    end
  end
end
