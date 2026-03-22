defmodule Emakola.Catalog.Validations.HasVariants do
  @moduledoc """
  Validates that a product has at least one variant before activation.

  In the Shopify-style model, variants hold price/SKU/stock — a product
  without variants is unpurchasable. This validation prevents merchants
  from publishing empty product shells to their storefront.

  IMPORTANT: This is a standalone module because Ash.Query.filter is a macro
  that does not work inside anonymous functions in Ash DSL action blocks.
  See CLAUDE.md "Ash DSL Gotchas" section.
  """

  use Ash.Resource.Validation
  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    product_id = Ash.Changeset.get_data(changeset, :id)

    if product_id do
      count =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(product_id == ^product_id)
        |> Ash.count!()

      if count == 0 do
        {:error,
         Ash.Error.Changes.InvalidAttribute.exception(
           field: :status,
           message: "product must have at least one variant before activation"
         )}
      else
        :ok
      end
    else
      {:error,
       Ash.Error.Changes.InvalidAttribute.exception(
         field: :status,
         message: "cannot activate unsaved product"
       )}
    end
  end
end
