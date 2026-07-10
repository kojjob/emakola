defmodule Emakola.Suppliers.InboundFulfillmentTest do
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Mox

  alias Emakola.Suppliers.InboundFulfillment

  setup :verify_on_exit!

  setup do
    {wholesaler_actor, wholesaler} = create_merchant_with_store!(%{name: "Inbound supplier"})
    {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Selling store"})
    customer = create_customer!(reseller, phone: "+233501234567")

    order =
      Emakola.Orders.create_order!(
        %{
          store_id: reseller.id,
          customer_id: customer.id,
          shipping_address: %{"phone" => customer.phone, "city" => "Accra"}
        },
        authorize?: false
      )

    supplier = create_supplier!(reseller, linked_store_id: wholesaler.id)
    fulfillment = create_fulfillment!(order, reseller, supplier_id: supplier.id)

    %{
      wholesaler_actor: wholesaler_actor,
      wholesaler: wholesaler,
      reseller_actor: reseller_actor,
      reseller: reseller,
      order: order,
      fulfillment: fulfillment
    }
  end

  test "wholesaler sees linked fulfillments across the reseller tenant", context do
    assert {:ok, [fulfillment]} =
             InboundFulfillment.list(context.wholesaler_actor, context.wholesaler.id)

    assert fulfillment.id == context.fulfillment.id
    assert fulfillment.order.id == context.order.id
    assert fulfillment.store_id == context.reseller.id
  end

  test "unrelated merchants cannot read or mutate inbound fulfillments", context do
    {outsider, outsider_store} = create_merchant_with_store!()

    assert {:error, :forbidden} =
             InboundFulfillment.list(outsider, context.wholesaler.id)

    assert {:error, :not_found} =
             InboundFulfillment.get(outsider, outsider_store.id, context.fulfillment.id)
  end

  test "supplier ships and completes delivery using the customer OTP", context do
    assert {:ok, shipped} =
             InboundFulfillment.mark_shipped(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id,
               "GH-TRACK-44"
             )

    assert shipped.status == :shipped

    parent = self()

    expect(Emakola.SMSProviderMock, :send_sms, fn phone, message, opts ->
      assert phone == "+233501234567"
      assert opts[:store_id] == context.reseller.id
      [code] = Regex.run(~r/delivery code is (\d{6})/, message, capture: :all_but_first)
      send(parent, {:delivery_code, code})
      {:ok, %{id: "sms-1"}}
    end)

    assert {:ok, proof} =
             InboundFulfillment.request_delivery_code(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id
             )

    assert String.ends_with?(proof.sent_to, "4567")
    refute proof.sent_to == "+233501234567"
    assert_receive {:delivery_code, code}

    assert {:error, :invalid_code} =
             InboundFulfillment.verify_delivery(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id,
               "000000"
             )

    attempted = Ash.get!(Emakola.Orders.FulfillmentDeliveryProof, proof.id, authorize?: false)
    assert attempted.attempts == 1

    assert {:ok, delivered} =
             InboundFulfillment.verify_delivery(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id,
               code
             )

    assert delivered.status == :delivered

    verified = Ash.get!(Emakola.Orders.FulfillmentDeliveryProof, proof.id, authorize?: false)
    assert %DateTime{} = verified.verified_at
  end

  test "delivery code cannot be requested before shipment", context do
    assert {:error, :fulfillment_not_shipped} =
             InboundFulfillment.request_delivery_code(
               context.wholesaler_actor,
               context.wholesaler.id,
               context.fulfillment.id
             )
  end
end
