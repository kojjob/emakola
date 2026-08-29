defmodule Emakola.Suppliers.NetworkCheckoutEligibility do
  @moduledoc """
  Enforces coupon launch rules for imported Earn products. Payout
  verification is no longer a sale gate: unverified parties' shares accrue
  on the internal ledger (internal-settlement P3).
  """

  require Ash.Query

  alias Emakola.Suppliers.ResellerListingVariant

  def validate(store_id, variants, opts) when is_map(variants) do
    mappings = mappings(store_id, Map.keys(variants))

    if mappings == [] do
      :ok
    else
      validate_network_order(mappings, opts)
    end
  end

  defp validate_network_order(_mappings, opts) do
    if Keyword.get(opts, :coupon_id) do
      {:error, :network_coupon_not_allowed}
    else
      :ok
    end
  end

  def network_items?(store_id, variant_ids) when is_list(variant_ids),
    do: mappings(store_id, variant_ids) != []

  defp mappings(_store_id, []), do: []

  defp mappings(store_id, variant_ids) do
    ResellerListingVariant
    |> Ash.Query.filter(
      reseller_variant_id in ^variant_ids and listing.reseller_store_id == ^store_id and
        listing.status == :active
    )
    |> Ash.read!(authorize?: false)
  end
end
