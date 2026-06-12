defmodule EmakolaWeb.Platform.StoreLive.Index do
  @moduledoc """
  Platform admin listing of all stores with search filtering.

  Mount is gated by RequirePermission (:manage_stores). No DB queries are
  issued during the disconnected render — a nil stores state is assigned
  and the template renders a loading shell. Every mutating handle_event
  re-checks the permission against a freshly reloaded user so that a
  permission revocation after mount is caught before the write.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_stores}

  alias Emakola.Accounts.PlatformPermissions

  @impl true
  def mount(_params, _session, socket) do
    # No DB queries in disconnected mount — render a loading shell first.
    socket =
      socket
      |> assign(:page_title, "Stores")
      |> assign(:active_nav, :stores)
      |> assign(:search, "")

    socket =
      if connected?(socket) do
        load_stores(socket, "")
      else
        assign(socket, :stores, nil)
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search, query)
     |> load_stores(query)}
  end

  def handle_event("toggle_featured", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      update_directory_meta(socket, id, fn s -> %{featured: !Map.get(s, :featured, false)} end)
    end)
  end

  def handle_event("toggle_verified", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      update_directory_meta(socket, id, fn s -> %{verified: !Map.get(s, :verified, false)} end)
    end)
  end

  def handle_event("update_rank", %{"store_id" => id, "value" => value}, socket) do
    authorized(socket, fn socket ->
      rank =
        case Integer.parse(value || "") do
          {n, _} when n > 0 -> n
          _ -> nil
        end

      update_directory_meta(socket, id, fn _ -> %{featured_rank: rank} end)
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

  defp update_directory_meta(socket, id, attrs_fn) do
    case Enum.find(socket.assigns.stores, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      store ->
        case Emakola.Stores.update_store_directory_meta(store, attrs_fn.(store),
               authorize?: false
             ) do
          {:ok, updated} ->
            stores =
              Enum.map(socket.assigns.stores, fn s -> if s.id == id, do: updated, else: s end)

            {:noreply, assign(socket, :stores, stores)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not update store")}
        end
    end
  end

  defp load_stores(socket, query) do
    search = if String.trim(query) == "", do: "", else: "%#{String.trim(query)}%"

    stores =
      case Emakola.Stores.list_stores_for_admin(search, authorize?: false) do
        {:ok, list} -> list
        _ -> []
      end

    assign(socket, :stores, stores)
  rescue
    _ -> assign(socket, :stores, [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Page header --%>
      <div class="mb-6 flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Stores</h1>
          <p class="text-sm text-gray-500 mt-1">
            {if @stores,
              do: "All stores on the Emakola platform (#{length(@stores)} shown)",
              else: "All stores on the Emakola platform — loading…"}
          </p>
        </div>
      </div>

      <%!-- Search bar --%>
      <div class="mb-4 max-w-sm relative">
        <svg
          class="w-4 h-4 text-gray-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
          />
        </svg>
        <input
          type="search"
          name="search"
          value={@search}
          placeholder="Search by name or slug..."
          phx-change="search"
          phx-debounce="300"
          class="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 transition-all"
        />
      </div>

      <%!-- Stores table --%>
      <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                <th class="px-6 py-3">Store</th>
                <th class="px-6 py-3">Slug</th>
                <th class="px-6 py-3">Currency</th>
                <th class="px-6 py-3">Status</th>
                <th class="px-6 py-3">Directory</th>
                <th class="px-6 py-3">Created</th>
                <th class="px-6 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr :if={is_nil(@stores)} class="hover:bg-gray-50">
                <td colspan="7" class="px-6 py-12 text-center text-sm text-gray-400">
                  Loading stores…
                </td>
              </tr>
              <tr :if={@stores == []} class="hover:bg-gray-50">
                <td colspan="7" class="px-6 py-12 text-center text-sm text-gray-400">
                  No stores found
                </td>
              </tr>
              <tr :for={store <- @stores || []} class="hover:bg-gray-50 transition-colors">
                <td class="px-6 py-4">
                  <div class="flex items-center gap-3">
                    <div class="w-9 h-9 rounded-lg bg-blue-100 flex items-center justify-center text-blue-700 text-sm font-bold shrink-0">
                      {store.name |> String.first() |> String.upcase()}
                    </div>
                    <div class="min-w-0">
                      <p class="font-medium text-gray-900 truncate">{store.name}</p>
                      <%= if Map.get(store, :city) do %>
                        <p class="text-xs text-gray-400 truncate">{store.city}</p>
                      <% end %>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 text-sm text-gray-500 font-mono">{store.slug}</td>
                <td class="px-6 py-4">
                  <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-600">
                    {Map.get(store, :currency, "GHS")}
                  </span>
                </td>
                <td class="px-6 py-4">
                  <span class={[
                    "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                    if(Map.get(store, :active, true),
                      do: "bg-green-100 text-green-700",
                      else: "bg-red-100 text-red-700"
                    )
                  ]}>
                    <span class={[
                      "w-1.5 h-1.5 rounded-full mr-1.5",
                      if(Map.get(store, :active, true), do: "bg-green-500", else: "bg-red-400")
                    ]}>
                    </span>
                    {if(Map.get(store, :active, true), do: "Active", else: "Suspended")}
                  </span>
                </td>
                <td class="px-6 py-4">
                  <div class="flex items-center gap-2">
                    <button
                      type="button"
                      phx-click="toggle_featured"
                      phx-value-id={store.id}
                      title="Toggle featured"
                      class={[
                        "inline-flex items-center gap-1 px-2 py-1 rounded-md text-[10px] font-bold uppercase tracking-wider transition-colors",
                        if(Map.get(store, :featured, false),
                          do: "bg-amber-400 text-amber-950 hover:bg-amber-300",
                          else: "bg-slate-100 text-slate-500 hover:bg-slate-200"
                        )
                      ]}
                    >
                      <span class="material-symbols-outlined" style="font-size: 12px;">star</span>
                      Featured
                    </button>
                    <button
                      type="button"
                      phx-click="toggle_verified"
                      phx-value-id={store.id}
                      title="Toggle verified"
                      class={[
                        "inline-flex items-center gap-1 px-2 py-1 rounded-md text-[10px] font-bold uppercase tracking-wider transition-colors",
                        if(Map.get(store, :verified, false),
                          do: "bg-sky-500 text-white hover:bg-sky-400",
                          else: "bg-slate-100 text-slate-500 hover:bg-slate-200"
                        )
                      ]}
                    >
                      <span class="material-symbols-outlined" style="font-size: 12px;">verified</span>
                      Verified
                    </button>
                    <form phx-change="update_rank" class="inline-flex items-center">
                      <input type="hidden" name="store_id" value={store.id} />
                      <input
                        type="number"
                        name="value"
                        value={Map.get(store, :featured_rank)}
                        placeholder="Rank"
                        min="1"
                        phx-debounce="500"
                        class="w-16 px-2 py-1 text-xs border border-slate-200 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
                      />
                    </form>
                  </div>
                </td>
                <td class="px-6 py-4 text-sm text-gray-500">
                  {Calendar.strftime(store.inserted_at, "%b %d, %Y")}
                </td>
                <td class="px-6 py-4 text-right">
                  <a
                    href={"/s/#{store.slug}"}
                    target="_blank"
                    class="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-700 font-medium"
                  >
                    Storefront <span class="material-symbols-outlined text-xs">open_in_new</span>
                  </a>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
