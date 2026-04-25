defmodule Emakola.Catalog.ReviewTest do
  use Emakola.DataCase, async: false

  alias Emakola.Catalog.Review
  alias Emakola.Factory

  setup do
    {_merchant, store} = Factory.create_merchant_with_store!()
    customer = Factory.create_customer!(store)
    product = Factory.create_product!(store, status: :active)
    variant = Factory.create_variant!(product, store, price: 5000, stock_quantity: 20)

    order =
      Factory.create_order!(store, %{
        customer_id: customer.id,
        total: 5000,
        subtotal: 5000,
        status: :delivered
      })

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!(authorize?: false)

    %{store: store, customer: customer, product: product, variant: variant, order: order}
  end

  describe "create" do
    test "creates a review with valid data", %{
      store: store,
      customer: customer,
      product: product,
      order: order
    } do
      assert {:ok, review} =
               Review
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 product_id: product.id,
                 customer_id: customer.id,
                 order_id: order.id,
                 rating: 5,
                 title: "Great product",
                 body: "This product exceeded my expectations."
               })
               |> Ash.create(authorize?: false)

      assert review.rating == 5
      assert review.title == "Great product"
      assert review.body == "This product exceeded my expectations."
      assert review.status == :published
      assert review.verified_purchase == true
    end

    test "rejects rating of 0", %{
      store: store,
      customer: customer,
      product: product,
      order: order
    } do
      assert {:error, _} =
               Review
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 product_id: product.id,
                 customer_id: customer.id,
                 order_id: order.id,
                 rating: 0,
                 body: "Bad rating value."
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects rating of 6", %{
      store: store,
      customer: customer,
      product: product,
      order: order
    } do
      assert {:error, _} =
               Review
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 product_id: product.id,
                 customer_id: customer.id,
                 order_id: order.id,
                 rating: 6,
                 body: "Too high rating."
               })
               |> Ash.create(authorize?: false)
    end

    test "body is required", %{
      store: store,
      customer: customer,
      product: product,
      order: order
    } do
      assert {:error, _} =
               Review
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 product_id: product.id,
                 customer_id: customer.id,
                 order_id: order.id,
                 rating: 4
               })
               |> Ash.create(authorize?: false)
    end

    test "prevents duplicate review for same customer and product", %{
      store: store,
      customer: customer,
      product: product,
      order: order
    } do
      Review
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        product_id: product.id,
        customer_id: customer.id,
        order_id: order.id,
        rating: 4,
        body: "First review."
      })
      |> Ash.create!(authorize?: false)

      assert {:error, _} =
               Review
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 product_id: product.id,
                 customer_id: customer.id,
                 order_id: order.id,
                 rating: 3,
                 body: "Duplicate review."
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "hide/unhide" do
    test "hides and unhides a review", %{
      store: store,
      customer: customer,
      product: product,
      order: order
    } do
      review =
        Review
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer.id,
          order_id: order.id,
          rating: 3,
          body: "Average product."
        })
        |> Ash.create!(authorize?: false)

      assert review.status == :published

      hidden =
        review
        |> Ash.Changeset.for_update(:hide)
        |> Ash.update!(authorize?: false)

      assert hidden.status == :hidden

      unhidden =
        hidden
        |> Ash.Changeset.for_update(:unhide)
        |> Ash.update!(authorize?: false)

      assert unhidden.status == :published
    end
  end

  describe "eligible?/3" do
    test "returns {:ok, order_id} when customer has delivered order with product", %{
      store: store,
      customer: customer,
      product: product,
      order: order
    } do
      assert {:ok, order_id} = Review.eligible?(store.id, product.id, customer.id)
      assert order_id == order.id
    end

    test "returns {:error, :not_eligible} when no delivered order", %{
      store: store,
      product: product
    } do
      other_customer = Factory.create_customer!(store)
      assert {:error, :not_eligible} = Review.eligible?(store.id, product.id, other_customer.id)
    end

    test "returns {:error, :already_reviewed} when already reviewed", %{
      store: store,
      customer: customer,
      product: product,
      order: order
    } do
      Review
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        product_id: product.id,
        customer_id: customer.id,
        order_id: order.id,
        rating: 5,
        body: "Already reviewed."
      })
      |> Ash.create!(authorize?: false)

      assert {:error, :already_reviewed} =
               Review.eligible?(store.id, product.id, customer.id)
    end
  end

  describe "product aggregates" do
    test "avg_rating and review_count reflect published reviews", %{
      store: store,
      product: product,
      order: order
    } do
      customer1 = Factory.create_customer!(store)
      customer2 = Factory.create_customer!(store)

      Review
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        product_id: product.id,
        customer_id: customer1.id,
        order_id: order.id,
        rating: 4,
        body: "Good product."
      })
      |> Ash.create!(authorize?: false)

      review2 =
        Review
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer2.id,
          order_id: order.id,
          rating: 2,
          body: "Not great."
        })
        |> Ash.create!(authorize?: false)

      product_loaded =
        Ash.get!(Emakola.Catalog.Product, product.id, load: [:review_count, :avg_rating])

      assert product_loaded.review_count == 2
      assert_in_delta product_loaded.avg_rating, 3.0, 0.01

      # Hide one review and check aggregates update
      review2
      |> Ash.Changeset.for_update(:hide)
      |> Ash.update!(authorize?: false)

      product_reloaded =
        Ash.get!(Emakola.Catalog.Product, product.id, load: [:review_count, :avg_rating])

      assert product_reloaded.review_count == 1
      assert_in_delta product_reloaded.avg_rating, 4.0, 0.01
    end
  end
end
