defmodule Emakola.Suppliers.Offers do
  @moduledoc """
  Authorized service boundary for SP3 supplier offers.

  Offers reference existing catalog products and variants. They never clone
  catalog content. Published discovery is restricted to resellers with an
  active `SupplyConnection` to the wholesaler.
  """

  require Ash.Query

  alias Emakola.Catalog.{Product, Variant}
  alias Emakola.Suppliers
  alias Emakola.Suppliers.{SupplierOffer, SupplierOfferVariant, SupplyConnection}

  def create_draft(actor, attrs) do
    store_id = attrs[:wholesaler_store_id]

    with :ok <- ensure_access(actor, store_id),
         {:ok, product} <- get_product(attrs[:source_product_id]),
         :ok <- ensure_product_owner(product, store_id) do
      Suppliers.create_supplier_offer(attrs, authorize?: false)
    end
  end

  def add_variant(actor, offer, attrs) do
    with :ok <- ensure_access(actor, offer.wholesaler_store_id),
         :ok <- ensure_editable(offer),
         {:ok, variant} <- get_variant(attrs[:source_variant_id]),
         :ok <- ensure_variant_owner(variant, offer),
         :ok <- validate_economics(offer.earning_model, attrs) do
      attrs =
        attrs
        |> Map.put(:offer_id, offer.id)
        |> Map.put(:wholesaler_store_id, offer.wholesaler_store_id)

      Suppliers.create_supplier_offer_variant(attrs, authorize?: false)
    end
  end

  @doc """
  Reprices one variant's terms. Allowed only while the offer is editable
  (`:draft` or `:paused`) — published economics are locked because importers
  priced against them; republish re-validates economics.
  """
  def update_variant(actor, offer, variant, attrs) do
    with :ok <- ensure_access(actor, offer.wholesaler_store_id),
         :ok <- ensure_editable(offer),
         :ok <- ensure_offer_variant(variant, offer) do
      variant
      |> Ash.Changeset.for_update(:update_terms, attrs)
      |> Ash.update(authorize?: false)
    end
  end

  @doc "Removes one variant's terms from an editable (draft/paused) offer."
  def remove_variant(actor, offer, variant) do
    with :ok <- ensure_access(actor, offer.wholesaler_store_id),
         :ok <- ensure_editable(offer),
         :ok <- ensure_offer_variant(variant, offer) do
      variant
      |> Ash.Changeset.for_destroy(:destroy)
      |> Ash.destroy(authorize?: false)
    end
  end

  def publish(actor, offer) do
    with :ok <- ensure_access(actor, offer.wholesaler_store_id),
         {:ok, product} <- get_product(offer.source_product_id),
         :ok <- ensure_publishable_product(product),
         {:ok, variants} <- offer_variants(offer.id),
         :ok <- ensure_publishable_variants(offer, variants) do
      Suppliers.publish_supplier_offer(offer, authorize?: false)
    end
  end

  @doc """
  Revises what this supplier will honour back to the reseller — the returns
  window, the warranty, and the prose behind them.

  Deliberately allowed on a *published* offer, unlike `add_variant/3`: the
  resellers already carrying these goods need the current terms, not the ones
  the offer launched with, and forcing a supplier to unpublish (which pauses
  every reseller's listing) just to correct a warranty would guarantee stale
  terms stay live.

  These terms are never quoted to a shopper. The merchant is the seller of
  record, so the storefront states the merchant's own policy; these are shown to
  the merchant so they can see what is — and is not — behind them.
  """
  def update_terms(actor, offer, attrs) do
    with :ok <- ensure_access(actor, offer.wholesaler_store_id) do
      offer
      |> Ash.Changeset.for_update(:update_terms, attrs)
      |> Ash.update(authorize?: false)
    end
  end

  def pause(actor, offer), do: owner_update_and_pause_listings(actor, offer, :pause)
  def archive(actor, offer), do: owner_update_and_pause_listings(actor, offer, :archive)

  @doc """
  Restores an archived offer to `:draft` so it can be edited and republished.
  Unlike `pause/2` and `archive/2`, there are no live reseller listings to
  pause — an archived offer was never discoverable — so this is a plain
  owner-authorized update.
  """
  def unarchive(actor, offer), do: owner_update(actor, offer, :unarchive)

  def list_owned(actor, store_id) do
    with :ok <- ensure_access(actor, store_id) do
      Suppliers.list_supplier_offers_owned_by_store(store_id, authorize?: false)
    end
  end

  def list_available(actor, reseller_store_id) do
    with :ok <- ensure_access(actor, reseller_store_id),
         {:ok, wholesaler_ids} <- connected_wholesaler_ids(reseller_store_id) do
      available_offers(wholesaler_ids)
    end
  end

  @doc """
  Every published, discoverable offer on the network EXCEPT the store's own —
  the browse-all supplier catalog. Each entry carries `connected?` so callers
  can gate wholesale pricing. Query-capped at 200 (scaling boundary; see spec).
  """
  def list_discoverable(actor, reseller_store_id) do
    with :ok <- ensure_access(actor, reseller_store_id),
         {:ok, connected_ids} <- connected_wholesaler_ids(reseller_store_id),
         {:ok, offers} <- discoverable_offers(reseller_store_id) do
      connected = MapSet.new(connected_ids)

      {:ok,
       Enum.map(offers, fn offer ->
         %{offer: offer, connected?: MapSet.member?(connected, offer.wholesaler_store_id)}
       end)}
    end
  end

  @doc """
  One discoverable offer for the catalog detail page, with the reseller's
  connection status toward its wholesaler:
  `:connected | :pending | :unavailable | :none`. A rejected, suspended, or
  terminated prior connection reports `:unavailable` rather than `:none` —
  `Network.request/2` rejects a duplicate request against any-status prior
  connection, so a fresh request could never succeed. `{:error, :not_found}`
  for drafts, paused/archived offers, undiscoverable products, and the
  store's own offers.
  """
  def get_discoverable(actor, reseller_store_id, offer_id) do
    with :ok <- ensure_access(actor, reseller_store_id) do
      query =
        SupplierOffer
        |> Ash.Query.filter(
          id == ^offer_id and status == :published and
            wholesaler_store_id != ^reseller_store_id
        )
        |> Ash.Query.load([
          :wholesaler_store,
          source_product: [:images, :category],
          offer_variants: :source_variant
        ])

      case Ash.read_one(query, authorize?: false) do
        {:ok, nil} ->
          {:error, :not_found}

        {:ok, offer} ->
          if discoverable?(offer) do
            {:ok,
             %{
               offer: offer,
               connection_status: connection_status(reseller_store_id, offer.wholesaler_store_id)
             }}
          else
            {:error, :not_found}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp owner_update(actor, offer, action) do
    with :ok <- ensure_access(actor, offer.wholesaler_store_id) do
      offer
      |> Ash.Changeset.for_update(action, %{})
      |> Ash.update(authorize?: false)
    end
  end

  defp owner_update_and_pause_listings(actor, offer, action) do
    case owner_update(actor, offer, action) do
      {:ok, updated} ->
        Emakola.Suppliers.ListingImporter.pause_offer_listings!(offer.id)
        {:ok, updated}

      error ->
        error
    end
  end

  defp available_offers([]), do: {:ok, []}

  defp available_offers(wholesaler_ids) do
    case SupplierOffer
         |> Ash.Query.filter(status == :published and wholesaler_store_id in ^wholesaler_ids)
         |> Ash.Query.sort(published_at: :desc)
         |> Ash.Query.load([
           :wholesaler_store,
           source_product: [:images, :category],
           offer_variants: :source_variant
         ])
         |> Ash.read(authorize?: false) do
      {:ok, offers} -> {:ok, Enum.filter(offers, &discoverable?/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp discoverable_offers(excluding_store_id) do
    case SupplierOffer
         |> Ash.Query.filter(status == :published and wholesaler_store_id != ^excluding_store_id)
         |> Ash.Query.sort(published_at: :desc)
         |> Ash.Query.limit(200)
         |> Ash.Query.load([
           :wholesaler_store,
           source_product: [:images, :category],
           offer_variants: :source_variant
         ])
         |> Ash.read(authorize?: false) do
      {:ok, offers} -> {:ok, Enum.filter(offers, &discoverable?/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp discoverable?(offer) do
    offer.source_product.status == :active and offer.source_product.moderation_status == :ok and
      Enum.any?(offer.offer_variants, &source_available?(&1.source_variant))
  end

  defp connected_wholesaler_ids(reseller_store_id) do
    case SupplyConnection
         |> Ash.Query.filter(reseller_store_id == ^reseller_store_id and status == :active)
         |> Ash.read(authorize?: false) do
      {:ok, connections} -> {:ok, Enum.map(connections, & &1.wholesaler_store_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp connection_status(reseller_store_id, wholesaler_store_id) do
    case SupplyConnection
         |> Ash.Query.filter(
           reseller_store_id == ^reseller_store_id and
             wholesaler_store_id == ^wholesaler_store_id
         )
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(1)
         |> Ash.read(authorize?: false) do
      {:ok, [%{status: :active} | _]} -> :connected
      {:ok, [%{status: :pending} | _]} -> :pending
      {:ok, [_ | _]} -> :unavailable
      _ -> :none
    end
  end

  defp offer_variants(offer_id) do
    SupplierOfferVariant
    |> Ash.Query.filter(offer_id == ^offer_id)
    |> Ash.Query.load(:source_variant)
    |> Ash.read(authorize?: false)
  end

  defp ensure_publishable_product(%{status: :active, moderation_status: :ok}), do: :ok
  defp ensure_publishable_product(_), do: {:error, :source_product_not_sellable}

  defp ensure_publishable_variants(_offer, []), do: {:error, :offer_requires_variants}

  defp ensure_publishable_variants(offer, variants) do
    cond do
      not Enum.any?(variants, &source_available?(&1.source_variant)) ->
        {:error, :offer_requires_available_variant}

      Enum.any?(variants, &(&1.source_variant.product_id != offer.source_product_id)) ->
        {:error, :variant_product_mismatch}

      Enum.any?(variants, &(validate_economics(offer.earning_model, Map.from_struct(&1)) != :ok)) ->
        {:error, :invalid_offer_economics}

      true ->
        :ok
    end
  end

  defp validate_economics(:markup, attrs) do
    supplier = attrs[:supplier_price]
    suggested = attrs[:suggested_retail_price]
    maximum = attrs[:max_retail_price]
    commission = attrs[:fixed_commission_amount]

    if is_integer(supplier) and is_integer(suggested) and suggested > supplier and
         (is_nil(maximum) or (is_integer(maximum) and maximum >= suggested)) and
         is_nil(commission),
       do: :ok,
       else: {:error, :invalid_markup_terms}
  end

  defp validate_economics(:fixed_commission, attrs) do
    supplier = attrs[:supplier_price]
    suggested = attrs[:suggested_retail_price]
    commission = attrs[:fixed_commission_amount]

    if is_integer(supplier) and is_integer(suggested) and is_integer(commission) and
         commission > 0 and suggested - supplier == commission and
         is_nil(attrs[:max_retail_price]),
       do: :ok,
       else: {:error, :invalid_fixed_commission_terms}
  end

  defp ensure_editable(%{status: status}) when status in [:draft, :paused], do: :ok
  defp ensure_editable(_), do: {:error, :offer_not_editable}

  defp ensure_product_owner(%{store_id: store_id}, store_id), do: :ok
  defp ensure_product_owner(_, _), do: {:error, :product_not_owned}

  defp ensure_variant_owner(%{store_id: store_id, product_id: product_id}, offer)
       when store_id == offer.wholesaler_store_id and product_id == offer.source_product_id,
       do: :ok

  defp ensure_variant_owner(_, _), do: {:error, :variant_not_owned}

  defp ensure_offer_variant(%{offer_id: offer_id}, %{id: offer_id}), do: :ok
  defp ensure_offer_variant(_, _), do: {:error, :variant_not_owned}

  defp source_available?(variant), do: variant.available and Variant.in_stock?(variant)

  defp get_product(nil), do: {:error, :product_not_found}
  defp get_product(id), do: normalize_get(Ash.get(Product, id, authorize?: false))
  defp get_variant(nil), do: {:error, :variant_not_found}
  defp get_variant(id), do: normalize_get(Ash.get(Variant, id, authorize?: false))

  defp normalize_get({:ok, nil}), do: {:error, :catalog_record_not_found}
  defp normalize_get({:ok, record}), do: {:ok, record}
  defp normalize_get({:error, _}), do: {:error, :catalog_record_not_found}

  defp ensure_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    case Emakola.Accounts.StoreMembership
         |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
         |> Ash.Query.limit(1)
         |> Ash.read(authorize?: false) do
      {:ok, [_]} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_access(_, _), do: {:error, :forbidden}
end
