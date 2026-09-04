defmodule EmakolaWeb.Admin.ProductLive.AiDescriptionChipTest do
  @moduledoc """
  The merchant who gets AI descriptions is the one who adds products through
  the photo cards, and that merchant never opens the edit form. The product
  list is where they look, so the mark has to be there too.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  @chip "Makola wrote this"

  setup %{conn: conn} do
    {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  test "a product with an AI-written description carries the mark in the list", %{
    conn: conn,
    store: store
  } do
    store
    |> create_product!(%{title: "Canvas tote", description: nil})
    |> Ash.Changeset.for_update(:backfill_description, %{description: "Canvas tote, zip top."})
    |> Ash.update!(authorize?: false)

    {:ok, _view, html} = live(conn, "/admin/products")

    assert html =~ @chip
  end

  test "a product the merchant described carries no mark", %{conn: conn, store: store} do
    create_product!(store, %{title: "Canvas tote", description: "My own words."})

    {:ok, _view, html} = live(conn, "/admin/products")

    refute html =~ @chip
  end
end
