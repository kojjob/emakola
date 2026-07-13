defmodule Emakola.Catalog.StoreTestimonialsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Catalog

  # A Review REQUIRES an order_id: the resource only lets someone who actually
  # bought the thing say something about it. That is the honesty property this
  # whole change leans on, and it is enforced in the domain, not the theme.
  defp create_review!(store, product, customer, attrs) do
    order = create_order!(store)

    Emakola.Catalog.Review
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer.id,
          order_id: order.id,
          rating: 5,
          body: "A real review."
        },
        attrs
      )
    )
    |> Ash.create!(authorize?: false)
  end

  describe "store_testimonials/2" do
    test "a store with no reviews has no testimonials — nothing is invented" do
      {_merchant, store} = create_merchant_with_store!()

      assert Catalog.store_testimonials(store.id) == []
    end

    test "returns the store's own published reviews, with the reviewer loaded" do
      {_merchant, store} = create_merchant_with_store!()
      product = create_product!(store, %{status: :active})
      customer = create_customer!(store, %{name: "Akosua Mensah"})

      create_review!(store, product, customer, %{rating: 4, body: "Arrived quickly, well made."})

      assert [review] = Catalog.store_testimonials(store.id)
      assert review.body == "Arrived quickly, well made."
      assert review.rating == 4
      assert review.customer.name == "Akosua Mensah"
    end

    test "a hidden review is not a testimonial" do
      {_merchant, store} = create_merchant_with_store!()
      product = create_product!(store, %{status: :active})
      customer = create_customer!(store, %{name: "Kwesi"})

      review = create_review!(store, product, customer, %{body: "Hidden by the merchant."})

      review
      |> Ash.Changeset.for_update(:hide, %{})
      |> Ash.update!(authorize?: false)

      assert Catalog.store_testimonials(store.id) == []
    end

    # The tenancy rule that matters most: one shop must never wear another
    # shop's praise.
    test "a review never crosses a store boundary" do
      {_m1, store} = create_merchant_with_store!()
      {_m2, other_store} = create_merchant_with_store!()

      other_product = create_product!(other_store, %{status: :active})
      other_customer = create_customer!(other_store, %{name: "Someone Else"})

      create_review!(other_store, other_product, other_customer, %{
        body: "Praise belonging to another shop."
      })

      assert Catalog.store_testimonials(store.id) == []
    end

    # One review per customer per product — the resource enforces it, so five
    # reviews means five different products.
    test "honours the limit" do
      {_merchant, store} = create_merchant_with_store!()
      customer = create_customer!(store, %{name: "Adjoa"})

      for n <- 1..5 do
        product = create_product!(store, %{status: :active})
        create_review!(store, product, customer, %{body: "Review #{n}."})
      end

      assert length(Catalog.store_testimonials(store.id, 3)) == 3
    end
  end
end
