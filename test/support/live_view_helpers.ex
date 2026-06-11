defmodule Emakola.LiveViewHelpers do
  @moduledoc """
  Shared helpers for LiveView integration tests.
  Import this module in test cases that need LiveView interaction helpers.

  Usage:
      use Emakola.LiveViewHelpers
  """

  defmacro __using__(_opts) do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Emakola.LiveViewHelpers
    end
  end

  alias Emakola.Factory

  @doc "Create a user, org, and membership, returning {conn, user, org}."
  def setup_authenticated_user(conn) do
    user = Factory.create_user!()
    org = Factory.create_organisation!()
    Factory.create_membership!(user, org, :owner)

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(user))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, user, org}
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
end
