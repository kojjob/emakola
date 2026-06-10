defmodule Emakola.Payments.Validations.RefundAmountNotExceeded do
  @moduledoc """
  Validates that `refunded_amount` does not exceed the original `amount` on
  a payment. Used in the `mark_refunded` action.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    refunded_amount = Ash.Changeset.get_attribute(changeset, :refunded_amount)
    amount = changeset.data.amount

    if is_nil(refunded_amount) or is_nil(amount) or refunded_amount <= amount do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidAttribute.exception(
         field: :refunded_amount,
         message: "cannot exceed original payment amount"
       )}
    end
  end
end
