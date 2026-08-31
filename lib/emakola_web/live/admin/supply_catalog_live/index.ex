defmodule EmakolaWeb.Admin.SupplyCatalogLive.Index do
  @moduledoc """
  Browse-all supplier catalog. Every published offer on the network is
  visible; wholesale pricing stays hidden until the merchant's connection
  to that wholesaler is approved (gating happens in Show — the index never
  renders wholesale numbers at all).
  """
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.Offers
  alias EmakolaWeb.Live.Admin.SupplyStockStatus

  import EmakolaWeb.Admin.SupplyCatalogLive.Glyphs
  import EmakolaWeb.Admin.SupplyCatalogLive.IndexComponents
  import EmakolaWeb.Helpers.Currency, only: [format_price: 1, format_price_range: 3]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Browse Suppliers",
        active_nav: :supply_catalog,
        search: "",
        search_form: to_form(%{"search" => ""}),
        mine_only?: false
      )

    socket =
      if connected?(socket) do
        assign(socket, loading: false, entries: load_entries(socket))
      else
        # Dead render is a shell — no SEO surface behind admin auth.
        assign(socket, loading: true, entries: [])
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) when is_binary(query) do
    {:noreply, assign(socket, search: query, search_form: to_form(%{"search" => query}))}
  end

  def handle_event("search", _params, socket), do: {:noreply, socket}

  # Both filters are cuts over the list the merchant is already allowed to
  # see, so there is nothing new to authorise: load_entries/1 did that.
  def handle_event("toggle_mine", _params, socket),
    do: {:noreply, assign(socket, mine_only?: !socket.assigns.mine_only?)}

  defp load_entries(socket) do
    with %{id: store_id} <- socket.assigns[:current_store],
         {:ok, entries} <- Offers.list_discoverable(socket.assigns.current_merchant, store_id) do
      entries
    else
      _ -> []
    end
  end

  defp filtered(entries, assigns) do
    entries
    |> search_filter(assigns.search)
    |> then(&if assigns.mine_only?, do: Enum.filter(&1, fn e -> e.connected? end), else: &1)
  end

  defp search_filter(entries, search) do
    case String.trim(String.downcase(search)) do
      "" ->
        entries

      needle ->
        Enum.filter(entries, fn %{offer: offer} ->
          String.contains?(String.downcase(offer.source_product.title), needle) or
            String.contains?(String.downcase(offer.wholesaler_store.name), needle)
        end)
    end
  end

  defp stock(offer),
    do: SupplyStockStatus.aggregate(Enum.map(offer.offer_variants, & &1.source_variant))

  # The margin is the number a reseller decides on, and it is the reason to
  # browse at all — but only a merchant the wholesaler has approved may see
  # it. `connected?` is computed server-side in Offers.list_discoverable/2.
  defp card_margin(_offer, false), do: nil

  defp card_margin(offer, true) do
    margins = Enum.map(offer.offer_variants, &(&1.suggested_retail_price - &1.supplier_price))
    {min, max} = Enum.min_max(margins)
    format_price_range(min, max, "GHS")
  end

  defp card_dispatch(offer) do
    case Map.values(offer.dispatch_fees) do
      [] ->
        nil

      fees ->
        {min, max} = Enum.min_max(fees)
        if min == max, do: format_price(min), else: format_price_range(min, max, "GHS")
    end
  end

  # The supplier's own category. Categories are store-scoped, so this is a
  # label about THEIR shop — there is no shared taxonomy to filter on, and
  # pretending otherwise would only work while every store runs the seeds.
  defp category_name(offer) do
    case offer.source_product.category do
      %{name: name} -> name
      _ -> nil
    end
  end

  defp card_price(offer) do
    prices = Enum.map(offer.offer_variants, & &1.suggested_retail_price)
    {min, max} = Enum.min_max(prices)
    format_price_range(min, max, "GHS")
  end

  defp first_image_url(offer) do
    case offer.source_product.images do
      [_ | _] = images ->
        img = images |> Enum.sort_by(&Map.get(&1, :position, 0)) |> List.first()
        Map.get(img, :thumbnail_url) || Map.get(img, :url)

      _ ->
        nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 pb-12">
      <.admin_page_header
        icon="hero-building-storefront"
        title="Browse Suppliers"
        subtitle="Products you can stock from suppliers across the network"
      >
        <.form
          for={@search_form}
          id="supply-catalog-search-form"
          phx-change="search"
          class="w-full sm:w-72"
        >
          <.input
            field={@search_form[:search]}
            type="text"
            value={@search}
            placeholder="Search products or suppliers…"
            phx-debounce="200"
            class="w-full rounded-control border border-border px-3 py-2.5 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary"
          />
        </.form>
      </.admin_page_header>

      <div :if={@loading} class="py-16 text-center text-sm text-slate-400">
        Loading catalog…
      </div>

      <%!-- One cut, leading with its symbol; the word is the fallback, not the
            channel. An "in stock" filter was drawn and then dropped: an offer
            with no available variant is not discoverable in the first place
            (Offers.discoverable?/1), so it would have filtered nothing. --%>
      <div :if={!@loading} class="flex flex-wrap items-center gap-2.5 mb-4">
        <button
          phx-click="toggle_mine"
          class={[
            "inline-flex items-center gap-2 h-10 px-3.5 rounded-control text-[13px] font-bold",
            "cursor-pointer transition-colors",
            @mine_only? && "bg-primary-soft border border-emerald-200 text-primary-hover",
            !@mine_only? && "bg-surface border border-border text-slate-600 hover:bg-surface-subtle"
          ]}
        >
          <.glyph name={:connect} class="w-[19px] h-[19px]" stroke_width="1.9" /> My suppliers
        </button>
      </div>

      <div
        :if={!@loading and filtered(@entries, assigns) == []}
        class="py-16 text-center text-sm text-slate-500"
      >
        No supplier products match. Suppliers publish offers from their Partners page.
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <.offer_card
          :for={%{offer: offer, connected?: connected?} <- filtered(@entries, assigns)}
          id={"offer-card-#{offer.id}"}
          href={~p"/admin/supply/catalog/#{offer.id}"}
          title={offer.source_product.title}
          supplier={offer.wholesaler_store.name}
          image_url={first_image_url(offer)}
          price={card_price(offer)}
          margin={card_margin(offer, connected?)}
          connected?={connected?}
          stock={stock(offer)}
          dispatch={card_dispatch(offer)}
          category={category_name(offer)}
        />
      </div>
    </div>
    """
  end
end
