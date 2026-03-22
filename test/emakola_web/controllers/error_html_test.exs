defmodule EmakolaWeb.ErrorHTMLTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html with custom design" do
    html = render_to_string(EmakolaWeb.ErrorHTML, "404", "html", [])
    assert html =~ "Lost in the void"
    assert html =~ "404"
    assert html =~ "Back to Safety"
  end

  test "renders 500.html with custom design" do
    html = render_to_string(EmakolaWeb.ErrorHTML, "500", "html", [])
    assert html =~ "Something broke"
    assert html =~ "500"
    assert html =~ "Back to Safety"
  end
end
