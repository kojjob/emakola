defmodule Emakola.Catalog.Changes.UntrackDigitalInventory do
  @moduledoc """
  Ash change that forces `track_inventory: false` on any variant whose product
  does not ship. Runs on `:create` and `:update`.

  A downloadable file is infinitely copyable, so numeric stock is meaningless
  for it. Without this, the resource defaults (`track_inventory: true`,
  `stock_quantity: 0`) make every digital variant permanently out of stock:
  the PDP hides Add-to-Cart, `CheckoutService.validate_stock/2` refuses the
  order, and `DecrementStock` would burn a unit at a physical warehouse
  location for a download.

  Registered *after* `UntrackDropshippedInventory` so digital always wins. That
  sibling re-tracks a variant when its supplier is de-linked, which would
  otherwise resurrect tracking on a digital variant that had been dropshipped.

  `product_id` is read via `Ash.Changeset.get_attribute/2`, which falls back to
  the persisted value on update when the attribute isn't being changed. A
  product that cannot be loaded leaves the changeset untouched — the foreign
  key will surface the real error, which is better than masking it here.
  """

  use Ash.Resource.Change

  alias Emakola.Catalog.Product

  @impl true
  def change(changeset, _opts, _context) do
    with product_id when not is_nil(product_id) <-
           Ash.Changeset.get_attribute(changeset, :product_id),
         {:ok, product} <- Ash.get(Product, product_id, authorize?: false),
         false <- Product.requires_shipping?(product) do
      Ash.Changeset.force_change_attribute(changeset, :track_inventory, false)
    else
      _ -> changeset
    end
  end
end
