defmodule EmakolaWeb.Storefront.CategoryLive do
  @moduledoc """
  Category page — shows all active products in a specific category.
  """
  use EmakolaWeb, :live_view
  import EmakolaWeb.StorefrontComponents

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug, "category_slug" => category_slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        case load_category(store.id, category_slug) do
          nil ->
            {:ok,
             socket
             |> assign(:store, store)
             |> put_flash(:error, "Category not found")
             |> redirect(to: "/s/#{slug}/products")}

          category ->
            products = load_category_products(store.id, category.id)
            cart_session_id = session["cart_session_id"]
            cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:category, category)
             |> assign(:products, products)
             |> assign(:cart_session_id, cart_session_id)
             |> assign(:cart_count, cart_count)
             |> assign(:page_title, "#{category.name} - #{store.name}")}
        end

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 py-6 pb-16 sm:pb-0">
      <!-- Breadcrumb -->
      <nav class="text-sm text-gray-500 mb-6">
        <a href={"/s/#{@store.slug}"} class="hover:text-gray-700">Home</a>
        <span class="mx-2">/</span>
        <span class="text-gray-900">{@category.name}</span>
      </nav>

      <h1 class="text-2xl font-bold text-gray-900 mb-2">{@category.name}</h1>
      <p :if={@category.description} class="text-gray-500 mb-6">{@category.description}</p>

      <%= if @products == [] do %>
        <p class="text-center text-gray-500 py-12">No products in this category yet.</p>
      <% else %>
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          <.product_card :for={product <- @products} product={product} store={@store} />
        </div>
      <% end %>
    </div>

    <.bottom_nav store_slug={@store.slug} active_tab={:search} cart_count={@cart_count} />
    """
  end

  # -- Helpers --

  defp load_category(store_id, category_slug) do
    Emakola.Catalog.Category
    |> Ash.Query.filter(store_id == ^store_id and slug == ^category_slug)
    |> Ash.read_one!()
  end

  defp load_category_products(store_id, category_id) do
    Emakola.Catalog.list_products_by_category!(category_id, store_id)
    |> Enum.filter(&(&1.status == :active))
    |> Ash.load!([:min_price, :max_price, :images])
  end
end
