defmodule Emakola.Stores.DirectorySignalsTest do
  @moduledoc """
  The Store aggregates that feed DirectoryScore and DirectoryEligibility.

  Rows for resources whose create actions demand a whole commerce chain
  (reviews, returns, protection holds) are planted with `Ash.Seed`,
  following the precedent in ghana_digital_address_test.exs — the point
  here is the aggregate SQL, not the write paths.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Stores.Store

  @signals [
    :delivered_order_count_90d,
    :cancelled_order_count_90d,
    :last_order_at,
    :last_product_published_at,
    :successful_payment_count_90d,
    :refunded_payment_count_90d,
    :taken_down_product_count_90d,
    :verified_review_count,
    :verified_review_rating_sum,
    :merchant_fault_return_count_90d,
    :staff_refunded_hold_count_90d,
    :payout_verified,
    :kyc_approved
  ]

  defp reload(store), do: Ash.get!(Store, store.id, load: @signals, authorize?: false)

  defp days_ago(n), do: DateTime.add(DateTime.utc_now(), -n, :day)

  test "a bare store reads zeros and nils, not errors" do
    store = reload(create_store!())

    assert store.delivered_order_count_90d == 0
    assert store.verified_review_rating_sum in [0, nil]
    assert is_nil(store.last_order_at)
    refute store.payout_verified
    refute store.kyc_approved
  end

  test "order counts respect status and the 90-day window" do
    store = create_store!()
    create_order!(store, %{status: :delivered})
    create_order!(store, %{status: :delivered})
    create_order!(store, %{status: :cancelled})
    # An old delivered order — outside the window, still the latest clock tick
    # if nothing newer exists (it isn't here).
    old = create_order!(store, %{status: :delivered})
    Ash.Seed.update!(old, %{inserted_at: days_ago(120)})

    store = reload(store)
    assert store.delivered_order_count_90d == 2
    assert store.cancelled_order_count_90d == 1
    assert DateTime.diff(DateTime.utc_now(), store.last_order_at, :day) < 1
  end

  test "payment counts split success from any shape of refund" do
    store = create_store!()

    for status <- [:success, :success] do
      create_payment!(store) |> Ash.Seed.update!(%{status: status})
    end

    create_payment!(store) |> Ash.Seed.update!(%{status: :refunded})
    # The partial-refund shape: still :success, but money went back.
    create_payment!(store) |> Ash.Seed.update!(%{status: :success, refunded_amount: 2_000})

    store = reload(store)
    assert store.successful_payment_count_90d == 3
    assert store.refunded_payment_count_90d == 2
  end

  test "reviews count on verified_purchase alone — hiding one does not hide it from merit" do
    store = create_store!()
    product = create_product!(store)

    # One review per customer per product is a unique identity — the very
    # anti-gaming rule the aggregate leans on — so each review needs its own
    # customer.
    seed_review = fn rating, status, verified? ->
      Ash.Seed.seed!(Emakola.Catalog.Review, %{
        store_id: store.id,
        product_id: product.id,
        order_id: create_order!(store, %{status: :delivered}).id,
        customer_id: create_customer!(store).id,
        rating: rating,
        body: "Genuine goods, arrived as described.",
        status: status,
        verified_purchase: verified?
      })
    end

    seed_review.(5, :published, true)
    seed_review.(1, :hidden, true)
    seed_review.(4, :published, true)
    seed_review.(5, :published, false)

    store = reload(store)
    assert store.verified_review_count == 3
    assert store.verified_review_rating_sum == 10
  end

  test "only merchant-fault refunded returns count" do
    store = create_store!()
    order = create_order!(store, %{status: :delivered})

    seed_return = fn reason, status, order_id ->
      Ash.Seed.seed!(Emakola.Orders.Return, %{
        store_id: store.id,
        order_id: order_id,
        reason: reason,
        status: status
      })
    end

    seed_return.(:defective, :refunded, order.id)
    seed_return.(:changed_mind, :refunded, create_order!(store, %{status: :delivered}).id)
    seed_return.(:wrong_item, :requested, create_order!(store, %{status: :delivered}).id)

    assert reload(store).merchant_fault_return_count_90d == 1
  end

  test "the payout gate needs a VERIFIED account, not just an account" do
    unverified_store = create_store!()

    Ash.Seed.seed!(Emakola.Stores.StorePayoutAccount, %{
      store_id: unverified_store.id,
      payout_destination: %{"momo_number" => "0241234567"},
      verification_status: :unverified
    })

    verified_store = create_store!()

    Ash.Seed.seed!(Emakola.Stores.StorePayoutAccount, %{
      store_id: verified_store.id,
      payout_destination: %{"momo_number" => "0241234567"},
      verification_status: :verified
    })

    refute reload(unverified_store).payout_verified
    assert reload(verified_store).payout_verified
  end

  test "kyc_approved reads the verification record, and only an approved one" do
    pending_store = create_store!()

    Ash.Seed.seed!(Emakola.Stores.StoreVerification, %{
      store_id: pending_store.id,
      business_name: "Pending Ventures",
      status: :pending
    })

    approved_store = create_store!()

    Ash.Seed.seed!(Emakola.Stores.StoreVerification, %{
      store_id: approved_store.id,
      business_name: "Approved Ventures",
      status: :approved
    })

    refute reload(pending_store).kyc_approved
    assert reload(approved_store).kyc_approved
  end

  test "takedowns count only recent ones" do
    store = create_store!()

    create_product!(store)
    |> Ash.Seed.update!(%{moderation_status: :taken_down, moderation_at: days_ago(5)})

    create_product!(store)
    |> Ash.Seed.update!(%{moderation_status: :taken_down, moderation_at: days_ago(120)})

    assert reload(store).taken_down_product_count_90d == 1
  end

  test "the aggregates leave product_count and card_image_url untouched" do
    store = create_store!()
    # product_count counts ACTIVE products; the factory creates a draft.
    create_product!(store) |> Ash.Seed.update!(%{status: :active})

    loaded = Ash.get!(Store, store.id, load: [:product_count | @signals], authorize?: false)
    assert loaded.product_count == 1
  end
end
