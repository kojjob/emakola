defmodule Emakola.Suppliers.ListingImporter do
  @moduledoc """
  Transactional one-click import of a published supplier offer into a reseller catalog.

  The reseller receives normal Product/Variant records so the existing storefront,
  cart, fulfillment, and split-settlement paths work unchanged. Mapping resources
  retain source identity for later synchronization; no source fields are added to
  the core catalog schemas.
  """

  require Ash.Query

  alias Emakola.Catalog.{OptionType, OptionValue, VariantOptionValue}
  alias Emakola.Suppliers
  alias Emakola.Suppliers.{Network, Offers, ResellerListing}

  def import(actor, reseller_store_id, offer, retail_prices \\ %{}) do
    with {:ok, available} <- Offers.list_available(actor, reseller_store_id),
         {:ok, authorized_offer} <- find_offer(available, offer.id),
         :ok <- ensure_not_imported(authorized_offer.id, reseller_store_id),
         {:ok, priced_variants} <- price_variants(authorized_offer, retail_prices) do
      import_transaction(reseller_store_id, authorized_offer, priced_variants)
    end
  end

  def import_approved_franchise_offer(reseller_store_id, offer) do
    offer =
      Ash.load!(
        offer,
        [:wholesaler_store, source_product: :images, offer_variants: :source_variant],
        authorize?: false
      )

    with true <- offer.status == :published,
         true <- active_connection?(offer.wholesaler_store_id, reseller_store_id),
         {:ok, priced_variants} <- price_variants(offer, %{}) do
      case existing_listing(offer.id, reseller_store_id) do
        nil -> import_transaction(reseller_store_id, offer, priced_variants)
        listing -> activate_existing_listing(listing)
      end
    else
      false -> {:error, :offer_not_available}
      error -> error
    end
  end

  # `opts[:preload]` is opt-in — most of this function's callers (dashboard
  # widgets, sales-kit/content-draft/group-buy authorization) never touch
  # source-variant data, so the extra `listing_variants: [offer_variant:
  # :source_variant]` join is only loaded for callers that ask for it (the
  # supply-network LiveView's badge-rendering listings tab).
  def list(actor, store_id, opts \\ []) do
    with {:ok, _connections} <- Network.list_for_store(actor, store_id),
         {:ok, listings} <-
           Suppliers.list_reseller_listings_for_store(store_id, authorize?: false) do
      {:ok, maybe_preload_source_variants(listings, opts[:preload])}
    end
  end

  defp maybe_preload_source_variants(listings, :source_variants) do
    Ash.load!(listings, [listing_variants: [offer_variant: :source_variant]], authorize?: false)
  end

  defp maybe_preload_source_variants(listings, _no_preload), do: listings

  def sync(actor, listing) do
    with {:ok, _connections} <- Network.list_for_store(actor, listing.reseller_store_id) do
      listing =
        Ash.load!(
          listing,
          [
            :reseller_product,
            offer: [:source_product, offer_variants: :source_variant],
            listing_variants: [:reseller_variant, :offer_variant]
          ],
          authorize?: false
        )

      if source_active_for_reseller?(listing),
        do: sync_active_listing(listing),
        else: pause_listing(listing)
    end
  end

  def pause_offer_listings!(offer_id) do
    ResellerListing
    |> Ash.Query.filter(offer_id == ^offer_id and status == :active)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn listing ->
      listing
      |> Ash.load!([listing_variants: :reseller_variant], authorize?: false)
      |> pause_listing!()
    end)

    :ok
  end

  def pause_connection_listings!(wholesaler_store_id, reseller_store_id) do
    offer_ids =
      Emakola.Suppliers.SupplierOffer
      |> Ash.Query.filter(wholesaler_store_id == ^wholesaler_store_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    if offer_ids != [] do
      ResellerListing
      |> Ash.Query.filter(
        offer_id in ^offer_ids and reseller_store_id == ^reseller_store_id and status == :active
      )
      |> Ash.read!(authorize?: false)
      |> Enum.each(fn listing ->
        listing
        |> Ash.load!([listing_variants: :reseller_variant], authorize?: false)
        |> pause_listing!()
      end)
    end

    :ok
  end

  defp import_transaction(reseller_store_id, offer, priced_variants) do
    case Emakola.Repo.transaction(fn ->
           supplier = find_or_create_supplier!(reseller_store_id, offer)
           product = create_product!(reseller_store_id, offer.source_product)

           option_value_map =
             clone_options!(reseller_store_id, offer.source_product_id, product.id)

           listing =
             Suppliers.create_reseller_listing!(
               %{
                 offer_id: offer.id,
                 reseller_store_id: reseller_store_id,
                 reseller_product_id: product.id,
                 supplier_id: supplier.id,
                 synced_at: DateTime.utc_now()
               },
               authorize?: false
             )

           Enum.each(priced_variants, fn {terms, retail_price} ->
             reseller_variant =
               create_variant!(reseller_store_id, product.id, supplier.id, terms, retail_price)

             clone_variant_options!(
               reseller_store_id,
               terms.source_variant_id,
               reseller_variant.id,
               option_value_map
             )

             Suppliers.create_reseller_listing_variant!(
               %{
                 listing_id: listing.id,
                 offer_variant_id: terms.id,
                 reseller_variant_id: reseller_variant.id,
                 retail_price: retail_price
               },
               authorize?: false
             )
           end)

           create_image_mappings!(listing, product, offer.source_product.images)
           activated = Emakola.Catalog.activate_product!(product, authorize?: false)
           {listing, activated}
         end) do
      {:ok, {listing, _product}} ->
        enqueue_image_replication(listing.id)

        {:ok,
         Ash.load!(
           listing,
           [:supplier, listing_variants: :reseller_variant, reseller_product: [:variants]],
           authorize?: false
         )}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sync_active_listing(listing) do
    case Emakola.Repo.transaction(fn ->
           source = listing.offer.source_product

           Emakola.Catalog.update_product!(
             listing.reseller_product,
             %{
               title: source.title,
               description: source.description,
               tags: source.tags,
               seo_title: source.seo_title,
               seo_description: source.seo_description,
               product_type: source.product_type
             },
             authorize?: false
           )

           terms_by_id = Map.new(listing.offer.offer_variants, &{&1.id, &1})

           Enum.each(listing.listing_variants, fn mapping ->
             terms = Map.fetch!(terms_by_id, mapping.offer_variant_id)

             retail_price =
               synced_retail_price(listing.offer.earning_model, terms, mapping.retail_price)

             source_variant = terms.source_variant

             Emakola.Catalog.update_variant!(
               mapping.reseller_variant,
               %{
                 price: retail_price,
                 cost_price: terms.supplier_price,
                 weight_grams: source_variant.weight_grams,
                 barcode: source_variant.barcode
               },
               authorize?: false
             )

             # Same sync formula SupplierStockSyncWorker uses to compute
             # availability — written through the dedicated
             # `:sync_availability` action (not folded into the `:update`
             # call above) so it stamps/clears `supplier_sync_paused_at`
             # correctly, instead of being cleared by
             # `Changes.ClearSupplierSyncPause`, which is reserved for
             # genuinely manual writes.
             Emakola.Catalog.sync_availability_variant!(
               mapping.reseller_variant,
               %{
                 available:
                   source_variant.available and
                     Emakola.Catalog.Variant.in_stock?(source_variant)
               },
               authorize?: false
             )

             mapping
             |> Ash.Changeset.for_update(:record_price, %{retail_price: retail_price})
             |> Ash.update!(authorize?: false)
           end)

           listing
           |> Ash.Changeset.for_update(:activate, %{})
           |> Ash.update!(authorize?: false)
         end) do
      {:ok, updated} -> {:ok, updated}
      {:error, reason} -> {:error, reason}
    end
  end

  # Sets available:false for a LIFECYCLE reason (the offer this listing
  # depends on paused, or its supply connection was severed/suspended) —
  # NOT a stock-driven sync computation — so this deliberately does NOT
  # stamp `supplier_sync_paused_at` (via `:update`, which leaves the marker
  # nil through `Changes.ClearSupplierSyncPause`). Two reasons this is safe
  # rather than a gap: (1) `SupplierStockSyncWorker` only ever touches
  # `status == :active` listings, so a paused listing's marker is moot
  # regardless of its value while paused — a source restock cannot reach
  # it either way; (2) reactivating a listing always goes back through
  # `sync_active_listing/1`, which recomputes availability (and the
  # marker, via `:sync_availability`) fresh from CURRENT source state — any
  # stale marker value from before the pause is superseded there, never
  # read.
  defp pause_listing(listing) do
    case Emakola.Repo.transaction(fn ->
           Enum.each(listing.listing_variants, fn mapping ->
             Emakola.Catalog.update_variant!(mapping.reseller_variant, %{available: false},
               authorize?: false
             )
           end)

           listing
           |> Ash.Changeset.for_update(:pause, %{})
           |> Ash.update!(authorize?: false)
         end) do
      {:ok, updated} -> {:ok, updated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp pause_listing!(listing) do
    {:ok, updated} = pause_listing(listing)
    updated
  end

  defp source_active_for_reseller?(listing) do
    product = listing.offer.source_product

    listing.offer.status == :published and product.status == :active and
      product.moderation_status == :ok and active_connection?(listing)
  end

  defp active_connection?(listing) do
    active_connection?(listing.offer.wholesaler_store_id, listing.reseller_store_id)
  end

  defp active_connection?(wholesaler_store_id, reseller_store_id) do
    case Emakola.Suppliers.SupplyConnection
         |> Ash.Query.filter(
           wholesaler_store_id == ^wholesaler_store_id and
             reseller_store_id == ^reseller_store_id and status == :active
         )
         |> Ash.Query.limit(1)
         |> Ash.read(authorize?: false) do
      {:ok, [_]} -> true
      _ -> false
    end
  end

  defp synced_retail_price(:fixed_commission, terms, _current),
    do: terms.suggested_retail_price

  defp synced_retail_price(:markup, terms, current) do
    minimum = max(terms.suggested_retail_price, terms.supplier_price + 1)
    current = max(current, minimum)
    if terms.max_retail_price, do: min(current, terms.max_retail_price), else: current
  end

  defp create_product!(store_id, source) do
    Emakola.Catalog.create_product!(
      %{
        store_id: store_id,
        title: source.title,
        description: source.description,
        tags: source.tags,
        seo_title: source.seo_title,
        seo_description: source.seo_description,
        product_type: source.product_type
      },
      authorize?: false
    )
  end

  defp create_variant!(store_id, product_id, supplier_id, terms, retail_price) do
    source = terms.source_variant
    available = source.available and Emakola.Catalog.Variant.in_stock?(source)

    Emakola.Catalog.create_variant!(
      %{
        store_id: store_id,
        product_id: product_id,
        supplier_id: supplier_id,
        cost_price: terms.supplier_price,
        price: retail_price,
        sku: imported_sku(terms),
        barcode: source.barcode,
        weight_grams: source.weight_grams,
        position: source.position,
        available: available,
        track_inventory: false,
        stock_quantity: 0,
        # This snapshot uses the identical formula SupplierStockSyncWorker
        # uses — it IS a sync computation, not reseller intent, so an
        # out-of-stock-at-import listing must carry the marker. Without it,
        # the first restock afterward would see a nil marker, read it as
        # "reseller turned this off deliberately," and leave the listing
        # dark forever — the exact gap this feature exists to close.
        supplier_sync_paused_at: if(available, do: nil, else: DateTime.utc_now())
      },
      authorize?: false
    )
  end

  defp create_image_mappings!(listing, product, source_images) do
    Enum.each(source_images, fn image ->
      Suppliers.create_reseller_listing_image!(
        %{
          listing_id: listing.id,
          source_image_id: image.id,
          storage_key:
            "stores/#{listing.reseller_store_id}/products/#{product.id}/earn-#{image.id}#{image_extension(image)}"
        },
        authorize?: false
      )
    end)
  end

  defp enqueue_image_replication(listing_id) do
    %{listing_id: listing_id}
    |> Emakola.Suppliers.Workers.ListingImageReplicationWorker.new()
    |> Oban.insert()

    :ok
  end

  defp image_extension(%{content_type: "image/jpeg"}), do: ".jpg"
  defp image_extension(%{content_type: "image/png"}), do: ".png"
  defp image_extension(%{content_type: "image/webp"}), do: ".webp"
  defp image_extension(_image), do: ""

  defp clone_options!(store_id, source_product_id, reseller_product_id) do
    source_types =
      OptionType
      |> Ash.Query.filter(product_id == ^source_product_id)
      |> Ash.Query.sort(position: :asc)
      |> Ash.Query.load(:option_values)
      |> Ash.read!(authorize?: false)

    Enum.reduce(source_types, %{}, fn source_type, value_map ->
      local_type =
        OptionType
        |> Ash.Changeset.for_create(:create, %{
          store_id: store_id,
          product_id: reseller_product_id,
          name: source_type.name,
          position: source_type.position
        })
        |> Ash.create!(authorize?: false)

      Enum.reduce(source_type.option_values, value_map, fn source_value, acc ->
        local_value =
          OptionValue
          |> Ash.Changeset.for_create(:create, %{
            store_id: store_id,
            option_type_id: local_type.id,
            value: source_value.value,
            position: source_value.position
          })
          |> Ash.create!(authorize?: false)

        Map.put(acc, source_value.id, local_value.id)
      end)
    end)
  end

  defp clone_variant_options!(store_id, source_variant_id, reseller_variant_id, value_map) do
    VariantOptionValue
    |> Ash.Query.filter(variant_id == ^source_variant_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn link ->
      case Map.fetch(value_map, link.option_value_id) do
        {:ok, local_value_id} ->
          VariantOptionValue
          |> Ash.Changeset.for_create(:create, %{
            store_id: store_id,
            variant_id: reseller_variant_id,
            option_value_id: local_value_id
          })
          |> Ash.create!(authorize?: false)

        :error ->
          :ok
      end
    end)
  end

  defp find_or_create_supplier!(reseller_store_id, offer) do
    case Emakola.Suppliers.Supplier
         |> Ash.Query.filter(
           store_id == ^reseller_store_id and linked_store_id == ^offer.wholesaler_store_id
         )
         |> Ash.Query.limit(1)
         |> Ash.read_one(authorize?: false, tenant: reseller_store_id) do
      {:ok, %{} = supplier} ->
        supplier

      _ ->
        Suppliers.create_supplier!(
          %{
            store_id: reseller_store_id,
            linked_store_id: offer.wholesaler_store_id,
            name:
              "#{offer.wholesaler_store.name} · Earn #{String.slice(offer.wholesaler_store_id, 0, 6)}",
            active: true
          },
          authorize?: false
        )
    end
  end

  defp price_variants(offer, retail_prices) do
    Enum.reduce_while(offer.offer_variants, {:ok, []}, fn terms, {:ok, acc} ->
      price = Map.get(retail_prices, terms.id, terms.suggested_retail_price)

      if valid_retail_price?(offer.earning_model, terms, price, retail_prices) do
        {:cont, {:ok, [{terms, price} | acc]}}
      else
        {:halt, {:error, {:invalid_retail_price, terms.id}}}
      end
    end)
    |> case do
      {:ok, variants} -> {:ok, Enum.reverse(variants)}
      error -> error
    end
  end

  defp valid_retail_price?(:fixed_commission, terms, price, _retail_prices),
    do: price == terms.suggested_retail_price

  defp valid_retail_price?(:markup, terms, price, _retail_prices) do
    is_integer(price) and price > terms.supplier_price and
      (is_nil(terms.max_retail_price) or price <= terms.max_retail_price)
  end

  defp imported_sku(terms),
    do: "EARN-#{String.slice(terms.offer_id, 0, 8)}-#{String.slice(terms.id, 0, 8)}"

  defp find_offer(offers, offer_id) do
    case Enum.find(offers, &(&1.id == offer_id)) do
      nil -> {:error, :offer_not_available}
      offer -> {:ok, offer}
    end
  end

  defp ensure_not_imported(offer_id, reseller_store_id) do
    case ResellerListing
         |> Ash.Query.filter(offer_id == ^offer_id and reseller_store_id == ^reseller_store_id)
         |> Ash.Query.limit(1)
         |> Ash.read(authorize?: false) do
      {:ok, []} -> :ok
      {:ok, [_]} -> {:error, :listing_exists}
      {:error, reason} -> {:error, reason}
    end
  end

  defp existing_listing(offer_id, reseller_store_id) do
    ResellerListing
    |> Ash.Query.filter(offer_id == ^offer_id and reseller_store_id == ^reseller_store_id)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  defp activate_existing_listing(listing) do
    listing =
      Ash.load!(
        listing,
        [
          :reseller_product,
          offer: [:source_product, offer_variants: :source_variant],
          listing_variants: [:reseller_variant, :offer_variant]
        ],
        authorize?: false
      )

    with {:ok, _updated} <- sync_active_listing(listing) do
      {:ok, Ash.get!(ResellerListing, listing.id, authorize?: false)}
    end
  end
end
