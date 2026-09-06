defmodule Emakola.Customers.Validations.ProductInStore do
  @moduledoc """
  A wishlist row must reference a product that actually belongs to the
  store the row is being written under.

  `WishlistItem.store_id` is denormalised from the customer/storefront
  context rather than derived from the product, so nothing else ties the
  two together. Without this, a client-supplied `product_id` for another
  store's product could be paired with this store's `store_id` — exactly
  the gap `WishlistLive.toggle_wishlist/2` leaves open by skipping the
  `get_active_product/3` check its sibling handler makes. The
  `Product.wishlist_count` aggregate already filters by `parent(store_id)`
  as defence in depth; this validation stops the bad row from being
  written at all.
  """
  use Ash.Resource.Validation

  alias Emakola.Catalog.Product

  @impl true
  def validate(changeset, _opts, _context) do
    product_id = Ash.Changeset.get_attribute(changeset, :product_id)
    store_id = Ash.Changeset.get_attribute(changeset, :store_id)

    validate_product(product_id, store_id)
  end

  defp validate_product(nil, _store_id), do: :ok
  defp validate_product(_product_id, nil), do: :ok

  defp validate_product(product_id, store_id) do
    case Ash.get(Product, product_id, authorize?: false) do
      {:ok, %{store_id: ^store_id}} ->
        :ok

      _other ->
        {:error,
         Ash.Error.Changes.InvalidAttribute.exception(
           field: :product_id,
           message: "That product is not in this shop"
         )}
    end
  end
end
