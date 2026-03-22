defmodule EmakolaWeb.Plugs.CartSessionTest do
  use EmakolaWeb.ConnCase, async: true

  alias EmakolaWeb.Plugs.CartSession

  describe "call/2" do
    test "assigns a cart_session_id when none exists", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> CartSession.call([])

      session_id = get_session(conn, "cart_session_id")
      assert is_binary(session_id)
      assert byte_size(session_id) > 0
    end

    test "preserves existing cart_session_id", %{conn: conn} do
      existing_id = Ecto.UUID.generate()

      conn =
        conn
        |> init_test_session(%{"cart_session_id" => existing_id})
        |> CartSession.call([])

      assert get_session(conn, "cart_session_id") == existing_id
    end

    test "generates a valid UUID", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> CartSession.call([])

      session_id = get_session(conn, "cart_session_id")
      assert {:ok, _} = Ecto.UUID.cast(session_id)
    end
  end
end
