defmodule EmakolaWeb.Admin.SupplyCatalogLive.Index do
  @moduledoc """
  Browse-all supplier catalog. Every published offer on the network is
  visible; wholesale pricing stays hidden until the merchant's connection
  to that wholesaler is approved (gating happens in Show — the index never
  renders wholesale numbers at all).
  """
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.Offers

  import EmakolaWeb.Helpers.Currency, only: [format_price: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Browse Suppliers",
        active_nav: :supply_catalog,
        search: "",
        search_form: to_form(%{"search" => ""})
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

  defp load_entries(socket) do
    with %{id: store_id} <- socket.assigns[:current_store],
         {:ok, entries} <- Offers.list_discoverable(socket.assigns.current_merchant, store_id) do
      entries
    else
      _ -> []
    end
  end

  defp filtered(entries, search) do
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

  defp first_image_url(offer) do
    case offer.source_product.images do
      [_ | _] = images ->
        img = images |> Enum.sort_by(&Map.get(&1, :position, 0)) |> List.first()
        Map.get(img, :thumbnail_url) || Map.get(img, :url)

      _ ->
        nil
    end
  end

  defp retail_range(offer) do
    prices = Enum.map(offer.offer_variants, & &1.suggested_retail_price)
    {Enum.min(prices), Enum.max(prices)}
  end

  defp dispatch_label(offer) do
    case Map.values(offer.dispatch_fees) do
      [] ->
        "Dispatch —"

      fees ->
        {min, max} = {Enum.min(fees), Enum.max(fees)}

        if min == max,
          do: "#{format_price(min)} dispatch",
          else: "#{format_price(min)}–#{format_price(max)} dispatch"
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

      <div
        :if={!@loading and filtered(@entries, @search) == []}
        class="py-16 text-center text-sm text-slate-500"
      >
        No supplier products match. Suppliers publish offers from their Partners page.
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <.link
          :for={%{offer: offer, connected?: connected?} <- filtered(@entries, @search)}
          navigate={~p"/admin/supply/catalog/#{offer.id}"}
          class="group rounded-2xl border border-slate-200 bg-white overflow-hidden hover:shadow-md transition-shadow"
        >
          <div class="aspect-[4/3] bg-slate-100 overflow-hidden">
            <img
              :if={first_image_url(offer)}
              src={first_image_url(offer)}
              alt={offer.source_product.title}
              class="w-full h-full object-cover group-hover:scale-[1.02] transition-transform"
            />
          </div>
          <div class="p-4 space-y-1.5">
            <div class="flex items-start justify-between gap-2">
              <p class="min-w-0 flex-1 font-semibold text-sm text-slate-900 truncate">
                {offer.source_product.title}
              </p>
              <span
                :if={connected?}
                class="shrink-0 text-[10px] font-semibold uppercase tracking-wide text-emerald-700 bg-emerald-50 rounded-full px-2 py-0.5"
              >
                Connected
              </span>
            </div>
            <p class="text-xs text-slate-500 truncate">{offer.wholesaler_store.name}</p>
            <p class="text-sm font-medium text-slate-800">
              {retail_range(offer)
              |> then(fn {min, max} ->
                if min == max,
                  do: format_price(min),
                  else: "#{format_price(min)} – #{format_price(max)}"
              end)} <span class="text-xs text-slate-400">suggested retail</span>
            </p>
            <p class="text-xs text-slate-500">{dispatch_label(offer)}</p>
            <div class="flex flex-wrap gap-1 pt-1">
              <span
                :for={area <- offer.delivery_areas}
                class="text-[10px] text-slate-600 bg-slate-100 rounded-full px-2 py-0.5"
              >
                {area}
              </span>
            </div>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
