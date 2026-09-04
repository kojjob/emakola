defmodule Emakola.Catalog.ProductDescriptionWrittenByAiTest do
  @moduledoc """
  A description the AI wrote is marked as such until the merchant changes it,
  so the shop can tell the merchant to read it. Their own words never carry
  the mark.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  setup do
    store = create_store!()
    {:ok, product: create_product!(store, %{description: nil})}
  end

  test "a new product is the merchant's own words until the AI writes for it", %{
    product: product
  } do
    refute product.description_written_by_ai
  end

  test "the backfill action records that the AI wrote the description", %{product: product} do
    written = backfill(product, "Canvas tote, zip top.")

    assert written.description == "Canvas tote, zip top."
    assert written.description_written_by_ai
  end

  test "the merchant changing the description takes it back", %{product: product} do
    theirs =
      product
      |> backfill("Canvas tote, zip top.")
      |> Ash.Changeset.for_update(:update, %{description: "My own words."})
      |> Ash.update!(authorize?: false)

    refute theirs.description_written_by_ai
  end

  test "the merchant changing something else leaves the mark in place", %{product: product} do
    renamed =
      product
      |> backfill("Canvas tote, zip top.")
      |> Ash.Changeset.for_update(:update, %{title: "Big canvas tote"})
      |> Ash.update!(authorize?: false)

    assert renamed.description_written_by_ai
  end

  defp backfill(product, description) do
    product
    |> Ash.Changeset.for_update(:backfill_description, %{description: description})
    |> Ash.update!(authorize?: false)
  end
end
