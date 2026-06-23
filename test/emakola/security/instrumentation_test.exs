defmodule Emakola.Security.InstrumentationTest do
  @moduledoc """
  The security-event instrumentation points: the RateLimiter plug records a
  :rate_limit_exceeded event on deny, and a failed merchant login records an
  :auth_failed event.
  """
  use EmakolaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  require Ash.Query

  alias Emakola.Security.SecurityEvent

  defp count(type) do
    SecurityEvent
    |> Ash.Query.filter(event_type == ^type)
    |> Ash.count!(authorize?: false)
  end

  describe "RateLimiter plug" do
    setup do
      Application.put_env(:emakola, :disable_rate_limit, false)
      on_exit(fn -> Application.put_env(:emakola, :disable_rate_limit, true) end)
      :ok
    end

    test "records a :rate_limit_exceeded event when the limit is exceeded" do
      opts = EmakolaWeb.Plugs.RateLimiter.init(limit: 1, window_ms: 60_000, key: :ip)
      octet = rem(System.unique_integer([:positive]), 250) + 2
      conn = %{Phoenix.ConnTest.build_conn(:get, "/auth/login") | remote_ip: {203, 0, 113, octet}}

      EmakolaWeb.Plugs.RateLimiter.call(conn, opts)
      denied = EmakolaWeb.Plugs.RateLimiter.call(conn, opts)

      assert denied.halted
      assert count(:rate_limit_exceeded) == 1
    end
  end

  describe "merchant login failure" do
    test "records an :auth_failed event on invalid credentials", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/auth/login")

      view
      |> form("form", %{"user" => %{"email" => "nobody@example.com", "password" => "wrong"}})
      |> render_submit()

      assert count(:auth_failed) == 1
    end
  end
end
