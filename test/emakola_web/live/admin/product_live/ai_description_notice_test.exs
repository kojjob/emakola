defmodule EmakolaWeb.Admin.ProductLive.AiDescriptionNoticeTest do
  @moduledoc """
  A description the AI wrote goes live on the shopfront the moment it is
  saved. The merchant has to be told, in the place they edit it, in words
  short enough to be read by someone who reads slowly.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  @notice "Makola wrote this. Change what is wrong."

  setup %{conn: conn} do
    {conn, _merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  test "an AI-written description is labelled so the merchant knows to read it", %{
    conn: conn,
    store: store
  } do
    product =
      store
      |> create_product!(%{description: nil})
      |> Ash.Changeset.for_update(:backfill_description, %{description: "Canvas tote, zip top."})
      |> Ash.update!(authorize?: false)

    {:ok, _view, html} = live(conn, "/admin/products/#{product.id}/edit")

    assert html =~ @notice
  end

  test "the merchant's own description carries no label", %{conn: conn, store: store} do
    product = create_product!(store, %{description: "My own words."})

    {:ok, _view, html} = live(conn, "/admin/products/#{product.id}/edit")

    refute html =~ @notice
  end
end
