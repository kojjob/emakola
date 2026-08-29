defmodule Emakola.SplitPay.ClientIntegrationTest do
  @moduledoc """
  Makola as a SplitPay tenant (ship-dark): the client is disabled until
  both base URL and API key are configured; Checkout.initiate builds the
  own-stock split plan (merchant net + platform remainder) and returns
  the provider checkout URL.
  """
  use Emakola.DataCase, async: false
  import Emakola.Factory

  alias Emakola.SplitPay.Checkout
  alias Emakola.SplitPay.Client

  setup do
    original = Application.get_env(:emakola, Emakola.SplitPay.Client)

    on_exit(fn ->
      if original,
        do: Application.put_env(:emakola, Emakola.SplitPay.Client, original),
        else: Application.delete_env(:emakola, Emakola.SplitPay.Client)
    end)

    :ok
  end

  defp enable_client! do
    Application.put_env(:emakola, Emakola.SplitPay.Client,
      base_url: "https://splitpay.test",
      api_key: "sk_sandbox_test",
      req_options: [plug: {Req.Test, __MODULE__}]
    )
  end

  test "disabled unless base_url and api_key are both configured" do
    Application.delete_env(:emakola, Emakola.SplitPay.Client)
    refute Client.enabled?()

    Application.put_env(:emakola, Emakola.SplitPay.Client, base_url: "https://splitpay.test")
    refute Client.enabled?()

    enable_client!()
    assert Client.enabled?()
  end

  test "Checkout.initiate sends the own-stock plan and returns the checkout URL" do
    enable_client!()

    store = create_store!()
    product = create_product!(store, title: "SplitPay Own-Stock")
    variant = create_variant!(product, store, price: 5_000, sku: "SPY-OWN", stock_quantity: 5)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 2}],
        []
      )

    Req.Test.stub(__MODULE__, fn conn ->
      assert ["Bearer sk_sandbox_test"] = Plug.Conn.get_req_header(conn, "authorization")

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      assert decoded["amount"] == order.total
      assert decoded["currency"] == "GHS"
      assert decoded["provider"] == "paystack"
      assert decoded["external_reference"] == order.order_number

      fee = Emakola.Payments.PlatformFee.calculate(order.total, 200).fee

      assert [
               %{"recipient_ref" => "platform", "remainder" => true},
               %{"recipient_ref" => merchant_ref, "amount" => net}
             ] = Enum.sort_by(decoded["allocations"], & &1["recipient_ref"])

      assert merchant_ref == "store_#{store.id}"
      assert net == order.total - fee

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        201,
        Jason.encode!(%{
          "id" => "chg_1",
          "status" => "pending",
          "checkout_url" => "https://pay.test/SP-chg_1"
        })
      )
    end)

    assert {:ok, %{checkout_url: "https://pay.test/SP-chg_1"}} =
             Checkout.initiate(order, store)
  end

  test "a SplitPay error surfaces as an error tuple" do
    enable_client!()

    store = create_store!()
    product = create_product!(store, title: "SplitPay Err")
    variant = create_variant!(product, store, price: 2_000, sku: "SPY-ERR", stock_quantity: 5)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 1}],
        []
      )

    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(422, Jason.encode!(%{"error" => %{"code" => "remainder_required"}}))
    end)

    assert {:error, {:splitpay_error, 422, _body}} = Checkout.initiate(order, store)
  end
end
