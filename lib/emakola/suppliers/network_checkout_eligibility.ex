defmodule Emakola.Suppliers.NetworkCheckoutEligibility do
  @moduledoc "Enforces payout and coupon launch rules for imported Earn products."

  require Ash.Query

  alias Emakola.Suppliers.ResellerListingVariant

  def validate(store_id, variants, opts) when is_map(variants) do
    mappings = mappings(store_id, Map.keys(variants))

    if mappings == [] do
      :ok
    else
      validate_network_order(store_id, mappings, opts)
    end
  end

  defp validate_network_order(store_id, mappings, opts) do
    if Keyword.get(opts, :coupon_id) do
      {:error, :network_coupon_not_allowed}
    else
      with :ok <- verified_payout(store_id, :reseller_payout_unverified),
           :ok <- verify_wholesaler_payouts(mappings) do
        :ok
      end
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
    |> Ash.Query.load(listing: :offer)
    |> Ash.read!(authorize?: false)
  end

  defp verify_wholesaler_payouts(mappings) do
    mappings
    |> Enum.map(& &1.listing.offer.wholesaler_store_id)
    |> Enum.uniq()
    |> Enum.reduce_while(:ok, fn store_id, :ok ->
      case verified_payout(store_id, :wholesaler_payout_unverified) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp verified_payout(store_id, error) do
    case Emakola.Stores.get_payout_account(store_id, authorize?: false) do
      {:ok, %{verification_status: :verified, subaccount_code: code}}
      when is_binary(code) and code != "" ->
        :ok

      _ ->
        {:error, error}
    end
  end
end
