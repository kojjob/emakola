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

  ## Options
    * `:subtotal_pesewas` — merchandise subtotal of the cart. When the zone
      has `free_above_pesewas` set and the subtotal reaches it, delivery is
      free.
    * `:total_weight_grams` — total cart weight (see `total_weight_grams/1`).
      When the zone has `per_kg_fee_pesewas` set, the fee becomes
      `fee + per_kg_fee_pesewas * ceil(weight / 1kg)`.

  Precedence: free-above wins (fee 0), otherwise base fee + weight surcharge.
  Without options — or on zones without the tier/weight fields — this is
  today's flat per-zone fee.

  ## Returns
    * `{:ok, fee_in_pesewas}` when an active matching zone exists
    * `{:error, :no_zone}` otherwise — caller decides the fallback (e.g. a
      default fee or rejecting the region)
  """
  @spec calculate_fee(binary(), binary(), keyword()) :: {:ok, integer()} | {:error, :no_zone}
  def calculate_fee(store_id, region, opts \\ [])
      when is_binary(store_id) and is_binary(region) and is_list(opts) do
    case find_zone(store_id, region) do
      {:ok, zone} -> {:ok, zone_fee(zone, opts)}
      {:error, :no_zone} -> {:error, :no_zone}
    end
  end

  @doc """
  The active zone a `store_id` + region pair resolves to, matched the same way
  `calculate_fee/3` matches it (case-insensitive, `_` and ` ` equivalent).

  Callers that need the zone's own terms — its `estimated_days`, say — rather
  than just its fee should use this, so that what the storefront promises and
  what the checkout charges come from the same row.
  """
  @spec find_zone(binary(), binary()) ::
          {:ok, Emakola.Shipping.DeliveryZone.t()} | {:error, :no_zone}
  def find_zone(store_id, region) when is_binary(store_id) and is_binary(region) do
    Emakola.Shipping.DeliveryZone
    |> Ash.Query.filter(store_id == ^store_id and active == true)
    |> Ash.read!(authorize?: false)
    |> zone_for_region(region)
    |> case do
      nil -> {:error, :no_zone}
      zone -> {:ok, zone}
    end
  end

  @doc """
  The zone whose name matches a buyer's region, else the store's catch-all
  zone if one is among `zones`, else nil. The name match is the one
  checkout uses: case-insensitive, `_` and space are the same. Pass only
  active zones when the answer must be sellable.
  """
  @spec zone_for_region([Emakola.Shipping.DeliveryZone.t()], binary() | nil) ::
          Emakola.Shipping.DeliveryZone.t() | nil
  def zone_for_region(zones, region) when is_list(zones) and is_binary(region) do
    normalised_target = normalise_region(region)

    Enum.find(zones, fn zone -> normalise_region(zone.name) == normalised_target end) ||
      Enum.find(zones, & &1.fallback)
  end

  def zone_for_region(_zones, _region), do: nil

  @doc """
  A region as a merchant would read it: "greater_accra" becomes
  "Greater Accra". Nil or blank becomes "Not given".
  """
  @spec humanise_region(binary() | nil) :: binary()
  def humanise_region(region) when is_binary(region) and region != "" do
    region
    |> String.replace("_", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  def humanise_region(_region), do: "Not given"

  @doc """
  Sums cart weight in grams from `%{weight_grams: integer | nil, quantity: integer}`
  items. Variants without a configured weight count as 0.
  """
  @spec total_weight_grams([%{weight_grams: integer() | nil, quantity: integer()}]) ::
          non_neg_integer()
  def total_weight_grams(items) when is_list(items) do
    Enum.reduce(items, 0, fn item, acc -> acc + (item.weight_grams || 0) * item.quantity end)
  end

  defp zone_fee(zone, opts) do
    subtotal = Keyword.get(opts, :subtotal_pesewas)
    weight = Keyword.get(opts, :total_weight_grams)

    if free_above?(zone, subtotal) do
      0
    else
      zone.fee + weight_surcharge(zone, weight)
    end
  end

  defp free_above?(%{free_above_pesewas: threshold}, subtotal)
       when is_integer(threshold) and is_integer(subtotal),
       do: subtotal >= threshold

  defp free_above?(_zone, _subtotal), do: false

  # Integer ceiling: div(grams + 999, 1000) charges every started kg.
  defp weight_surcharge(%{per_kg_fee_pesewas: per_kg}, grams)
       when is_integer(per_kg) and is_integer(grams) and grams > 0,
       do: per_kg * div(grams + 999, 1000)

  defp weight_surcharge(_zone, _grams), do: 0

  defp normalise_region(value) do
    value
    |> String.downcase()
    |> String.replace("_", " ")
    |> String.trim()
  end
end
