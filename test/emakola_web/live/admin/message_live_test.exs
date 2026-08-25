defmodule EmakolaWeb.Admin.MessageLiveTest do
  @moduledoc """
  The merchant's side of buyer messaging.

  The isolation test is the one that matters: a thread belonging to another
  store must never be readable, whatever id is typed into the URL.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Conversations

  setup do
    {merchant, store} = create_merchant_with_store!()
    customer = create_customer!(store, %{name: "Ama Mensah", phone: "+233201234567"})
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn, merchant: merchant, store: store, customer: customer}
  end

  test "an empty inbox says so plainly", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/messages")

    assert html =~ "No messages yet"
  end

  test "lists a buyer thread with the buyer's name", ctx do
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)

    {:ok, _} =
      Conversations.post_message(thread, :customer, ctx.customer.id, "Is the cloth ready?")

    {:ok, _view, html} = live(ctx.conn, ~p"/admin/messages")

    assert html =~ "Ama Mensah"
    assert html =~ "Is the cloth ready?"
  end

  test "the merchant replies and the buyer's message is marked read", ctx do
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
    {:ok, _} = Conversations.post_message(thread, :customer, ctx.customer.id, "Is it ready?")

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/messages/#{thread.id}")

    # Opening the thread is reading it.
    assert Conversations.unread_count(thread.id, :merchant) == 0

    view |> form("#message-form", message: %{body: "Ready tomorrow."}) |> render_submit()

    assert {:ok, messages} = Conversations.list_messages(thread.id)
    assert List.last(messages).body == "Ready tomorrow."
    assert List.last(messages).author_kind == :merchant
  end

  test "another store's thread is not readable", ctx do
    {_other_merchant, other_store} = create_merchant_with_store!()
    other_customer = create_customer!(other_store, %{name: "Someone Else"})
    {:ok, theirs} = Conversations.open_shop_thread(other_store.id, other_customer.id)
    {:ok, _} = Conversations.post_message(theirs, :customer, other_customer.id, "Private")

    assert {:error, {:live_redirect, %{to: "/admin/messages"}}} =
             live(ctx.conn, ~p"/admin/messages/#{theirs.id}")
  end
end
