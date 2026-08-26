defmodule EmakolaWeb.Admin.MessagesNavTest do
  @moduledoc """
  The inbox badge, end to end.

  Covers the whole wire rather than any one link in it: an unread buyer
  message has to travel from the database, through `AssignDefaults`, into the
  layout, and out as a number the merchant can see on any admin page.
  """

  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Conversations
  alias Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = Factory.create_merchant_with_store!(%{name: "Badge Shop"})
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn, merchant: merchant, store: store}
  end

  defp messages_link(html) do
    case Regex.run(~r{<a[^>]*href="/admin/messages".*?</a>}s, html) do
      [anchor] -> anchor
      nil -> flunk("no sidebar link pointing at /admin/messages")
    end
  end

  test "the dashboard offers a way into the inbox", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert messages_link(html) =~ "Messages"
  end

  test "an unread buyer message raises the badge", ctx do
    ama = Factory.create_customer!(ctx.store, %{name: "Ama"})
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)
    {:ok, _} = Conversations.post_message(thread, :customer, ama.id, "Are you open?")
    {:ok, _} = Conversations.post_message(thread, :customer, ama.id, "Hello?")

    {:ok, _view, html} = live(ctx.conn, ~p"/dashboard")
    anchor = messages_link(html)

    assert anchor =~ "sidebar-badge"
    assert anchor =~ "2"
  end

  test "a shop with nothing unread shows no badge", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    refute messages_link(html) =~ "sidebar-badge"
  end

  test "the merchant's own replies never raise the badge", ctx do
    ama = Factory.create_customer!(ctx.store, %{name: "Ama"})
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)
    {:ok, _} = Conversations.post_message(thread, :merchant, ctx.merchant.id, "We are open")

    {:ok, _view, html} = live(ctx.conn, ~p"/dashboard")

    refute messages_link(html) =~ "sidebar-badge"
  end

  test "a message arriving mid-session raises the badge without a refresh", ctx do
    ama = Factory.create_customer!(ctx.store, %{name: "Ama"})
    {:ok, thread} = Conversations.open_shop_thread(ctx.store.id, ama.id)

    {:ok, view, html} = live(ctx.conn, ~p"/dashboard")
    refute messages_link(html) =~ "sidebar-badge"

    {:ok, _} = Conversations.post_message(thread, :customer, ama.id, "Are you open?")

    # No navigation, no reload — the merchant is sitting on the page.
    anchor = messages_link(render(view))
    assert anchor =~ "sidebar-badge"
    assert anchor =~ "1"
  end

  test "a message to another shop leaves this badge alone mid-session", ctx do
    {_other_merchant, other_store} = Factory.create_merchant_with_store!()
    esi = Factory.create_customer!(other_store, %{name: "Esi"})
    {:ok, other_thread} = Conversations.open_shop_thread(other_store.id, esi.id)

    {:ok, view, _html} = live(ctx.conn, ~p"/dashboard")

    {:ok, _} = Conversations.post_message(other_thread, :customer, esi.id, "Private")

    refute messages_link(render(view)) =~ "sidebar-badge"
  end

  test "another shop's unread messages stay out of this badge", ctx do
    {_other_merchant, other_store} = Factory.create_merchant_with_store!()
    esi = Factory.create_customer!(other_store, %{name: "Esi"})
    {:ok, thread} = Conversations.open_shop_thread(other_store.id, esi.id)
    {:ok, _} = Conversations.post_message(thread, :customer, esi.id, "Private")

    {:ok, _view, html} = live(ctx.conn, ~p"/dashboard")

    refute messages_link(html) =~ "sidebar-badge"
  end
end
