defmodule EmakolaWeb.Platform.FlakeProbeTest do
  @moduledoc "THROWAWAY. Proves the boundary flake is real and the guard closes it."
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers

  import Emakola.Factory

  @generic_error "Invalid email or password"
  @window_ms 60_000

  setup %{conn: conn}, do: {:ok, conn: put_unique_peer_ip(conn)}

  defp ms_left, do: @window_ms - rem(System.system_time(:millisecond), @window_ms)

  defp submit(view, email) do
    view
    |> form("#platform-credentials-form", user: %{email: email, password: "WrongPassword99!"})
    |> render_submit()
  end

  # PART 1 — the mechanism. Spend the 5 attempts, then deliberately step over a
  # minute boundary before the 6th. If Hammer's :fix_window really resets at the
  # boundary, the 6th attempt escapes the limit and we get the generic error
  # instead of "Too many attempts" — exactly what CI saw.
  test "crossing a window boundary resets the counter and lets attempt 6 through", %{conn: conn} do
    user = create_platform_owner!()
    {:ok, view, _html} = live(conn, "/platform/login")

    for _ <- 1..5, do: assert(submit(view, user.email) =~ @generic_error)

    Process.sleep(ms_left() + 200)

    html = submit(view, user.email)
    assert html =~ @generic_error, "expected the reset to let attempt 6 through"
    refute html =~ "Too many attempts"
  end

  # PART 2 — the guard. Stand 300ms before a boundary (the worst possible start)
  # and show the guard lands us in a fresh window with room to spare.
  test "ensure_rate_window_headroom moves the worst-case start into a fresh window" do
    Process.sleep(rem(ms_left() - 300 + @window_ms, @window_ms))
    assert ms_left() < 1_000, "probe failed to reach the boundary"

    window_ms = @window_ms
    left = window_ms - rem(System.system_time(:millisecond), window_ms)
    if left < 15_000, do: Process.sleep(left + 100)

    assert ms_left() >= 15_000,
           "guard left only #{ms_left()}ms — six bcrypt submits need seconds"
  end
end
