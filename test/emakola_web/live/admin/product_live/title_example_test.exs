defmodule EmakolaWeb.Admin.ProductLive.TitleExampleTest do
  @moduledoc """
  A product title is the ceiling on what its page can rank for. "watch" ranks
  for nothing; "Oraimo Watch 2 smart watch" can. The nudge is an example in
  the empty field, not an instruction, because an example is what a merchant
  who reads slowly can copy.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @example "Oraimo FreePods 3 earbuds"

  setup %{conn: conn} do
    {conn, _merchant, _store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
    %{conn: conn}
  end

  test "the typed product form shows a brand-plus-item example in the title field", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, "/admin/products/new/form")

    assert html =~ ~s(placeholder="e.g. #{@example}")
  end

  test "each photo card shows the same example in its name field", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/products/new")

    png =
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
      )

    html =
      view
      |> file_input("#add-products-form", :photos, [
        %{name: "shot.png", content: png, type: "image/png"}
      ])
      |> render_upload("shot.png")

    assert html =~ ~s(placeholder="What is it? e.g. #{@example}")
  end
end
