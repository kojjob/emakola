defmodule Emakola.Shipping.Validations.OneCatchAllPerStore do
  @moduledoc """
  A store names at most one delivery zone as its catch-all. Two catch-alls
  would make the fee for an unnamed region depend on row order.
  """

  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    if Ash.Changeset.get_attribute(changeset, :fallback) == true and
         other_catch_all_exists?(changeset) do
      {:error, field: :fallback, message: "another zone is already the catch-all for this store"}
    else
      :ok
    end
  end

  defp other_catch_all_exists?(changeset) do
    store_id = Ash.Changeset.get_attribute(changeset, :store_id)
    own_id = changeset.data.id

    Emakola.Shipping.DeliveryZone
    |> Ash.Query.filter(store_id == ^store_id and fallback == true)
    |> exclude_self(own_id)
    |> Ash.exists?(authorize?: false)
  end

  defp exclude_self(query, nil), do: query
  defp exclude_self(query, own_id), do: Ash.Query.filter(query, id != ^own_id)
end
