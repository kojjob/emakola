defmodule EmakolaWeb.Storefront.CustomerMessagesReachableTest do
  @moduledoc """
  Buyers finding their way to the shop conversation.

  `/account/messages` shipped with no link pointing at it anywhere in the app
  and was declared in only two of the three storefront live_sessions, so the
  short-slug form 404'd. Both are pinned here.
  """

  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup %{conn: conn} do
    {_merchant, store} = Factory.create_merchant_with_store!(%{name: "Reach Shop"})
    customer = Factory.create_customer!(store, %{name: "Ama", email: "ama@example.com"})

    conn = log_in_customer(conn, customer, store)

    %{conn: conn, store: store, customer: customer}
  end

  # Mirrors what Storefront.CustomerSessionController sets.
  defp log_in_customer(conn, customer, store) do
    token = EmakolaWeb.AuthTokens.sign_subject("customer?id=#{customer.id}&store_id=#{store.id}")

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:customer_token, token)
  end

  describe "every URL shape serves the inbox" do
    test "the /s/:slug form", ctx do
      assert {:ok, _view, _html} = live(ctx.conn, "/s/#{ctx.store.slug}/account/messages")
    end

    test "the short /:slug form", ctx do
      # Declared in :storefront and :storefront_root but not :storefront_short,
      # so makola.io/<slug>/account/messages 404'd while /account did not.
      assert {:ok, _view, _html} = live(ctx.conn, "/#{ctx.store.slug}/account/messages")
    end
  end

  describe "the account page points at it" do
    test "links to messages in the same URL dialect it was reached by", ctx do
      {:ok, _view, html} = live(ctx.conn, "/s/#{ctx.store.slug}/account")

      assert html =~ "/s/#{ctx.store.slug}/account/messages"
    end

    test "keeps the short dialect when reached by the short URL", ctx do
      {:ok, _view, html} = live(ctx.conn, "/#{ctx.store.slug}/account")

      assert html =~ "/#{ctx.store.slug}/account/messages"
      refute html =~ "/s/#{ctx.store.slug}/account/messages"
    end
  end
end
