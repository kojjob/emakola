defmodule EmakolaWeb.Storefront.ProductDetailLive do
  @moduledoc """
  Product detail page — shows full product information with variant selection,
  pricing, stock status, and "Add to Cart" functionality.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.{Currency, StoreResolver}

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug, "product_slug" => product_slug}, _session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        case load_product(store.id, product_slug) do
          nil ->
            {:ok,
             socket
             |> assign(:store, store)
             |> put_flash(:error, "Product not found")
             |> redirect(to: "/s/#{slug}/products")}

          product ->
            option_types = load_option_types(product)
            selected_variant = List.first(product.variants)

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:product, product)
             |> assign(:option_types, option_types)
             |> assign(:selected_variant, selected_variant)
             |> assign(:selected_options, build_initial_options(option_types, selected_variant))
             |> assign(:quantity, 1)
             |> assign(:cart, [])
             |> assign(:cart_count, 0)
             |> assign(:page_title, "#{product.title} - #{store.name}")}
        end

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("select_option", %{"option_type_id" => ot_id, "value" => value}, socket) do
    selected_options = Map.put(socket.assigns.selected_options, ot_id, value)

    variant =
      find_matching_variant(
        socket.assigns.product.variants,
        selected_options,
        socket.assigns.option_types
      )

    {:noreply,
     socket
     |> assign(:selected_options, selected_options)
     |> assign(:selected_variant, variant)}
  end

  @impl true
  def handle_event("add_to_cart", _params, socket) do
    variant = socket.assigns.selected_variant

    if is_nil(variant) || variant.stock_quantity <= 0 do
      {:noreply, put_flash(socket, :error, "This variant is out of stock")}
    else
      cart = socket.assigns.cart
      quantity = socket.assigns.quantity
      existing = Enum.find_index(cart, &(&1.variant_id == variant.id))

      new_cart =
        if existing do
          List.update_at(cart, existing, fn item ->
            %{item | quantity: item.quantity + quantity}
          end)
        else
          cart ++
            [
              %{
                variant_id: variant.id,
                quantity: quantity,
                product_title: socket.assigns.product.title,
                variant_info: variant_label(variant, socket.assigns.option_types),
                unit_price: variant.price,
                sku: variant.sku
              }
            ]
        end

      cart_count = Enum.reduce(new_cart, 0, fn item, acc -> acc + item.quantity end)

      {:noreply,
       socket
       |> assign(:cart, new_cart)
       |> assign(:cart_count, cart_count)
       |> put_flash(:info, "Added to cart")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 py-6">
      <!-- Breadcrumb -->
      <nav class="text-sm text-gray-500 mb-6">
        <a href={"/s/#{@store.slug}/products"} class="hover:text-gray-700">Products</a>
        <span class="mx-2">/</span>
        <span class="text-gray-900">{@product.title}</span>
      </nav>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-8">
        <!-- Images -->
        <div>
          <div class="aspect-square bg-gray-100 rounded-lg overflow-hidden flex items-center justify-center">
            <%= if first_image(@product) do %>
              <img
                src={first_image(@product)}
                alt={@product.title}
                loading="lazy"
                class="w-full h-full object-cover"
              />
            <% else %>
              <svg
                class="w-20 h-20 text-gray-300"
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
          <!-- Thumbnail gallery -->
          <div
            :if={length(@product.images) > 1}
            class="mt-3 grid grid-cols-4 gap-2"
          >
            <div
              :for={img <- @product.images}
              class="aspect-square bg-gray-100 rounded overflow-hidden"
            >
              <img
                src={img.thumbnail_url || img.url}
                alt={img.alt_text || @product.title}
                loading="lazy"
                class="w-full h-full object-cover"
              />
            </div>
          </div>
        </div>
        <!-- Product info -->
        <div>
          <h1 class="text-2xl font-bold text-gray-900">{@product.title}</h1>
          
    <!-- Price -->
          <div class="mt-3">
            <%= if @selected_variant do %>
              <p class="text-2xl font-bold text-gray-900">
                {Currency.format_price(@selected_variant.price, @store.currency)}
              </p>
            <% else %>
              <p class="text-2xl font-bold text-gray-900">
                {Currency.format_price_range(@product.min_price, @product.max_price, @store.currency)}
              </p>
            <% end %>
          </div>
          
    <!-- Stock status -->
          <div class="mt-2">
            <.stock_badge variant={@selected_variant} />
          </div>
          
    <!-- Option selectors -->
          <div :if={@option_types != []} class="mt-6 space-y-4">
            <div :for={ot <- @option_types}>
              <label class="block text-sm font-medium text-gray-700 mb-1">{ot.name}</label>
              <select
                phx-change="select_option"
                name="value"
                phx-value-option_type_id={ot.id}
                class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                <option
                  :for={ov <- ot.option_values}
                  value={ov.id}
                  selected={Map.get(@selected_options, ot.id) == ov.id}
                >
                  {ov.value}
                </option>
              </select>
            </div>
          </div>
          
    <!-- Description -->
          <div :if={@product.description} class="mt-6">
            <h2 class="text-sm font-semibold text-gray-900 mb-2">Description</h2>
            <p class="text-sm text-gray-600 leading-relaxed">{@product.description}</p>
          </div>
          
    <!-- Add to cart -->
          <div class="mt-6">
            <button
              phx-click="add_to_cart"
              disabled={is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0}
              class={[
                "w-full py-3 px-6 rounded-lg text-sm font-semibold transition-colors",
                if(is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0,
                  do: "bg-gray-300 text-gray-500 cursor-not-allowed",
                  else: "bg-indigo-600 text-white hover:bg-indigo-700"
                )
              ]}
            >
              <%= if is_nil(@selected_variant) || @selected_variant.stock_quantity <= 0 do %>
                Out of Stock
              <% else %>
                Add to Cart
              <% end %>
            </button>
          </div>
          
    <!-- SKU -->
          <p :if={@selected_variant && @selected_variant.sku} class="mt-4 text-xs text-gray-400">
            SKU: {@selected_variant.sku}
          </p>
        </div>
      </div>
    </div>
    """
  end

  # -- Components --

  defp stock_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@variant) -> %>
        <span class="text-sm text-gray-500">Select options</span>
      <% @variant.stock_quantity <= 0 -> %>
        <span class="inline-flex items-center text-sm font-medium text-red-600">
          Out of Stock
        </span>
      <% @variant.stock_quantity < 5 -> %>
        <span class="inline-flex items-center text-sm font-medium text-amber-600">
          Low Stock ({@variant.stock_quantity} left)
        </span>
      <% true -> %>
        <span class="inline-flex items-center text-sm font-medium text-green-600">
          In Stock
        </span>
    <% end %>
    """
  end

  # -- Helpers --

  defp load_product(store_id, product_slug) do
    Emakola.Catalog.Product
    |> Ash.Query.filter(store_id == ^store_id and slug == ^product_slug and status == :active)
    |> Ash.Query.load([:variants, :images, :min_price, :max_price])
    |> Ash.read_one!()
  end

  defp load_option_types(product) do
    Emakola.Catalog.OptionType
    |> Ash.Query.filter(product_id == ^product.id)
    |> Ash.Query.load(:option_values)
    |> Ash.Query.sort(position: :asc)
    |> Ash.read!()
  end

  defp build_initial_options([], _variant), do: %{}
  defp build_initial_options(_option_types, nil), do: %{}

  defp build_initial_options(option_types, variant) do
    # Load variant option values to pre-select
    vovs =
      Emakola.Catalog.VariantOptionValue
      |> Ash.Query.filter(variant_id == ^variant.id)
      |> Ash.Query.load(:option_value)
      |> Ash.read!()

    Enum.reduce(vovs, %{}, fn vov, acc ->
      ov = vov.option_value
      # Find which option_type this value belongs to
      ot = Enum.find(option_types, fn ot -> ot.id == ov.option_type_id end)
      if ot, do: Map.put(acc, ot.id, ov.id), else: acc
    end)
  end

  defp find_matching_variant(variants, selected_options, _option_types)
       when map_size(selected_options) == 0 do
    List.first(variants)
  end

  defp find_matching_variant(variants, selected_options, _option_types) do
    selected_value_ids = Map.values(selected_options) |> MapSet.new()

    Enum.find(variants, fn variant ->
      vovs =
        Emakola.Catalog.VariantOptionValue
        |> Ash.Query.filter(variant_id == ^variant.id)
        |> Ash.read!()

      variant_value_ids = MapSet.new(Enum.map(vovs, & &1.option_value_id))
      MapSet.subset?(selected_value_ids, variant_value_ids)
    end) || List.first(variants)
  end

  defp variant_label(variant, option_types) do
    if option_types == [] do
      variant.sku || "Default"
    else
      vovs =
        Emakola.Catalog.VariantOptionValue
        |> Ash.Query.filter(variant_id == ^variant.id)
        |> Ash.Query.load(:option_value)
        |> Ash.read!()

      Enum.map(vovs, fn vov -> vov.option_value.value end)
      |> Enum.join(" / ")
    end
  end

  defp first_image(product) do
    case product.images do
      [%{medium_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end
end
