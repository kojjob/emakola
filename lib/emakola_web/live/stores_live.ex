defmodule EmakolaWeb.StoresLive do
  @moduledoc """
  Public marketplace directory at `/stores`.

  A mobile-first discovery surface for browsing active Makola shops by
  category, region, and search query. The main directory uses a LiveView
  stream so pagination does not retain duplicate rendered state.
  """
  use EmakolaWeb, :live_view

  require Logger

  alias Emakola.Stores.Directory
  alias Emakola.Stores.Store
  alias EmakolaWeb.Plugs.RecentlyViewedStores
  alias EmakolaWeb.SEO.Canonical
  alias EmakolaWeb.LandingComponents
  alias EmakolaWeb.StoresComponents

  @per_page 12

  @impl true
  def mount(_params, session, socket) do
    customer = socket.assigns[:current_customer]
    favorite_slugs = load_favorite_slugs(customer)
    recently_viewed_slugs = load_recently_viewed_slugs(session)

    featured_stores = Directory.spotlight(load_featured(), Date.utc_today())
    {hero, tiles} = split_spotlight(featured_stores)

    socket =
      socket
      |> assign(
        page_title: "Shop Ghanaian Stores Online | Makola",
        meta_description:
          "Discover independent Ghanaian shops on Makola. Browse by category or region, pay with mobile money or card, and shop from any phone.",
        canonical_url: Canonical.url("/stores"),
        og_image: url(~p"/images/og-image.png"),
        json_ld: EmakolaWeb.Helpers.SEO.json_ld_organization(),
        active_theme: "all",
        active_region: "",
        active_sort: "featured",
        search_query: "",
        search_form: to_form(%{"query" => ""}, as: :search),
        filter_form: to_form(%{"region" => "", "sort" => "featured"}, as: :filters),
        offset: 0,
        per_page: @per_page,
        has_more: true,
        stores_empty?: true,
        map_stores: [],
        featured_stores: featured_stores,
        spotlight_hero: hero,
        spotlight_tiles: tiles,
        # The hero photo is the page's LCP — preload it, not a static asset.
        preload_image: hero && card_image_url(hero),
        rails: Directory.rails(),
        current_customer: customer,
        favorite_slugs: favorite_slugs,
        favorite_stores: load_stores_by_slug(favorite_slugs),
        recently_viewed_stores: load_stores_by_slug(recently_viewed_slugs),
        map_open: false
      )
      |> stream(:stores, [])
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
     |> put_search_form()
     |> load_grid(reset: true)}
  end

  def handle_event("update_search", %{"search" => %{"query" => query}}, socket) do
    handle_event("update_search", %{"value" => query}, socket)
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
     |> put_filter_form()
     |> load_grid(reset: true)}
  end

  def handle_event("select_sort", %{"sort" => sort}, socket) do
    {:noreply,
     socket
     |> assign(active_sort: sort, offset: 0)
     |> put_filter_form()
     |> load_grid(reset: true)}
  end

  def handle_event(
        "update_filters",
        %{"filters" => %{"region" => region, "sort" => sort}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(active_region: region, active_sort: sort, offset: 0)
     |> put_filter_form()
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
     |> put_search_form()
     |> put_filter_form()
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
    <Layouts.app flash={@flash} variant={:plain}>
      <div id="stores-page" class="min-h-screen overflow-x-clip bg-[#f7f6f1] text-[#132219]">
        <LandingComponents.landing_nav />

        <main class="pt-16">
          <section id="stores-hero" class="stores-hero relative overflow-hidden bg-[#0c1f17]">
            <div class="absolute -right-36 -top-40 size-[28rem] rounded-full bg-[#d4a843]/15 blur-3xl">
            </div>
            <div class="absolute -left-32 -bottom-44 size-[30rem] rounded-full bg-emerald-400/10 blur-3xl">
            </div>

            <div class="relative mx-auto max-w-7xl px-4 py-12 sm:px-6 sm:py-16 lg:px-8">
              <div class="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between lg:gap-12">
                <h1 class="stores-rise font-headline text-4xl font-black leading-[1.02] tracking-[-0.045em] text-white sm:text-5xl lg:text-6xl">
                  Find a shop worth<br />
                  <span class="text-[#e4bd63]">coming back to.</span>
                </h1>
                <p class="max-w-sm text-base leading-7 text-[#b9c8bf] sm:text-lg">
                  Independent shops across Ghana. Pay with the methods you already use.
                </p>
              </div>

              <.form
                for={@search_form}
                id="stores-search-form"
                phx-change="update_search"
                phx-submit="update_search"
                class="mt-8 max-w-2xl"
              >
                <div class="relative [&_.fieldset]:mb-0">
                  <.icon
                    name="hero-magnifying-glass"
                    class="pointer-events-none absolute left-4 top-1/2 z-10 size-5 -translate-y-1/2 text-slate-400"
                  />
                  <.input
                    field={@search_form[:query]}
                    id="stores-search-input"
                    type="search"
                    phx-debounce="300"
                    autocomplete="off"
                    placeholder="Search shops, products or places"
                    class="h-14 w-full rounded-2xl border border-white/10 bg-white pl-12 pr-28 text-[15px] font-medium text-slate-900 shadow-2xl shadow-black/20 outline-none placeholder:text-slate-400 focus:border-[#e4bd63] focus:ring-4 focus:ring-[#e4bd63]/20 sm:h-16 sm:pr-32 sm:text-base"
                  />
                  <button
                    id="stores-search-submit"
                    type="submit"
                    class="absolute right-2 top-1/2 inline-flex h-10 -translate-y-1/2 items-center justify-center rounded-xl bg-[#d4a843] px-4 text-sm font-bold text-[#0c1f17] transition hover:bg-[#e4bd63] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#e4bd63] focus-visible:ring-offset-2 sm:h-12 sm:px-5"
                  >
                    Search
                  </button>
                </div>
              </.form>
            </div>
          </section>

          <StoresComponents.featured_spotlight
            :if={@spotlight_hero && !filters_active?(assigns)}
            hero={@spotlight_hero}
            tiles={@spotlight_tiles}
          />

          <section id="main-grid" class="scroll-mt-20 bg-[#f7f6f1]">
            <div class="mx-auto max-w-7xl px-4 py-12 sm:px-6 sm:py-16 lg:px-8 lg:py-20">
              <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
                <div>
                  <p class="text-xs font-bold uppercase tracking-[0.2em] text-emerald-700">
                    Explore the market
                  </p>
                  <h2 class="mt-2 font-headline text-3xl font-black tracking-tight text-[#132219] sm:text-4xl">
                    <%= if filters_active?(assigns) do %>
                      Shops matching your search
                    <% else %>
                      Every shop, one place
                    <% end %>
                  </h2>
                  <p class="mt-2 text-sm text-slate-600 sm:text-base">
                    <span class="font-bold text-[#132219]">{@total_filtered}</span>
                    {if @total_filtered == 1, do: "shop is", else: "shops are"} ready to browse.
                  </p>
                </div>

                <button
                  :if={filters_active?(assigns)}
                  id="stores-clear-filters-top"
                  type="button"
                  phx-click="clear_filters"
                  class="inline-flex w-fit items-center gap-2 rounded-full border border-slate-300 bg-white px-4 py-2 text-sm font-bold text-slate-700 transition hover:border-emerald-600 hover:text-emerald-700"
                >
                  <.icon name="hero-x-mark" class="size-4" /> Clear filters
                </button>
              </div>

              <div
                id="stores-discovery-controls"
                class="mt-8 rounded-[1.75rem] border border-[#dfe3dc] bg-white p-3 shadow-sm sm:p-5"
              >
                <div class="-mx-3 overflow-x-auto px-3 pb-2 sm:mx-0 sm:px-0">
                  <StoresComponents.filter_chips
                    active_theme={@active_theme}
                    counts={@theme_counts}
                  />
                </div>

                <div class="mt-3 border-t border-slate-100 pt-4">
                  <.form
                    for={@filter_form}
                    id="stores-filter-form"
                    phx-change="update_filters"
                    class="grid grid-cols-2 gap-3 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto]"
                  >
                    <div class="relative [&_.fieldset]:mb-0">
                      <.icon
                        name="hero-map-pin"
                        class="pointer-events-none absolute left-3 top-1/2 z-10 size-4 -translate-y-1/2 text-slate-500"
                      />
                      <.input
                        field={@filter_form[:region]}
                        id="stores-region-filter"
                        type="select"
                        options={StoresComponents.regions()}
                        class="h-11 w-full appearance-none rounded-xl border border-slate-200 bg-slate-50 pl-9 pr-8 text-sm font-semibold text-slate-700 outline-none transition hover:border-slate-300 focus:border-emerald-600 focus:ring-2 focus:ring-emerald-600/15"
                      />
                    </div>

                    <div class="relative [&_.fieldset]:mb-0">
                      <.icon
                        name="hero-arrows-up-down"
                        class="pointer-events-none absolute left-3 top-1/2 z-10 size-4 -translate-y-1/2 text-slate-500"
                      />
                      <.input
                        field={@filter_form[:sort]}
                        id="stores-sort-filter"
                        type="select"
                        options={StoresComponents.sorts()}
                        class="h-11 w-full appearance-none rounded-xl border border-slate-200 bg-slate-50 pl-9 pr-8 text-sm font-semibold text-slate-700 outline-none transition hover:border-slate-300 focus:border-emerald-600 focus:ring-2 focus:ring-emerald-600/15"
                      />
                    </div>

                    <button
                      id="stores-map-button"
                      type="button"
                      phx-click="open_map"
                      class="col-span-2 inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-[#132219] px-5 text-sm font-bold text-white transition hover:bg-emerald-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 md:col-span-1"
                    >
                      <.icon name="hero-map" class="size-4" /> Browse map
                    </button>
                  </.form>
                </div>
              </div>

              <div
                :if={@stores_empty?}
                id="stores-empty-state"
                class="mt-8 flex flex-col items-center rounded-[2rem] border border-dashed border-slate-300 bg-white px-6 py-16 text-center"
              >
                <span class="flex size-16 items-center justify-center rounded-2xl bg-amber-50 text-[#b67c17]">
                  <.icon name="hero-magnifying-glass" class="size-8" />
                </span>
                <h3 class="mt-5 text-xl font-black text-[#132219]">No shops found yet</h3>
                <p class="mt-2 max-w-md text-sm leading-6 text-slate-500">
                  Try a broader search, another category, or clear everything and start again.
                </p>
                <button
                  id="stores-clear-filters-empty"
                  type="button"
                  phx-click="clear_filters"
                  class="mt-6 inline-flex items-center gap-2 rounded-xl bg-[#132219] px-5 py-3 text-sm font-bold text-white transition hover:bg-emerald-800"
                >
                  <.icon name="hero-arrow-path" class="size-4" /> Reset discovery
                </button>
              </div>

              <div
                id="stores-grid"
                phx-update="stream"
                class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3"
              >
                <StoresComponents.store_card
                  :for={{id, store} <- @streams.stores}
                  id={id}
                  store={store}
                  is_favorite={store.slug in @favorite_slugs}
                />
              </div>

              <div :if={@has_more} class="mt-12 text-center">
                <button
                  id="stores-load-more"
                  type="button"
                  phx-click="load_more"
                  phx-disable-with="Loading shops…"
                  class="inline-flex items-center gap-2 rounded-xl border border-slate-300 bg-white px-6 py-3 text-sm font-bold text-[#132219] shadow-sm transition hover:-translate-y-0.5 hover:border-[#d4a843] hover:shadow-md"
                >
                  Show more shops <.icon name="hero-chevron-down" class="size-4" />
                </button>
              </div>
            </div>
          </section>

          <div
            :if={!filters_active?(assigns) && @current_customer && @favorite_stores != []}
            class="border-t border-slate-200 bg-rose-50/40"
          >
            <StoresComponents.recent_strip
              stores={@favorite_stores}
              id_prefix="saved"
              title="Your saved shops"
              subtitle="The places you want to visit again"
            />
          </div>

          <div
            :if={!filters_active?(assigns) && @recently_viewed_stores != []}
            class="border-t border-slate-200 bg-white"
          >
            <StoresComponents.recent_strip
              stores={@recently_viewed_stores}
              id_prefix="viewed"
              title="Recently viewed"
              subtitle="Pick up where you left off"
            />
          </div>

          <div
            :for={rail <- @rails}
            :if={!filters_active?(assigns)}
            class="border-t border-slate-200 bg-white"
          >
            <StoresComponents.recent_strip
              stores={rail.stores}
              title={rail.title}
              subtitle={rail.subtitle}
              id_prefix={to_string(rail.id)}
            />
          </div>

          <section id="stores-sell-cta" class="bg-[#f7f6f1] px-4 py-12 sm:px-6 sm:py-20 lg:px-8">
            <div class="relative mx-auto max-w-7xl overflow-hidden rounded-[2rem] bg-[#0c1f17] shadow-2xl sm:rounded-[2.5rem]">
              <img
                src="/images/landing/cta-market.jpg"
                alt="Ghanaian merchant standing proudly in her market"
                class="absolute inset-0 h-full w-full object-cover object-center opacity-35"
                loading="lazy"
              />
              <div class="absolute inset-0 bg-gradient-to-r from-[#0c1f17] via-[#0c1f17]/90 to-[#0c1f17]/35">
              </div>
              <div class="relative max-w-2xl px-6 py-12 sm:px-10 sm:py-16 lg:px-16 lg:py-20">
                <p class="text-xs font-bold uppercase tracking-[0.2em] text-[#e4bd63]">
                  Your shop belongs here
                </p>
                <h2 class="mt-3 font-headline text-3xl font-black leading-tight text-white sm:text-5xl">
                  Have something Ghana should be able to find?
                </h2>
                <p class="mt-4 max-w-xl text-base leading-7 text-[#c4d0c8]">
                  Open a professional shop, accept mobile money, and join the market without
                  paying before your first sale.
                </p>
                <div class="mt-7 flex flex-col gap-3 sm:flex-row">
                  <a
                    href="/auth/register"
                    class="inline-flex items-center justify-center gap-2 rounded-xl bg-[#d4a843] px-5 py-3 text-sm font-bold text-[#0c1f17] transition hover:bg-[#e4bd63]"
                  >
                    Start selling — free <.icon name="hero-arrow-right" class="size-4" />
                  </a>
                  <a
                    href="/how-it-works"
                    class="inline-flex items-center justify-center rounded-xl border border-white/20 bg-white/5 px-5 py-3 text-sm font-bold text-white transition hover:bg-white/10"
                  >
                    See how Makola works
                  </a>
                </div>
              </div>
            </div>
          </section>

          <StoresComponents.map_view
            stores={@map_stores}
            active_region={@active_region}
            open={@map_open}
          />
        </main>

        <LandingComponents.landing_footer />
      </div>
    </Layouts.app>
    """
  end

  defp filters_active?(assigns) do
    assigns.active_theme != "all" or
      assigns.active_region != "" or
      assigns.active_sort != "featured" or
      (assigns.search_query || "") != ""
  end

  defp put_search_form(socket) do
    assign(socket, :search_form, to_form(%{"query" => socket.assigns.search_query}, as: :search))
  end

  defp put_filter_form(socket) do
    assign(
      socket,
      :filter_form,
      to_form(
        %{"region" => socket.assigns.active_region, "sort" => socket.assigns.active_sort},
        as: :filters
      )
    )
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
      |> Ash.Query.load([:product_count, :card_image_url])
      |> Ash.Query.limit(per_page)
      |> Ash.Query.offset(offset)
      |> Ash.read!(authorize?: false)

    total_filtered = filtered_count(args)
    next_offset = offset + length(new_page)

    map_stores =
      if reset? do
        new_page
      else
        socket.assigns.map_stores ++ new_page
      end

    socket
    |> assign(
      map_stores: map_stores,
      stores_empty?: total_filtered == 0,
      offset: next_offset,
      total_filtered: total_filtered,
      has_more: length(new_page) == per_page and next_offset < total_filtered
    )
    |> stream(:stores, new_page, reset: reset?)
  end

  defp restream_grid(socket) do
    stream(socket, :stores, socket.assigns.map_stores, reset: true)
  end

  defp filtered_count(args) do
    Store
    |> Ash.Query.for_read(:list_with_filters, args)
    |> Ash.count!(authorize?: false)
  rescue
    exception ->
      Logger.error("[stores_live] filtered_count raised: #{Exception.message(exception)}")
      0
  end

  # The hero is the day's top-ranked featured shop WITH a photo; the next
  # four with photos become the side tiles. A shop without a real image is
  # skipped rather than rendered as a giant gradient placeholder — it stays
  # featured in the grid, it just does not hold the big slot.
  defp split_spotlight(featured) do
    case Enum.filter(featured, &card_image_url/1) do
      [] -> {nil, []}
      [hero | rest] -> {hero, Enum.take(rest, 4)}
    end
  end

  defp card_image_url(store) do
    case Map.get(store, :card_image_url) do
      url when is_binary(url) and url != "" -> url
      _missing -> Map.get(store, :cover_image_url) || Map.get(store, :logo_url)
    end
  end

  defp load_featured do
    Store
    |> Ash.Query.for_read(:list_featured, %{limit: 8})
    |> Ash.Query.load([:card_image_url, :product_count])
    |> Ash.Query.limit(8)
    |> Ash.read!(authorize?: false)
  rescue
    exception ->
      Logger.error("[stores_live] load_featured stores raised: #{Exception.message(exception)}")
      []
  end

  defp count_active_stores do
    Store
    |> Ash.Query.for_read(:list_active)
    |> Ash.count!(authorize?: false)
  rescue
    exception ->
      Logger.error("[stores_live] count_active_stores raised: #{Exception.message(exception)}")
      0
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
    exception ->
      Logger.error("[stores_live] load_favorite_slugs raised: #{Exception.message(exception)}")
      []
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
      |> Ash.Query.for_read(:list_by_slugs, %{slugs: slugs})
      |> Ash.Query.load([:product_count, :card_image_url])
      |> Ash.read!(authorize?: false)

    # Preserve cookie order (most-recent first); the DB query won't
    by_slug = Map.new(stores, &{&1.slug, &1})

    slugs
    |> Enum.map(&Map.get(by_slug, &1))
    |> Enum.reject(&is_nil/1)
  rescue
    exception ->
      Logger.error("[stores_live] load_stores_by_slug raised: #{Exception.message(exception)}")
      []
  end

  defp find_store_by_slug(slug) when is_binary(slug) do
    case Emakola.Stores.get_store_by_slug(slug, authorize?: false) do
      {:ok, %{active: true} = store} -> store
      _ -> nil
    end
  rescue
    exception ->
      Logger.error("[stores_live] find_store_by_slug raised: #{Exception.message(exception)}")
      nil
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
         )
         |> restream_grid()}

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
       )
       |> restream_grid()}
    else
      _ -> {:noreply, socket}
    end
  end
end
