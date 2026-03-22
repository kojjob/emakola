defmodule EmakolaWeb.Storefront.StoreLive do
  @moduledoc """
  Store landing page — the customer's first view of a merchant's shop.

  Matches the emakola-storefront-home.html prototype:
  - Story-style category circles (horizontal scroll)
  - Featured product hero card
  - Product grid (2-col mobile, 3-col tablet, 4-col desktop)
  - About section
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
    <div class="max-w-[1280px] mx-auto">
      <%!-- Story-style category circles --%>
      <nav
        :if={@categories != []}
        class="py-4 bg-white border-b border-[#E2E8F0]"
        aria-label="Product categories"
      >
        <div
          class="flex gap-4 px-4 sm:px-6 lg:px-8 lg:gap-6 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
          role="list"
        >
          <a
            :for={category <- @categories}
            href={"/s/#{@store.slug}/category/#{category.slug}"}
            class="flex flex-col items-center gap-1.5 flex-shrink-0 group"
            role="listitem"
          >
            <div class="w-[68px] h-[68px] rounded-full p-[3px] bg-[#E2E8F0] group-hover:scale-105 transition-transform">
              <%= if category_image(category) do %>
                <img
                  src={category_image(category)}
                  alt={category.name}
                  class="w-full h-full rounded-full object-cover border-2 border-white"
                  loading="lazy"
                  width="62"
                  height="62"
                />
              <% else %>
                <div class="w-full h-full rounded-full bg-[#F1F5F9] border-2 border-white flex items-center justify-center">
                  <span class="text-lg font-semibold text-[#94A3B8]">
                    {String.first(category.name)}
                  </span>
                </div>
              <% end %>
            </div>
            <span class="text-[0.6875rem] font-medium text-[#475569] text-center whitespace-nowrap group-hover:text-[#0F172A]">
              {category.name}
            </span>
          </a>
        </div>
      </nav>

      <%!-- Main content --%>
      <div class="px-4 sm:px-6 lg:px-8 py-4 sm:py-6">
        <%!-- Featured product hero card --%>
        <.featured_card :if={@products != []} product={List.first(@products)} store={@store} />

        <%!-- Product grid --%>
        <section :if={@products != []} aria-labelledby="shop-all-heading">
          <h2 id="shop-all-heading" class="text-lg font-bold text-[#0F172A] mb-4">Shop All</h2>
          <div class="grid grid-cols-2 gap-3 md:grid-cols-3 md:gap-4 lg:grid-cols-4 lg:gap-5 mb-10">
            <.product_card :for={product <- @products} product={product} store={@store} />
          </div>
        </section>

        <%!-- About section --%>
        <section class="bg-white border border-[#E2E8F0] rounded-[20px] p-6 sm:p-8 mb-10 text-center">
          <h2 class="text-lg font-bold text-[#0F172A] mb-4">About the Shop</h2>
          <div class="w-20 h-20 rounded-full bg-[#FEF3C7] border-[3px] border-[#FEF3C7] mx-auto mb-3.5 flex items-center justify-center">
            <span class="text-2xl font-bold text-[#B45309]">{String.first(@store.name)}</span>
          </div>
          <p
            :if={@store.description}
            class="text-sm text-[#475569] leading-relaxed max-w-[480px] mx-auto mb-4"
          >
            {@store.description}
          </p>
          <p
            :if={!@store.description}
            class="text-sm text-[#475569] leading-relaxed max-w-[480px] mx-auto mb-4"
          >
            Welcome to {@store.name}. Browse our collection of quality products handpicked for you.
          </p>
        </section>
      </div>
    </div>
    """
  end

  # -- Components --

  defp featured_card(assigns) do
    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="block bg-white rounded-[20px] overflow-hidden border border-[#E2E8F0] mb-8 hover:shadow-[0_4px_24px_rgba(0,0,0,0.06)] transition-shadow md:grid md:grid-cols-2"
      aria-label={"Featured product: #{@product.title}"}
    >
      <div class="w-full aspect-[16/10] md:aspect-auto md:h-full md:min-h-[320px] bg-[#F1F5F9] overflow-hidden">
        <%= if first_image(@product) do %>
          <img
            src={first_image(@product)}
            alt={@product.title}
            class="w-full h-full object-cover"
            loading="eager"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center">
            <svg
              class="w-16 h-16 text-[#94A3B8]"
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
          </div>
        <% end %>
      </div>
      <div class="p-5 sm:p-6 md:p-8 md:flex md:flex-col md:justify-center">
        <span class="inline-flex items-center px-2.5 py-1 text-[0.625rem] font-bold tracking-wider uppercase text-[#B45309] bg-[#FEF3C7] rounded-full mb-2.5">
          New Arrival
        </span>
        <h1 class="text-xl font-bold text-[#0F172A] mb-1.5 leading-tight">{@product.title}</h1>
        <p :if={@product.description} class="text-sm text-[#475569] leading-relaxed mb-4 line-clamp-2">
          {@product.description}
        </p>
        <p class="text-lg font-bold text-[#0F172A] mb-4">
          {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
        </p>
        <span class="flex items-center justify-center gap-2 w-full py-3.5 px-6 bg-[#1C1917] text-white rounded-full text-[0.9375rem] font-semibold hover:bg-[#292524] active:scale-[0.98] transition-all leading-none">
          <svg
            class="w-[18px] h-[18px]"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
            />
          </svg>
          Add to Bag
        </span>
      </div>
    </a>
    """
  end

  defp product_card(assigns) do
    ~H"""
    <a
      href={"/s/#{@store.slug}/products/#{@product.slug}"}
      class="group block"
    >
      <div class="relative rounded-[16px] overflow-hidden mb-2 bg-[#F1F5F9]">
        <%= if first_image(@product) do %>
          <img
            src={first_image(@product)}
            alt={@product.title}
            loading="lazy"
            class="w-full aspect-[3/4] object-cover group-hover:scale-[1.04] transition-transform duration-300"
          />
        <% else %>
          <div class="w-full aspect-[3/4] flex items-center justify-center">
            <svg
              class="w-12 h-12 text-[#94A3B8]"
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
          </div>
        <% end %>
        <div class="absolute bottom-0 left-0 right-0 p-2.5 bg-gradient-to-t from-black/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity flex justify-center">
          <span class="text-xs font-semibold text-white tracking-wide">Add to Bag</span>
        </div>
      </div>
      <p class="text-[0.8125rem] font-medium text-[#0F172A] leading-tight mb-0.5 truncate">
        {@product.title}
      </p>
      <p class="text-[0.8125rem] font-bold text-[#0F172A]">
        {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
      </p>
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

  defp category_image(category) do
    if Map.has_key?(category, :image_url) do
      category.image_url
    else
      nil
    end
  end
end
