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
  alias EmakolaWeb.Plugs.RecentlyViewedStores
  alias EmakolaWeb.StoresComponents

  @per_page 12

  @impl true
  def mount(_params, session, socket) do
    customer = socket.assigns[:current_customer]
    favorite_slugs = load_favorite_slugs(customer)
    recently_viewed_slugs = load_recently_viewed_slugs(session)

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
        editor_picks: load_editor_picks(),
        current_customer: customer,
        favorite_slugs: favorite_slugs,
        favorite_stores: load_stores_by_slug(favorite_slugs),
        recently_viewed_stores: load_stores_by_slug(recently_viewed_slugs),
        map_open: false
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
     |> assign(active_region: region, offset: 0, map_open: false)
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

  # Toggle a store as a customer favorite. No-ops (with a soft prompt
  # via flash) when the visitor isn't logged in as a customer — keeps
  # the ♡ button visually present for everyone but only persists for
  # authenticated customers.
  def handle_event("toggle_favorite", %{"slug" => slug}, socket) do
    case socket.assigns.current_customer do
      nil ->
        {:noreply,
         socket
         |> put_flash(:info, "Sign in as a customer to save stores.")}

      customer ->
        store = find_store_by_slug(slug)

        cond do
          is_nil(store) ->
            {:noreply, socket}

          slug in socket.assigns.favorite_slugs ->
            unfavorite_store(customer, store, socket)

          true ->
            favorite_store(customer, store, socket)
        end
    end
  end

  def handle_event("open_map", _params, socket) do
    {:noreply, assign(socket, :map_open, true)}
  end

  def handle_event("close_map", _params, socket) do
    {:noreply, assign(socket, :map_open, false)}
  end

  # ── Render ──

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-slate-900">
      <%!-- Header — clean white with subtle border --%>
      <header class="sticky top-0 z-40 backdrop-blur-md bg-white/90 border-b border-slate-200/80">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <a
              href="/"
              class="flex items-center gap-2 font-bold text-lg tracking-tight text-slate-900"
            >
              <span class="inline-flex items-center justify-center w-7 h-7 rounded-lg bg-gradient-to-br from-amber-400 to-amber-500 shadow-sm">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  class="w-4 h-4 text-white"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path d="M3 7l3-4h12l3 4v2a3 3 0 0 1-5 2 3 3 0 0 1-5 0 3 3 0 0 1-5 0 3 3 0 0 1-3-2V7Zm2 5a5 5 0 0 0 3-1 5 5 0 0 0 3 1 5 5 0 0 0 3-1 5 5 0 0 0 3 1v8a1 1 0 0 1-1 1h-3v-6h-4v6H6a1 1 0 0 1-1-1v-8Z" />
                </svg>
              </span>
              emakola
            </a>

            <div class="hidden md:flex flex-1 max-w-md mx-8">
              <form phx-change="update_search" phx-submit="update_search" class="relative w-full">
                <input
                  type="text"
                  name="search"
                  value={@search_query}
                  phx-debounce="300"
                  placeholder="Search stores by name…"
                  class="w-full pl-10 pr-4 py-2 rounded-full bg-slate-100 border border-slate-200 text-sm text-slate-900 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-400/40 focus:border-amber-400/60 focus:bg-white"
                />
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  aria-hidden="true"
                >
                  <circle cx="11" cy="11" r="7" />
                  <path d="m21 21-4.3-4.3" />
                </svg>
              </form>
            </div>

            <a
              href="/"
              class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-slate-900 text-white text-sm font-semibold hover:bg-slate-700 transition-colors shadow-sm"
            >
              Sell on Emakola
            </a>
          </div>
        </div>
      </header>

      <%!--
        Hero — light, premium treatment. Soft cream-to-white background
        with amber + emerald accent blobs (radial gradients) for warmth.
        All text is dark on light: no contrast guesswork, fully WCAG AAA.
      --%>
      <section class="relative overflow-hidden bg-gradient-to-b from-amber-50/40 via-white to-white">
        <%!-- Decorative warm gradient blobs (very subtle) --%>
        <div
          class="absolute -top-32 -right-32 w-96 h-96 rounded-full opacity-40 blur-3xl pointer-events-none"
          style="background: radial-gradient(circle, rgba(251,191,36,0.45), transparent 70%);"
        >
        </div>
        <div
          class="absolute -bottom-32 -left-32 w-96 h-96 rounded-full opacity-30 blur-3xl pointer-events-none"
          style="background: radial-gradient(circle, rgba(16,185,129,0.4), transparent 70%);"
        >
        </div>

        <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24 text-center">
          <p class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-100 text-amber-800 text-xs font-bold uppercase tracking-[0.2em] mb-5">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 16 16"
              class="w-3.5 h-3.5"
              fill="currentColor"
              aria-hidden="true"
            >
              <path d="M8 0 9.5 5 14.5 6 10.5 9.5 11.5 14.5 8 12 4.5 14.5 5.5 9.5 1.5 6 6.5 5 8 0Z" />
            </svg>
            Browse the marketplace
          </p>
          <h1 class="text-4xl sm:text-5xl lg:text-6xl font-black tracking-tight mb-5 leading-[1.05] text-slate-900">
            <%= if @total_active > 0 do %>
              Discover
              <span class="relative inline-block">
                <span class="relative z-10 text-amber-600">{@total_active}</span>
                <span class="absolute inset-x-0 bottom-1 h-3 bg-amber-200/70 -z-0"></span>
              </span>
              shops<br class="hidden sm:block" />
              <span class="text-slate-900">across Ghana</span>
            <% else %>
              The marketplace is just getting started
            <% end %>
          </h1>
          <p class="text-base sm:text-lg text-slate-600 max-w-2xl mx-auto mb-10 leading-relaxed">
            Verified shops. Mobile money. Doorstep delivery. Search by category, region,
            or just browse.
          </p>

          <%!-- Hero search — large, premium feel --%>
          <form
            phx-change="update_search"
            phx-submit="update_search"
            class="relative max-w-xl mx-auto mb-8"
          >
            <input
              type="text"
              name="search"
              value={@search_query}
              phx-debounce="300"
              placeholder="Try 'beauty', 'kente', 'tomatoes'..."
              class="w-full pl-14 pr-4 py-4 rounded-2xl bg-white border-2 border-slate-200 text-base text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-4 focus:ring-amber-400/30 focus:border-amber-400 shadow-lg shadow-slate-200/50"
            />
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              class="w-5 h-5 absolute left-5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <circle cx="11" cy="11" r="7" />
              <path d="m21 21-4.3-4.3" />
            </svg>
          </form>

          <%!-- Trust pills — solid colored chips, fully readable --%>
          <div class="flex flex-wrap items-center justify-center gap-2 sm:gap-3 text-sm font-semibold">
            <span class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white border border-slate-200 text-slate-800 shadow-sm">
              <span class="inline-flex items-center justify-center w-5 h-5 rounded-full bg-emerald-100">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  class="w-3.5 h-3.5 text-emerald-600"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M8.6 2.5a3 3 0 0 1 4.8 0 3 3 0 0 1 3.4 1.4 3 3 0 0 1 2.7 2.7 3 3 0 0 1 1.4 3.4 3 3 0 0 1 0 4.8 3 3 0 0 1-1.4 3.4 3 3 0 0 1-2.7 2.7 3 3 0 0 1-3.4 1.4 3 3 0 0 1-4.8 0 3 3 0 0 1-3.4-1.4 3 3 0 0 1-2.7-2.7 3 3 0 0 1-1.4-3.4 3 3 0 0 1 0-4.8 3 3 0 0 1 1.4-3.4 3 3 0 0 1 2.7-2.7A3 3 0 0 1 8.6 2.5Zm7.7 6.7a1 1 0 0 0-1.4-1.4l-4.4 4.4-1.7-1.7a1 1 0 1 0-1.4 1.4l2.4 2.4a1 1 0 0 0 1.4 0l5.1-5.1Z"
                    clip-rule="evenodd"
                  />
                </svg>
              </span>
              Verified merchants
            </span>
            <span class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white border border-slate-200 text-slate-800 shadow-sm">
              <span class="inline-flex items-center justify-center w-5 h-5 rounded-full bg-amber-100">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  class="w-3.5 h-3.5 text-amber-600"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path d="M2 7a3 3 0 0 1 3-3h14a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3V7Zm2 1v2h16V8H4Zm0 4v5a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-5H4Z" />
                </svg>
              </span>
              Mobile money + cards
            </span>
            <span class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white border border-slate-200 text-slate-800 shadow-sm">
              <span class="inline-flex items-center justify-center w-5 h-5 rounded-full bg-sky-100">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  class="w-3.5 h-3.5 text-sky-600"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path d="M3 4a1 1 0 0 0-1 1v11a3 3 0 0 0 3 3 3 3 0 0 0 6 0h2a3 3 0 0 0 6 0 3 3 0 0 0 3-3v-3.59L18.4 7H14V5a1 1 0 0 0-1-1H3Zm14 5h.59L20 11.41V13h-3V9ZM7 18.5a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3Zm10 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3Z" />
                </svg>
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

      <%!-- Filters bar — light, sticky, on a soft slate-50 strip --%>
      <section class="sticky top-16 z-30 backdrop-blur-md bg-white/90 border-y border-slate-200">
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
              <button
                phx-click="open_map"
                type="button"
                class="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-700 transition-colors"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M9 20l-5.5-3V4l5.5 3 6-3 5.5 3v13l-5.5-3-6 3z" />
                  <path d="M9 4v13M15 7v13" />
                </svg>
                Map
              </button>
            </div>
            <p class="text-sm text-slate-600">
              <span class="font-bold text-slate-900">{@total_filtered}</span>
              {if @total_filtered == 1, do: "store", else: "stores"}
              <button
                :if={filters_active?(assigns)}
                phx-click="clear_filters"
                class="ml-2 text-emerald-700 hover:text-emerald-800 hover:underline font-semibold"
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
            <StoresComponents.store_card
              :for={store <- @stores}
              store={store}
              is_favorite={store.slug in @favorite_slugs}
            />
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

      <%!-- "Your saved stores" — only when logged-in customer has favorites --%>
      <div
        :if={!filters_active?(assigns) && @current_customer && @favorite_stores != []}
        class="bg-rose-50/40"
      >
        <StoresComponents.recent_strip
          stores={@favorite_stores}
          title="Your saved stores"
          subtitle="Stores you've hearted on Emakola"
        />
      </div>

      <%!-- "Recently viewed" — only when cookie has slugs --%>
      <div
        :if={!filters_active?(assigns) && @recently_viewed_stores != []}
        class="bg-slate-50"
      >
        <StoresComponents.recent_strip
          stores={@recently_viewed_stores}
          title="Recently viewed"
          subtitle="Pick up where you left off"
        />
      </div>

      <%!-- New on Emakola strip (light section) — hidden when filtering --%>
      <div :if={!filters_active?(assigns)} class="bg-slate-50">
        <StoresComponents.recent_strip stores={@recent_stores} />
      </div>

      <%!-- Editor's picks (dark editorial) — hidden when filtering --%>
      <StoresComponents.editor_picks
        :if={!filters_active?(assigns)}
        stores={@editor_picks}
      />

      <%!-- Map view modal (Phase 3 / Track C). Renders nothing when closed. --%>
      <StoresComponents.map_view
        stores={@stores}
        active_region={@active_region}
        open={@map_open}
      />

      <%!-- Footer --%>
      <footer class="bg-slate-900 text-slate-300 text-sm py-10 text-center">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
          <p>
            &copy; {DateTime.utc_now().year} Emakola — A marketplace for West Africa
          </p>
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
      sort:
        Emakola.SafeAtom.to_atom_in(
          socket.assigns.active_sort,
          [:featured, :newest, :popular, :name],
          :featured
        ),
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

  # ── Phase 3: favorites + recently viewed ──

  defp load_favorite_slugs(nil), do: []

  defp load_favorite_slugs(customer) do
    case Emakola.Customers.list_favorite_stores(customer.id, actor: customer) do
      {:ok, favorites} ->
        favorites
        |> Enum.map(fn fav -> fav.store && fav.store.slug end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  # The recently_viewed_stores cookie is set by RecentlyViewedStores plug
  # on the connected (HTTP) request before LiveView mounts. We read it
  # from the session — Phoenix promotes Plug.Conn cookies into the
  # session map under the same key when they're :http_only and
  # :same_site Lax (our case).
  defp load_recently_viewed_slugs(session) do
    case Map.get(session, RecentlyViewedStores.cookie_name()) do
      cookie when is_binary(cookie) ->
        cookie
        |> String.split(",", trim: true)
        |> Enum.take(8)

      _ ->
        []
    end
  end

  defp load_stores_by_slug([]), do: []

  defp load_stores_by_slug(slugs) when is_list(slugs) do
    stores =
      Store
      |> Ash.Query.filter(active == true and slug in ^slugs)
      |> Ash.Query.load([:product_count])
      |> Ash.read!(authorize?: false)

    # Preserve cookie order (most-recent first); the DB query won't
    by_slug = Map.new(stores, &{&1.slug, &1})

    slugs
    |> Enum.map(&Map.get(by_slug, &1))
    |> Enum.reject(&is_nil/1)
  rescue
    _ -> []
  end

  defp find_store_by_slug(slug) when is_binary(slug) do
    Store
    |> Ash.Query.filter(active == true and slug == ^slug)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, store} -> store
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp favorite_store(customer, store, socket) do
    case Emakola.Customers.favorite_store(
           %{customer_id: customer.id, store_id: store.id},
           actor: customer
         ) do
      {:ok, _} ->
        new_slugs = [store.slug | socket.assigns.favorite_slugs]

        {:noreply,
         socket
         |> assign(
           favorite_slugs: new_slugs,
           favorite_stores: load_stores_by_slug(new_slugs)
         )}

      _ ->
        {:noreply, socket}
    end
  end

  defp unfavorite_store(customer, store, socket) do
    # Find the favorite row to destroy via the read action
    with {:ok, favorites} <- Emakola.Customers.list_favorite_stores(customer.id, actor: customer),
         %{} = favorite <- Enum.find(favorites, &(&1.store_id == store.id)),
         :ok <- Emakola.Customers.unfavorite_store(favorite, actor: customer) do
      new_slugs = Enum.reject(socket.assigns.favorite_slugs, &(&1 == store.slug))

      {:noreply,
       socket
       |> assign(
         favorite_slugs: new_slugs,
         favorite_stores: load_stores_by_slug(new_slugs)
       )}
    else
      _ -> {:noreply, socket}
    end
  end
end
