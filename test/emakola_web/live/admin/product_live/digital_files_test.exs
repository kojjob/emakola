defmodule EmakolaWeb.Admin.ProductLive.DigitalFilesTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mox

  setup :verify_on_exit!

  alias Emakola.Catalog.DigitalFile
  alias Emakola.LiveViewHelpers

  defp create_digital_product!(store) do
    store
    |> Ash.Changeset.for_update(:update_settings, %{
      enabled_product_types: [:physical, :digital_download]
    })
    |> Ash.update!(authorize?: false)

    Emakola.Factory.create_product!(store, product_type: :digital_download)
  end

  defp attach_file!(store, product, file_name, overrides \\ %{}) do
    DigitalFile
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          store_id: store.id,
          product_id: product.id,
          file_name: file_name,
          storage_key:
            "stores/#{store.id}/files/#{file_name}-#{System.unique_integer([:positive])}",
          content_type: "application/zip",
          byte_size: 5_242_880
        },
        Map.new(overrides)
      )
    )
    |> Ash.create!(authorize?: false)
  end

  describe "mount — auth" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/products/#{Ecto.UUID.generate()}/files")
    end
  end

  describe "mount — authenticated" do
    setup %{conn: conn} do
      {conn, merchant, store} = LiveViewHelpers.setup_authenticated_merchant(conn)
      product = create_digital_product!(store)
      %{conn: conn, merchant: merchant, store: store, product: product}
    end

    test "renders empty state when product has no digital files",
         %{conn: conn, product: p} do
      {:ok, _view, html} = live(conn, ~p"/admin/products/#{p.id}/files")

      assert html =~ "Digital files"
      assert html =~ "No files yet" or html =~ "no files"
    end

    test "lists existing files with name, size, and preview/paid flag",
         %{conn: conn, store: s, product: p} do
      _f1 = attach_file!(s, p, "ebook.pdf")
      _f2 = attach_file!(s, p, "sample.pdf", %{is_preview: true})

      {:ok, _view, html} = live(conn, ~p"/admin/products/#{p.id}/files")

      assert html =~ "ebook.pdf"
      assert html =~ "sample.pdf"
      # The preview file should show some "preview" affordance
      assert html =~ "Preview"
    end

    test "shows 404 redirect for a product that doesn't exist", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: redirect}}} =
               live(conn, ~p"/admin/products/#{Ecto.UUID.generate()}/files")

      assert redirect =~ "/admin/products"
    end

    test "does not allow access to a product from a different store", %{conn: conn} do
      # Different store with its own product
      other_store = Emakola.Factory.create_store!()
      other_product = create_digital_product!(other_store)

      assert {:error, {:live_redirect, %{to: redirect}}} =
               live(conn, ~p"/admin/products/#{other_product.id}/files")

      assert redirect =~ "/admin/products"
    end

    test "delete_file event removes the file row", %{conn: conn, store: s, product: p} do
      file = attach_file!(s, p, "remove-me.zip")

      {:ok, view, _html} = live(conn, ~p"/admin/products/#{p.id}/files")

      assert view
             |> element("button[phx-value-id='#{file.id}'][phx-click='delete_file']")
             |> render_click()

      refute render(view) =~ "remove-me.zip"
      assert {:error, _} = Ash.get(DigitalFile, file.id, authorize?: false)
    end

    test "toggle_preview event flips is_preview", %{conn: conn, store: s, product: p} do
      file = attach_file!(s, p, "toggleable.pdf")
      refute file.is_preview

      {:ok, view, _html} = live(conn, ~p"/admin/products/#{p.id}/files")

      view
      |> element("button[phx-value-id='#{file.id}'][phx-click='toggle_preview']")
      |> render_click()

      reloaded = Ash.get!(DigitalFile, file.id, authorize?: false)
      assert reloaded.is_preview
    end
  end
end
