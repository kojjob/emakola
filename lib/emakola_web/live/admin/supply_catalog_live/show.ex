defmodule EmakolaWeb.Admin.SupplyCatalogLive.Show do
  @moduledoc """
  Supplier offer detail. Product info, suggested retail, per-area dispatch
  fees, and supplier terms are always visible; wholesale price, margin, and
  the import action are gated behind an approved supply connection. The gate
  is enforced server-side in the import handler, not just hidden in markup.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.Offers
  alias EmakolaWeb.Live.Admin.SupplyStockStatus

  import EmakolaWeb.Admin.SupplyCatalogLive.Glyphs
  import EmakolaWeb.Admin.SupplyCatalogLive.ShowComponents
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

  defp offer_stock_status(offer) do
    SupplyStockStatus.aggregate(Enum.map(offer.offer_variants, & &1.source_variant))
  end

  defp margin(variant), do: variant.suggested_retail_price - variant.supplier_price

  defp margin_pct(variant) do
    Float.round(margin(variant) * 100 / variant.supplier_price, 1)
  end

  # The wholesaler's own category name. Store-scoped, so it says what THEY
  # call it and claims nothing about anybody else's catalogue.
  defp offer_category(offer) do
    case offer.source_product.category do
      %{name: name} -> name
      _ -> nil
    end
  end

  defp primary_image_url(product) do
    product.images
    |> List.wrap()
    |> Enum.sort_by(&Map.get(&1, :position, 0))
    |> List.first()
    |> case do
      nil -> nil
      image -> image.url
    end
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

    {min_margin, max_margin} = Enum.min_max(margins)

    %{
      retail: format_price_range(retail_min, retail_max, "GHS"),
      wholesale: format_price_range(wholesale_min, wholesale_max, "GHS"),
      margin: format_price_range(min_margin, max_margin, "GHS"),
      margin_pct: margin_pct_label(margin_pcts)
    }
  end

  defp margin_pct_label(margin_pcts) do
    {min_pct, max_pct} = Enum.min_max(margin_pcts)

    if min_pct == max_pct, do: "#{min_pct}%", else: "#{min_pct}%–#{max_pct}%"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 sm:px-6 pb-12">
      <div :if={@loading} class="py-16 text-center text-sm text-slate-400">Loading offer…</div>

      <div :if={!@loading and @offer} class="space-y-4">
        <.link
          navigate={~p"/admin/supply/catalog"}
          class="inline-flex items-center gap-1.5 text-sm text-text-muted hover:text-slate-700"
        >
          <.glyph name={:back} class="w-4 h-4" stroke_width="2" /> Browse suppliers
        </.link>

        <%!-- Identity. A 96px square, never a half-page well: most suppliers
              give us no photograph, and an empty frame that size was the
              loudest thing on the page. --%>
        <div class="rounded-card border border-border bg-surface shadow-sm p-6 flex items-start gap-5">
          <.identity_slot
            image_url={primary_image_url(@offer.source_product)}
            alt={@offer.source_product.title}
          />

          <div class="flex flex-col gap-2 min-w-0 grow">
            <div class="flex items-start justify-between gap-4">
              <h1 class="text-2xl font-extrabold tracking-tight text-text leading-tight">
                {@offer.source_product.title}
              </h1>
              <div class="flex items-center gap-2 shrink-0">
                <div id="offer-stock-badge">
                  <.supplier_stock_badge status={offer_stock_status(@offer)} />
                </div>
                <span
                  :if={@connection_status == :connected}
                  class="inline-flex items-center gap-1.5 rounded-full bg-primary px-2.5 py-1 text-[11px] font-bold text-white"
                >
                  <.glyph name={:check} class="w-3 h-3" stroke_width="2.6" /> Connected
                </span>
              </div>
            </div>

            <p class="flex flex-wrap items-center gap-2 text-sm text-text-muted">
              <.glyph name={:supplier} class="w-4 h-4 text-slate-400" />
              <span>
                Supplied by
                <span class="font-semibold text-slate-700">{@offer.wholesaler_store.name}</span>
              </span>
              <span
                :if={offer_category(@offer)}
                data-role="offer-category"
                class="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-bold text-text-muted"
              >
                {offer_category(@offer)}
              </span>
            </p>

            <p :if={@offer.source_product.description} class="text-sm leading-relaxed text-slate-600">
              {@offer.source_product.description}
            </p>
          </div>
        </div>

        <%!-- The money. Three tiles, the two a merchant cannot see yet drawn
              as covered values rather than emptied cells. --%>
        <% tiles = stat_tiles(@offer) %>
        <% connected? = @connection_status == :connected %>
        <div id="offer-money" class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <.money_tile
            label="Sells for"
            sub="suggested"
            value={tiles.retail}
            icon={:tag}
            tone={:info}
          />
          <.money_tile
            label="You pay"
            sub="wholesale"
            value={if connected?, do: tiles.wholesale}
            icon={:wallet}
            tone={:accent}
          />
          <.money_tile
            label="You keep"
            sub="your margin"
            value={if connected?, do: tiles.margin}
            value_role="margin-value"
            icon={:margin}
            tone={:primary}
          >
            <:delta>
              <span
                :if={connected? and tiles.margin_pct}
                data-role="margin-delta"
                class="rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-bold text-primary-hover tabular-nums"
              >
                {tiles.margin_pct}
              </span>
            </:delta>
          </.money_tile>
        </div>

        <%!-- The one action, in the same place in every state. --%>
        <.action_band
          :if={@connection_status == :none}
          icon={:connect}
          title="See your price and profit"
          detail={"#{@offer.wholesaler_store.name} reviews your request, then wholesale prices open up."}
          event="request_connection"
          action_label="Request connection"
        />
        <.action_band
          :if={connected?}
          icon={:add_to_store}
          title="Put it in your shop"
          detail="Price, description and stock are copied. Photos follow on their own."
          event="import_offer"
          action_label="Add to my store"
        />
        <div
          :if={@connection_status in [:pending, :unavailable]}
          id="catalog-cta"
          class="rounded-card border border-border bg-surface shadow-sm p-5 flex items-center gap-4"
        >
          <div class={[
            "w-13 h-13 shrink-0 rounded-control flex items-center justify-center",
            @connection_status == :pending && "bg-warning-soft text-warning",
            @connection_status == :unavailable && "bg-danger-soft text-danger"
          ]}>
            <.glyph
              name={if @connection_status == :pending, do: :waiting, else: :lock}
              class="w-6 h-6"
              stroke_width="1.9"
            />
          </div>
          <div class="flex flex-col gap-1 grow min-w-0">
            <span class="text-[17px] font-bold text-text">
              {if @connection_status == :pending, do: "Request sent", else: "Connection unavailable"}
            </span>
            <span :if={@connection_status == :pending} class="text-[13px] text-text-muted">
              {@offer.wholesaler_store.name} has not answered yet.
            </span>
            <.link
              :if={@connection_status == :unavailable}
              navigate={~p"/admin/settings/supply-network"}
              class="text-[13px] font-medium text-primary-hover hover:text-emerald-800"
            >
              Manage it from your Partners page
            </.link>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <%!-- Dispatch. Each area leads with the pin that identifies it, and
                an unquoted fee is a chip, not a dash. --%>
          <div class="rounded-card border border-border bg-surface shadow-sm overflow-hidden">
            <p class="flex items-center gap-2.5 px-5 py-3 bg-surface-subtle border-b border-slate-100 text-xs font-bold uppercase tracking-wider text-text-muted">
              <span class="w-9 h-9 rounded-control bg-cyan-50 text-cyan-600 flex items-center justify-center shrink-0">
                <.glyph name={:dispatch} class="w-[18px] h-[18px]" />
              </span>
              Dispatch cost by area
            </p>
            <div class="divide-y divide-slate-100">
              <div
                :for={area <- @offer.delivery_areas}
                class="flex items-center gap-3 px-5 py-3.5"
              >
                <div class={[
                  "w-8 h-8 rounded-[10px] flex items-center justify-center shrink-0",
                  @offer.dispatch_fees[area] && "bg-cyan-50 text-cyan-600",
                  is_nil(@offer.dispatch_fees[area]) && "bg-slate-100 text-slate-400"
                ]}>
                  <.glyph name={:area} class="w-[17px] h-[17px]" stroke_width="1.9" />
                </div>
                <span class="text-sm text-slate-700 grow">{area}</span>
                <span
                  :if={@offer.dispatch_fees[area]}
                  class="text-[15px] font-bold text-text tabular-nums"
                >
                  {format_price(@offer.dispatch_fees[area])}
                </span>
                <span
                  :if={is_nil(@offer.dispatch_fees[area])}
                  class="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-bold text-text-muted"
                >
                  Ask supplier
                </span>
              </div>
            </div>
          </div>

          <%!-- Terms. Two facts, each behind the icon that names it. --%>
          <div class="rounded-card border border-border bg-surface shadow-sm overflow-hidden">
            <p class="flex items-center gap-2.5 px-5 py-3 bg-surface-subtle border-b border-slate-100 text-xs font-bold uppercase tracking-wider text-text-muted">
              <span class="w-9 h-9 rounded-control bg-violet-50 text-violet-600 flex items-center justify-center shrink-0">
                <.glyph name={:warranty} class="w-[18px] h-[18px]" />
              </span>
              Supplier terms
            </p>
            <div class="divide-y divide-slate-100">
              <div :if={@offer.returns_window_days} class="flex items-start gap-3 px-5 py-4">
                <div class="w-9 h-9 rounded-[10px] bg-warning-soft text-warning flex items-center justify-center shrink-0">
                  <.glyph name={:returns} class="w-[19px] h-[19px]" stroke_width="1.9" />
                </div>
                <div class="flex flex-col gap-0.5">
                  <span class="text-sm font-bold text-text">
                    {@offer.returns_window_days} days to return
                  </span>
                  <span :if={@offer.return_terms} class="text-[13px] leading-relaxed text-text-muted">
                    {@offer.return_terms}
                  </span>
                </div>
              </div>
              <div :if={@offer.warranty_months} class="flex items-start gap-3 px-5 py-4">
                <div class="w-9 h-9 rounded-[10px] bg-info-soft text-info flex items-center justify-center shrink-0">
                  <.glyph name={:warranty} class="w-[19px] h-[19px]" stroke_width="1.9" />
                </div>
                <div class="flex flex-col gap-0.5">
                  <span class="text-sm font-bold text-text">
                    {@offer.warranty_months} months warranty
                  </span>
                  <span
                    :if={@offer.warranty_terms}
                    class="text-[13px] leading-relaxed text-text-muted"
                  >
                    {@offer.warranty_terms}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Variants. The locked cells lose the padlock emoji: a drawn lock
              and the same three words used everywhere else on the page. --%>
        <div class="rounded-card border border-border bg-surface shadow-sm overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-xs font-bold uppercase tracking-wider text-text-muted bg-surface-subtle">
                <th class="px-5 py-3">Variant</th>
                <th class="px-5 py-3 text-right">Sells for</th>
                <th class="px-5 py-3 text-right">You pay</th>
                <th class="px-5 py-3 text-right">
                  {if @offer.earning_model == :fixed_commission, do: "Commission", else: "You keep"}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr :for={variant <- @offer.offer_variants}>
                <td class="px-5 py-4">
                  <span class="flex items-center gap-2.5">
                    <span class="w-[30px] h-[30px] rounded-[9px] bg-info-soft text-info flex items-center justify-center shrink-0">
                      <.glyph name={:variant} class="w-4 h-4" />
                    </span>
                    <span class="text-slate-700">{variant.source_variant.sku || "Default"}</span>
                  </span>
                </td>
                <td class="px-5 py-4 text-right font-bold text-text tabular-nums">
                  {format_price(variant.suggested_retail_price)}
                  <span
                    :if={connected? and variant.max_retail_price}
                    class="block text-[11px] font-normal text-slate-400"
                  >
                    cap {format_price(variant.max_retail_price)}
                  </span>
                </td>
                <%= if connected? do %>
                  <td class="px-5 py-4 text-right text-slate-700 tabular-nums">
                    {format_price(variant.supplier_price)}
                  </td>
                  <td class="px-5 py-4 text-right font-bold text-primary-hover tabular-nums">
                    <%= if @offer.earning_model == :fixed_commission do %>
                      {format_price(variant.fixed_commission_amount || 0)}
                    <% else %>
                      {format_price(margin(variant))} ({margin_pct(variant)}%)
                    <% end %>
                  </td>
                <% else %>
                  <td :for={_ <- 1..2} class="px-5 py-4 text-right">
                    <span class="inline-flex items-center justify-end gap-1.5 text-[13px] text-slate-400">
                      <.glyph name={:lock} class="w-[15px] h-[15px] text-slate-300" stroke_width="2" />
                      Connect to see
                    </span>
                  </td>
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
