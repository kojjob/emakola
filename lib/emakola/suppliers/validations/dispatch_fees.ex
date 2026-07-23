defmodule Emakola.Suppliers.Validations.DispatchFees do
  @moduledoc """
  dispatch_fees is a map of delivery-area => fee in integer pesewas.
  Every fee must be a non-negative integer and every area key must be
  one of the offer's delivery_areas.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    fees = Ash.Changeset.get_attribute(changeset, :dispatch_fees) || %{}
    areas = Ash.Changeset.get_attribute(changeset, :delivery_areas) || []

    cond do
      Enum.any?(Map.values(fees), fn v -> not (is_integer(v) and v >= 0) end) ->
        {:error, field: :dispatch_fees, message: "fees must be non-negative integers in pesewas"}

      Enum.any?(Map.keys(fees), &(&1 not in areas)) ->
        {:error, field: :dispatch_fees, message: "fee areas must be listed in delivery_areas"}

      true ->
        :ok
    end
  end
end
