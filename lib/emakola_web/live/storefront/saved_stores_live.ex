defmodule EmakolaWeb.Storefront.SavedStoresLive do
  @moduledoc """
  Customer's saved-stores page — lists stores the logged-in customer
  has hearted from the public `/stores` directory.

  Loads favorites via `Emakola.Customers.list_favorite_stores/2` (which
  passes `:customer_id` as the action arg and respects the resource's
  read policy: only the customer's own favorites are visible). Each
  card has an unfavorite button that destroys the row and reloads.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  alias EmakolaWeb.StoresComponents

  @impl true
  def mount(%{"store_slug" => slug}, _session, socket) do
    case socket.assigns[:current_customer] do
      nil ->
        {:ok,
         socket
         |> put_flash(:info, "Please sign in to view your saved stores")
         |> redirect(to: "/@#{slug}/login")}

      customer ->
        {:ok,
         socket
         |> assign(:page_title, "Saved Stores")
         |> assign(:customer, customer)
         |> assign(:favorites, load_favorites(customer))}
    end
  end

  @impl true
  def handle_event("unfavorite", %{"id" => favorite_id}, socket) do
    customer = socket.assigns.customer

    with %{} = favorite <- Enum.find(socket.assigns.favorites, &(&1.id == favorite_id)),
         :ok <- Emakola.Customers.unfavorite_store(favorite, actor: customer) do
      {:noreply,
       socket
       |> put_flash(:info, "Removed from saved stores")
       |> assign(:favorites, load_favorites(customer))}
    else
      _ -> {:noreply, put_flash(socket, :error, "Could not remove store")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50">
      <header class="bg-white border-b border-slate-200">
        <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-6 flex items-end justify-between gap-4 flex-wrap">
          <div>
            <p class="text-xs font-bold uppercase tracking-[0.2em] text-rose-600">
              Your collection
            </p>
            <h1 class="text-3xl sm:text-4xl font-black text-slate-900 mt-1">Saved stores</h1>
            <p class="text-sm text-slate-500 mt-1">
              <span :if={@favorites != []}>
                {length(@favorites)} {if length(@favorites) == 1, do: "store", else: "stores"} you've hearted
              </span>
              <span :if={@favorites == []}>Stores you heart from the directory show up here.</span>
            </p>
          </div>
          <a
            href="/stores"
            class="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-slate-900 text-white text-sm font-bold hover:bg-slate-700 transition-colors"
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
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2h-4v-7H9v7H5a2 2 0 0 1-2-2z" />
            </svg>
            Browse marketplace
          </a>
        </div>
      </header>

      <main class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14">
        <div :if={@favorites == []} class="text-center py-20">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            class="w-20 h-20 text-rose-200 mx-auto mb-4"
            fill="currentColor"
          >
            <path d="M12 21s-7-4.5-7-11a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 6.5-7 11-7 11Z" />
          </svg>
          <h2 class="text-xl font-bold text-slate-900 mb-2">No saved stores yet</h2>
          <p class="text-sm text-slate-500 max-w-md mx-auto mb-6">
            Tap the heart icon on any store card in the marketplace to save it here.
          </p>
          <a
            href="/stores"
            class="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-rose-500 text-white text-sm font-bold hover:bg-rose-600 transition-colors"
          >
            Discover stores
          </a>
        </div>

        <div
          :if={@favorites != []}
          class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5 sm:gap-6"
        >
          <div :for={favorite <- @favorites} class="relative">
            <StoresComponents.store_card store={favorite.store} is_favorite={true} />
            <button
              type="button"
              phx-click="unfavorite"
              phx-value-id={favorite.id}
              class="absolute top-3 right-3 inline-flex items-center justify-center w-9 h-9 rounded-full bg-white/95 text-rose-500 shadow-md hover:bg-rose-50 hover:scale-105 transition-all backdrop-blur-sm z-10"
              aria-label={"Remove #{favorite.store.name} from saved"}
              title="Unfavorite"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                class="w-4 h-4"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="M12 21s-7-4.5-7-11a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 6.5-7 11-7 11Z" />
              </svg>
            </button>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp load_favorites(customer) do
    case Emakola.Customers.list_favorite_stores(customer.id, actor: customer) do
      {:ok, favorites} ->
        favorites
        |> Enum.reject(fn fav -> is_nil(fav.store) || !fav.store.active end)

      _ ->
        []
    end
  rescue
    _ -> []
  end
end
