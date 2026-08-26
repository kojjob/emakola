defmodule EmakolaWeb.SidebarMessagesLinkTest do
  @moduledoc """
  The merchant's way into their inbox.

  `/admin/messages` has served since the conversations feature shipped, but
  nothing in the sidebar pointed at it, so the only way to reach it was to
  type the URL. These tests pin the link so it cannot go missing again.
  """

  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias EmakolaWeb.SidebarComponents

  defp sidebar(assigns \\ %{}) do
    defaults = %{
      active_nav: :dashboard,
      current_user: nil,
      current_merchant: nil,
      current_store: nil,
      pending_order_count: 0,
      unread_message_count: 0
    }

    render_component(&SidebarComponents.admin_sidebar/1, Map.merge(defaults, assigns))
  end

  # The whole <a> for the Messages item, so assertions cannot accidentally
  # match a badge or an "active" class belonging to a neighbouring link.
  defp messages_link(assigns \\ %{}) do
    html = sidebar(assigns)

    case Regex.run(~r{<a[^>]*href="/admin/messages".*?</a>}s, html) do
      [anchor] -> anchor
      nil -> flunk("no sidebar link pointing at /admin/messages")
    end
  end

  describe "Messages navigation" do
    test "links to the merchant inbox" do
      html = sidebar()

      assert html =~ ~s(href="/admin/messages")
      assert html =~ "Messages"
    end

    test "marks itself active on the messages page" do
      # Admin.MessageLive sets active_nav: :messages — the link has to answer
      # to the same atom or the page highlights nothing.
      assert messages_link(%{active_nav: :messages}) =~ "active"
    end

    test "is not active when another page is open" do
      refute messages_link(%{active_nav: :orders}) =~ "active"
    end

    test "renders an unread badge when buyers are waiting" do
      anchor = messages_link(%{unread_message_count: 3})

      assert anchor =~ "sidebar-badge"
      assert anchor =~ "3"
    end

    test "renders no badge when nothing is unread" do
      refute messages_link(%{unread_message_count: 0}) =~ "sidebar-badge"
    end

    test "draws a real icon rather than an empty path" do
      # Map.get(@sidebar_icons, icon, "") silently yields d="" for an unknown
      # key, so a typo'd icon name renders an invisible glyph and no error.
      refute messages_link() =~ ~s(d="")
    end
  end
end
