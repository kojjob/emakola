defmodule EmakolaWeb.Storefront.CustomerMessagesLiveTest do
  @moduledoc """
  The buyer's side: message the shop without WhatsApp or SMS.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Conversations

  setup %{conn: conn} do
    {_merchant, store} = create_merchant_with_store!()
    customer = create_customer!(store, %{name: "Ama", phone: "+233201234567"})
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))

    conn = Phoenix.ConnTest.init_test_session(conn, %{"customer_token" => token})

    %{conn: conn, store: store, customer: customer}
  end

  test "a buyer writes to the shop", ctx do
    {:ok, view, _html} = live(ctx.conn, "/s/#{ctx.store.slug}/account/messages")

    view
    |> form("#customer-message-form", message: %{body: "Do you have blue?"})
    |> render_submit()

    assert {:ok, [thread]} = Conversations.list_shop_threads(ctx.store.id)
    assert {:ok, [message]} = Conversations.list_messages(thread.id)
    assert message.body == "Do you have blue?"
    assert message.author_kind == :customer
  end

  test "a buyer sees the shop's reply", ctx do
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
    {:ok, _} = Conversations.post_message(thread, :merchant, Ecto.UUID.generate(), "Yes, we do.")

    {:ok, _view, html} = live(ctx.conn, "/s/#{ctx.store.slug}/account/messages")

    assert html =~ "Yes, we do."
  end
end
