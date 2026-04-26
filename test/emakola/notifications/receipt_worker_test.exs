defmodule Emakola.Notifications.ReceiptWorkerTest do
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Mox

  alias Emakola.Notifications.Workers.OrderNotificationWorker

  setup :verify_on_exit!

  setup do
    {_merchant, store} = create_merchant_with_store!()
    customer = create_customer!(store, %{phone: "+233244123456", email: "receipt@example.com"})
    product = create_product!(store, status: :active)
    variant = create_variant!(product, store, price: 5000, stock_quantity: 20)

    order =
      create_order!(store, %{
        customer_id: customer.id,
        total: 5000,
        subtotal: 5000,
        status: :confirmed
      })

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!(authorize?: false)

    # Stub SMS and WhatsApp providers
    Emakola.SMSProviderMock
    |> stub(:send_sms, fn _to, _message, _opts -> {:ok, %{message_id: "test"}} end)

    Emakola.WhatsAppProviderMock
    |> stub(:send_message, fn _to, _template, _params, _opts ->
      {:ok, %{message_id: "test"}}
    end)

    %{store: store, order: order, customer: customer}
  end

  describe "order_confirmed notification with line items" do
    test "processes without error and loads line items", %{order: order} do
      assert :ok ==
               OrderNotificationWorker.perform(%Oban.Job{
                 args: %{"order_id" => order.id, "event" => "order_confirmed"}
               })
    end
  end
end
