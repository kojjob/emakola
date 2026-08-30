defmodule Emakola.Notifications.WhatsAppFirstTest do
  @moduledoc """
  One paid message per notification, not two.

  Order events used to send WhatsApp AND SMS to every buyer with a phone —
  the merchant paid twice to say one thing. WhatsApp is tried first because
  it is cheaper (often free to the recipient); SMS runs only when WhatsApp
  actually fails, which it reports as `{:error, _}`.

  The precedent is `Accounts.PhoneAuth`, which has always done this for login
  codes — where a failed delivery means a merchant locked out of their shop.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Mox

  alias Emakola.Notifications.Workers.OrderNotificationWorker

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    {_merchant, store} = create_merchant_with_store!()

    customer =
      create_customer!(store, %{name: "Ama", phone: "+233201234567", email: "ama@example.com"})

    order =
      create_order!(store, %{
        customer_id: customer.id,
        total: 50_000,
        subtotal: 48_000,
        currency: "GHS"
      })

    %{store: store, customer: customer, order: order}
  end

  defp run(order, event) do
    OrderNotificationWorker.perform(%Oban.Job{
      args: %{"order_id" => order.id, "event" => event}
    })
  end

  test "a delivered WhatsApp message costs no SMS", ctx do
    expect(Emakola.WhatsAppProviderMock, :send_message, fn to, _template, _params, _opts ->
      assert to == "+233201234567"
      {:ok, %{message_id: "wa_1"}}
    end)

    # The merchant's own alert still sends; the BUYER must get no SMS.
    stub(Emakola.SMSProviderMock, :send_sms, fn to, _body, _opts ->
      refute to == "+233201234567", "buyer was charged an SMS after WhatsApp succeeded"
      {:ok, %{message_id: "sm_merchant"}}
    end)

    assert :ok = run(ctx.order, "order_placed")
  end

  test "a failed WhatsApp message falls back to SMS", ctx do
    # What an unapproved template or a bad request looks like.
    expect(Emakola.WhatsAppProviderMock, :send_message, fn _to, _template, _params, _opts ->
      {:error, %{status: 400, body: "template not approved"}}
    end)

    test_pid = self()

    stub(Emakola.SMSProviderMock, :send_sms, fn to, _body, _opts ->
      if to == "+233201234567", do: send(test_pid, :buyer_sms)
      {:ok, %{message_id: "sm_1"}}
    end)

    assert :ok = run(ctx.order, "order_placed")

    assert_received :buyer_sms
  end

  test "an event with no WhatsApp template goes straight to SMS", ctx do
    # protection_held has no approved template — the channel refuses it, so
    # SMS is the only route and must still run.
    test_pid = self()

    stub(Emakola.SMSProviderMock, :send_sms, fn to, _body, _opts ->
      if to == "+233201234567", do: send(test_pid, :buyer_sms)
      {:ok, %{message_id: "sm_1"}}
    end)

    stub(Emakola.WhatsAppProviderMock, :send_message, fn _to, _t, _p, _o ->
      {:error, :no_template}
    end)

    assert :ok = run(ctx.order, "protection_held")

    assert_received :buyer_sms
  end
end
