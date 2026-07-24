defmodule EmakolaWeb.Admin.SupplyCatalogLive.Show do
  @moduledoc """
  Supplier offer detail. Product info, suggested retail, per-area dispatch
  fees, and supplier terms are always visible; wholesale price, margin, and
  the import action are gated behind an approved supply connection. The gate
  is enforced server-side in the import handler, not just hidden in markup.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.Offers

  import EmakolaWeb.Helpers.Currency, only: [format_price: 1, format_price_range: 3]

  @impl true
  def mount(%{"offer_id" => offer_id}, _session, socket) do
    socket = assign(socket, page_title: "Supplier offer", active_nav: :supply_catalog)

    if connected?(socket) do
      case load_offer(socket, offer_id) do
        {:ok, assigns} ->
          {:ok, assign(socket, Map.put(assigns, :loading, false))}

        {:error, _} ->
          {:ok,
           socket
           |> put_flash(:error, "This offer is no longer available.")
           |> push_navigate(to: ~p"/admin/supply/catalog")}
      end
    else
      {:ok, assign(socket, loading: true, offer: nil, connection_status: :none)}
    end
  end

  defp load_offer(socket, offer_id) do
    with %{id: store_id} <- socket.assigns[:current_store],
         {:ok, %{offer: offer, connection_status: status}} <-
           Offers.get_discoverable(socket.assigns.current_merchant, store_id, offer_id) do
      {:ok, %{offer: offer, connection_status: status, offer_id: offer_id}}
    else
      _ -> {:error, :not_found}
    end
  end

  @impl true
  def handle_event("request_connection", _params, socket) do
    store = socket.assigns.current_store

    result =
      Emakola.Suppliers.Network.request(socket.assigns.current_merchant, %{
        wholesaler_store_id: socket.assigns.offer.wholesaler_store_id,
        reseller_store_id: store.id,
        requested_by_store_id: store.id
      })

    case result do
      {:ok, _connection} ->
        {:noreply,
         socket
         |> assign(connection_status: :pending)
         |> put_flash(:info, "Connection requested. The supplier will review it.")}

      {:error, :connection_exists} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "A connection with this supplier already exists — manage it from your Partners page."
         )}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not request this connection right now.")}
    end
  end

  @impl true
  def handle_event("import_offer", _params, socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    # Server-side gate: re-check discoverability AND the connection before
    # importing — a crafted event must not bypass the markup gate.
    with {:ok, %{offer: offer, connection_status: :connected}} <-
           Offers.get_discoverable(actor, store.id, socket.assigns.offer_id),
         {:ok, _listing} <- Emakola.Suppliers.ListingImporter.import(actor, store.id, offer) do
      {:noreply,
       put_flash(socket, :info, "Product added to your store. Its images are being prepared.")}
    else
      {:error, :listing_exists} ->
        {:noreply, put_flash(socket, :info, "Already in your store.")}

      {:ok, %{connection_status: _not_connected}} ->
        {:noreply, put_flash(socket, :error, "Connect with this supplier first.")}

      _ ->
        {:noreply, put_flash(socket, :error, "This product could not be added right now.")}
    end
  end

  defp margin(variant), do: variant.suggested_retail_price - variant.supplier_price

  defp margin_pct(variant) do
    Float.round(margin(variant) * 100 / variant.supplier_price, 1)
  end

  defp sorted_images(product) do
    Enum.sort_by(product.images || [], &Map.get(&1, :position, 0))
  end

  # Margin economics for the stat tiles above the variants table. A single
  # variant reads its own numbers; multiple variants collapse to a min–max
  # range (format_price_range/3 already collapses to one price when
  # min == max). Uses the same retail-minus-wholesale margin() as the
  # per-row markup display regardless of earning model, so a fixed-commission
  # offer's tile still reflects what the reseller would keep on a straight
  # resale — the per-row table is what shows the actual commission amount.
  defp stat_tiles(offer) do
    variants = offer.offer_variants
    retail_prices = Enum.map(variants, & &1.suggested_retail_price)
    wholesale_prices = Enum.map(variants, & &1.supplier_price)
    margins = Enum.map(variants, &margin/1)
    margin_pcts = Enum.map(variants, &margin_pct/1)

    {retail_min, retail_max} = Enum.min_max(retail_prices)
    {wholesale_min, wholesale_max} = Enum.min_max(wholesale_prices)

    %{
      retail: format_price_range(retail_min, retail_max, "GHS"),
      wholesale: format_price_range(wholesale_min, wholesale_max, "GHS"),
      margin: margin_tile(margins, margin_pcts)
    }
  end

  defp margin_tile(margins, margin_pcts) do
    {min_margin, max_margin} = Enum.min_max(margins)
    {min_pct, max_pct} = Enum.min_max(margin_pcts)

    if min_margin == max_margin and min_pct == max_pct do
      "#{format_price(min_margin)} (#{min_pct}%)"
    else
      "#{format_price_range(min_margin, max_margin, "GHS")} (#{min_pct}%–#{max_pct}%)"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 sm:px-6 pb-12">
      <div :if={@loading} class="py-16 text-center text-sm text-slate-400">Loading offer…</div>

      <div :if={!@loading and @offer} class="space-y-6">
        <.link
          navigate={~p"/admin/supply/catalog"}
          class="text-sm text-slate-500 hover:text-slate-700"
        >
          ← Supplier catalog
        </.link>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- Gallery --%>
          <div class="space-y-2">
            <div class="aspect-square rounded-2xl bg-slate-100 overflow-hidden">
              <img
                :if={sorted_images(@offer.source_product) != []}
                src={List.first(sorted_images(@offer.source_product)).url}
                alt={@offer.source_product.title}
                class="w-full h-full object-cover"
              />
            </div>
            <div :if={length(sorted_images(@offer.source_product)) > 1} class="flex gap-2">
              <img
                :for={img <- Enum.drop(sorted_images(@offer.source_product), 1)}
                src={img.thumbnail_url || img.url}
                alt=""
                class="w-16 h-16 rounded-lg object-cover bg-slate-100"
              />
            </div>
          </div>

          <%!-- Summary + CTA --%>
          <div class="space-y-4">
            <div>
              <h1 class="text-2xl font-bold text-slate-900">{@offer.source_product.title}</h1>
              <p class="text-sm text-slate-500 mt-1">
                Supplied by <span class="font-medium">{@offer.wholesaler_store.name}</span>
                <span
                  :if={@connection_status == :connected}
                  class="ml-2 text-[10px] font-semibold uppercase tracking-wide text-emerald-700 bg-emerald-50 rounded-full px-2 py-0.5"
                >
                  Connected
                </span>
              </p>
            </div>

            <p :if={@offer.source_product.description} class="text-sm text-slate-600">
              {@offer.source_product.description}
            </p>

            <%!-- CTA block (buttons activated in later tasks: Task 6 wires
            "Request connection", Task 7 wires "Add to my store") --%>
            <div id="catalog-cta" class="rounded-2xl border border-slate-200 p-4 space-y-2">
              <p
                :if={@connection_status != :connected and @connection_status != :unavailable}
                class="text-sm text-slate-600"
              >
                Connect to see wholesale pricing and add this product to your store.
              </p>

              <button
                :if={@connection_status == :none}
                phx-click="request_connection"
                class="w-full rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold px-4 py-2.5"
              >
                Request connection
              </button>
              <button
                :if={@connection_status == :pending}
                disabled
                class="w-full rounded-xl bg-slate-200 text-slate-500 text-sm font-semibold px-4 py-2.5"
              >
                Request sent
              </button>
              <div :if={@connection_status == :unavailable} class="space-y-1.5">
                <button
                  disabled
                  class="w-full rounded-xl bg-slate-200 text-slate-500 text-sm font-semibold px-4 py-2.5"
                >
                  Connection unavailable
                </button>
                <p class="text-xs text-slate-500">
                  <.link
                    navigate={~p"/admin/settings/supply-network"}
                    class="text-emerald-700 hover:text-emerald-800 font-medium"
                  >
                    Manage it from your Partners page
                  </.link>
                </p>
              </div>
              <button
                :if={@connection_status == :connected}
                phx-click="import_offer"
                class="w-full rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold px-4 py-2.5"
              >
                Add to my store
              </button>
            </div>

            <%!-- Dispatch fees --%>
            <div class="rounded-2xl border border-slate-200 overflow-hidden">
              <p class="px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-slate-500 bg-slate-50">
                Dispatch cost by area
              </p>
              <div class="divide-y divide-slate-100">
                <div
                  :for={area <- @offer.delivery_areas}
                  class="flex items-center justify-between px-4 py-2.5 text-sm"
                >
                  <span class="text-slate-700">{area}</span>
                  <span :if={@offer.dispatch_fees[area]} class="font-medium text-slate-900">
                    {format_price(@offer.dispatch_fees[area])}
                  </span>
                  <span :if={is_nil(@offer.dispatch_fees[area])} class="text-slate-400">
                    — (ask supplier)
                  </span>
                </div>
              </div>
            </div>

            <%!-- Supplier terms --%>
            <div class="rounded-2xl border border-slate-200 p-4 space-y-2 text-sm">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Supplier terms
              </p>
              <p :if={@offer.returns_window_days} class="text-slate-700">
                Returns window: {@offer.returns_window_days} days
              </p>
              <p :if={@offer.return_terms} class="text-slate-600">{@offer.return_terms}</p>
              <p :if={@offer.warranty_months} class="text-slate-700">
                Warranty: {@offer.warranty_months} months
              </p>
              <p :if={@offer.warranty_terms} class="text-slate-600">{@offer.warranty_terms}</p>
            </div>
          </div>
        </div>

        <%!-- Margin economics stat tiles (connected only) --%>
        <div :if={@connection_status == :connected} class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <% tiles = stat_tiles(@offer) %>
          <div class="rounded-2xl border border-slate-200 bg-white p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
              Suggested retail
            </p>
            <p class="text-2xl font-bold text-slate-900 mt-1">{tiles.retail}</p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Wholesale</p>
            <p class="text-2xl font-bold text-slate-900 mt-1">{tiles.wholesale}</p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Your margin</p>
            <p class="text-2xl font-bold text-emerald-700 mt-1">{tiles.margin}</p>
          </div>
        </div>

        <%!-- Variants table --%>
        <div class="rounded-2xl border border-slate-200 overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-xs uppercase tracking-wide text-slate-500 bg-slate-50">
                <th class="px-4 py-2.5">Variant</th>
                <th class="px-4 py-2.5 text-right">Suggested retail</th>
                <th class="px-4 py-2.5 text-right">
                  {if @connection_status == :connected, do: "Wholesale", else: "🔒"}
                </th>
                <th class="px-4 py-2.5 text-right">
                  <%= cond do %>
                    <% @connection_status != :connected -> %>
                      🔒
                    <% @offer.earning_model == :fixed_commission -> %>
                      Commission
                    <% true -> %>
                      Your margin
                  <% end %>
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr :for={variant <- @offer.offer_variants}>
                <td class="px-4 py-3 text-slate-700">
                  {variant.source_variant.sku || "Default"}
                </td>
                <td class="px-4 py-3 text-right font-medium text-slate-900">
                  {format_price(variant.suggested_retail_price)}
                  <span
                    :if={@connection_status == :connected and variant.max_retail_price}
                    class="block text-[11px] font-normal text-slate-400"
                  >
                    cap {format_price(variant.max_retail_price)}
                  </span>
                </td>
                <%= if @connection_status == :connected do %>
                  <td class="px-4 py-3 text-right text-slate-900">
                    {format_price(variant.supplier_price)}
                  </td>
                  <td class="px-4 py-3 text-right text-emerald-700 font-medium">
                    <%= if @offer.earning_model == :fixed_commission do %>
                      {format_price(variant.fixed_commission_amount || 0)}
                    <% else %>
                      {format_price(margin(variant))} ({margin_pct(variant)}%)
                    <% end %>
                  </td>
                <% else %>
                  <td class="px-4 py-3 text-right text-slate-300">
                    <span class="inline-flex items-center gap-1">🔒</span>
                  </td>
                  <td class="px-4 py-3 text-right text-slate-300">🔒</td>
                <% end %>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
