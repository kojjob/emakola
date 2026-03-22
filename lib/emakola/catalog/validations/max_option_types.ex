defmodule Emakola.Catalog.Validations.MaxOptionTypes do
  @moduledoc """
  Validates that a product has at most 3 option types.

  This mirrors Shopify's limit — 3 options (e.g., Size, Color, Material)
  is enough for virtually all product types while preventing unwieldy
  variant matrices.
  """

  use Ash.Resource.Validation
  require Ash.Query

  @max_option_types 3

  @impl true
  def validate(changeset, _opts, _context) do
    product_id = Ash.Changeset.get_attribute(changeset, :product_id)

    if product_id do
      count =
        Emakola.Catalog.OptionType
        |> Ash.Query.filter(product_id == ^product_id)
        |> Ash.count!()

      if count >= @max_option_types do
        {:error,
         Ash.Error.Changes.InvalidAttribute.exception(
           field: :product_id,
           message: "product already has the maximum of #{@max_option_types} option types"
         )}
      else
        :ok
      end
    else
      :ok
    end
  end
end
