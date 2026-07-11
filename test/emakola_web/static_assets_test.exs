defmodule EmakolaWeb.StaticAssetsTest do
  use EmakolaWeb.ConnCase, async: true

  test "serves the SVG favicon referenced by the root layout", %{conn: conn} do
    conn = get(conn, "/favicon.svg")

    assert response(conn, 200) =~ "<svg"
    assert get_resp_header(conn, "content-type") == ["image/svg+xml"]
  end
end
