defmodule EmakolaWeb.Storefront.StoreLive do
  @moduledoc """
  Store landing page — the customer's first view of a merchant's shop.

  Shows a hero section with the store name, featured active products,
  and root category navigation cards.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug}, _session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        products = load_featured_products(store)
        categories = load_root_categories(store)

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:products, products)
         |> assign(:categories, categories)
         |> assign(:cart, [])
         |> assign(:cart_count, 0)
         |> assign(:page_title, store.name)}

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
    <div class="max-w-7xl mx-auto px-4 sm:px-6">
      <!-- Hero section -->
      <section class="py-8 sm:py-12 text-center">
        <h1 class="text-3xl sm:text-4xl font-bold text-gray-900">
          Welcome to {@store.name}
        </h1>
        <p class="mt-3 text-gray-500 text-base sm:text-lg max-w-2xl mx-auto">
          Browse our collection of quality products
        </p>
        <a
          href={"/s/#{@store.slug}/products"}
          class="mt-6 inline-block bg-indigo-600 text-white px-6 py-3 rounded-lg text-sm font-semibold hover:bg-indigo-700 transition-colors"
        >
          Shop Now
        </a>
      </section>
      <!-- Categories -->
      <section :if={@categories != []} class="py-6">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Shop by Category</h2>
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          <a
            :for={category <- @categories}
            href={"/s/#{@store.slug}/category/#{category.slug}"}
            class="block p-4 bg-gray-50 rounded-lg border border-gray-200 hover:border-indigo-300 hover:bg-indigo-50 transition-colors text-center"
          >
            <p class="font-medium text-gray-900 text-sm">{category.name}</p>
            <p :if={category.description} class="mt-1 text-xs text-gray-500 line-clamp-2">
              {category.description}
            </p>
          </a>
        </div>
      </section>
      <!-- Featured products -->
      <section :if={@products != []} class="py-6 pb-12">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold text-gray-900">Featured Products</h2>
          <a
            href={"/s/#{@store.slug}/products"}
            class="text-sm text-indigo-600 hover:text-indigo-700 font-medium"
          >
            View all &rarr;
          </a>
        </div>
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          <.product_card :for={product <- @products} product={product} store={@store} />
        </div>
      </section>
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

  defp load_featured_products(store) do
    Emakola.Catalog.list_products_by_store_and_status!(store.id, :active)
    |> Ash.load!([:min_price, :max_price, :images])
    |> Enum.take(8)
  end

  defp load_root_categories(store) do
    Emakola.Catalog.list_root_categories!(store.id)
  end

  defp first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end
end
