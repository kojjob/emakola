defmodule EmakolaWeb.Platform.MessageAccessTest do
  @moduledoc """
  Who may read merchant conversations, and how a staff member starts one.

  The page shipped ungated — every platform staff member could read every
  merchant's thread regardless of what they were trusted with. It also had no
  way in: `open_platform_thread/1` had no caller anywhere in `lib`, so the
  empty state's "open one from a merchant's page" pointed at a button that did
  not exist.
  """

  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers

  alias Emakola.Conversations
  alias Emakola.Factory

  describe "reading merchant conversations" do
    test "staff without merchant permissions are turned away", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_billing])

      assert {:error, {:redirect, %{to: "/platform"}}} = live(conn, ~p"/platform/messages")
    end

    test "staff who manage merchants may read them", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_merchants])

      assert {:ok, _view, _html} = live(conn, ~p"/platform/messages")
    end

    test "an owner may read them", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)

      assert {:ok, _view, _html} = live(conn, ~p"/platform/messages")
    end
  end

  describe "buyer threads in the staff inbox" do
    setup %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_merchants])
      {_merchant, store} = Factory.create_merchant_with_store!()
      customer = Factory.create_customer!(store, %{name: "Ama Mensah"})

      %{conn: conn, store: store, customer: customer}
    end

    test "a buyer's thread is listed, by their name", ctx do
      {:ok, thread} = Conversations.open_platform_customer_thread(ctx.customer.id)
      {:ok, _} = Conversations.post_message(thread, :customer, ctx.customer.id, "My order")

      {:ok, _view, html} = live(ctx.conn, ~p"/platform/messages")

      assert html =~ "Ama Mensah"
    end

    test "staff can open it", ctx do
      {:ok, thread} = Conversations.open_platform_customer_thread(ctx.customer.id)

      {:ok, _} =
        Conversations.post_message(thread, :customer, ctx.customer.id, "My order never came")

      {:ok, _view, html} = live(ctx.conn, ~p"/platform/messages/#{thread.id}")

      assert html =~ "My order never came"
    end

    test "staff can reply, and the buyer is told", ctx do
      {:ok, thread} = Conversations.open_platform_customer_thread(ctx.customer.id)

      {:ok, view, _html} = live(ctx.conn, ~p"/platform/messages/#{thread.id}")

      view
      |> form("#message-form", message: %{body: "We are looking into it"})
      |> render_submit()

      {:ok, messages} = Conversations.list_messages(thread.id)
      assert Enum.any?(messages, &(&1.body == "We are looking into it"))

      types = ctx.customer |> Emakola.Notifications.list_for() |> Enum.map(& &1.type)
      assert :new_message in types
    end

    test "a shop thread is still not reachable from the staff inbox", ctx do
      # Staff read merchant and buyer conversations with Makola — not a
      # merchant's private conversation with their own buyer.
      {:ok, shop_thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)

      assert {:error, {:live_redirect, %{to: "/platform/messages"}}} =
               live(ctx.conn, ~p"/platform/messages/#{shop_thread.id}")
    end
  end

  describe "starting a conversation with a merchant" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn, permissions: [:manage_merchants])
      merchant = Factory.create_merchant!()

      %{conn: conn, user: user, merchant: merchant}
    end

    test "the merchant page offers a way to message them", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/platform/merchants")

      html =
        view
        |> element("[phx-click='select_merchant'][phx-value-id='#{ctx.merchant.id}']")
        |> render_click()

      assert html =~ "message_merchant"
    end

    test "clicking it opens the thread and lands on the conversation", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/platform/merchants")

      view
      |> element("[phx-click='select_merchant'][phx-value-id='#{ctx.merchant.id}']")
      |> render_click()

      assert {:error, {:live_redirect, %{to: path}}} =
               view |> element("[phx-click='message_merchant']") |> render_click()

      assert path =~ ~r{^/platform/messages/}

      # The thread is real, belongs to this merchant, and is reused next time.
      thread = Conversations.platform_thread_for(ctx.merchant.id)
      refute is_nil(thread)
      assert path == "/platform/messages/#{thread.id}"
    end

    test "opening twice reuses the one thread rather than making a second", ctx do
      {:ok, _} = Conversations.open_platform_thread(ctx.merchant.id)
      first = Conversations.platform_thread_for(ctx.merchant.id)

      {:ok, view, _html} = live(ctx.conn, ~p"/platform/merchants")

      view
      |> element("[phx-click='select_merchant'][phx-value-id='#{ctx.merchant.id}']")
      |> render_click()

      assert {:error, {:live_redirect, %{to: path}}} =
               view |> element("[phx-click='message_merchant']") |> render_click()

      assert path == "/platform/messages/#{first.id}"
    end
  end
end
