defmodule EmakolaWeb.Platform.MerchantLive.Index do
  @moduledoc """
  Platform directory of all merchants — a Studio split view: the merchant
  queue on the left (search + confirmed/unconfirmed filters), the selected
  merchant's panel on the right (identity, impersonation, stores and roles).

  Mount is gated by RequirePermission (:manage_merchants). No DB queries are
  issued during the disconnected render — an empty stream and loading state
  render the shell. The page is read-only, so its
  events (search, filter, select) issue no writes.
  """
  use EmakolaWeb, :live_view
  require Logger

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_merchants}

  # How many rows reach the DOM at once. The queue used to stream every
  # merchant on the platform on mount, which is fine at two dozen and expensive
  # at a few thousand.
  @page_size 25

  alias Emakola.Accounts
  alias Emakola.Conversations

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Merchants")
      |> assign(:active_nav, :merchants)
      |> assign(:search, "")
      |> assign(:search_form, to_form(%{"search" => ""}))
      |> assign(:filter, :all)
      |> assign(:sort, :recent)
      |> assign(:sort_form, to_form(%{"sort" => "recent"}))
      |> assign(:window, @page_size)
      |> assign(:merchants_total, 0)
      |> assign(:selected_merchant, nil)
      |> assign(:merchant_ids, MapSet.new())
      |> assign(:merchants_by_id, %{})
      |> assign(:merchants_count, 0)
      |> assign(:merchants_loaded?, false)
      |> assign(:stats, nil)
      |> stream(:merchants, [], dom_id: &"merchant-#{&1.id}")

    socket =
      if connected?(socket) do
        load_merchants(socket)
      else
        socket
      end

    {:ok, socket}
  end

  # ── Events ─────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"search" => q} = params, socket) do
    {:noreply,
     socket
     |> assign(:search, q)
     |> assign(:search_form, to_form(params))
     |> assign(:window, @page_size)
     |> load_merchants()}
  end

  def handle_event("filter", %{"filter" => f}, socket) do
    {:noreply,
     socket
     |> assign(:filter, parse_filter(f))
     |> assign(:window, @page_size)
     |> load_merchants()}
  end

  def handle_event("sort", %{"sort" => sort} = params, socket) do
    {:noreply,
     socket
     |> assign(:sort, parse_sort(sort))
     |> assign(:sort_form, to_form(params))
     |> assign(:window, @page_size)
     |> load_merchants()}
  end

  # Appends the next page rather than re-streaming the queue: keeping rows out
  # of the DOM is the whole point, so a reset here would undo it.
  def handle_event("load_more", _params, socket) do
    {_all, matches} = queue(socket)
    next = matches |> Enum.drop(socket.assigns.window) |> Enum.take(@page_size)

    appended = Enum.reduce(next, socket, &stream_insert(&2, :merchants, &1))

    {:noreply,
     appended
     |> assign(:window, socket.assigns.window + length(next))
     |> assign(:merchants_count, socket.assigns.merchants_count + length(next))
     |> assign(
       :merchant_ids,
       MapSet.union(socket.assigns.merchant_ids, MapSet.new(next, & &1.id))
     )
     |> assign(
       :merchants_by_id,
       Map.merge(socket.assigns.merchants_by_id, Map.new(next, &{&1.id, &1}))
     )}
  end

  def handle_event("select_merchant", %{"id" => id}, socket) do
    # Membership in the mounted queue is the guard — a forged id no-ops.
    if MapSet.member?(socket.assigns.merchant_ids, id) do
      previously_selected = socket.assigns.selected_merchant

      socket =
        socket
        |> assign(:selected_merchant, load_merchant_detail(id))
        |> refresh_queue_row(id)

      socket =
        if previously_selected && previously_selected.id != id do
          refresh_queue_row(socket, previously_selected.id)
        else
          socket
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Opening is idempotent, so a staff member returning to a merchant lands
  # back in the thread they already have rather than starting a second one.
  #
  # Permission is re-checked here rather than leaning on the mount gate: the
  # event arrives from the client, and a button hidden by :if is not access
  # control. Membership in the mounted queue guards the id, same as
  # select_merchant above.
  def handle_event("message_merchant", %{"id" => id}, socket) do
    staff = socket.assigns.current_user

    with true <- Accounts.PlatformPermissions.allowed?(staff, :manage_merchants),
         true <- MapSet.member?(socket.assigns.merchant_ids, id),
         {:ok, thread} <- Conversations.open_platform_thread(id) do
      {:noreply, push_navigate(socket, to: ~p"/platform/messages/#{thread.id}")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Could not open that conversation.")}
    end
  end

  defp refresh_queue_row(socket, merchant_id) do
    case Map.get(socket.assigns.merchants_by_id, merchant_id) do
      nil -> socket
      merchant -> stream_insert(socket, :merchants, merchant)
    end
  end

  # ── Data ───────────────────────────────────────────────

  defp load_merchants(socket) do
    {all, matches} = queue(socket)
    merchants = Enum.take(matches, socket.assigns.window)

    # Keep the current selection when it survives the filter; otherwise the
    # first visible merchant, so the panel is never empty while rows exist.
    previously_selected_id =
      socket.assigns.selected_merchant && socket.assigns.selected_merchant.id

    selected_merchant =
      cond do
        Enum.any?(merchants, &(&1.id == previously_selected_id)) ->
          socket.assigns.selected_merchant

        merchants != [] ->
          load_merchant_detail(hd(merchants).id)

        true ->
          nil
      end

    socket
    |> assign(:merchant_ids, MapSet.new(merchants, & &1.id))
    |> assign(:merchants_by_id, Map.new(merchants, &{&1.id, &1}))
    |> assign(:merchants_count, length(merchants))
    |> assign(:merchants_total, length(matches))
    |> assign(:merchants_loaded?, true)
    |> assign(:stats, compute_stats(all))
    |> assign(:selected_merchant, selected_merchant)
    |> stream(:merchants, merchants, reset: true)
  rescue
    exception ->
      Logger.error(
        "[platform.merchant_live] load_merchants loading merchants raised: #{Exception.message(exception)}"
      )

      socket
      |> assign(:merchant_ids, MapSet.new())
      |> assign(:merchants_by_id, %{})
      |> assign(:merchants_count, 0)
      |> assign(:merchants_total, 0)
      |> assign(:merchants_loaded?, true)
      |> assign(:stats, compute_stats([]))
      |> assign(:selected_merchant, nil)
      |> stream(:merchants, [], reset: true)
  end

  defp load_merchant_detail(id) do
    case Accounts.get_merchant(id, load: [store_memberships: [:store]], authorize?: false) do
      {:ok, merchant} -> merchant
      _ -> nil
    end
  rescue
    exception ->
      Logger.error(
        "[platform.merchant_live] load_merchant_detail loading merchant detail raised: #{Exception.message(exception)}"
      )

      nil
  end

  # The whole filtered, sorted queue — `load_merchants/1` takes the first page
  # from it and `load_more` takes the next.
  defp queue(socket) do
    all =
      case Accounts.list_merchants_for_admin("", authorize?: false) do
        {:ok, list} -> list
        _ -> []
      end

    matches =
      all
      |> filtered(socket.assigns.search, socket.assigns.filter)
      |> sorted(socket.assigns.sort)

    {all, matches}
  end

  defp sorted(merchants, :name) do
    Enum.sort_by(merchants, fn m ->
      m.name
      |> Kernel.||(m.email)
      |> to_string()
      |> String.downcase()
    end)
  end

  defp sorted(merchants, :stores), do: Enum.sort_by(merchants, &store_count/1, :desc)

  defp sorted(merchants, _recent),
    do: Enum.sort_by(merchants, & &1.inserted_at, {:desc, DateTime})

  defp filtered(all, search, filter) do
    q = normalize(search)
    Enum.filter(all, &(matches_search?(&1, q) and matches_filter?(&1, filter)))
  end

  defp matches_search?(_m, ""), do: true

  defp matches_search?(m, q) do
    [m.name, to_string(m.email), m.business_name, m.phone]
    |> Enum.any?(fn v -> v && String.contains?(String.downcase(to_string(v)), q) end)
  end

  defp matches_filter?(_m, :all), do: true
  defp matches_filter?(m, :confirmed), do: confirmed?(m)
  defp matches_filter?(m, :unconfirmed), do: not confirmed?(m)

  defp confirmed?(m), do: not is_nil(m.confirmed_at)

  defp compute_stats(all) do
    cutoff = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)

    %{
      total: length(all),
      confirmed: Enum.count(all, &confirmed?/1),
      with_store: Enum.count(all, fn m -> (m.stores || []) != [] end),
      new_30d: Enum.count(all, fn m -> DateTime.compare(m.inserted_at, cutoff) == :gt end)
    }
  end

  # ── Helpers ────────────────────────────────────────────

  defp normalize(s), do: s |> to_string() |> String.trim() |> String.downcase()

  defp parse_filter("confirmed"), do: :confirmed
  defp parse_filter("unconfirmed"), do: :unconfirmed
  defp parse_filter(_), do: :all

  # String matching, not String.to_atom/1: the value arrives from the client.
  defp parse_sort("name"), do: :name
  defp parse_sort("stores"), do: :stores
  defp parse_sort(_), do: :recent

  defp initials(m) do
    source = m.name || to_string(m.email) || "?"

    source
    |> String.split(~r/[\s@.]+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
    |> case do
      "" -> "?"
      s -> s
    end
  end

  defp store_count(m), do: length(m.stores || [])

  defp role_class(:owner), do: "bg-slate-100 text-slate-600"
  defp role_class(:admin), do: "bg-violet-100 text-violet-700"
  defp role_class(_), do: "bg-slate-100 text-slate-600"

  # ── Render ─────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Header --%>
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Merchants</h1>
        <p class="text-sm text-gray-500 mt-1">
          {if @merchants_loaded?,
            do: "Everyone building on Makola (#{@stats.total})",
            else: "Loading merchants…"}
        </p>
      </div>

      <%!-- Loading shell (disconnected mount — no DB) --%>
      <div
        :if={!@merchants_loaded?}
        class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center text-sm text-gray-400"
      >
        Loading merchants…
      </div>

      <div :if={@merchants_loaded?}>
        <%!-- Stat strip --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <.stat_tile label="Total" value={@stats.total} icon="group" color="blue" />
          <.stat_tile label="Confirmed" value={@stats.confirmed} icon="verified" color="emerald" />
          <.stat_tile label="With a store" value={@stats.with_store} icon="storefront" color="violet" />
          <.stat_tile label="New (30d)" value={@stats.new_30d} icon="trending_up" color="amber" />
        </div>

        <%!-- Toolbar --%>
        <div class="mb-5 flex items-center gap-3 flex-wrap">
          <.form
            for={@search_form}
            id="merchant-search-form"
            phx-change="search"
            class="relative flex-1 min-w-[200px] max-w-sm"
          >
            <span class="material-symbols-outlined text-base text-gray-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none">
              search
            </span>
            <.input
              field={@search_form[:search]}
              type="search"
              id="merchant-search"
              placeholder="Search name, email, business, phone..."
              phx-debounce="300"
              class="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-400 transition-all"
            />
          </.form>
          <div class="flex items-center gap-1.5">
            <.chip filter="all" active={@filter} label="All" />
            <.chip filter="confirmed" active={@filter} label="Confirmed" />
            <.chip filter="unconfirmed" active={@filter} label="Unconfirmed" />
          </div>
          <.form for={@sort_form} id="merchant-sort-form" phx-change="sort" class="ml-auto">
            <select
              id="merchant-sort"
              name="sort"
              aria-label="Sort merchants"
              class="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-600 focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 cursor-pointer"
            >
              <option value="recent" selected={@sort == :recent}>Recently joined</option>
              <option value="name" selected={@sort == :name}>Name A–Z</option>
              <option value="stores" selected={@sort == :stores}>Most stores</option>
            </select>
          </.form>
        </div>

        <%!-- Empty states --%>
        <div
          :if={@stats.total == 0}
          class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center"
        >
          <span class="material-symbols-outlined text-4xl text-gray-300">group</span>
          <p class="mt-2 text-sm font-medium text-gray-900">No merchants yet</p>
          <p class="text-sm text-gray-400">Merchants will appear here as they sign up.</p>
        </div>

        <%!-- Studio split: merchant queue + case panel --%>
        <div
          :if={@stats.total > 0}
          class="flex flex-col lg:flex-row bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden lg:min-h-[560px]"
        >
          <div class="w-full lg:w-[360px] shrink-0 border-b lg:border-b-0 lg:border-r border-gray-100 max-h-96 lg:max-h-none overflow-y-auto p-2">
            <div id="platform-merchants" phx-update="stream" data-count={@merchants_count}>
              <div
                :if={@merchants_count == 0}
                id="platform-merchants-empty"
                class="px-3 py-10 text-center text-sm text-gray-400"
              >
                No merchants match your filters
              </div>
              <div
                :for={{id, m} <- @streams.merchants}
                id={id}
                data-selected={@selected_merchant && @selected_merchant.id == m.id}
                class={[
                  "rounded-[10px] transition-colors",
                  if(@selected_merchant && @selected_merchant.id == m.id,
                    do: "bg-emerald-50/60 shadow-[inset_3px_0_0_theme(colors.emerald.600)]",
                    else: "hover:bg-slate-50"
                  )
                ]}
              >
                <button
                  type="button"
                  phx-click="select_merchant"
                  phx-value-id={m.id}
                  class="w-full flex items-center gap-3 px-3 py-2.5 text-left cursor-pointer"
                >
                  <div class="w-9 h-9 rounded-full bg-primary-soft flex items-center justify-center text-emerald-700 text-sm font-bold shrink-0 overflow-hidden">
                    <img
                      :if={m.avatar_url}
                      src={m.avatar_url}
                      alt=""
                      class="w-full h-full object-cover"
                    />
                    <span :if={is_nil(m.avatar_url)}>{initials(m)}</span>
                  </div>
                  <span class="min-w-0 flex-1">
                    <span class="block text-[13.5px] font-semibold text-gray-900 leading-tight truncate">
                      {m.name || "—"}
                    </span>
                    <span class="block text-[11px] text-gray-400 leading-tight truncate mt-0.5">
                      {m.email}
                    </span>
                  </span>
                  <span class="flex flex-col items-end gap-1.5 shrink-0">
                    <span
                      class={[
                        "h-2 w-2 rounded-full",
                        if(confirmed?(m), do: "bg-emerald-500", else: "bg-amber-500")
                      ]}
                      title={if confirmed?(m), do: "Confirmed", else: "Pending"}
                    >
                    </span>
                    <span :if={store_count(m) > 0} class="text-[10px] font-medium text-slate-400">
                      {store_count(m)} {if store_count(m) == 1, do: "store", else: "stores"}
                    </span>
                  </span>
                </button>
              </div>
            </div>
            <div class="flex items-center justify-between gap-3 px-3 pt-3 pb-1">
              <span class="text-[11px] font-medium tabular-nums text-slate-500">
                Showing {@merchants_count} of {@merchants_total}
              </span>
              <button
                :if={@merchants_count < @merchants_total}
                id="merchants-load-more"
                type="button"
                phx-click="load_more"
                class="cursor-pointer rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-[11px] font-bold text-slate-600 transition-colors hover:bg-slate-50"
              >
                Load more
              </button>
            </div>
          </div>

          <div id="merchant-panel" class="flex-1 min-w-0 overflow-y-auto p-6 lg:p-7">
            <.platform_empty_state
              :if={is_nil(@selected_merchant)}
              icon="hero-user-group"
              title="No merchant selected"
              description="Choose a merchant from the list."
            />
            <div :if={@selected_merchant} class="space-y-7">
              <% m = @selected_merchant %>
              <div class="flex flex-col gap-4 xl:flex-row xl:items-center">
                <div class="flex min-w-0 flex-1 items-center gap-4">
                  <div class="w-14 h-14 rounded-full bg-primary-soft flex items-center justify-center text-emerald-700 text-lg font-extrabold shrink-0 overflow-hidden">
                    <img
                      :if={m.avatar_url}
                      src={m.avatar_url}
                      alt=""
                      class="w-full h-full object-cover"
                    />
                    <span :if={is_nil(m.avatar_url)}>{initials(m)}</span>
                  </div>
                  <div class="min-w-0">
                    <div class="flex items-center gap-2.5">
                      <h3 class="text-xl font-extrabold text-slate-900 truncate">{m.name || "—"}</h3>
                      <span class={[
                        "inline-flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-extrabold",
                        if(confirmed?(m),
                          do: "bg-emerald-50 text-emerald-700",
                          else: "bg-amber-100 text-amber-700"
                        )
                      ]}>
                        {if confirmed?(m), do: "Confirmed", else: "Pending"}
                      </span>
                    </div>
                    <p class="mt-0.5 truncate text-[13px] text-slate-500">
                      {m.email} · joined {Calendar.strftime(m.inserted_at, "%b %d, %Y")}
                    </p>
                  </div>
                </div>

                <div
                  :if={Accounts.PlatformPermissions.allowed?(@current_user, :manage_merchants)}
                  class="flex shrink-0 gap-2"
                >
                  <button
                    type="button"
                    phx-click="message_merchant"
                    phx-value-id={m.id}
                    class="inline-flex items-center gap-2 rounded-[10px] bg-primary px-4 py-2.5 text-[13px] font-bold text-white shadow-sm shadow-emerald-600/25 transition-colors hover:bg-primary-hover cursor-pointer"
                  >
                    <.icon name="hero-chat-bubble-left-right" class="size-4" /> Message
                  </button>
                  <.form for={%{}} action={~p"/platform/impersonate/#{m.id}"} method="post">
                    <button
                      type="submit"
                      class="inline-flex items-center gap-2 rounded-[10px] border-[1.5px] border-gray-200 bg-white px-4 py-2.5 text-[13px] font-bold text-slate-700 transition-colors hover:border-gray-300 cursor-pointer"
                    >
                      <.icon name="hero-user" class="size-4" /> Log in as merchant
                    </button>
                  </.form>
                </div>
              </div>

              <div>
                <h4 class="mb-3 text-[10.5px] font-extrabold uppercase tracking-[0.12em] text-slate-400">
                  Details
                </h4>
                <dl class="grid grid-cols-2 gap-3 xl:grid-cols-4">
                  <.detail_tile label="Business" value={m.business_name} />
                  <.detail_tile label="Phone" value={m.phone} />
                  <.detail_tile label="Joined" value={Calendar.strftime(m.inserted_at, "%b %d, %Y")} />
                  <.detail_tile label="Stores" value={to_string(length(m.store_memberships))} />
                </dl>
              </div>

              <div>
                <h4 class="mb-3 text-[10.5px] font-extrabold uppercase tracking-[0.12em] text-slate-400">
                  Stores
                </h4>
                <div :if={m.store_memberships == []} class="text-sm text-gray-400">
                  This merchant has no stores yet.
                </div>
                <ul
                  :if={m.store_memberships != []}
                  class="divide-y divide-slate-50 overflow-hidden rounded-xl border border-slate-100"
                >
                  <li
                    :for={sm <- m.store_memberships}
                    class="flex items-center gap-3.5 bg-white px-4 py-3.5"
                  >
                    <div class="flex h-[42px] w-[42px] shrink-0 items-center justify-center rounded-[11px] bg-primary-soft text-sm font-extrabold text-emerald-700">
                      {sm.store.name |> String.first() |> String.upcase()}
                    </div>
                    <div class="min-w-0 flex-1">
                      <p class="truncate text-sm font-bold text-slate-900">{sm.store.name}</p>
                      <p class="truncate font-mono text-[11.5px] text-slate-400">{sm.store.slug}</p>
                    </div>
                    <span class={[
                      "rounded-md px-2.5 py-1 text-[10px] font-extrabold uppercase tracking-wide",
                      role_class(sm.role)
                    ]}>
                      {sm.role}
                    </span>
                    <a
                      href={EmakolaWeb.Storefront.Path.public_path(sm.store.slug)}
                      target="_blank"
                      class="inline-flex items-center gap-1 text-[12.5px] font-bold text-emerald-600 hover:text-emerald-700"
                    >
                      Storefront <.icon name="hero-arrow-up-right" class="size-3" />
                    </a>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Function components ─────────────────────────────────

  attr :label, :string, required: true
  attr :value, :string, default: nil

  defp detail_tile(assigns) do
    ~H"""
    <div class="rounded-xl border border-slate-100 bg-slate-50 px-4 py-3.5">
      <dt class="text-[11px] font-bold text-slate-400">{@label}</dt>
      <dd :if={@value not in [nil, ""]} class="mt-1 text-sm font-bold text-slate-900">{@value}</dd>
      <dd :if={@value in [nil, ""]} class="mt-1 text-sm font-semibold italic text-slate-300">
        Not added yet
      </dd>
    </div>
    """
  end

  attr :filter, :string, required: true
  attr :active, :atom, required: true
  attr :label, :string, required: true

  defp chip(assigns) do
    assigns = assign(assigns, :is_active, to_string(assigns.active) == assigns.filter)

    ~H"""
    <button
      id={"merchant-filter-#{@filter}"}
      type="button"
      phx-click="filter"
      phx-value-filter={@filter}
      class={[
        "px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors",
        if(@is_active,
          do: "bg-slate-900 text-white",
          else: "bg-white border border-gray-200 text-gray-600 hover:bg-gray-50"
        )
      ]}
    >
      {@label}
    </button>
    """
  end
end
