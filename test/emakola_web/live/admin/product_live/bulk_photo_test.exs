defmodule EmakolaWeb.Admin.ProductLive.BulkPhotoTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  describe "mount" do
    test "renders the bulk photo page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/products/bulk")
      assert html =~ "Add many products"
      assert html =~ ~s(id="bulk-photo-form")
    end
  end

  describe "entry point" do
    test "products index links to the bulk photo page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products")
      assert has_element?(view, ~s{a[href="/admin/products/bulk"]})
    end
  end
end
