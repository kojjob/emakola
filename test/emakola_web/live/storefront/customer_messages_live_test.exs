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

  test "a visitor without an account is invited to sign in, not given a dead form", ctx do
    {:ok, _view, html} = live(build_conn(), "/s/#{ctx.store.slug}/account/messages")

    assert html =~ "Sign in to message the shop"
    refute html =~ "customer-message-form"
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

  test "the shop's photo reply renders in the buyer chat", ctx do
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)

    {:ok, _} =
      Conversations.post_message(thread, :merchant, Ecto.UUID.generate(), "Here it is",
        attachments: [
          %{"url" => "/uploads/chat/cloth.jpg", "content_type" => "image/jpeg", "name" => "cloth.jpg"}
        ]
      )

    {:ok, _view, html} = live(ctx.conn, "/s/#{ctx.store.slug}/account/messages")

    assert html =~ ~s(<img src="/uploads/chat/cloth.jpg")
  end

  test "a sent message shows once, not twice", ctx do
    {:ok, view, _html} = live(ctx.conn, "/s/#{ctx.store.slug}/account/messages")

    view
    |> form("#customer-message-form", message: %{body: "Do you have blue?"})
    |> render_submit()

    # The sender's own PubSub echo must not append a second copy.
    {:ok, [thread]} = Conversations.list_shop_threads(ctx.store.id)
    {:ok, [message]} = Conversations.list_messages(thread.id)
    occurrences = length(String.split(render(view), ~s(id="customer-message-#{message.id}"))) - 1
    assert occurrences == 1
  end

  test "the conversation renders as grouped chat bubbles", ctx do
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
    {:ok, first} = Conversations.post_message(thread, :customer, ctx.customer.id, "Hello")
    {:ok, _} = Conversations.post_message(thread, :customer, ctx.customer.id, "Anyone there?")

    {:ok, _view, html} = live(ctx.conn, "/s/#{ctx.store.slug}/account/messages")

    # Grouped: the buyer's own run of messages carries one read receipt.
    assert html =~ ~s(id="customer-message-#{first.id}")
    assert html =~ ~s(data-read="false")
  end

  test "the shop's reply appears without a refresh", ctx do
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
    {:ok, view, _html} = live(ctx.conn, "/s/#{ctx.store.slug}/account/messages")

    # Posted from elsewhere entirely — the merchant's admin, in real life.
    {:ok, _} = Conversations.post_message(thread, :merchant, Ecto.UUID.generate(), "On its way.")

    assert render(view) =~ "On its way."
  end

  test "a buyer sees the shop's reply", ctx do
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
    {:ok, _} = Conversations.post_message(thread, :merchant, Ecto.UUID.generate(), "Yes, we do.")

    {:ok, _view, html} = live(ctx.conn, "/s/#{ctx.store.slug}/account/messages")

    assert html =~ "Yes, we do."
  end
end
