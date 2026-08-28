defmodule EmakolaWeb.Platform.StoreLive.Index do
  @moduledoc """
  Platform admin "Directory Studio" for stores: a split view with a
  searchable, filterable store list on the left and a curation panel for
  the selected store on the right (featured/verified toggles, rank
  stepper, and a preview of the store's public directory card).

  Mount is gated by RequirePermission (:manage_stores). No DB queries are
  issued during the disconnected render — an empty stream and loading state
  render the shell. Every mutating handle_event re-checks the permission
  against a freshly reloaded user so that a permission revocation after
  mount is caught before the write.
  """
  use EmakolaWeb, :live_view
  require Logger

  import EmakolaWeb.StoresComponents, only: [store_card: 1]

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_stores}

  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Stores.DirectoryCuration
  alias Emakola.Stores.FeaturedRanking
  alias Emakola.Stores.Store

  @impl true
  def mount(_params, _session, socket) do
    # No DB queries in disconnected mount — render a loading shell first.
    socket =
      socket
      |> assign(:page_title, "Stores")
      |> assign(:active_nav, :stores)
      |> assign(:search, "")
      |> assign(:search_form, search_form(""))
      |> assign(:filter, :all)
      |> assign(:total_count, 0)
      |> assign(:featured_count, 0)
      |> assign(:suspended_count, 0)
      |> assign(:stores_count, 0)
      |> assign(:stores_loaded?, false)
      |> assign(:selected, nil)
      |> assign(:standing, nil)
      |> assign(:truncated?, false)
      |> stream(:stores, [], dom_id: &"store-#{&1.id}")

    {:ok, socket}
  end

  # All loading happens here, once per navigation (mount stays query-free so
  # the disconnected render is a pure loading shell). The platform topbar
  # search is a plain GET form handing off ?q= — seed the in-page search
  # from it before loading.
  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case params["q"] do
        q when is_binary(q) and q != "" ->
          socket |> assign(:search, q) |> assign(:search_form, search_form(q))

        _ ->
          socket
      end

    if connected?(socket) do
      {:noreply, load_stores(socket, socket.assigns.search)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search, query)
     |> assign(:search_form, search_form(query))
     |> load_stores(query)}
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:filter, parse_filter(filter))
     |> load_stores(socket.assigns.search)}
  end

  def handle_event("select_store", %{"id" => id}, socket) do
    {:noreply, load_stores(socket, socket.assigns.search, select_id: id)}
  end

  def handle_event("toggle_featured", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      mutate_store(socket, id, fn store ->
        # The featured flag and the verified badge write silently for months;
        # both are public trust surfaces, so both audit now.
        result =
          if store.featured,
            do: FeaturedRanking.unfeature(store),
            else: FeaturedRanking.feature(store)

        with {:ok, updated} <- result do
          audit(
            socket,
            if(updated.featured, do: :store_featured, else: :store_unfeatured),
            updated
          )

          {:ok, updated}
        end
      end)
    end)
  end

  def handle_event("toggle_verified", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      mutate_store(socket, id, fn store ->
        result =
          Emakola.Stores.update_store_directory_meta(
            store,
            %{verified: !Map.get(store, :verified, false)},
            authorize?: false
          )

        with {:ok, updated} <- result do
          audit(
            socket,
            if(updated.verified,
              do: :store_verified_badge_granted,
              else: :store_verified_badge_revoked
            ),
            updated
          )

          {:ok, updated}
        end
      end)
    end)
  end

  def handle_event("move_rank", %{"id" => id, "dir" => dir}, socket)
      when dir in ["up", "down"] do
    direction = if dir == "up", do: :up, else: :down

    authorized(socket, fn socket ->
      mutate_store(socket, id, &FeaturedRanking.move(&1, direction))
    end)
  end

  # Assigns are stale — re-check permission against a freshly reloaded user
  # so that a post-mount revocation is caught before any write is issued.
  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_stores) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to manage stores.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  defp audit(socket, action, store) do
    Emakola.Accounts.PlatformAudit.log(action, socket.assigns.current_user, %{
      "store_id" => store.id,
      "store_slug" => store.slug
    })
  end

  defp mutate_store(socket, id, fun) do
    case Emakola.Stores.get_store(id, authorize?: false) do
      {:ok, store} ->
        case fun.(store) do
          {:ok, _updated} ->
            {:noreply, load_stores(socket, socket.assigns.search)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not update store")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp load_stores(socket, query, opts \\ []) do
    search = if String.trim(query) == "", do: "", else: "%#{String.trim(query)}%"
    limit = list_limit()

    # Fetch one past the cap so truncation is detectable without a count query.
    stores =
      case Emakola.Stores.list_stores_for_admin(search,
             authorize?: false,
             query: [limit: limit + 1]
           ) do
        {:ok, list} -> list
        _ -> []
      end

    socket
    |> assign(:truncated?, length(stores) > limit)
    |> assign_stores(Enum.take(stores, limit), opts)
  rescue
    exception ->
      Logger.error(
        "[platform.store_live] load_stores loading stores raised: #{Exception.message(exception)}"
      )

      socket
      |> assign(:truncated?, false)
      |> assign_stores([], opts)
  end

  # Guards the unbounded-admin-list debt: real merchant volume should get
  # pagination; until then the page loads at most this many stores.
  defp list_limit, do: Application.get_env(:emakola, :platform_admin_store_limit, 200)

  defp assign_stores(socket, stores, opts) do
    filtered = apply_filter(stores, socket.assigns.filter)

    preferred_id =
      Keyword.get(opts, :select_id) ||
        (socket.assigns.selected && socket.assigns.selected.id)

    selected =
      (Enum.find(stores, &(&1.id == preferred_id)) || List.first(filtered))
      |> load_preview_image()

    featured_position =
      if selected && selected.featured, do: FeaturedRanking.position(selected), else: nil

    socket
    |> assign(:total_count, length(stores))
    |> assign(:featured_count, Enum.count(stores, &(&1.featured == true)))
    |> assign(:suspended_count, Enum.count(stores, &(!Store.live?(&1))))
    |> assign(:stores_count, length(filtered))
    |> assign(:stores_loaded?, true)
    |> assign(:selected, selected)
    |> assign(:standing, selected && load_standing(selected.id))
    |> assign(:featured_position, featured_position)
    |> stream(:stores, Enum.map(filtered, &store_row(&1, selected)), reset: true)
  end

  defp apply_filter(stores, :featured), do: Enum.filter(stores, &(&1.featured == true))
  defp apply_filter(stores, :suspended), do: Enum.reject(stores, &Store.live?/1)
  defp apply_filter(stores, _all), do: stores

  defp parse_filter("featured"), do: :featured
  defp parse_filter("suspended"), do: :suspended
  defp parse_filter(_), do: :all

  defp store_row(store, selected) do
    %{id: store.id, store: store, selected?: selected != nil && selected.id == store.id}
  end

  defp search_form(query), do: to_form(%{"search" => query})

  # The public directory card falls back to the newest active product photo
  # (:card_image_url aggregate) when the merchant hasn't set a cover image —
  # load it for the selected store only, so the panel preview shows what the
  # directory actually shows.
  defp load_preview_image(nil), do: nil

  defp load_preview_image(store) do
    case Ash.load(store, [:card_image_url, :product_count], authorize?: false) do
      {:ok, loaded} -> loaded
      _ -> store
    end
  end

  @avatar_tints [
    "bg-rose-100 text-rose-600",
    "bg-amber-100 text-amber-600",
    "bg-blue-100 text-blue-600",
    "bg-emerald-100 text-emerald-600",
    "bg-sky-100 text-sky-600",
    "bg-violet-100 text-violet-600",
    "bg-indigo-100 text-indigo-600",
    "bg-green-100 text-green-700"
  ]

  defp avatar_tint(store) do
    Enum.at(@avatar_tints, :erlang.phash2(store.id, length(@avatar_tints)))
  end

  defp initial(store), do: store.name |> String.first() |> String.upcase()

  defp status_label(store) do
    cond do
      Store.live?(store) -> "Active"
      store.status in [:suspended, :blocked, :archived] -> humanize_status(store.status)
      true -> "Inactive"
    end
  end

  defp humanize_status(status), do: status |> Atom.to_string() |> String.capitalize()

  defp status_tone(store), do: if(Store.live?(store), do: "green", else: "red")

  defp position_label({position, total}), do: "##{position} of #{total}"

  defp filter_chip_classes(active?) do
    [
      "inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11.5px] transition-colors cursor-pointer",
      if(active?,
        do: "bg-slate-900 text-white font-semibold",
        else:
          "bg-slate-50 text-slate-600 font-medium ring-1 ring-inset ring-slate-200 hover:bg-slate-100"
      )
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Page header --%>
      <div class="mb-6 flex items-end justify-between gap-4 flex-wrap">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 tracking-tight">Stores</h1>
          <p class="text-sm text-gray-500 mt-1">Curate how stores appear on the Makola directory</p>
        </div>
        <div :if={@stores_loaded?} class="flex items-center gap-2">
          <.severity_pill label={"#{@total_count} stores"} tone="blue" />
          <.severity_pill label={"#{@featured_count} featured"} tone="amber" />
        </div>
      </div>

      <%!-- Split view: list + curation panel --%>
      <div class="flex flex-col lg:flex-row bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden lg:h-[calc(100vh-15rem)] lg:min-h-[520px]">
        <%!-- Store list --%>
        <div class="w-full lg:w-[380px] shrink-0 border-b lg:border-b-0 lg:border-r border-gray-100 flex flex-col max-h-96 lg:max-h-none">
          <div class="p-4 border-b border-gray-100">
            <.form
              for={@search_form}
              id="platform-store-search-form"
              phx-change="search"
              phx-debounce="300"
              class="relative"
            >
              <.icon
                name="hero-magnifying-glass"
                class="size-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none"
              />
              <.input
                field={@search_form[:search]}
                type="search"
                id="platform-store-search"
                placeholder="Search by name or slug..."
                autocomplete="off"
                class="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-[10px] text-[13px] text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 transition-all"
              />
            </.form>
            <div class="flex items-center gap-1.5 mt-2.5">
              <button
                type="button"
                id="filter-all"
                phx-click="filter"
                phx-value-filter="all"
                class={filter_chip_classes(@filter == :all)}
              >
                All <span class="opacity-60 tabular-nums">{@total_count}</span>
              </button>
              <button
                type="button"
                id="filter-featured"
                phx-click="filter"
                phx-value-filter="featured"
                class={filter_chip_classes(@filter == :featured)}
              >
                Featured <span class="opacity-60 tabular-nums">{@featured_count}</span>
              </button>
              <button
                type="button"
                id="filter-suspended"
                phx-click="filter"
                phx-value-filter="suspended"
                class={filter_chip_classes(@filter == :suspended)}
              >
                Suspended <span class="opacity-60 tabular-nums">{@suspended_count}</span>
              </button>
            </div>
          </div>
          <div
            id="platform-stores"
            phx-update="stream"
            data-count={@stores_count}
            class="flex-1 overflow-y-auto p-2"
          >
            <div
              :if={!@stores_loaded?}
              id="platform-stores-loading"
              class="px-4 py-12 text-center text-sm text-gray-400"
            >
              Loading stores…
            </div>
            <div
              :if={@stores_loaded? && @stores_count == 0}
              id="platform-stores-empty"
              class="px-4 py-12 text-center text-sm text-gray-400"
            >
              No stores found
            </div>
            <div
              :for={{id, %{store: store, selected?: selected?}} <- @streams.stores}
              id={id}
              role="button"
              tabindex="0"
              phx-click="select_store"
              phx-value-id={store.id}
              data-selected={selected?}
              class={[
                "flex items-center gap-3 px-3 py-2.5 rounded-[10px] cursor-pointer transition-colors",
                if(selected?,
                  do: "bg-blue-50 shadow-[inset_3px_0_0_#3b82f6]",
                  else: "hover:bg-slate-50"
                )
              ]}
            >
              <div class={[
                "w-8 h-8 rounded-[9px] flex items-center justify-center text-[13px] font-bold shrink-0",
                avatar_tint(store)
              ]}>
                {initial(store)}
              </div>
              <div class="min-w-0 flex-1">
                <p class={[
                  "text-[13.5px] font-semibold leading-tight truncate",
                  if(selected?, do: "text-gray-900", else: "text-slate-700")
                ]}>
                  {store.name}
                </p>
                <p class="text-[11px] text-gray-400 font-mono truncate leading-tight mt-0.5">
                  {store.slug}
                </p>
              </div>
              <.icon
                :if={store.featured}
                name="hero-star-solid"
                class="size-3 text-amber-500 shrink-0"
              />
              <span class={[
                "w-2 h-2 rounded-full shrink-0",
                if(Store.live?(store), do: "bg-green-500", else: "bg-red-400")
              ]}>
              </span>
            </div>
          </div>
          <div
            :if={@truncated?}
            id="platform-stores-truncated"
            class="px-4 py-3 border-t border-gray-100 text-[11px] text-gray-400 text-center shrink-0"
          >
            Showing the first {list_limit()} stores — refine your search to see the rest.
          </div>
        </div>

        <%!-- Curation panel --%>
        <div class="flex-1 min-w-0 overflow-y-auto">
          <div :if={@selected} id="store-panel" class="p-6 lg:p-7">
            <%!-- Identity --%>
            <div class="flex flex-wrap items-center gap-4">
              <div class={[
                "w-14 h-14 rounded-[14px] flex items-center justify-center text-[22px] font-bold shrink-0",
                avatar_tint(@selected)
              ]}>
                {initial(@selected)}
              </div>
              <div class="min-w-0 flex-1">
                <div class="flex items-center gap-2 flex-wrap">
                  <h2 class="text-xl font-bold text-gray-900 tracking-tight truncate">
                    {@selected.name}
                  </h2>
                  <.severity_pill label={status_label(@selected)} tone={status_tone(@selected)} />
                </div>
                <p class="text-[13px] text-gray-500 mt-0.5 truncate">
                  {if @selected.city, do: "#{@selected.city} · "}<span class="font-mono">{@selected.slug}</span> {"· #{@selected.currency || "GHS"} · Since #{Calendar.strftime(@selected.inserted_at, "%b %d, %Y")}"}
                </p>
              </div>
              <div class="flex items-center gap-2 shrink-0">
                <a
                  href={EmakolaWeb.Storefront.Path.public_path(@selected.slug)}
                  target="_blank"
                  class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold text-blue-600 bg-white ring-1 ring-inset ring-gray-200 hover:bg-slate-50 transition-colors"
                >
                  Storefront <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
                </a>
                <.link
                  navigate={~p"/platform/stores/#{@selected.id}"}
                  class="inline-flex items-center px-3.5 py-2 rounded-[10px] text-[13px] font-semibold text-white bg-slate-900 hover:bg-slate-800 transition-colors"
                >
                  Manage store
                </.link>
              </div>
            </div>

            <%!-- Hidden-from-directory banner --%>
            <div
              :if={!Store.live?(@selected)}
              id="panel-hidden-banner"
              class="flex items-start gap-2.5 mt-5 px-3.5 py-3 bg-amber-50 rounded-[10px] ring-1 ring-inset ring-amber-200"
            >
              <.icon name="hero-exclamation-triangle" class="size-4 text-amber-600 shrink-0 mt-0.5" />
              <p class="text-[13px] text-amber-800 leading-relaxed">
                This store is hidden from the public directory. Directory settings are kept and
                take effect when it is live again.
              </p>
            </div>

            <div class="h-px bg-gray-100 my-6"></div>

            <div class="flex flex-col 2xl:flex-row gap-7">
              <%!-- Directory presence controls --%>
              <div class="flex-1 min-w-0">
                <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
                  Directory presence
                </p>
                <div class="border border-gray-200 rounded-xl divide-y divide-gray-100">
                  <div class="flex items-center gap-3.5 p-4">
                    <span class="flex h-9 w-9 items-center justify-center rounded-[10px] bg-amber-100 text-amber-600 shrink-0">
                      <.icon name="hero-star" class="size-[18px]" />
                    </span>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-semibold text-gray-900">Featured</p>
                      <p class="text-xs text-gray-400 mt-0.5">
                        Shown in the featured strip on the directory
                      </p>
                    </div>
                    <button
                      type="button"
                      id="panel-featured-toggle"
                      role="switch"
                      aria-checked={to_string(@selected.featured == true)}
                      phx-click="toggle_featured"
                      phx-value-id={@selected.id}
                      class={[
                        "relative w-11 h-6 rounded-full transition-colors shrink-0 cursor-pointer",
                        if(@selected.featured, do: "bg-blue-500", else: "bg-slate-200")
                      ]}
                    >
                      <span class={[
                        "absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-all",
                        if(@selected.featured, do: "right-0.5", else: "left-0.5")
                      ]}>
                      </span>
                    </button>
                  </div>
                  <div class="flex items-center gap-3.5 p-4">
                    <span class="flex h-9 w-9 items-center justify-center rounded-[10px] bg-sky-100 text-sky-600 shrink-0">
                      <.icon name="hero-check-badge" class="size-[18px]" />
                    </span>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-semibold text-gray-900">Verified</p>
                      <p class="text-xs text-gray-400 mt-0.5">
                        Verified badge on the directory card and storefront
                      </p>
                    </div>
                    <button
                      type="button"
                      id="panel-verified-toggle"
                      role="switch"
                      aria-checked={to_string(@selected.verified == true)}
                      phx-click="toggle_verified"
                      phx-value-id={@selected.id}
                      class={[
                        "relative w-11 h-6 rounded-full transition-colors shrink-0 cursor-pointer",
                        if(@selected.verified, do: "bg-blue-500", else: "bg-slate-200")
                      ]}
                    >
                      <span class={[
                        "absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-all",
                        if(@selected.verified, do: "right-0.5", else: "left-0.5")
                      ]}>
                      </span>
                    </button>
                  </div>
                  <div
                    :if={@selected.featured && @featured_position}
                    class="flex items-center gap-3.5 p-4"
                  >
                    <span class="flex h-9 w-9 items-center justify-center rounded-[10px] bg-slate-100 text-slate-500 shrink-0">
                      <.icon name="hero-hashtag" class="size-[18px]" />
                    </span>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-semibold text-gray-900">Featured order</p>
                      <p class="text-xs text-gray-400 mt-0.5">Position in the featured strip</p>
                    </div>
                    <span
                      id="panel-rank-value"
                      class="text-sm font-semibold text-gray-900 tabular-nums shrink-0"
                    >
                      {position_label(@featured_position)}
                    </span>
                    <div class="flex items-center rounded-[10px] ring-1 ring-inset ring-gray-200 overflow-hidden shrink-0">
                      <button
                        type="button"
                        id="panel-rank-up"
                        phx-click="move_rank"
                        phx-value-id={@selected.id}
                        phx-value-dir="up"
                        aria-label="Move up in the featured order"
                        class="flex w-8 h-8 items-center justify-center hover:bg-slate-50 transition-colors cursor-pointer"
                      >
                        <.icon name="hero-chevron-up" class="size-3.5 text-slate-500" />
                      </button>
                      <button
                        type="button"
                        id="panel-rank-down"
                        phx-click="move_rank"
                        phx-value-id={@selected.id}
                        phx-value-dir="down"
                        aria-label="Move down in the featured order"
                        class="flex w-8 h-8 items-center justify-center border-l border-gray-100 hover:bg-slate-50 transition-colors cursor-pointer"
                      >
                        <.icon name="hero-chevron-down" class="size-3.5 text-slate-500" />
                      </button>
                    </div>
                  </div>
                </div>
                <p class="text-xs text-gray-400 mt-3">
                  {if Store.live?(@selected),
                    do: "Changes apply to the public directory immediately.",
                    else: "Settings are kept; they take effect when the store is live again."}
                </p>
              </div>

              <%!-- Directory preview --%>
              <div class="w-full xl:w-[280px] shrink-0">
                <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
                  Directory preview
                </p>
                <div class={["relative", !Store.live?(@selected) && "opacity-80"]}>
                  <.store_card
                    id="panel-directory-card"
                    store={@selected}
                    target="_blank"
                    show_favorite={false}
                  />
                  <span
                    :if={!Store.live?(@selected)}
                    class="absolute top-2.5 right-2.5 z-10 inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-700 text-white"
                  >
                    <.icon name="hero-eye-slash" class="size-2.5" /> HIDDEN
                  </span>
                </div>
                <p class="text-[11px] text-gray-400 mt-2.5">
                  {if Store.live?(@selected),
                    do: "How this store appears on the public directory.",
                    else: "Not shown on the public directory right now."}
                </p>
              </div>
            </div>
            <div :if={@standing} id="panel-standing" class="mt-7">
              <h3 class="text-[11px] font-bold uppercase tracking-[0.14em] text-gray-400 mb-3">
                Featuring standing
              </h3>
              <div class="rounded-2xl ring-1 ring-inset ring-gray-200 divide-y divide-gray-100 bg-white">
                <div class="flex items-center gap-3.5 p-4">
                  <span class="flex h-9 w-9 items-center justify-center rounded-[10px] bg-slate-100 text-slate-500 shrink-0">
                    <.icon name="hero-chart-bar" class="size-[18px]" />
                  </span>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-semibold text-gray-900">
                      Score
                      <span id="panel-standing-score" class="tabular-nums">{@standing.score}</span>
                      / 1000
                    </p>
                    <p class="text-xs text-gray-400 mt-0.5">
                      <%= if @standing.eligible do %>
                        Eligible for every featured slot
                      <% else %>
                        Barred: {Enum.map_join(
                          @standing.disqualifiers,
                          ", ",
                          &humanize_disqualifier/1
                        )}
                      <% end %>
                    </p>
                  </div>
                  <span
                    :if={@standing.slot}
                    id="panel-standing-slot"
                    class="rounded-full bg-emerald-50 px-2.5 py-1 text-[11px] font-bold uppercase tracking-wide text-emerald-700 shrink-0"
                  >
                    {@standing.override_slot || @standing.slot}
                  </span>
                </div>

                <.form
                  for={%{}}
                  as={:directory_pin}
                  phx-submit="directory_pin"
                  class="flex items-center gap-2 p-4"
                >
                  <select
                    name="slot"
                    id="panel-pin-slot"
                    class="h-9 rounded-[10px] border-gray-200 text-sm text-gray-700"
                  >
                    <option value="clear">Clear pin</option>
                    <option value="spotlight">Pin: Spotlight</option>
                    <option value="rising">Pin: Rising</option>
                    <option value="editors_pick">Pin: Editors pick</option>
                  </select>
                  <input
                    type="text"
                    name="reason"
                    id="panel-pin-reason"
                    placeholder="Reason (required)"
                    class="h-9 flex-1 min-w-0 rounded-[10px] border-gray-200 text-sm"
                  />
                  <button
                    type="submit"
                    id="panel-pin-submit"
                    class="h-9 rounded-[10px] bg-slate-900 px-3.5 text-sm font-semibold text-white"
                  >
                    Pin
                  </button>
                </.form>

                <.form
                  for={%{}}
                  as={:directory_exclude}
                  phx-submit="directory_exclude"
                  class="flex items-center gap-2 p-4"
                >
                  <input
                    type="text"
                    name="reason"
                    id="panel-exclude-reason"
                    placeholder="Reason (required)"
                    class="h-9 flex-1 min-w-0 rounded-[10px] border-gray-200 text-sm"
                  />
                  <button
                    type="submit"
                    id="panel-exclude-toggle"
                    class={[
                      "h-9 rounded-[10px] px-3.5 text-sm font-semibold",
                      if(@standing.override_excluded,
                        do: "bg-emerald-600 text-white",
                        else: "bg-rose-600 text-white"
                      )
                    ]}
                  >
                    {if @standing.override_excluded, do: "Readmit", else: "Exclude"}
                  </button>
                </.form>
              </div>
              <p class="text-xs text-gray-400 mt-3">
                Pins lapse after 30 days. Exclusions hold until readmitted. Every change is
                logged with its reason.
              </p>
            </div>
          </div>

          <div :if={@stores_loaded? && is_nil(@selected)} class="p-6 lg:p-7">
            <.platform_empty_state
              icon="hero-building-storefront"
              title="No store selected"
              description="Choose a store from the list to curate its directory presence."
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
