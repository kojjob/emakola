defmodule Emakola.Orders.Changes.DenormalizeVariant do
  @moduledoc """
  Ash resource change that denormalizes variant price and product title onto a
  new line item at create time.

  Fetches `Emakola.Catalog.Variant` (with its product loaded) by the
  `:variant_id` attribute on the changeset, then snapshots the following
  fields so the order record remains accurate if the catalog changes later:

    * `:product_title` — from `variant.product.title`
    * `:variant_sku`   — from `variant.sku`
    * `:unit_price`    — from `variant.price` (minor units)
    * `:line_total`    — `unit_price * quantity`
    * `:cost_price`    — from `variant.cost_price` (nil for own-stock)

  Extracted from an anonymous change function in `Emakola.Orders.LineItem`
  to make the cross-context Catalog→Orders call named, visible, and
  independently testable.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    variant_id = Ash.Changeset.get_attribute(changeset, :variant_id)

    case Ash.get(Emakola.Catalog.Variant, variant_id, load: [:product], authorize?: false) do
      {:ok, variant} ->
        quantity = Ash.Changeset.get_attribute(changeset, :quantity)
        line_total = variant.price * (quantity || 0)

        changeset
        |> Ash.Changeset.force_change_attribute(:product_title, variant.product.title)
        |> Ash.Changeset.force_change_attribute(:variant_sku, variant.sku)
        |> Ash.Changeset.force_change_attribute(:unit_price, variant.price)
        |> Ash.Changeset.force_change_attribute(:line_total, line_total)
        |> Ash.Changeset.force_change_attribute(:cost_price, variant.cost_price)

      {:error, _} ->
        Ash.Changeset.add_error(changeset,
          field: :variant_id,
          message: "variant not found"
        )
    end
  end
end
