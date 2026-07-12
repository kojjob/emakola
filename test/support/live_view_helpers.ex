defmodule Emakola.LiveViewHelpers do
  @moduledoc """
  Shared helpers for LiveView integration tests.
  Import this module in test cases that need LiveView interaction helpers.

  Usage:
      use Emakola.LiveViewHelpers
  """

  defmacro __using__(_opts) do
    quote do
      # build_conn/0 comes from EmakolaWeb.ConnCase (apex-host default), which
      # these test cases also `use`; exclude the Phoenix.ConnTest one to avoid
      # an import conflict.
      import Phoenix.ConnTest, except: [build_conn: 0]
      import Phoenix.LiveViewTest
      import Emakola.LiveViewHelpers
    end
  end

  alias Emakola.Factory

  @doc """
  Create platform staff with a DB-backed session, returning {conn, user, session}.

  Creates an owner by default; pass `permissions: [...]` for a non-owner
  staff user with those platform permissions. The signed session id is
  stored under :platform_session_token.
  """
  def setup_platform_staff(conn, opts \\ []) do
    user =
      case opts[:permissions] do
        nil ->
          Factory.create_platform_owner!()

        permissions ->
          Factory.create_user!()
          |> Ash.Changeset.for_update(:set_platform_permissions, %{
            platform_permissions: permissions
          })
          |> Ash.update!(authorize?: false)
      end

    session = Factory.create_user_session!(user)
    signed = EmakolaWeb.AuthTokens.sign_platform_session(session.id)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:platform_session_token, signed)

    {conn, user, session}
  end

  @doc "Create a merchant, store, and membership, returning {conn, merchant, store}."
  def setup_authenticated_merchant(conn, store_attrs \\ %{}) do
    {merchant, store} = Factory.create_merchant_with_store!(store_attrs)
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, merchant, store}
  end

  @rate_window_ms 60_000
  @rate_headroom_ms 15_000

  @doc """
  Sleep into a fresh rate-limit window when too little of the current one remains.

  `Emakola.RateLimit` is Hammer's `:fix_window`: it counts inside epoch-aligned
  buckets of `div(system_time_ms, 60_000)`. A test that spends five attempts
  reaching the limit and then asserts the sixth is blocked is implicitly
  asserting all six land in the SAME bucket. Straddle a minute boundary and the
  counter resets to 1, the sixth attempt is correctly allowed, and the test
  fails for reasons that have nothing to do with the code under test.

  Call this before the attempt loop. The 15s margin is sized against the loop
  itself: six bcrypt-backed submits take a couple of seconds, and more on a
  loaded CI box.
  """
  def ensure_rate_window_headroom do
    ms_left = @rate_window_ms - rem(System.system_time(:millisecond), @rate_window_ms)
    if ms_left < @rate_headroom_ms, do: Process.sleep(ms_left + 100)
    :ok
  end
end
