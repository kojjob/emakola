defmodule EmakolaWeb.Platform.StoreLive.Index do
  @moduledoc "Platform admin listing of all stores with search filtering."
  use EmakolaWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Stores")
     |> assign(:active_nav, :stores)
     |> assign(:search, "")
     |> load_stores("")}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search, query)
     |> load_stores(query)}
  end

  defp load_stores(socket, query) do
    stores =
      if String.trim(query) == "" do
        Emakola.Stores.Store
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.read!(authorize?: false)
      else
        q = "%#{String.trim(query)}%"

        Emakola.Stores.Store
        |> Ash.Query.filter(ilike(name, ^q) or ilike(slug, ^q))
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.read!(authorize?: false)
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
            All stores on the Emakola platform ({length(@stores)} shown)
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
                <th class="px-6 py-3">Created</th>
                <th class="px-6 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr :if={@stores == []} class="hover:bg-gray-50">
                <td colspan="6" class="px-6 py-12 text-center text-sm text-gray-400">
                  No stores found
                </td>
              </tr>
              <tr :for={store <- @stores} class="hover:bg-gray-50 transition-colors">
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
