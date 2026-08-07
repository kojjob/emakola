defmodule EmakolaWeb.SplitPayWebhookControllerTest do
  @moduledoc """
  Inbound SplitPay events: signature (t=..,v1=HMAC-SHA256 over "ts.body")
  verified against the configured signing secret; charge.succeeded
  confirms the order named by external_reference; everything valid is
  200-acknowledged.
  """
  use EmakolaWeb.ConnCase, async: false
  import Emakola.Factory

  require Ash.Query

  @secret "whsec_test_secret"

  setup do
    original = Application.get_env(:emakola, Emakola.SplitPay.Client)

    Application.put_env(:emakola, Emakola.SplitPay.Client, webhook_secret: @secret)

    on_exit(fn ->
      if original,
        do: Application.put_env(:emakola, Emakola.SplitPay.Client, original),
        else: Application.delete_env(:emakola, Emakola.SplitPay.Client)
    end)

    store = create_store!()
    product = create_product!(store, title: "SplitPay Hook")
    variant = create_variant!(product, store, price: 3_000, sku: "SPY-HOOK", stock_quantity: 5)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 1}],
        []
      )

    %{store: store, order: order}
  end

  defp deliver(conn, body, signature) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("splitpay-signature", signature)
    |> post("/webhooks/splitpay", body)
  end

  defp sign(body, timestamp) do
    mac =
      :crypto.mac(:hmac, :sha256, @secret, "#{timestamp}.#{body}")
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{mac}"
  end

  test "charge.succeeded with a valid signature confirms the order", %{
    conn: conn,
    store: store,
    order: order
  } do
    body =
      Jason.encode!(%{
        "type" => "charge.succeeded",
        "data" => %{"external_reference" => order.order_number, "charge_id" => "chg_1"}
      })

    assert deliver(conn, body, sign(body, 1_754_500_000)).status == 200

    confirmed =
      Emakola.Orders.Order
      |> Ash.Query.filter(id == ^order.id)
      |> Ash.read_one!(authorize?: false, tenant: store.id)

    assert confirmed.status == :confirmed
  end

  test "an invalid signature is a 401 and confirms nothing", %{
    conn: conn,
    store: store,
    order: order
  } do
    body =
      Jason.encode!(%{
        "type" => "charge.succeeded",
        "data" => %{"external_reference" => order.order_number}
      })

    assert deliver(conn, body, "t=1,v1=deadbeef").status == 401

    pending =
      Emakola.Orders.Order
      |> Ash.Query.filter(id == ^order.id)
      |> Ash.read_one!(authorize?: false, tenant: store.id)

    assert pending.status == :pending
  end

  test "unknown references and other event types are acknowledged no-ops", %{conn: conn} do
    for body <- [
          Jason.encode!(%{
            "type" => "charge.succeeded",
            "data" => %{"external_reference" => "ORD-nope"}
          }),
          Jason.encode!(%{"type" => "payout.paid", "data" => %{}})
        ] do
      assert deliver(conn, body, sign(body, 1_754_500_001)).status == 200
    end
  end
end
