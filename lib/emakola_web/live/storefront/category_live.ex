defmodule EmakolaWeb.Storefront.CategoryLive do
  @moduledoc """
  Category page — shows all active products in a specific category.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

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
    <div class="max-w-7xl mx-auto px-4 sm:px-6 py-6">
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
    """
  end

  # -- Components --

  defp product_card(assigns) do
    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="group block bg-white rounded-lg border border-gray-200 overflow-hidden hover:shadow-md transition-shadow"
    >
      <div class="aspect-square bg-gray-100 flex items-center justify-center">
        <%= if first_image(@product) do %>
          <img
            src={first_image(@product)}
            alt={@product.title}
            loading="lazy"
            class="w-full h-full object-cover"
          />
        <% else %>
          <svg
            class="w-12 h-12 text-gray-300"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        <% end %>
      </div>
      <div class="p-3">
        <h3 class="text-sm font-medium text-gray-900 truncate group-hover:text-indigo-600">
          {@product.title}
        </h3>
        <p class="mt-1 text-sm font-semibold text-gray-700">
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
      </div>
    </a>
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

  defp first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end
end
