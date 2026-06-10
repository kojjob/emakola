defmodule Emakola.Shipping do
  @moduledoc "Shipping domain — delivery zones and shipping rates for store fulfilment configuration."
  use Ash.Domain

  require Ash.Query

  resources do
    resource Emakola.Shipping.DeliveryZone do
      define(:create_delivery_zone, action: :create)
      define(:update_delivery_zone, action: :update)
      define(:destroy_delivery_zone, action: :destroy)
      define(:list_delivery_zones, action: :list_by_store, args: [:store_id])
    end
  end

  @doc """
  Looks up the active delivery zone fee for a `store_id` + region pair.

  The `region` argument may be either a snake_case key from the storefront
  form (e.g. `"greater_accra"`) or a human zone name (`"Greater Accra"`).
  Match is case-insensitive and treats `_` and ` ` as equivalent.

  ## Returns
    * `{:ok, fee_in_pesewas}` when an active matching zone exists
    * `{:error, :no_zone}` otherwise — caller decides the fallback (e.g. a
      default fee or rejecting the region)
  """
  @spec calculate_fee(binary(), binary()) :: {:ok, integer()} | {:error, :no_zone}
  def calculate_fee(store_id, region) when is_binary(store_id) and is_binary(region) do
    normalised_target = normalise_region(region)

    Emakola.Shipping.DeliveryZone
    |> Ash.Query.filter(store_id == ^store_id and active == true)
    |> Ash.read!(authorize?: false)
    |> Enum.find(fn zone -> normalise_region(zone.name) == normalised_target end)
    |> case do
      nil -> {:error, :no_zone}
      zone -> {:ok, zone.fee}
    end
  end

  defp normalise_region(value) do
    value
    |> String.downcase()
    |> String.replace("_", " ")
    |> String.trim()
  end
end
