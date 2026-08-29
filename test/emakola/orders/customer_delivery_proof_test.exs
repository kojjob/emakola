defmodule Emakola.Orders.CustomerDeliveryProofTest do
  @moduledoc """
  Proof of delivery on the leg where the fraud actually happens.

  `FulfillmentDeliveryProof` — a short-lived, attempt-capped OTP the buyer
  reads to the courier — already existed, but its only caller was
  `Suppliers.InboundFulfillment`, the wholesaler-to-merchant leg. On a customer
  order the merchant simply marked the order delivered themselves, which
  stamped `release_after` and let `:auto_timer` pay them out. Self-attested
  delivery with no counterparty is the hole this closes: the OTP is the only
  mechanism in the system that requires a second party to assent.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Mox
  require Ash.Query

  setup :verify_on_exit!

  alias Emakola.Orders.CustomerDelivery
  alias Emakola.Orders.Fulfillment

  # NEVER Application.put_env here: :sms_provider is global, config/test.exs
  # already points it at the Mox mock, and an unrestored override leaks into
  # every test that runs after this file.
  setup do
    stub(Emakola.SMSProviderMock, :send_sms, fn _phone, _message, _opts -> {:ok, %{}} end)
    :ok
  end

  defp shipped_fulfillment! do
    store = create_store!()
    product = create_product!(store)
    variant = create_variant!(product, store, price: 20_000, sku: "CDP-1", stock_quantity: 5)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 1}],
        shipping_address: %{"phone" => "+233240000001", "name" => "Ama"}
      )

    fulfillment =
      Fulfillment
      |> Ash.Query.filter(order_id == ^order.id)
      |> Ash.read!(authorize?: false)
      |> List.first()

    fulfillment =
      fulfillment
      |> Ash.Changeset.for_update(:mark_notified, %{notified_via: :sms})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:mark_shipped, %{tracking_number: "TRK-1"})
      |> Ash.update!(authorize?: false)

    %{store: store, order: order, fulfillment: fulfillment}
  end

  describe "request_delivery_code/2" do
    test "issues a code for the merchant's own customer fulfilment" do
      ctx = shipped_fulfillment!()

      assert {:ok, proof} =
               CustomerDelivery.request_delivery_code(ctx.store.id, ctx.fulfillment.id)

      assert proof.fulfillment_id == ctx.fulfillment.id
      assert is_binary(proof.code_hash)
      refute proof.verified_at
      # The stored recipient is masked — the raw phone is never persisted here.
      assert proof.sent_to =~ "•"
    end

    test "refuses a fulfilment that has not shipped" do
      store = create_store!()
      product = create_product!(store)
      variant = create_variant!(product, store, price: 20_000, sku: "CDP-2", stock_quantity: 5)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          store.id,
          [%{variant_id: variant.id, quantity: 1}],
          shipping_address: %{"phone" => "+233240000002"}
        )

      pending =
        Fulfillment
        |> Ash.Query.filter(order_id == ^order.id)
        |> Ash.read!(authorize?: false)
        |> List.first()

      assert {:error, :fulfillment_not_shipped} =
               CustomerDelivery.request_delivery_code(store.id, pending.id)
    end

    # Tenant isolation: another store must never be able to issue a code
    # against this store's fulfilment.
    test "refuses a fulfilment belonging to another store" do
      ctx = shipped_fulfillment!()
      other = create_store!()

      assert {:error, :not_found} =
               CustomerDelivery.request_delivery_code(other.id, ctx.fulfillment.id)
    end
  end

  describe "verify_delivery/3" do
    test "a wrong code is refused and records an attempt" do
      ctx = shipped_fulfillment!()
      {:ok, _proof} = CustomerDelivery.request_delivery_code(ctx.store.id, ctx.fulfillment.id)

      assert {:error, :invalid_code} =
               CustomerDelivery.verify_delivery(ctx.store.id, ctx.fulfillment.id, "000000")

      proof =
        Ash.get!(Emakola.Orders.FulfillmentDeliveryProof, [fulfillment_id: ctx.fulfillment.id],
          authorize?: false
        )

      assert proof.attempts == 1
      refute proof.verified_at
    end

    test "verifying without a code ever being requested is refused" do
      ctx = shipped_fulfillment!()

      assert {:error, :delivery_code_not_requested} =
               CustomerDelivery.verify_delivery(ctx.store.id, ctx.fulfillment.id, "123456")
    end

    # The whole point: the fulfilment only reaches :delivered when a second
    # party proved receipt.
    test "the right code marks the fulfilment delivered" do
      ctx = shipped_fulfillment!()

      {:ok, code} =
        CustomerDelivery.request_delivery_code(ctx.store.id, ctx.fulfillment.id,
          return_code: true
        )

      assert {:ok, delivered} =
               CustomerDelivery.verify_delivery(ctx.store.id, ctx.fulfillment.id, code)

      assert delivered.status == :delivered
    end
  end
end
