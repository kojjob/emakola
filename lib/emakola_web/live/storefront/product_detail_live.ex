defmodule EmakolaWeb.Storefront.ProductDetailLive do
  @moduledoc """
  Product detail page — matches emakola-storefront-product.html prototype.

  Mobile-first layout:
  - Sticky top bar with back button + store name + cart
  - Full-width image gallery with dot indicators
  - Product info: badge, title, price, rating, description
  - Variant selectors: pill buttons for size, color swatches
  - Quantity stepper + Add to Bag CTA + WhatsApp ask button
  - Accordion for details, shipping, returns
  - Related products horizontal scroll
  """
  use EmakolaWeb, :live_view
  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug, "product_slug" => product_slug}, session, socket) do
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
            related = load_related_products(store, product)
            cart_session_id = session["cart_session_id"]
            cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:product, product)
             |> assign(:option_types, option_types)
             |> assign(:selected_variant, selected_variant)
             |> assign(:selected_options, build_initial_options(option_types, selected_variant))
             |> assign(:quantity, 1)
             |> assign(:current_image_index, 0)
             |> assign(:related_products, related)
             |> assign(:cart_session_id, cart_session_id)
             |> assign(:cart_count, cart_count)
             |> assign(:page_title, "#{product.title} - #{store.name}")
             |> assign(:theme, Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{}))
             |> assign(
               :theme_module,
               Emakola.Themes.ThemeResolver.theme_module(
                 (store.theme_config || %{})["theme"] || "market"
               )
             )}
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
  def handle_event("increment_quantity", _params, socket) do
    {:noreply, assign(socket, :quantity, min(socket.assigns.quantity + 1, 10))}
  end

  @impl true
  def handle_event("decrement_quantity", _params, socket) do
    {:noreply, assign(socket, :quantity, max(socket.assigns.quantity - 1, 1))}
  end

  @impl true
  def handle_event("select_image", %{"index" => index_str}, socket) do
    {:noreply, assign(socket, :current_image_index, String.to_integer(index_str))}
  end

  @impl true
  def handle_event("add_to_cart", _params, socket) do
    variant = socket.assigns.selected_variant

    if is_nil(variant) || variant.stock_quantity <= 0 do
      {:noreply, put_flash(socket, :error, "This variant is out of stock")}
    else
      cart_session_id = socket.assigns.cart_session_id
      quantity = socket.assigns.quantity

      CartStore.add_item(cart_session_id, %{
        variant_id: variant.id,
        quantity: quantity,
        product_title: socket.assigns.product.title,
        variant_info: variant_label(variant, socket.assigns.option_types),
        unit_price: variant.price,
        sku: variant.sku
      })

      cart_count = CartStore.cart_count(cart_session_id)

      {:noreply,
       socket
       |> assign(:cart_count, cart_count)
       |> put_flash(:info, "Added to cart")}
    end
  end

  @impl true
  def render(assigns) do
    assigns.theme_module.render_product_detail(assigns)
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

  defp load_related_products(store, product) do
    Emakola.Catalog.list_products_by_store_and_status!(store.id, :active)
    |> Ash.load!([:min_price, :max_price, :images])
    |> Enum.reject(&(&1.id == product.id))
    |> Enum.take(6)
  end

  defp build_initial_options([], _variant), do: %{}
  defp build_initial_options(_option_types, nil), do: %{}

  defp build_initial_options(option_types, variant) do
    vovs =
      Emakola.Catalog.VariantOptionValue
      |> Ash.Query.filter(variant_id == ^variant.id)
      |> Ash.Query.load(:option_value)
      |> Ash.read!()

    Enum.reduce(vovs, %{}, fn vov, acc ->
      ov = vov.option_value
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
end
