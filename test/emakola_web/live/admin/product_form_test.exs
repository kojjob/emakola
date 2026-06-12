defmodule EmakolaWeb.Admin.ProductFormTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  require Ash.Query

  describe "Form — price field, variant creation, honest publish" do
    setup %{conn: conn} do
      {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, store: store}
    end

    # _action is on a <button name="product[_action]">, not an input/select/textarea,
    # so form/3 cannot resolve it. element + render_submit targets the form by
    # id="product-form" (still browser-faithful; fails if the id is absent).
    # Flash is a signed token in the live_redirect tuple; follow_redirect decodes it.
    test "creating with price + activate → active product, 2500-pesewas variant, storefront visible, published flash",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/new")

      {:ok, _redirect_view, html} =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{"title" => "Kente Cloth", "price" => "25.00", "_action" => "activate"}
        })
        |> follow_redirect(conn)

      assert html =~ "Product published"

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read_one!(authorize?: false)

      assert product.status == :active

      variants =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(product_id == ^product.id)
        |> Ash.read!(authorize?: false)

      assert [%{price: 2500}] = variants

      active_products =
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_by_store_and_status, %{
          store_id: store.id,
          status: :active
        })
        |> Ash.read!(authorize?: false)

      assert Enum.any?(active_products, &(&1.id == product.id))
    end

    test "activating without price → draft product, honest flash",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/new")

      {:ok, _redirect_view, html} =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{"title" => "Draft Product", "_action" => "activate"}
        })
        |> follow_redirect(conn)

      assert html =~ "Saved as draft"

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read_one!(authorize?: false)

      assert product.status == :draft
    end

    test "invalid price → no product created, validation error rendered",
         %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/products/new")

      html =
        view
        |> element("#product-form")
        |> render_submit(%{
          "product" => %{"title" => "Ankara Print", "price" => "abc", "_action" => "activate"}
        })

      assert html =~ "must be a valid amount"

      products =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert products == []
    end
  end
end
