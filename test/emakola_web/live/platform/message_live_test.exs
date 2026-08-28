defmodule EmakolaWeb.Platform.MessageLiveTest do
  @moduledoc """
  Makola staff talking to a merchant, and the merchant answering back.

  This is the same core as buyer messaging — only the two sides differ — so
  these tests concentrate on what is genuinely different: staff see every
  merchant, a merchant sees only their own thread.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Conversations

  setup %{conn: conn} do
    {merchant, store} = create_merchant_with_store!(%{name: "Kente Kingdom"})
    {staff_conn, _staff_user, _session} = setup_platform_staff(conn)

    %{staff_conn: staff_conn, merchant: merchant, store: store}
  end

  describe "platform staff" do
    test "an empty inbox says so", %{staff_conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/messages")

      assert html =~ "No conversations yet"
    end

    test "opens a thread with a merchant and writes", ctx do
      {:ok, thread} = Conversations.open_platform_thread(ctx.merchant.id)

      {:ok, view, _html} = live(ctx.staff_conn, ~p"/platform/messages/#{thread.id}")

      view
      |> form("#message-form", message: %{body: "Your payout is on the way."})
      |> render_submit()

      assert {:ok, [message]} = Conversations.list_messages(thread.id)
      assert message.body == "Your payout is on the way."
      assert message.author_kind == :platform
    end

    test "a sent message shows once, not twice", ctx do
      {:ok, thread} = Conversations.open_platform_thread(ctx.merchant.id)

      {:ok, view, _html} = live(ctx.staff_conn, ~p"/platform/messages/#{thread.id}")

      view
      |> form("#message-form", message: %{body: "Your payout is on the way."})
      |> render_submit()

      # The sender's own PubSub echo must not append a second copy.
      {:ok, [message]} = Conversations.list_messages(thread.id)
      occurrences = length(String.split(render(view), ~s(id="message-#{message.id}"))) - 1
      assert occurrences == 1
    end

    test "an open thread links to the merchant directory", ctx do
      {:ok, thread} = Conversations.open_platform_thread(ctx.merchant.id)

      {:ok, _view, html} = live(ctx.staff_conn, ~p"/platform/messages/#{thread.id}")

      assert html =~ ~s(href="/platform/merchants")
    end

    test "the inbox search filters merchants by name", ctx do
      {other, _store} = create_merchant_with_store!(%{name: "Bead Palace"})
      {:ok, mine} = Conversations.open_platform_thread(ctx.merchant.id)
      {:ok, theirs} = Conversations.open_platform_thread(other.id)
      {:ok, _} = Conversations.post_message(mine, :merchant, ctx.merchant.id, "Hello")
      {:ok, _} = Conversations.post_message(theirs, :merchant, other.id, "Hi there")

      {:ok, view, _html} = live(ctx.staff_conn, ~p"/platform/messages")

      # A merchant's display name falls back to their email.
      mine_name = to_string(ctx.merchant.email)
      other_name = to_string(other.email)

      render_change(element(view, "#inbox-search"), %{"q" => mine_name})

      inbox = render(element(view, "#chat-list"))
      assert inbox =~ mine_name
      refute inbox =~ other_name
    end

    test "a staff message shows read only after the merchant reads it", ctx do
      {:ok, thread} = Conversations.open_platform_thread(ctx.merchant.id)

      {:ok, message} =
        Conversations.post_message(thread, :platform, Ecto.UUID.generate(), "Hello")

      {:ok, _view, html} = live(ctx.staff_conn, ~p"/platform/messages/#{thread.id}")
      assert html =~ ~s(id="read-#{message.id}" data-read="false")

      {:ok, _} = Conversations.mark_read(thread, :merchant)
      {:ok, _view, html} = live(ctx.staff_conn, ~p"/platform/messages/#{thread.id}")
      assert html =~ ~s(id="read-#{message.id}" data-read="true")
    end

    test "lists merchants who have written", ctx do
      {:ok, thread} = Conversations.open_platform_thread(ctx.merchant.id)

      {:ok, _} =
        Conversations.post_message(thread, :merchant, ctx.merchant.id, "My payout is late")

      {:ok, _view, html} = live(ctx.staff_conn, ~p"/platform/messages")

      assert html =~ "My payout is late"
    end
  end

  describe "the merchant's side" do
    setup ctx do
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(ctx.merchant))

      conn =
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      Map.put(ctx, :merchant_conn, conn)
    end

    test "sees Makola's message in their own inbox", ctx do
      {:ok, thread} = Conversations.open_platform_thread(ctx.merchant.id)
      {:ok, _} = Conversations.post_message(thread, :platform, Ecto.UUID.generate(), "Welcome!")

      {:ok, _view, html} = live(ctx.merchant_conn, ~p"/admin/messages")

      assert html =~ "Makola"
      assert html =~ "Welcome!"
    end

    test "never sees another merchant's platform thread", ctx do
      {other_merchant, _other_store} = create_merchant_with_store!()
      {:ok, theirs} = Conversations.open_platform_thread(other_merchant.id)

      {:ok, _} =
        Conversations.post_message(theirs, :platform, Ecto.UUID.generate(), "Private note")

      {:ok, _view, html} = live(ctx.merchant_conn, ~p"/admin/messages")

      refute html =~ "Private note"
    end
  end
end
