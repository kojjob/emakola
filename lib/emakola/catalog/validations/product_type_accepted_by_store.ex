defmodule Emakola.Catalog.Validations.ProductTypeAcceptedByStore do
  @moduledoc """
  Validates that the product's `:product_type` is present in the owning
  store's `:enabled_product_types`. This is the merchant-facing
  capability gate — a store that hasn't opted into auctions can't have
  an auction product, even via direct API access.

  Runs on `:create` and `:update`. The resource's `one_of` constraint
  catches unknown atoms first; this validation runs after, so by the
  time we get here the type is guaranteed to be a valid product_type
  atom — we're only asking whether *this store* has opted into it.

  Grandfathering: if a store later disables a type, products of that
  type that already exist are untouched. This validation only blocks
  *new* products and updates that *change* the type to a disabled one.
  """

  use Ash.Resource.Validation

  alias Emakola.Stores.Store

  @impl true
  def validate(changeset, _opts, _context) do
    product_type = Ash.Changeset.get_attribute(changeset, :product_type)
    store_id = Ash.Changeset.get_attribute(changeset, :store_id)

    cond do
      is_nil(product_type) ->
        :ok

      is_nil(store_id) ->
        :ok

      true ->
        check_store(store_id, product_type)
    end
  end

  defp check_store(store_id, product_type) do
    case Ash.get(Store, store_id, authorize?: false) do
      {:ok, store} ->
        if Store.accepts?(store, product_type) do
          :ok
        else
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :product_type,
             message:
               "is not enabled for this store. " <>
                 "Enable it in store settings before creating products of this type."
           )}
        end

      {:error, _} ->
        # Store doesn't exist or isn't loadable — let the FK / belongs_to
        # constraints surface the real error rather than masking it with
        # an unrelated product_type validation failure.
        :ok
    end
  end
end
