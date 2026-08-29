defmodule EmakolaWeb.Admin.SupplyNetworkLive.Presentation do
  @moduledoc "Presentation helpers and user-facing error copy for the supply-network page."

  alias Emakola.Suppliers.SalesSharing
  alias EmakolaWeb.Live.Admin.SupplyStockStatus

  def inventory_policy_options(offers) do
    for offer <- offers,
        variant <- offer.offer_variants do
      label = "#{offer.source_product.title} · #{String.slice(variant.id, 0, 6)}"
      {label, variant.id}
    end
  end

  def group_buy_options(listings) do
    Enum.flat_map(listings, fn listing ->
      Enum.map(listing.listing_variants, fn mapping ->
        {"#{listing.reseller_product.title} — #{money(mapping.retail_price)}", mapping.id}
      end)
    end)
  end

  def franchise_offer_options(offers),
    do: Enum.map(offers, &{&1.source_product.title, &1.id})

  def inventory_error(:not_eligible), do: "Your current passport tier does not meet this rule."
  def inventory_error(:reseller_limit_exceeded), do: "That exceeds the published reseller limit."
  def inventory_error(:insufficient_inventory), do: "The supplier no longer has enough stock."

  def inventory_error(:inventory_not_tracked),
    do: "The supplier must track this stock before reserving it."

  def inventory_error(_reason), do: "The inventory request could not be completed."

  def group_buy_error(:price_below_supplier_floor),
    do: "The campaign price cannot underpay the supplier."

  def group_buy_error(:deadline_must_be_future), do: "Choose a future campaign deadline."

  def group_buy_error(:refund_deadline_invalid),
    do: "The refund deadline must be after the campaign deadline."

  def group_buy_error(_reason), do: "The group buy could not be created."
  def sales_team_error(:merchant_not_found), do: "No Makola merchant uses that email."

  def sales_team_error(:split_total_must_equal_10000),
    do: "The two earnings percentages must total exactly 100%."

  def sales_team_error(_reason), do: "The sales team could not be created."

  def franchise_error(:package_incomplete),
    do: "Add training, brand rules, channels, and a published offer."

  def franchise_error(_reason), do: "The micro-franchise package could not be published."

  def partner(connection, current_store_id) do
    if connection.wholesaler_store_id == current_store_id,
      do: connection.reseller_store,
      else: connection.wholesaler_store
  end

  def incoming?(connection, current_store_id) do
    connection.status == :pending and connection.requested_by_store_id != current_store_id
  end

  def relationship_label(connection, current_store_id) do
    if connection.wholesaler_store_id == current_store_id,
      do: "You supply this store",
      else: "You sell this store's products"
  end

  def status_classes(:active), do: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
  def status_classes(:pending), do: "bg-amber-50 text-amber-700 ring-amber-600/20"
  def status_classes(:suspended), do: "bg-slate-100 text-slate-600 ring-slate-500/20"
  def status_classes(:rejected), do: "bg-rose-50 text-rose-700 ring-rose-600/20"
  def status_classes(:terminated), do: "bg-slate-100 text-slate-500 ring-slate-500/20"

  def fulfillment_status_classes(:pending), do: "bg-amber-50 text-amber-700"
  def fulfillment_status_classes(:notified), do: "bg-blue-50 text-blue-700"
  def fulfillment_status_classes(:shipped), do: "bg-violet-50 text-violet-700"
  def fulfillment_status_classes(:delivered), do: "bg-emerald-50 text-emerald-700"
  def fulfillment_status_classes(:cancelled), do: "bg-slate-100 text-slate-500"
  def fulfillment_status_classes(:declined), do: "bg-red-50 text-red-700"

  def content_status_classes(:draft), do: "bg-amber-50 text-amber-700"
  def content_status_classes(:approved), do: "bg-emerald-50 text-emerald-700"
  def content_status_classes(:rejected), do: "bg-rose-50 text-rose-700"
  def content_status_classes(:stale), do: "bg-slate-100 text-slate-600"

  def shipment_open?(fulfillment_id, selected_id), do: fulfillment_id == selected_id
  def delivery_open?(fulfillment_id, selected_id), do: fulfillment_id == selected_id

  def customer_city(order) do
    address = order.shipping_address || %{}
    Map.get(address, "city") || Map.get(address, :city) || "Delivery address on order"
  end

  def lead_image(offer), do: List.first(offer.source_product.images)

  def earning_range(offer) do
    earnings = Enum.map(offer.offer_variants, &(&1.suggested_retail_price - &1.supplier_price))

    case Enum.min_max(earnings, fn -> {0, 0} end) do
      {same, same} -> money(same)
      {minimum, maximum} -> "#{money(minimum)}–#{money(maximum)}"
    end
  end

  def supplier_terms(offer), do: Emakola.Themes.Terms.badges(%{page_content: offer})

  def supplier_backing_line(offer) do
    case supplier_terms(offer) do
      [] -> "Nothing stated — any returns or warranty you offer, you fund yourself."
      badges -> Enum.join(badges, " · ")
    end
  end

  def retail_range(offer) do
    prices = Enum.map(offer.offer_variants, & &1.suggested_retail_price)

    case Enum.min_max(prices, fn -> {0, 0} end) do
      {same, same} -> money(same)
      {minimum, maximum} -> "#{money(minimum)}–#{money(maximum)}"
    end
  end

  def offer_stock_status(offer) do
    SupplyStockStatus.aggregate(Enum.map(offer.offer_variants, & &1.source_variant))
  end

  def listing_stock_status(listing) do
    SupplyStockStatus.aggregate(
      Enum.map(listing.listing_variants, & &1.offer_variant.source_variant)
    )
  end

  def money(pesewas), do: "GH₵#{:erlang.float_to_binary(pesewas / 100, decimals: 2)}"

  def sales_share_url(share), do: SalesSharing.url(share)
  def sales_share_message(share), do: SalesSharing.message(share)

  def whatsapp_share_url(share),
    do: "https://wa.me/?text=#{URI.encode_www_form(sales_share_message(share))}"

  def facebook_share_url(share),
    do:
      "https://www.facebook.com/sharer/sharer.php?u=#{URI.encode_www_form(sales_share_url(share))}"

  def channel_label(:whatsapp), do: "WhatsApp"
  def channel_label(:facebook), do: "Facebook"
  def channel_label(:copy_link), do: "Copy link"

  def channel_icon(:whatsapp), do: "hero-chat-bubble-left-right"
  def channel_icon(:facebook), do: "hero-user-group"
  def channel_icon(:copy_link), do: "hero-link"

  def next_action_message(:publish), do: "Start by adding one recommended partner product."

  def next_action_message(:create_sales_kit),
    do: "Turn your first product into tracked share links."

  def next_action_message(:share), do: "Share a tracked link where customers already know you."

  def next_action_message(:follow_up),
    do: "People are viewing your links—follow up and answer questions."

  def next_action_message(:fulfill),
    do: "A customer ordered. Help the supplier complete delivery successfully."

  def journey_step(first_money, key, label, description) do
    %{
      key: key,
      complete?: Map.get(first_money, key, false),
      label: label,
      description: description
    }
  end
end
