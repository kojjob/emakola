defmodule EmakolaWeb.Admin.StoredCountsTest do
  @moduledoc """
  Wishlist items, saved shops, ratings, newsletter emails and delivery stamps
  were all captured and none reached the merchant.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  test "products say how many people want them", ctx do
    product = Factory.create_product!(ctx.store, title: "Shea Butter")
    c1 = Factory.create_customer!(ctx.store)
    c2 = Factory.create_customer!(ctx.store)

    for c <- [c1, c2] do
      Emakola.Customers.add_to_wishlist(
        %{customer_id: c.id, product_id: product.id, store_id: ctx.store.id},
        authorize?: false
      )
    end

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/products")

    assert has_element?(view, "#want-#{product.id}", "2 people want this")
  end

  # Production gate, defence in depth: `Emakola.Customers.Validations.ProductInStore`
  # now refuses to *write* a wishlist row for another store's product (see
  # test/emakola/customers/wishlist_item_test.exs), so the aggregate can no
  # longer be exercised through the public `:add` action. A row mistagged
  # before that validation existed (or written some other way) must still
  # not inflate this store's count — planted directly with `Ash.Seed`,
  # bypassing the action entirely, the way such a legacy row would look.
  test "a wishlist row mistagged with another store's id does not inflate the count", ctx do
    product = Factory.create_product!(ctx.store, title: "Shea Butter")
    customer = Factory.create_customer!(ctx.store)

    Emakola.Customers.add_to_wishlist(
      %{customer_id: customer.id, product_id: product.id, store_id: ctx.store.id},
      authorize?: false
    )

    {_other_merchant, other_store} = Factory.create_merchant_with_store!()
    other_customer = Factory.create_customer!(other_store)
    other_product = Factory.create_product!(other_store)

    {:ok, mistagged} =
      Emakola.Customers.add_to_wishlist(
        %{customer_id: other_customer.id, product_id: other_product.id, store_id: other_store.id},
        authorize?: false
      )

    Ash.Seed.update!(mistagged, %{product_id: product.id})

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/products")

    assert has_element?(view, "#want-#{product.id}", "1 person want this")
  end

  test "the dashboard says how many people saved the shop and how fast it delivers", ctx do
    c1 = Factory.create_customer!(ctx.store)

    Emakola.Customers.favorite_store(%{customer_id: c1.id, store_id: ctx.store.id},
      authorize?: false
    )

    order = Factory.create_order!(ctx.store, %{subtotal: 100, total: 100, status: :shipped})

    order
    |> Ash.Changeset.for_update(:mark_delivered, %{})
    |> Ash.update!(authorize?: false)

    {:ok, view, _html} = live(ctx.conn, ~p"/dashboard")
    render_async(view)

    assert has_element?(view, "#saved-shop", "1")
    assert has_element?(view, "#days-to-deliver")
  end

  test "reviews show the average and the count", ctx do
    product = Factory.create_product!(ctx.store)
    customer = Factory.create_customer!(ctx.store)

    for rating <- [5, 3] do
      order =
        Factory.create_order!(ctx.store, %{
          subtotal: 100,
          total: 100,
          status: :delivered,
          customer_id: customer.id
        })

      c = Factory.create_customer!(ctx.store)

      Emakola.Catalog.Review
      |> Ash.Changeset.for_create(:create, %{
        store_id: ctx.store.id,
        product_id: product.id,
        customer_id: c.id,
        order_id: order.id,
        rating: rating,
        body: "ok"
      })
      |> Ash.create!(authorize?: false)
    end

    _ = customer

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/reviews")

    assert has_element?(view, "#reviews-rating", "4.0")
    assert has_element?(view, "#reviews-rating", "2 reviews")
  end

  test "newsletter emails are counted and exportable", ctx do
    Emakola.Customers.subscribe_to_newsletter(
      %{store_id: ctx.store.id, email: "fan@example.com"},
      authorize?: false
    )

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

    assert has_element?(view, "#newsletter-count", "1")
    assert has_element?(view, ~s{a[href="/admin/export/newsletter.csv"]})
  end

  test "a campaign lists the numbers that did not get it", ctx do
    {:ok, campaign} =
      Emakola.Marketing.Campaigns.create(ctx.merchant, ctx.store.id, %{
        name: "Sale",
        channel: :sms,
        body: "Sale on."
      })

    customer = Factory.create_customer!(ctx.store, %{phone: "+233201111111"})

    {:ok, recipient} =
      Emakola.Marketing.CampaignRecipient
      |> Ash.Changeset.for_create(:claim, %{
        campaign_id: campaign.id,
        customer_id: customer.id,
        phone: customer.phone
      })
      |> Ash.create(authorize?: false)

    recipient
    |> Ash.Changeset.for_update(:mark_failed, %{error: "Number not on network"})
    |> Ash.update!(authorize?: false)

    campaign
    |> Ash.Changeset.for_update(:record_result, %{sent_count: 0, failed_count: 1})
    |> Ash.update!(authorize?: false)

    {:ok, view, html} = live(ctx.conn, ~p"/admin/campaigns")

    assert has_element?(view, "#campaign-#{campaign.id}-failed", "+233201111111")
    assert has_element?(view, "#campaign-#{campaign.id}-failed", "Not delivered")
    # The gateway's own error text is platform detail (account ids, balance
    # messages) — it is stored but never shown to the merchant.
    refute html =~ "Number not on network"
  end
end
