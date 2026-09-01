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
    assert_push_event(view, "composer:clear", %{})
  end

  test "a sent message shows once, not twice", ctx do
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
    {:ok, _} = Conversations.post_message(thread, :customer, ctx.customer.id, "Is it ready?")

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/messages/#{thread.id}")

    view |> form("#message-form", message: %{body: "Ready tomorrow."}) |> render_submit()

    # The sender's own PubSub echo must not append a second copy of the
    # message the submit already rendered.
    {:ok, messages} = Conversations.list_messages(thread.id)
    sent = List.last(messages)
    occurrences = length(String.split(render(view), ~s(id="message-#{sent.id}"))) - 1
    assert occurrences == 1
  end

  test "media attachments render as playable bubbles", ctx do
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)

    {:ok, _} =
      Conversations.post_message(thread, :customer, ctx.customer.id, "",
        attachments: [
          %{
            "url" => "/uploads/chat/pic.jpg",
            "content_type" => "image/jpeg",
            "name" => "pic.jpg"
          },
          %{
            "url" => "/uploads/chat/note.m4a",
            "content_type" => "audio/mp4",
            "name" => "note.m4a"
          },
          %{
            "url" => "/uploads/chat/clip.mp4",
            "content_type" => "video/mp4",
            "name" => "clip.mp4"
          }
        ]
      )

    {:ok, _view, html} = live(ctx.conn, ~p"/admin/messages/#{thread.id}")

    assert html =~ ~s(<img src="/uploads/chat/pic.jpg")
    assert html =~ ~s(<audio controls)
    assert html =~ ~s(<video controls)
  end

  test "a message can be only a picture", ctx do
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
    {:ok, _} = Conversations.post_message(thread, :customer, ctx.customer.id, "Hi")

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/messages/#{thread.id}")

    Mox.stub(Emakola.StorageMock, :upload, fn _binary, path, _opts ->
      {:ok, "/uploads/#{path}"}
    end)

    # The upload lands in the LiveView's channel process, not the test's.
    Mox.allow(Emakola.StorageMock, self(), view.pid)

    view
    |> file_input("#message-form", :chat_media, [
      %{
        name: "kente.jpg",
        content: File.read!("priv/static/images/icons/icon-192.png"),
        type: "image/jpeg"
      }
    ])
    |> render_upload("kente.jpg")

    view |> form("#message-form", message: %{body: ""}) |> render_submit()

    {:ok, messages} = Conversations.list_messages(thread.id)
    last = List.last(messages)
    assert [%{"url" => url}] = last.attachments
    assert String.contains?(url, "kente")
    assert render(view) =~ ~s(<img src="#{url}")
  end

  test "the inbox search filters threads by name", ctx do
    other = create_customer!(ctx.store, %{name: "Yaw Ofori", phone: "+233209999999"})
    {:ok, t1} = Conversations.open_shop_thread(ctx.store.id, ctx.customer.id)
    {:ok, t2} = Conversations.open_shop_thread(ctx.store.id, other.id)
    {:ok, _} = Conversations.post_message(t1, :customer, ctx.customer.id, "First")
    {:ok, _} = Conversations.post_message(t2, :customer, other.id, "Second")

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/messages")

    render_change(element(view, "#inbox-search"), %{"q" => "Ama"})

    # Scoped to the list: the topbar bell also carries the buyer's name.
    inbox = render(element(view, "#chat-list"))
    assert inbox =~ "Ama Mensah"
    refute inbox =~ "Yaw Ofori"
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
