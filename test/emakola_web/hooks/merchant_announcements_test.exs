defmodule EmakolaWeb.Hooks.MerchantAnnouncementsTest do
  @moduledoc """
  Merchant in-app announcement banner: an active announcement shows; dismissing
  it persists and hides it; scheduled/expired ones never show.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Notifications

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  defp publish!(overrides) do
    {:ok, ann} =
      Notifications.create_announcement(
        Map.merge(
          %{
            title: "Welcome to Payouts",
            body: "You can now add your payout details.",
            channels: [:banner],
            audience: :all,
            publish_at: ~U[2026-06-20 00:00:00Z]
          },
          overrides
        ),
        authorize?: false
      )

    {:ok, published} = Notifications.publish_announcement(ann, authorize?: false)
    published
  end

  test "an active banner announcement is shown", %{conn: conn} do
    publish!(%{title: "Active notice"})
    {:ok, _view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Active notice"
  end

  test "dismissing the banner hides it and persists", %{conn: conn, merchant: merchant} do
    ann = publish!(%{title: "Dismiss me"})

    {:ok, view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Dismiss me"

    html =
      view
      |> element("button[phx-value-id='#{ann.id}'][phx-click='dismiss_announcement']")
      |> render_click()

    refute html =~ "Dismiss me"

    {:ok, dismissals} =
      Notifications.list_dismissed_announcement_ids(merchant.id, authorize?: false)

    assert ann.id in Enum.map(dismissals, & &1.announcement_id)
  end

  test "a scheduled (unpublished) announcement is not shown", %{conn: conn} do
    {:ok, _scheduled} =
      Notifications.create_announcement(
        %{
          title: "Future notice",
          body: "Later.",
          channels: [:banner],
          audience: :all,
          publish_at: ~U[2026-06-20 00:00:00Z]
        },
        authorize?: false
      )

    {:ok, _view, html} = live(conn, ~p"/dashboard")
    refute html =~ "Future notice"
  end
end
