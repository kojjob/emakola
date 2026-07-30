defmodule Emakola.Orders.PayLinkClaimTest do
  use Emakola.DataCase, async: false

  alias Emakola.Orders.{PayLink, PayLinkClaim}

  defp custom_link_and_order(store) do
    link =
      PayLink
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        type: :custom,
        title: "Deal",
        amount: 25_000
      })
      |> Ash.create!(authorize?: false)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Deal", unit_price: 25_000},
        customer_name: "Ama",
        customer_phone: "0201234567",
        pay_link_id: link.id
      )

    {link, order}
  end

  test "first claim marks the link paid" do
    store = Emakola.Factory.create_store!()
    {link, order} = custom_link_and_order(store)

    assert :ok = PayLinkClaim.claim_for_order(order.id)

    assert Ash.get!(PayLink, link.id, authorize?: false, tenant: store.id).status == :paid
  end

  test "second claim flags the second order for refund attention" do
    store = Emakola.Factory.create_store!()
    {link, order1} = custom_link_and_order(store)

    {:ok, order2} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Deal", unit_price: 25_000},
        customer_name: "Kofi",
        customer_phone: "0209876543",
        pay_link_id: link.id
      )

    assert :ok = PayLinkClaim.claim_for_order(order1.id)
    assert :ok = PayLinkClaim.claim_for_order(order2.id)

    reloaded = Ash.get!(Emakola.Orders.Order, order2.id, authorize?: false, tenant: store.id)
    assert reloaded.notes =~ "already used"
  end

  test "orders without a pay link are a no-op" do
    store = Emakola.Factory.create_store!()

    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{store_id: store.id})
      |> Ash.create!(authorize?: false)

    assert :ok = PayLinkClaim.claim_for_order(order.id)
  end
end
