defmodule EmakolaWeb.Platform.MerchantLive.Index do
  @moduledoc """
  Platform directory of all merchants with a slide-over detail drawer.

  Mount is gated by RequirePermission (:manage_merchants). No DB queries are
  issued during the disconnected render — a nil merchants state is assigned
  and the template renders a loading shell. The page is read-only, so its
  events (search, filter, select) issue no writes.
  """
  use EmakolaWeb, :live_view
  require Logger

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_merchants}

  alias Emakola.Accounts

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Merchants")
      |> assign(:active_nav, :merchants)
      |> assign(:search, "")
      |> assign(:search_form, to_form(%{"search" => ""}))
      |> assign(:filter, :all)
      |> assign(:selected_merchant, nil)

    socket =
      if connected?(socket) do
        load_merchants(socket)
      else
        assign(socket, all_merchants: nil, merchants: [], stats: nil)
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
     |> apply_filter()}
  end

  def handle_event("filter", %{"filter" => f}, socket) do
    {:noreply, socket |> assign(:filter, parse_filter(f)) |> apply_filter()}
  end

  def handle_event("select_merchant", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_merchant, load_merchant_detail(id))}
  end

  # ── Data ───────────────────────────────────────────────

  defp load_merchants(socket) do
    all =
      case Accounts.list_merchants_for_admin("", authorize?: false) do
        {:ok, list} -> list
        _ -> []
      end

    socket
    |> assign(:all_merchants, all)
    |> assign(:stats, compute_stats(all))
    |> apply_filter()
  rescue
    exception ->
      Logger.error(
        "[platform.merchant_live] load_merchants loading merchants raised: #{Exception.message(exception)}"
      )

      assign(socket, all_merchants: [], merchants: [], stats: compute_stats([]))
  end

  defp apply_filter(socket) do
    all = socket.assigns.all_merchants || []
    assign(socket, :merchants, filtered(all, socket.assigns.search, socket.assigns.filter))
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

  defp role_class(:owner), do: "bg-blue-100 text-blue-700"
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
          {if @stats, do: "Everyone building on Makola (#{@stats.total})", else: "Loading merchants…"}
        </p>
      </div>

      <%!-- Loading shell (disconnected mount — no DB) --%>
      <div
        :if={is_nil(@all_merchants)}
        class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center text-sm text-gray-400"
      >
        Loading merchants…
      </div>

      <div :if={@all_merchants}>
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
              class="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 transition-all"
            />
          </.form>
          <div class="flex items-center gap-1.5">
            <.chip filter="all" active={@filter} label="All" />
            <.chip filter="confirmed" active={@filter} label="Confirmed" />
            <.chip filter="unconfirmed" active={@filter} label="Unconfirmed" />
          </div>
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

        <div
          :if={@stats.total > 0 and @merchants == []}
          class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center text-sm text-gray-400"
        >
          No merchants match your filters
        </div>

        <%!-- Table --%>
        <div
          :if={@merchants != []}
          class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden"
        >
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Merchant</th>
                  <th class="px-6 py-3">Business</th>
                  <th class="px-6 py-3">Stores</th>
                  <th class="px-6 py-3">Status</th>
                  <th class="px-6 py-3">Joined</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr
                  :for={m <- @merchants}
                  id={"merchant-#{m.id}"}
                  class="hover:bg-gray-50 transition-colors cursor-pointer"
                  phx-click={
                    JS.push("select_merchant", value: %{id: m.id}) |> show_modal("merchant-drawer")
                  }
                >
                  <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                      <div class="w-9 h-9 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 text-sm font-bold shrink-0 overflow-hidden">
                        <img
                          :if={m.avatar_url}
                          src={m.avatar_url}
                          alt=""
                          class="w-full h-full object-cover"
                        />
                        <span :if={is_nil(m.avatar_url)}>{initials(m)}</span>
                      </div>
                      <div class="min-w-0">
                        <p class="font-medium text-gray-900 truncate">{m.name || "—"}</p>
                        <p class="text-xs text-gray-400 truncate">{m.email}</p>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-600">{m.business_name || "—"}</td>
                  <td class="px-6 py-4">
                    <span
                      :if={store_count(m) > 0}
                      class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-600"
                    >
                      {store_count(m)} {if store_count(m) == 1, do: "store", else: "stores"}
                    </span>
                    <span :if={store_count(m) == 0} class="text-xs text-gray-400">—</span>
                  </td>
                  <td class="px-6 py-4">
                    <span class={[
                      "inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium",
                      if(confirmed?(m),
                        do: "bg-green-100 text-green-700",
                        else: "bg-amber-100 text-amber-700"
                      )
                    ]}>
                      <span class={[
                        "w-1.5 h-1.5 rounded-full",
                        if(confirmed?(m), do: "bg-green-500", else: "bg-amber-500")
                      ]}>
                      </span>
                      {if confirmed?(m), do: "Confirmed", else: "Pending"}
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-500">
                    {Calendar.strftime(m.inserted_at, "%b %d, %Y")}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <%!-- Detail drawer (always rendered, nil-safe) --%>
      <.modal id="merchant-drawer" kind={:slide_over} title="Merchant">
        <div :if={@selected_merchant} class="space-y-6">
          <% m = @selected_merchant %>
          <div class="flex items-center gap-4">
            <div class="w-16 h-16 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 text-xl font-bold shrink-0 overflow-hidden">
              <img :if={m.avatar_url} src={m.avatar_url} alt="" class="w-full h-full object-cover" />
              <span :if={is_nil(m.avatar_url)}>{initials(m)}</span>
            </div>
            <div class="min-w-0">
              <h3 class="text-lg font-semibold text-gray-900 truncate">{m.name || "—"}</h3>
              <p class="text-sm text-gray-500 truncate">{m.email}</p>
              <span class={[
                "inline-flex items-center gap-1.5 px-2 py-0.5 mt-1 rounded-full text-xs font-medium",
                if(confirmed?(m),
                  do: "bg-green-100 text-green-700",
                  else: "bg-amber-100 text-amber-700"
                )
              ]}>
                {if confirmed?(m), do: "Confirmed", else: "Pending"}
              </span>
            </div>
          </div>

          <.form
            :if={Accounts.PlatformPermissions.allowed?(@current_user, :manage_merchants)}
            for={%{}}
            action={~p"/platform/impersonate/#{m.id}"}
            method="post"
          >
            <button
              type="submit"
              class="w-full rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 transition-colors"
            >
              Log in as this merchant
            </button>
          </.form>

          <dl class="grid grid-cols-2 gap-4 text-sm">
            <div>
              <dt class="text-gray-400">Business</dt>
              <dd class="text-gray-900">{m.business_name || "—"}</dd>
            </div>
            <div>
              <dt class="text-gray-400">Phone</dt>
              <dd class="text-gray-900">{m.phone || "—"}</dd>
            </div>
            <div>
              <dt class="text-gray-400">Joined</dt>
              <dd class="text-gray-900">{Calendar.strftime(m.inserted_at, "%b %d, %Y")}</dd>
            </div>
            <div>
              <dt class="text-gray-400">Stores</dt>
              <dd class="text-gray-900">{length(m.store_memberships)}</dd>
            </div>
          </dl>

          <div>
            <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">Stores</h4>
            <div :if={m.store_memberships == []} class="text-sm text-gray-400">
              This merchant has no stores yet.
            </div>
            <ul class="space-y-2">
              <li
                :for={sm <- m.store_memberships}
                class="flex items-center justify-between gap-3 p-3 rounded-xl border border-gray-100"
              >
                <div class="min-w-0">
                  <p class="font-medium text-gray-900 truncate">{sm.store.name}</p>
                  <p class="text-xs text-gray-400 font-mono truncate">{sm.store.slug}</p>
                </div>
                <div class="flex items-center gap-2 shrink-0">
                  <span class={[
                    "px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide",
                    role_class(sm.role)
                  ]}>
                    {sm.role}
                  </span>
                  <a
                    href={"/s/#{sm.store.slug}"}
                    target="_blank"
                    class="text-xs text-blue-600 hover:text-blue-700 font-medium inline-flex items-center gap-0.5"
                  >
                    View
                    <span class="material-symbols-outlined" style="font-size: 13px;">
                      open_in_new
                    </span>
                  </a>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </.modal>
    </div>
    """
  end

  # ── Function components ─────────────────────────────────

  attr :filter, :string, required: true
  attr :active, :atom, required: true
  attr :label, :string, required: true

  defp chip(assigns) do
    assigns = assign(assigns, :is_active, to_string(assigns.active) == assigns.filter)

    ~H"""
    <button
      type="button"
      phx-click="filter"
      phx-value-filter={@filter}
      class={[
        "px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors",
        if(@is_active,
          do: "bg-blue-600 text-white",
          else: "bg-white border border-gray-200 text-gray-600 hover:bg-gray-50"
        )
      ]}
    >
      {@label}
    </button>
    """
  end
end
