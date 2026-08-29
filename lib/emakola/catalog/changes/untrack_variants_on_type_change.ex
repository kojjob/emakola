defmodule Emakola.Catalog.Changes.UntrackVariantsOnTypeChange do
  @moduledoc """
  Ash change on `Product.:update` that untracks a product's existing variants
  when it becomes non-shippable.

  `UntrackDigitalInventory` only fires on a *variant* write, so switching an
  existing physical product to `:digital_download` would otherwise leave its
  variants tracked at whatever stock they held — and a variant sitting at zero
  would make the product silently unbuyable.

  Deliberately one-directional: switching back to `:physical` does **not**
  re-track. Re-tracking would restore `stock_quantity: 0` on a live product and
  pull it straight off the storefront, and a deliberately untracked own-stock
  variant is a state `UntrackDropshippedInventory` also preserves. A merchant
  who wants tracking back sets it per variant.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Emakola.Catalog.Product
  alias Emakola.Catalog.Variant

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, product ->
      if Product.requires_shipping?(product) do
        {:ok, product}
      else
        untrack_variants(product)
        {:ok, product}
      end
    end)
  end

  defp untrack_variants(product) do
    Variant
    |> Ash.Query.filter(product_id == ^product.id and track_inventory == true)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn variant ->
      variant
      |> Ash.Changeset.for_update(:update, %{track_inventory: false})
      |> Ash.update!(authorize?: false)
    end)
  end
end
