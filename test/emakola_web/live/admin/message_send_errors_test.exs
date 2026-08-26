defmodule EmakolaWeb.Admin.MessageSendErrorsTest do
  @moduledoc """
  What a merchant is told when a message does not go.

  Every failure used to collapse into "Write something first." That is a lie
  for anything except an empty box, and it leaves someone who has been cut off
  by the limiter retyping a message that was never the problem.
  """
  # async: false — shares the limiter's global counters.
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Emakola.Conversations
  alias Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = Factory.create_merchant_with_store!()
    customer = Factory.create_customer!(store, %{name: "Ama"})
    {:ok, thread} = Conversations.open_shop_thread(store.id, customer.id)

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn, merchant: merchant, store: store, thread: thread}
  end

  test "an empty box still says to write something", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/messages/#{ctx.thread.id}")

    html = view |> form("#message-form", message: %{body: "   "}) |> render_submit()

    assert html =~ "Write something first"
  end

  test "being cut off by the limiter says so, and does not blame the merchant", ctx do
    # Spend the merchant's allowance outside the LiveView.
    for i <- 1..(Conversations.message_limit() + 1) do
      Conversations.post_message(ctx.thread, :merchant, ctx.merchant.id, "burst #{i}")
    end

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/messages/#{ctx.thread.id}")

    html = view |> form("#message-form", message: %{body: "A real message"}) |> render_submit()

    refute html =~ "Write something first"
    assert html =~ "too fast"
  end
end
