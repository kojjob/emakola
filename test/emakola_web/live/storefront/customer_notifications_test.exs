defmodule EmakolaWeb.Storefront.CustomerNotificationsTest do
  @moduledoc """
  The buyer's half of the notification centre.

  Buyers already receive `:new_message` rows — a merchant replying writes one,
  and so does Makola. Nothing rendered them, so they piled up unread forever:
  the same "dead in one direction" shape the merchant bell had before it was
  fixed, recreated on the other side.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Conversations
  alias Emakola.Factory
  alias Emakola.Notifications

  setup %{conn: conn} do
    {merchant, store} = Factory.create_merchant_with_store!(%{name: "Bell Shop"})
    customer = Factory.create_customer!(store, %{name: "Ama", email: "ama@example.com"})

    token = EmakolaWeb.AuthTokens.sign_subject("customer?id=#{customer.id}&store_id=#{store.id}")

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:customer_token, token)

    %{conn: conn, merchant: merchant, store: store, customer: customer}
  end

  describe "seeing what they were told" do
    test "a buyer sees a notification addressed to them", ctx do
      {:ok, _} =
        Notifications.notify(ctx.customer, :new_message, %{title: "Bell Shop replied to you"})

      {:ok, _view, html} = live(ctx.conn, "/#{ctx.store.slug}/account")

      assert html =~ "Bell Shop replied to you"
    end

    test "another buyer's notification stays out", ctx do
      other = Factory.create_customer!(ctx.store, %{name: "Kofi", phone: "+233240000001"})
      {:ok, _} = Notifications.notify(other, :new_message, %{title: "Not for you"})

      {:ok, _view, html} = live(ctx.conn, "/#{ctx.store.slug}/account")

      refute html =~ "Not for you"
    end

    test "a merchant's reply is what actually lands there", ctx do
      # The real path, not a hand-written notification.
      {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
      {:ok, _} = Conversations.post_message(thread, :merchant, ctx.merchant.id, "Yes, in stock")

      {:ok, _view, html} = live(ctx.conn, "/#{ctx.store.slug}/account")

      assert html =~ "Bell Shop replied to you"
    end

    test "nothing unread shows no count", ctx do
      {:ok, _view, html} = live(ctx.conn, "/#{ctx.store.slug}/account")

      refute html =~ ~s(data-role="customer-unread")
    end

    test "an unread notification shows a count", ctx do
      {:ok, _} = Notifications.notify(ctx.customer, :new_message, %{title: "One"})

      {:ok, _view, html} = live(ctx.conn, "/#{ctx.store.slug}/account")

      assert html =~ ~s(data-role="customer-unread")
    end
  end

  describe "writing to Makola" do
    test "the account page offers a way to reach Makola", ctx do
      {:ok, _view, html} = live(ctx.conn, "/#{ctx.store.slug}/account")

      assert html =~ "Makola"
    end

    test "a buyer can open their Makola thread and write", ctx do
      {:ok, view, _html} = live(ctx.conn, "/#{ctx.store.slug}/account/messages")

      view
      |> element(~s([phx-click="open_platform_thread"]))
      |> render_click()

      html =
        view
        |> form("#customer-message-form", message: %{body: "My order never came"})
        |> render_submit()

      thread = Conversations.platform_customer_thread_for(ctx.customer.id)
      refute is_nil(thread)

      {:ok, messages} = Conversations.list_messages(thread.id)
      assert Enum.any?(messages, &(&1.body == "My order never came"))
      assert html =~ "My order never came"
    end

    test "writing to Makola does not write to the shop", ctx do
      {:ok, view, _html} = live(ctx.conn, "/#{ctx.store.slug}/account/messages")

      view |> element(~s([phx-click="open_platform_thread"])) |> render_click()

      view
      |> form("#customer-message-form", message: %{body: "About the shop"})
      |> render_submit()

      # The shop must not see a complaint about itself.
      assert Conversations.unread_total_for_store(ctx.store.id) == 0
    end
  end
end
