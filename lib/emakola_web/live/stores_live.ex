defmodule EmakolaWeb.StoresLive do
  @moduledoc """
  Public stores directory — lists every active merchant store.

  Unauthenticated entry point for shoppers who want to browse what's available
  on Emakola before committing to register or visit a specific store.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:stores, list_active_stores())
     |> assign(:page_title, "Browse Stores — Emakola"), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0c1526] text-[#f1f5f9] font-body antialiased">
      <header class="border-b border-[#1a2744] bg-[#0c1526]/95 backdrop-blur-md sticky top-0 z-40">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex items-center justify-between">
          <a href="/" class="flex items-center gap-2">
            <img src={~p"/images/emakola-logo.svg"} alt="Emakola" class="h-8 w-auto" />
            <span class="text-lg font-bold tracking-tight">Emakola</span>
          </a>
          <a
            href="/auth/register"
            class="text-xs sm:text-sm font-semibold text-[#0c1526] bg-[#d4a843] hover:bg-[#c19833] px-4 py-2 rounded-lg transition-colors"
          >
            Sell on Emakola
          </a>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-16">
        <div class="mb-10 lg:mb-14">
          <h1 class="text-3xl lg:text-5xl font-extrabold tracking-tight">
            Browse Stores
          </h1>
          <p class="mt-3 text-[#8896ab] text-base lg:text-lg max-w-2xl">
            Discover merchants across Ghana selling fashion, beauty, food, electronics and more.
          </p>
        </div>

        <%= if @stores == [] do %>
          <div class="rounded-2xl border border-[#1a2744] bg-[#101b30] p-12 text-center">
            <span class="material-symbols-outlined text-5xl text-[#8896ab] mb-4 block">
              storefront
            </span>
            <h2 class="text-xl font-semibold text-[#f1f5f9] mb-2">No stores yet</h2>
            <p class="text-[#8896ab] text-sm max-w-md mx-auto">
              Be the first merchant on Emakola.
              <a href="/auth/register" class="text-[#d4a843] font-semibold hover:underline">
                Open your store
              </a>
              and start selling today.
            </p>
          </div>
        <% else %>
          <ul
            role="list"
            class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 lg:gap-6"
          >
            <li :for={store <- @stores}>
              <a
                href={~p"/s/#{store.slug}"}
                class="group block h-full rounded-2xl border border-[#1a2744] bg-[#101b30] hover:border-[#d4a843]/60 hover:bg-[#13203a] transition-all duration-200 overflow-hidden focus-visible:ring-2 focus-visible:ring-[#d4a843] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0c1526]"
              >
                <div class="aspect-[16/9] bg-[#0c1526] border-b border-[#1a2744] flex items-center justify-center overflow-hidden">
                  <%= if store.logo_url do %>
                    <img
                      src={store.logo_url}
                      alt={"#{store.name} logo"}
                      class="w-full h-full object-cover"
                      loading="lazy"
                    />
                  <% else %>
                    <span class="material-symbols-outlined text-6xl text-[#2a3a5c]">
                      storefront
                    </span>
                  <% end %>
                </div>
                <div class="p-5 lg:p-6">
                  <h2 class="text-lg lg:text-xl font-bold text-[#f1f5f9] group-hover:text-[#d4a843] transition-colors">
                    {store.name}
                  </h2>
                  <p
                    :if={location(store) != ""}
                    class="mt-1 flex items-center gap-1 text-xs text-[#8896ab]"
                  >
                    <span class="material-symbols-outlined text-sm">location_on</span>
                    {location(store)}
                  </p>
                  <p
                    :if={store.description}
                    class="mt-3 text-sm text-[#8896ab] line-clamp-2"
                  >
                    {store.description}
                  </p>
                  <span class="mt-4 inline-flex items-center gap-1 text-sm font-semibold text-[#d4a843]">
                    Visit store
                    <span class="material-symbols-outlined text-base group-hover:translate-x-1 transition-transform">
                      arrow_forward
                    </span>
                  </span>
                </div>
              </a>
            </li>
          </ul>
        <% end %>
      </main>

      <footer class="border-t border-[#1a2744] mt-16">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 text-center text-xs text-[#8896ab]">
          © {Date.utc_today().year} Emakola — Empowering West African merchants.
        </div>
      </footer>
    </div>
    """
  end

  defp list_active_stores do
    Emakola.Accounts.Store
    |> Ash.Query.filter(active == true)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp location(store) do
    [store.city, store.region]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(", ")
  end
end
