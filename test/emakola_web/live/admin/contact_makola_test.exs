defmodule EmakolaWeb.Admin.ContactMakolaTest do
  @moduledoc """
  A merchant reaching Makola first.

  Their Makola thread rode in the same inbox from the start, but only once it
  existed — and only staff could create one. A merchant with a question had
  nowhere to ask it.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Conversations
  alias Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = Factory.create_merchant_with_store!(%{name: "Ask Shop"})
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn, merchant: merchant, store: store}
  end

  test "the inbox offers a way to reach Makola", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/admin/messages")

    assert html =~ "contact_makola"
  end

  test "using it opens their thread and lands there", ctx do
    refute Conversations.platform_thread_for(ctx.merchant.id)

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/messages")

    assert {:error, {:live_redirect, %{to: path}}} =
             view |> element(~s([phx-click="contact_makola"])) |> render_click()

    thread = Conversations.platform_thread_for(ctx.merchant.id)
    refute is_nil(thread)
    assert path == "/admin/messages/#{thread.id}"
  end

  test "using it twice reuses the one thread", ctx do
    {:ok, first} = Conversations.open_platform_thread(ctx.merchant.id)

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/messages")

    assert {:error, {:live_redirect, %{to: path}}} =
             view |> element(~s([phx-click="contact_makola"])) |> render_click()

    assert path == "/admin/messages/#{first.id}"
  end

  test "a merchant can then write to Makola", ctx do
    {:ok, thread} = Conversations.open_platform_thread(ctx.merchant.id)

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/messages/#{thread.id}")

    view |> form("#message-form", message: %{body: "My payout is late"}) |> render_submit()

    {:ok, messages} = Conversations.list_messages(thread.id)
    assert Enum.any?(messages, &(&1.body == "My payout is late"))
  end

  test "opening a thread for one merchant never touches another's", ctx do
    other = Factory.create_merchant!()

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/messages")
    view |> element(~s([phx-click="contact_makola"])) |> render_click()

    refute Conversations.platform_thread_for(other.id)
  end
end
