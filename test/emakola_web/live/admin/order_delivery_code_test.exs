defmodule EmakolaWeb.Admin.OrderDeliveryCodeTest do
  @moduledoc """
  The delivery OTP has to be reachable from the customer order page, or the
  anti-fraud mechanism is code nobody can run — the same defect as the admin
  digital-files page and the customer downloads page before them.

  Marking an order delivered is a merchant asserting something about
  themselves. The OTP is the only path that requires the buyer to assent.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox
  require Ash.Query

  setup :verify_on_exit!

  setup %{conn: conn} do
    {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)

    stub(Emakola.SMSProviderMock, :send_sms, fn _phone, _msg, _opts -> {:ok, %{}} end)

    {:ok, conn: conn, store: store, merchant: merchant}
  end

  defp shipped_order!(store) do
    product = Emakola.Factory.create_product!(store)

    variant =
      Emakola.Factory.create_variant!(product, store,
        price: 20_000,
        sku: "ODC-#{System.unique_integer([:positive])}",
        stock_quantity: 5
      )

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 1}],
        shipping_address: %{"phone" => "+233240000009", "name" => "Ama"}
      )

    fulfillment =
      Emakola.Orders.Fulfillment
      |> Ash.Query.filter(order_id == ^order.id)
      |> Ash.read!(authorize?: false)
      |> List.first()
      |> Ash.Changeset.for_update(:mark_notified, %{notified_via: :sms})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:mark_shipped, %{tracking_number: "TRK-ODC"})
      |> Ash.update!(authorize?: false)

    %{order: order, fulfillment: fulfillment}
  end

  test "a shipped fulfilment offers a delivery code", %{conn: conn, store: store} do
    ctx = shipped_order!(store)

    {:ok, _view, html} = live(conn, ~p"/admin/orders/#{ctx.order.id}")

    assert html =~ "Send delivery code"
  end

  test "sending a code issues a proof the buyer must confirm", %{conn: conn, store: store} do
    ctx = shipped_order!(store)

    {:ok, view, _html} = live(conn, ~p"/admin/orders/#{ctx.order.id}")

    render_click(view, "request_delivery_code", %{"id" => ctx.fulfillment.id})

    proof =
      Emakola.Orders.FulfillmentDeliveryProof
      |> Ash.Query.filter(fulfillment_id == ^ctx.fulfillment.id)
      |> Ash.read_one!(authorize?: false)

    refute is_nil(proof)
    refute proof.verified_at
  end

  test "a wrong code does not mark the fulfilment delivered", %{conn: conn, store: store} do
    ctx = shipped_order!(store)

    {:ok, view, _html} = live(conn, ~p"/admin/orders/#{ctx.order.id}")
    render_click(view, "request_delivery_code", %{"id" => ctx.fulfillment.id})

    render_submit(view, "submit_delivery_code", %{
      "id" => ctx.fulfillment.id,
      "code" => "000000"
    })

    reloaded = Ash.get!(Emakola.Orders.Fulfillment, ctx.fulfillment.id, authorize?: false)
    assert reloaded.status == :shipped
  end
end
