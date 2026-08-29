defmodule EmakolaWeb.Storefront.CustomerLoginRateLimitTest do
  @moduledoc """
  Customer password attempts must be throttled at the socket, not just the
  page load.

  The `/s/:slug` scope's `:auth_rate_limit` plug only sees HTTP requests, but
  authentication happens in `handle_event` over the LiveView socket. Without a
  websocket-level limit a client loads the login page once and then guesses
  passwords indefinitely on that one connection — merchant `LoginLive` has
  always guarded this; customer login did not.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @limit 10
  @window_ms 60_000

  setup do
    # Emakola.RateLimit is a live Hammer/ETS counter in tests (deliberately not
    # covered by :disable_rate_limit), so give each run its own bucket.
    store = Emakola.Factory.create_store!()
    %{store: store}
  end

  # Hammer's :fix_window buckets are epoch-aligned, so a test that starts near a
  # boundary splits its counts across two windows and the Nth attempt is
  # (correctly) allowed — the flake pattern from PR #174. Same helper shape as
  # test/emakola/suppliers/network_test.exs.
  defp await_fresh_window(window_ms, guard_ms) do
    remaining = window_ms - rem(System.system_time(:millisecond), window_ms)
    if remaining < guard_ms, do: Process.sleep(remaining + 10)
  end

  defp submit_login(lv, email) do
    lv
    |> form("form", customer: %{email: email, password: "wrong-password"})
    |> render_submit()
  end

  test "customer login is throttled after the per-IP limit", %{conn: conn, store: store} do
    # Needs the whole 11-attempt sequence inside one window.
    await_fresh_window(@window_ms, 15_000)

    {:ok, lv, _html} = live(conn, ~p"/s/#{store.slug}/login")

    email = "shopper-#{System.unique_integer([:positive])}@example.com"

    # Up to the limit: rejected as bad credentials, never as rate-limited.
    for _ <- 1..@limit do
      html = submit_login(lv, email)
      assert html =~ "Invalid email or password"
      refute html =~ "Too many sign-in attempts"
    end

    # Past it: the limiter answers instead of the credential check.
    html = submit_login(lv, email)
    assert html =~ "Too many sign-in attempts"
  end

  test "failed customer logins are recorded as security events", %{conn: conn, store: store} do
    {:ok, lv, _html} = live(conn, ~p"/s/#{store.slug}/login")

    email = "audit-#{System.unique_integer([:positive])}@example.com"
    submit_login(lv, email)

    events = Ash.read!(Emakola.Security.SecurityEvent, authorize?: false)

    assert Enum.any?(events, fn e ->
             e.event_type == :auth_failed and e.subject_type == :customer and
               e.identifier == email
           end),
           "expected an :auth_failed customer security event for #{email}"
  end
end
