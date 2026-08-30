defmodule Emakola.Platform.StoreCaseFileTest do
  @moduledoc """
  The store case-file rollup behind the platform store detail page: orders,
  GMV (successful payments only), protection holds, refunds, per-store
  onboarding milestones, verification status, recent orders, and product
  photo URLs.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Platform.StoreCaseFile

  test "an untouched store reports zeros and no milestones beyond live" do
    store = create_store!(%{name: "Blank Slate"})

    case_file = StoreCaseFile.load(store)

    assert case_file.orders_count == 0
    assert case_file.gmv == 0
    assert case_file.holds_count == 0
    assert case_file.refunds_count == 0
    assert case_file.verification_status == nil
    assert case_file.recent_orders == []
    assert case_file.product_photo_urls == []
    assert case_file.milestones.products == false
    assert case_file.milestones.live == true
    assert case_file.completed == 1
  end

  test "rolls up orders, settled GMV, refunds, and recent orders" do
    store = create_store!(%{name: "Busy Stall"})
    order = create_order!(store, %{total: 45_000})
    _second_order = create_order!(store, %{total: 20_000})

    _settled =
      store
      |> create_payment!(%{order_id: order.id, amount: 45_000})
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

    _refunded =
      store
      |> create_payment!(%{amount: 20_000})
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 20_000})
      |> Ash.update!(authorize?: false)

    case_file = StoreCaseFile.load(store)

    assert case_file.orders_count == 2
    # Both payments reached :success before one was refunded — GMV counts
    # money that settled; the refund shows up in refunds_count, not as a
    # GMV subtraction.
    assert case_file.gmv == 65_000
    assert case_file.refunds_count == 1
    assert case_file.milestones.first_order == true
    assert length(case_file.recent_orders) == 2
    assert hd(case_file.recent_orders).total == 20_000
  end

  test "counts open protection holds for this store only" do
    store = create_store!(%{name: "Held Stall"})
    other_store = create_store!(%{name: "Other Stall"})

    for held_store <- [store, other_store] do
      held_order = create_order!(held_store, %{total: 10_000})

      payment =
        held_store
        |> create_payment!(%{
          order_id: held_order.id,
          amount: 10_000,
          payout_held: true,
          payout_hold_reason: "buyer_protection"
        })
        |> Ash.Changeset.for_update(:mark_success, %{})
        |> Ash.update!(authorize?: false)

      :ok = Emakola.Payments.ProtectionHolds.ensure_hold(payment)
    end

    assert StoreCaseFile.load(store).holds_count == 1
  end

  test "surfaces the latest verification status and product photos" do
    store = create_store!(%{name: "Verified Stall"})
    product = create_product!(store, %{title: "Kente Stole", status: :active})
    create_image!(product, store, %{url: "https://s3.example.com/kente/stole-photo.jpg"})

    {:ok, _verification} =
      Emakola.Stores.submit_store_verification(
        %{
          store_id: store.id,
          business_name: "Verified Stall Ltd",
          id_type: :ghana_card,
          id_number: "GHA-123",
          id_document_key: "docs/ghana-card.jpg"
        },
        authorize?: false
      )

    case_file = StoreCaseFile.load(store)

    assert case_file.verification_status == :pending
    assert "https://s3.example.com/kente/stole-photo.jpg" in case_file.product_photo_urls
  end
end
