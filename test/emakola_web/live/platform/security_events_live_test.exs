defmodule EmakolaWeb.Platform.SecurityEventsLiveTest do
  @moduledoc """
  Platform abuse monitor: hero aggregates + top-source leaderboard + recent
  stream, permission gating, and the all-quiet empty state.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Security

  test "staff without :view_audit_log is redirected", %{conn: conn} do
    {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
    assert {:error, {:redirect, _}} = live(conn, ~p"/platform/security-events")
  end

  describe "as an owner" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      %{conn: conn, user: user}
    end

    test "shows the all-quiet empty state when there are no events", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/security-events")
      assert html =~ "All quiet"
    end

    test "hero tiles render through the shared stat tiles with stable ids", %{conn: conn} do
      Security.record(%{event_type: :rate_limit_exceeded, ip: "203.0.113.9", path: "/x"})

      {:ok, view, _html} = live(conn, ~p"/platform/security-events")

      assert has_element?(view, "#security-events-total", "1")
      assert has_element?(view, "#security-events-rate-limit", "1")
      assert has_element?(view, "#security-events-auth-failed", "0")
      assert has_element?(view, "#security-events-flagged")
    end

    test "recent events render as a severity timeline", %{conn: conn} do
      Security.record(%{event_type: :rate_limit_exceeded, ip: "203.0.113.9", path: "/x"})

      Security.record(%{
        event_type: :auth_failed,
        subject_type: :merchant,
        identifier: "attacker@example.com"
      })

      {:ok, view, _html} = live(conn, ~p"/platform/security-events")

      assert has_element?(view, "#recent-security-events [data-severity='red']")
      assert has_element?(view, "#recent-security-events [data-severity='amber']")
    end

    test "renders aggregates, top sources, and recent events", %{conn: conn} do
      for _ <- 1..3,
          do:
            Security.record(%{
              event_type: :rate_limit_exceeded,
              ip: "203.0.113.7",
              path: "/auth/login"
            })

      Security.record(%{
        event_type: :auth_failed,
        subject_type: :merchant,
        identifier: "attacker@example.com"
      })

      {:ok, _view, html} = live(conn, ~p"/platform/security-events")

      assert html =~ "Security events"
      assert html =~ "203.0.113.7"
      assert html =~ "attacker@example.com"
    end
  end
end
