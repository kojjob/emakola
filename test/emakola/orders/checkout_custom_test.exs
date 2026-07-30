defmodule Emakola.Orders.CheckoutCustomTest do
  use Emakola.DataCase, async: true

  require Ash.Query

  alias Emakola.Orders.CheckoutService

  test "creates a paid-pending order with one variant-less line and correct total" do
    store = Emakola.Factory.create_store!()

    assert {:ok, order} =
             CheckoutService.checkout_custom!(
               store.id,
               %{title: "Custom kente dress", unit_price: 25_000},
               customer_name: "Ama Mensah",
               customer_phone: "+233201234567",
               pay_link_id: Ash.UUID.generate()
             )

    assert order.total == 25_000
    assert order.pay_link_id

    [line] =
      Emakola.Orders.LineItem
      |> Ash.Query.filter(order_id == ^order.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert line.variant_id == nil
    assert line.product_title == "Custom kente dress"
  end

  test "same phone twice resolves to the same customer" do
    store = Emakola.Factory.create_store!()
    opts = [customer_name: "Ama", customer_phone: "0201234567"]

    {:ok, o1} = CheckoutService.checkout_custom!(store.id, %{title: "A", unit_price: 500}, opts)
    {:ok, o2} = CheckoutService.checkout_custom!(store.id, %{title: "B", unit_price: 700}, opts)

    assert o1.customer_id == o2.customer_id
  end

  test "explicit email wins over the placeholder" do
    store = Emakola.Factory.create_store!()

    {:ok, order} =
      CheckoutService.checkout_custom!(
        store.id,
        %{title: "A", unit_price: 500},
        customer_name: "Ama",
        customer_phone: "0201234567",
        customer_email: "ama@example.com"
      )

    customer =
      Ash.get!(Emakola.Customers.Customer, order.customer_id, authorize?: false, tenant: store.id)

    assert to_string(customer.email) == "ama@example.com"
  end

  test "rejects unit_price below 1" do
    store = Emakola.Factory.create_store!()

    assert {:error, _} =
             CheckoutService.checkout_custom!(
               store.id,
               %{title: "A", unit_price: 0},
               customer_name: "Ama",
               customer_phone: "0201234567"
             )
  end
end
