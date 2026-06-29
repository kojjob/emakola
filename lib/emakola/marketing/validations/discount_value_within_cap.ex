defmodule Emakola.Marketing.Validations.DiscountValueWithinCap do
  @moduledoc """
  A `:percentage` coupon's `discount_value` (basis points) must not exceed 100%
  (10000 bps). Applied to both `:create` and `:update` so a coupon can't be
  edited above 100% after creation — which would let `calculate_discount`
  exceed the subtotal and drive an order total negative.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    type = Ash.Changeset.get_attribute(changeset, :discount_type)
    value = Ash.Changeset.get_attribute(changeset, :discount_value)

    if type == :percentage and is_integer(value) and value > 10_000 do
      {:error,
       Ash.Error.Changes.InvalidAttribute.exception(
         field: :discount_value,
         message: "percentage cannot exceed 100% (10000 basis points)"
       )}
    else
      :ok
    end
  end
end
