defmodule EmakolaWeb.Storefront.CategoryLive do
  @moduledoc """
  Category page — premium product browsing experience inspired by Stitch design.
  Features hero title, breadcrumbs, filters, sort, and a rich product grid with badges.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.SEO
  alias EmakolaWeb.Helpers.StoreResolver
  alias EmakolaWeb.SEO.Canonical

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
             |> redirect(to: "/@#{slug}/products")}

          category ->
            products = load_category_products(store.id, category.id)
            product_count = count_category_products(store.id, category.id)
            parent = if category.parent_id, do: load_category_by_id(category.parent_id), else: nil
            categories = Emakola.Catalog.list_root_categories!(store.id)
            cart_session_id = session["cart_session_id"]

            cart_count =
              if connected?(socket) && cart_session_id,
                do: CartStore.cart_count(cart_session_id, store.id),
                else: 0

            {:ok,
             socket
             |> assign(
               store: store,
               category: category,
               parent_category: parent,
               categories: categories,
               products: products,
               filtered_products: products,
               sort_by: :newest,
               cart_session_id: cart_session_id,
               cart_count: cart_count,
               page_title: "#{category.name} - #{store.name}",
               meta_description: category_meta_description(category, store, product_count),
               og_image: first_product_image(products),
               og_type: "website",
               og_site_name: store.name,
               canonical_url: Canonical.category_url(store, category),
               json_ld:
                 SEO.json_ld_breadcrumb([
                   %{name: store.name, url: Canonical.store_url(store)},
                   %{name: category.name, url: Canonical.category_url(store, category)}
                 ])
             )}
        end

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  # ── Events ──

  @impl true
  def handle_event("sort_products", %{"sort" => sort_key}, socket) do
    sort =
      Emakola.SafeAtom.to_atom_in(
        sort_key,
        [:newest, :price_asc, :price_desc, :name_asc],
        :newest
      )

    sorted = sort_products(socket.assigns.products, sort)
    {:noreply, assign(socket, filtered_products: sorted, sort_by: sort)}
  end

  @impl true
  def handle_event("add_to_cart", %{"product-id" => product_id}, socket) do
    case Emakola.Catalog.get_product(product_id, authorize?: false) do
      {:ok, product} when not is_nil(product) ->
        product = Ash.load!(product, [:variants, :images], authorize?: false)
        variant = product.variants |> Enum.sort_by(& &1.position) |> List.first()

        if variant && Emakola.Catalog.Variant.in_stock?(variant) do
          image_url =
            case product.images do
              [img | _] -> img.thumbnail_url || img.url
              _ -> nil
            end

          Emakola.Cart.CartStore.add_item(
            socket.assigns.cart_session_id,
            socket.assigns.store.id,
            %{
              variant_id: variant.id,
              quantity: 1,
              product_title: product.title,
              variant_info: variant.sku || "",
              unit_price: variant.price,
              sku: variant.sku,
              image_url: image_url
            }
          )

          cart_count =
            Emakola.Cart.CartStore.cart_count(
              socket.assigns.cart_session_id,
              socket.assigns.store.id
            )

          {:noreply,
           socket
           |> assign(:cart_count, cart_count)
           |> put_flash(:info, "#{product.title} added to cart")}
        else
          {:noreply, put_flash(socket, :error, "Out of stock")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Product not found")}
    end
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :category) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.Category.render(assigns)
    end
  end

  # ── Data Loading ──

  defp load_category(store_id, category_slug) do
    case Emakola.Catalog.get_category_by_slug(store_id, category_slug) do
      {:ok, category} -> category
      _ -> nil
    end
  end

  defp load_category_by_id(category_id) do
    case Emakola.Catalog.get_category(category_id) do
      {:ok, cat} -> cat
      _ -> nil
    end
  end

  defp load_category_products(store_id, category_id) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_category, %{
      category_id: category_id,
      store_id: store_id,
      status: :active
    })
    |> Ash.Query.limit(60)
    |> Ash.read!(authorize?: false)
  end

  defp sort_products(products, :newest) do
    Enum.sort_by(products, & &1.inserted_at, {:desc, DateTime})
  end

  defp sort_products(products, :price_asc) do
    Enum.sort_by(products, fn p -> p.min_price || 0 end, :asc)
  end

  defp sort_products(products, :price_desc) do
    Enum.sort_by(products, fn p -> p.max_price || 0 end, :desc)
  end

  defp sort_products(products, :name_asc) do
    Enum.sort_by(products, & &1.title)
  end

  defp sort_products(products, _), do: products

  # -- SEO --

  defp category_meta_description(category, store, count) do
    raw =
      Map.get(category, :description) ||
        "Shop #{category.name} at #{store.name}. #{count} products available. Fast delivery, mobile money accepted."

    raw
    |> to_string()
    |> String.trim()
    |> truncate_at_word(155)
  end

  defp count_category_products(store_id, category_id) do
    result =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:list_by_category, %{
        category_id: category_id,
        store_id: store_id,
        status: :active
      })
      |> Ash.count(authorize?: false)

    case result do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp first_product_image([first | _]) when is_map(first) do
    case Map.get(first, :images) do
      [img | _] when is_map(img) ->
        Map.get(img, :medium_url) || Map.get(img, :url)

      _ ->
        nil
    end
  end

  defp first_product_image(_), do: nil

  defp truncate_at_word(str, max) when byte_size(str) <= max, do: str

  defp truncate_at_word(str, max) do
    str
    |> binary_part(0, max)
    |> String.trim_trailing()
    |> String.replace(~r/\s+\S*$/, "")
    |> Kernel.<>("…")
  end
end
