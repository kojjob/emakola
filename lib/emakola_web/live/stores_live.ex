defmodule EmakolaWeb.StoresLive do
  @moduledoc """
  Public marketplace directory at `/stores`.

  Phase 1 sections:
  - Sticky header (logo + search + Sell-on-Emakola CTA)
  - Hero with prominent search input
  - Theme filter chips + region dropdown + sort dropdown
  - Paginated main grid via `Store.list_with_filters` (cursor-style
    "load more" rather than page numbers)

  Subsequent phases add featured carousel, recently-viewed,
  favorites, map view — see plan.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  alias Emakola.Stores.Store
  alias EmakolaWeb.StoresComponents

  @per_page 12

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Browse Stores — Emakola",
        active_theme: "all",
        active_region: "",
        active_sort: "featured",
        search_query: "",
        offset: 0,
        per_page: @per_page,
        has_more: true,
        total_active: count_active_stores(),
        featured_stores: load_featured(),
        recent_stores: load_recent(),
        editor_picks: load_editor_picks()
      )
      |> load_grid(reset: true)
      |> load_theme_counts()

    {:ok, socket, layout: false}
  end

  # ── Events ──

  @impl true
  def handle_event("update_search", %{"value" => query}, socket) do
    {:noreply,
     socket
     |> assign(search_query: query, offset: 0)
     |> load_grid(reset: true)}
  end

  def handle_event("update_search", %{"search" => query}, socket) do
    handle_event("update_search", %{"value" => query}, socket)
  end

  def handle_event("select_theme", %{"theme" => theme}, socket) do
    {:noreply,
     socket
     |> assign(active_theme: theme, offset: 0)
     |> load_grid(reset: true)}
  end

  def handle_event("select_region", %{"region" => region}, socket) do
    {:noreply,
     socket
     |> assign(active_region: region, offset: 0)
     |> load_grid(reset: true)}
  end

  def handle_event("select_sort", %{"sort" => sort}, socket) do
    {:noreply,
     socket
     |> assign(active_sort: sort, offset: 0)
     |> load_grid(reset: true)}
  end

  def handle_event("load_more", _params, socket) do
    {:noreply, load_grid(socket, reset: false)}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(
       active_theme: "all",
       active_region: "",
       active_sort: "featured",
       search_query: "",
       offset: 0
     )
     |> load_grid(reset: true)}
  end

  # Phase 3 placeholder — does nothing yet.
  def handle_event("toggle_favorite", _params, socket), do: {:noreply, socket}

  # ── Render ──

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0c1526] text-slate-100">
      <%!-- Header --%>
      <header class="sticky top-0 z-40 backdrop-blur-md bg-[#0c1526]/85 border-b border-white/5">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <a href="/" class="flex items-center gap-2 font-bold text-lg tracking-tight">
              <span class="text-amber-400">●</span> emakola
            </a>

            <div class="hidden md:flex flex-1 max-w-md mx-8">
              <form phx-change="update_search" phx-submit="update_search" class="relative w-full">
                <input
                  type="text"
                  name="search"
                  value={@search_query}
                  phx-debounce="300"
                  placeholder="Search stores by name…"
                  class="w-full pl-10 pr-4 py-2 rounded-full bg-white/10 border border-white/10 text-sm text-white placeholder:text-white/50 focus:outline-none focus:ring-2 focus:ring-amber-400/40 focus:border-amber-400/60"
                />
                <span
                  class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-white/50 pointer-events-none"
                  style="font-size: 18px;"
                >
                  search
                </span>
              </form>
            </div>

            <a
              href="/"
              class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-amber-400 text-slate-900 text-sm font-semibold hover:bg-amber-300 transition-colors"
            >
              Sell on Emakola
            </a>
          </div>
        </div>
      </header>

      <%!-- Hero --%>
      <section class="relative overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-br from-[#0c1526] via-[#101a30] to-[#0c1526]">
        </div>
        <div class="absolute inset-0 opacity-30 [background-image:radial-gradient(rgba(212,168,67,0.15),transparent_50%)]">
        </div>

        <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-14 sm:py-20 text-center">
          <p class="text-xs font-semibold uppercase tracking-[0.3em] text-amber-400 mb-4">
            Browse the marketplace
          </p>
          <h1 class="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight mb-4 leading-tight text-white drop-shadow-sm">
            <%= if @total_active > 0 do %>
              Discover <span class="text-amber-400">{@total_active}</span>
              stores<br class="hidden sm:block" />
              <span class="text-white">across Ghana</span>
            <% else %>
              The marketplace is just getting started
            <% end %>
          </h1>
          <p class="text-base sm:text-lg text-white/90 max-w-2xl mx-auto mb-8">
            Verified shops. Mobile money. Doorstep delivery. Search by category, region, or just
            browse.
          </p>

          <%!-- Hero search (mirrors header search but oversized) --%>
          <form
            phx-change="update_search"
            phx-submit="update_search"
            class="relative max-w-xl mx-auto mb-6"
          >
            <input
              type="text"
              name="search"
              value={@search_query}
              phx-debounce="300"
              placeholder="Try 'beauty', 'kente', 'tomatoes'..."
              class="w-full pl-12 pr-4 py-4 rounded-2xl bg-white/95 border border-white/20 text-base text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-4 focus:ring-amber-400/40"
            />
            <span
              class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
              style="font-size: 22px;"
            >
              search
            </span>
          </form>

          <%!-- Trust pills --%>
          <div class="flex flex-wrap items-center justify-center gap-2 sm:gap-3 text-xs sm:text-sm font-medium text-white">
            <span class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-full bg-white/15 border border-white/25 backdrop-blur-sm">
              <span class="material-symbols-outlined text-emerald-300" style="font-size: 16px;">
                verified
              </span>
              Verified merchants
            </span>
            <span class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-full bg-white/15 border border-white/25 backdrop-blur-sm">
              <span class="material-symbols-outlined text-amber-300" style="font-size: 16px;">
                payments
              </span>
              Mobile money + cards
            </span>
            <span class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-full bg-white/15 border border-white/25 backdrop-blur-sm">
              <span class="material-symbols-outlined text-sky-300" style="font-size: 16px;">
                local_shipping
              </span>
              Doorstep delivery
            </span>
          </div>
        </div>
      </section>

      <%!-- Featured carousel (only when no filters applied) --%>
      <StoresComponents.featured_carousel
        :if={!filters_active?(assigns)}
        stores={@featured_stores}
      />

      <%!-- Filters bar --%>
      <section class="sticky top-16 z-30 backdrop-blur-md bg-[#0c1526]/85 border-y border-white/5">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-4 space-y-3">
          <div class="overflow-x-auto -mx-4 px-4 sm:mx-0 sm:px-0">
            <div class="min-w-max sm:min-w-0">
              <StoresComponents.filter_chips
                active_theme={@active_theme}
                counts={@theme_counts}
              />
            </div>
          </div>

          <div class="flex flex-wrap items-center justify-between gap-3">
            <div class="flex flex-wrap items-center gap-2">
              <StoresComponents.region_filter active_region={@active_region} />
              <StoresComponents.sort_dropdown active_sort={@active_sort} />
            </div>
            <p class="text-xs text-white/65">
              <span class="font-semibold text-white">{@total_filtered}</span>
              {if @total_filtered == 1, do: "store", else: "stores"}
              <button
                :if={filters_active?(assigns)}
                phx-click="clear_filters"
                class="ml-2 text-amber-400 hover:underline"
              >
                Clear filters
              </button>
            </p>
          </div>
        </div>
      </section>

      <%!-- Main grid --%>
      <section id="main-grid" class="bg-slate-50 text-slate-900 scroll-mt-32">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14">
          <div :if={@stores == []} class="text-center py-20">
            <span class="material-symbols-outlined text-slate-300" style="font-size: 80px;">
              storefront
            </span>
            <h2 class="text-xl font-bold text-slate-900 mt-4 mb-2">
              No stores match your filters
            </h2>
            <p class="text-sm text-slate-500 mb-6">
              Try a different search or clear the filters.
            </p>
            <button
              phx-click="clear_filters"
              class="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-slate-900 text-white text-sm font-semibold hover:bg-slate-700 transition-colors"
            >
              Clear filters
            </button>
          </div>

          <div
            :if={@stores != []}
            class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5 sm:gap-6"
          >
            <StoresComponents.store_card :for={store <- @stores} store={store} />
          </div>

          <div :if={@has_more} class="text-center mt-10">
            <button
              phx-click="load_more"
              class="inline-flex items-center gap-2 px-7 py-3 rounded-full bg-slate-900 text-white text-sm font-semibold hover:bg-slate-700 transition-colors"
            >
              Load more
              <span class="material-symbols-outlined" style="font-size: 18px;">expand_more</span>
            </button>
          </div>
        </div>
      </section>

      <%!-- New on Emakola strip (light section) — hidden when filtering --%>
      <div :if={!filters_active?(assigns)} class="bg-slate-50">
        <StoresComponents.recent_strip stores={@recent_stores} />
      </div>

      <%!-- Editor's picks (dark editorial) — hidden when filtering --%>
      <StoresComponents.editor_picks
        :if={!filters_active?(assigns)}
        stores={@editor_picks}
      />

      <%!-- Footer --%>
      <footer class="bg-[#0c1526] text-white/60 text-xs py-8 text-center">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <p>&copy; {DateTime.utc_now().year} Emakola — A marketplace for West Africa</p>
        </div>
      </footer>
    </div>
    """
  end

  defp filters_active?(assigns) do
    assigns.active_theme != "all" or
      assigns.active_region != "" or
      assigns.active_sort != "featured" or
      (assigns.search_query || "") != ""
  end

  # ── Data loading ──

  defp load_grid(socket, opts) do
    reset? = Keyword.get(opts, :reset, false)

    offset = if reset?, do: 0, else: socket.assigns.offset
    per_page = socket.assigns.per_page

    args = %{
      theme: socket.assigns.active_theme,
      region: socket.assigns.active_region,
      search: socket.assigns.search_query,
      sort: String.to_existing_atom(socket.assigns.active_sort),
      limit: per_page,
      offset: offset
    }

    new_page =
      Store
      |> Ash.Query.for_read(:list_with_filters, args)
      |> Ash.Query.load([:product_count])
      |> Ash.Query.limit(per_page)
      |> Ash.Query.offset(offset)
      |> Ash.read!(authorize?: false)

    total_filtered = filtered_count(args)
    next_offset = offset + length(new_page)

    stores =
      if reset? do
        new_page
      else
        socket.assigns.stores ++ new_page
      end

    socket
    |> assign(
      stores: stores,
      offset: next_offset,
      total_filtered: total_filtered,
      has_more: length(new_page) == per_page and next_offset < total_filtered
    )
  end

  defp filtered_count(args) do
    Store
    |> Ash.Query.for_read(:list_with_filters, args)
    |> Ash.count!(authorize?: false)
  rescue
    _ -> 0
  end

  defp count_active_stores do
    Store
    |> Ash.Query.filter(active == true)
    |> Ash.count!(authorize?: false)
  rescue
    _ -> 0
  end

  defp load_featured do
    Store
    |> Ash.Query.for_read(:list_featured, %{limit: 8})
    |> Ash.Query.limit(8)
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  defp load_recent do
    Store
    |> Ash.Query.for_read(:list_recent, %{limit: 6})
    |> Ash.Query.limit(6)
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  defp load_editor_picks do
    Store
    |> Ash.Query.for_read(:list_editor_picks)
    |> Ash.Query.limit(6)
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  defp load_theme_counts(socket) do
    counts =
      Enum.reduce(theme_ids(), %{"all" => count_active_stores()}, fn theme_id, acc ->
        n = filtered_count(%{theme: theme_id, region: nil, search: nil, sort: :featured})
        Map.put(acc, theme_id, n)
      end)

    assign(socket, :theme_counts, counts)
  end

  defp theme_ids do
    ~w(market atelier vibrant starter bold fresh pharmacy beauty home_living electronics fashion)
  end
end
