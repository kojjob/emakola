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

  require Logger

  require Ash.Query

  import EmakolaWeb.Storefront.Path

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.SEO, as: SEOHelpers

  @impl true
  def mount(%{"product_slug" => product_slug}, session, socket) do
    slug = socket.assigns.store.slug
    store = socket.assigns.store

    case load_product(store.id, product_slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Product not found")
         |> redirect(to: store_path(slug, "/products"))}

      product ->
        if connected?(socket) do
          Emakola.Suppliers.OpportunitySignals.track_product_view(store.id, product.id)
        end

        partner_fulfillment = partner_fulfillment(product.id)
        option_types = load_option_types(product)
        selected_variant = List.first(product.variants)
        vov_map = load_variant_option_values(product.variants)
        related = load_related_products(store, product)
        group_buys = Emakola.Suppliers.GroupBuys.public_campaigns(store.id, product.id)
        categories = load_root_categories(store)
        cart_session_id = session["cart_session_id"]

        cart_count =
          if connected?(socket) && cart_session_id,
            do: CartStore.cart_count(cart_session_id, store.id),
            else: 0

        {:ok,
         socket
         |> assign(:product, product)
         |> assign(:partner_fulfillment, partner_fulfillment)
         |> assign(:option_types, option_types)
         |> assign(:vov_map, vov_map)
         |> assign(:selected_variant, selected_variant)
         |> assign(
           :selected_options,
           build_initial_options(option_types, selected_variant, vov_map)
         )
         |> assign(:quantity, 1)
         |> assign(:current_image_index, 0)
         |> assign(:related_products, related)
         |> assign(:group_buy_forms, group_buy_forms(group_buys))
         |> stream(:group_buys, group_buys)
         |> assign(:categories, categories)
         |> assign(:delivery_zones, load_delivery_zones(store))
         # The merchant's own returns window and warranty. Themes hardcoded
         # these; now a store that has stated no terms states none.
         |> assign(:page_content, EmakolaWeb.Storefront.ContentLoader.load(store.id))
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart_count, cart_count)
         |> assign(:page_title, "#{product.title} - #{store.name}")
         |> assign_seo_metadata(store, product)
         |> assign(:reviews, load_reviews(product.id))
         |> assign(:review_form_rating, 0)
         |> assign(:review_form_title, "")
         |> assign(:review_form_body, "")
         |> assign(:review_submitting, false)
         |> assign_review_eligibility(store, product)
         |> allow_upload(:review_photos,
           accept: ~w(.jpg .jpeg .png .webp),
           max_entries: 4,
           max_file_size: 5_000_000
         )}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Pin the canonical to the apex + /s/:slug subfolder (never the request host)
    # so subdomains/custom domains all canonicalize to one indexed URL.
    canonical =
      EmakolaWeb.SEO.Canonical.product_url(socket.assigns.store, socket.assigns.product)

    {:noreply, assign(socket, :canonical_url, canonical)}
  end

  @impl true
  def handle_event("select_option", %{"option_type_id" => ot_id, "value" => value}, socket) do
    selected_options = Map.put(socket.assigns.selected_options, ot_id, value)

    variant =
      find_matching_variant(
        socket.assigns.product.variants,
        selected_options,
        socket.assigns.vov_map
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
  def handle_event("prev_image", _params, socket) do
    images = socket.assigns.product.images || []
    count = length(images)
    current = socket.assigns.current_image_index
    new_index = if count > 0, do: rem(current - 1 + count, count), else: 0
    {:noreply, assign(socket, :current_image_index, new_index)}
  end

  @impl true
  def handle_event("next_image", _params, socket) do
    images = socket.assigns.product.images || []
    count = length(images)
    current = socket.assigns.current_image_index
    new_index = if count > 0, do: rem(current + 1, count), else: 0
    {:noreply, assign(socket, :current_image_index, new_index)}
  end

  @impl true
  def handle_event("add_to_cart", _params, socket) do
    variant = socket.assigns.selected_variant

    if is_nil(variant) || not Emakola.Catalog.Variant.in_stock?(variant, socket.assigns.quantity) do
      {:noreply, put_flash(socket, :error, "This variant is out of stock")}
    else
      cart_session_id = socket.assigns.cart_session_id
      quantity = socket.assigns.quantity

      image_url =
        case socket.assigns.product.images do
          images when is_list(images) and images != [] ->
            primary = images |> Enum.sort_by(& &1.position) |> List.first()
            primary.thumbnail_url || primary.url

          _ ->
            nil
        end

      CartStore.add_item(cart_session_id, socket.assigns.store.id, %{
        variant_id: variant.id,
        quantity: quantity,
        product_title: socket.assigns.product.title,
        variant_info: variant_label(variant, socket.assigns.option_types, socket.assigns.vov_map),
        unit_price: variant.price,
        sku: variant.sku,
        image_url: image_url
      })

      cart_count = CartStore.cart_count(cart_session_id, socket.assigns.store.id)

      {:noreply,
       socket
       |> assign(:cart_count, cart_count)
       |> put_flash(:info, "Added to cart")}
    end
  end

  def handle_event("join_group_buy", %{"group_buy" => params}, socket) do
    case socket.assigns[:current_customer] do
      nil ->
        {:noreply,
         push_navigate(socket,
           to: store_path(socket.assigns.store.slug, "/login")
         )}

      customer ->
        with {quantity, ""} <- Integer.parse(params["quantity"] || ""),
             true <- quantity > 0,
             callback_url <-
               EmakolaWeb.Endpoint.url() <>
                 store_path(
                   socket.assigns.store.slug,
                   "/products/#{socket.assigns.product.slug}"
                 ),
             {:ok, result} <-
               Emakola.Suppliers.GroupBuys.initiate_customer_payment(
                 params["campaign_id"],
                 customer,
                 quantity,
                 callback_url
               ) do
          {:noreply, redirect(socket, external: result.authorization_url)}
        else
          false -> {:noreply, put_flash(socket, :error, "Choose at least one item.")}
          :error -> {:noreply, put_flash(socket, :error, "Enter a valid quantity.")}
          {:error, reason} -> {:noreply, put_flash(socket, :error, group_buy_error(reason))}
        end
    end
  end

  @impl true
  def handle_event("set_review_rating", %{"rating" => r}, socket) do
    {:noreply, assign(socket, :review_form_rating, String.to_integer(r))}
  end

  @impl true
  def handle_event("submit_review", %{"body" => body} = params, socket) do
    title = Map.get(params, "title", "")
    rating = socket.assigns.review_form_rating
    store = socket.assigns.store
    product = socket.assigns.product

    case socket.assigns[:review_order_id] do
      nil ->
        {:noreply, put_flash(socket, :error, "Not eligible to review")}

      order_id ->
        images = consume_review_photo_uploads(socket)

        case Emakola.Catalog.create_review(
               %{
                 store_id: store.id,
                 product_id: product.id,
                 customer_id: socket.assigns.review_customer_id,
                 order_id: order_id,
                 rating: rating,
                 title: if(title == "", do: nil, else: title),
                 body: body,
                 images: images
               },
               authorize?: false
             ) do
          {:ok, _} ->
            updated_product =
              product |> Ash.load!([:avg_rating, :review_count], authorize?: false)

            {:noreply,
             socket
             |> assign(:product, updated_product)
             |> assign(:reviews, load_reviews(product.id))
             |> assign(:can_review, false)
             |> assign(:already_reviewed, true)
             |> assign(:review_form_rating, 0)
             |> assign(:review_form_title, "")
             |> assign(:review_form_body, "")
             |> put_flash(:info, "Review submitted!")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not submit review")}
        end
    end
  end

  @impl true
  def handle_event("share-product", %{"platform" => platform} = _params, socket) do
    # Public/anonymous storefront tracking — no actor required.
    # Atomic SQL UPDATE means concurrent shares can't collide.
    case Emakola.Catalog.increment_product_share_count(socket.assigns.product,
           authorize?: false
         ) do
      {:ok, updated} ->
        require Logger
        Logger.debug("[share] platform=#{platform} product=#{updated.id}")
        {:noreply, assign(socket, :product, updated)}

      {:error, _} ->
        # Don't fail the share — the link still opens client-side via the <a> tag.
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate_review", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("cancel_review_photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :review_photos, ref)}
  end

  @impl true
  def render(assigns) do
    theme_content = assigns.theme_module.render_product_detail(assigns)
    assigns = assign(assigns, :theme_content, theme_content)

    ~H"""
    <div
      :if={@partner_fulfillment}
      id="partner-fulfillment-disclosure"
      class="relative z-50 flex items-center justify-center gap-2 bg-emerald-950 px-4 py-2.5 text-center text-xs font-semibold text-emerald-50 shadow-sm"
    >
      <.icon name="hero-shield-check" class="size-4 text-emerald-300" />
      Fulfilled by verified partner {@partner_fulfillment.name}
    </div>
    <section
      id="group-buy-offers"
      phx-update="stream"
      class="mx-auto w-full max-w-7xl space-y-3 px-4 py-5 sm:px-6 lg:px-8"
    >
      <article
        :for={{dom_id, campaign} <- @streams.group_buys}
        id={dom_id}
        class="overflow-hidden rounded-3xl border border-emerald-200 bg-gradient-to-br from-emerald-950 to-teal-900 p-5 text-white shadow-lg shadow-emerald-950/10"
      >
        <div class="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p class="text-xs font-bold uppercase tracking-[0.2em] text-emerald-300">
              Buy together, pay less
            </p>
            <h2 class="mt-1 text-xl font-black">{campaign.title}</h2>
            <p class="mt-2 text-sm text-emerald-100">
              {campaign.committed_quantity}/{campaign.threshold_quantity} paid · {format_group_buy_money(
                campaign.unit_price
              )} each
            </p>
            <p class="mt-1 text-xs text-emerald-200">
              If the target is missed, payment is automatically refunded by {Calendar.strftime(
                campaign.refund_deadline,
                "%d %b %Y"
              )}.
            </p>
          </div>
          <.form
            for={Map.fetch!(@group_buy_forms, campaign.id)}
            id={"group-buy-form-#{campaign.id}"}
            phx-submit="join_group_buy"
            class="flex items-end gap-2"
          >
            <.input
              field={Map.fetch!(@group_buy_forms, campaign.id)[:campaign_id]}
              type="hidden"
            />
            <.input
              field={Map.fetch!(@group_buy_forms, campaign.id)[:quantity]}
              type="number"
              min="1"
              max={campaign.threshold_quantity - campaign.committed_quantity}
              label="Quantity"
              class="w-24 rounded-xl border border-white/20 bg-white px-3 py-2 text-slate-950"
            />
            <button
              id={"join-group-buy-#{campaign.id}"}
              type="submit"
              class="rounded-xl bg-amber-300 px-4 py-2.5 text-sm font-black text-emerald-950 transition hover:-translate-y-0.5 hover:bg-amber-200"
            >
              Join securely
            </button>
          </.form>
        </div>
      </article>
    </section>
    {@theme_content}
    """
  end

  # -- Helpers --

  defp load_product(store_id, product_slug) do
    case Emakola.Catalog.get_product_by_slug(store_id, product_slug, authorize?: false) do
      {:ok, product} -> product
      _ -> nil
    end
  end

  defp group_buy_forms(campaigns) do
    Map.new(campaigns, fn campaign ->
      {campaign.id, to_form(%{"campaign_id" => campaign.id, "quantity" => "1"}, as: :group_buy)}
    end)
  end

  defp group_buy_error(:quantity_exceeds_remaining), do: "That quantity is no longer available."
  defp group_buy_error(:campaign_closed), do: "This group buy has closed."

  defp group_buy_error(_reason),
    do: "We could not start this group-buy payment. Please try again."

  defp format_group_buy_money(amount) do
    formatted = :erlang.float_to_binary(amount / 100, decimals: 2)
    "GH₵ " <> (formatted |> String.trim_trailing("0") |> String.trim_trailing("."))
  end

  defp partner_fulfillment(product_id) do
    Emakola.Suppliers.ResellerListing
    |> Ash.Query.filter(reseller_product_id == ^product_id and status == :active)
    |> Ash.Query.load(offer: :wholesaler_store)
    |> Ash.Query.limit(1)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %{offer: %{wholesaler_store: partner}}} -> %{name: partner.name}
      _ -> nil
    end
  end

  defp load_option_types(product) do
    case Emakola.Catalog.list_option_types_by_product(product.id, authorize?: false) do
      {:ok, option_types} -> option_types
      _ -> []
    end
  end

  defp load_related_products(store, product) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_related, %{store_id: store.id, product_id: product.id})
    |> Ash.Query.limit(6)
    |> Ash.read!(authorize?: false)
  end

  # Load all VariantOptionValues for a product's variants in one query,
  # grouped by variant_id. Eliminates N+1 on every option selection click.
  defp load_variant_option_values(variants) do
    variant_ids = Enum.map(variants, & &1.id)

    case Emakola.Catalog.list_variant_option_values_by_variants(variant_ids,
           authorize?: false
         ) do
      {:ok, vovs} -> Enum.group_by(vovs, & &1.variant_id)
      _ -> %{}
    end
  end

  defp build_initial_options([], _variant, _vov_map), do: %{}
  defp build_initial_options(_option_types, nil, _vov_map), do: %{}

  defp build_initial_options(option_types, variant, vov_map) do
    vovs = Map.get(vov_map, variant.id, [])

    Enum.reduce(vovs, %{}, fn vov, acc ->
      ov = vov.option_value
      ot = Enum.find(option_types, fn ot -> ot.id == ov.option_type_id end)
      if ot, do: Map.put(acc, ot.id, ov.id), else: acc
    end)
  end

  defp find_matching_variant(variants, selected_options, _vov_map)
       when map_size(selected_options) == 0 do
    List.first(variants)
  end

  defp find_matching_variant(variants, selected_options, vov_map) do
    selected_value_ids = Map.values(selected_options) |> MapSet.new()

    Enum.find(variants, fn variant ->
      vovs = Map.get(vov_map, variant.id, [])
      variant_value_ids = MapSet.new(Enum.map(vovs, & &1.option_value_id))
      MapSet.subset?(selected_value_ids, variant_value_ids)
    end) || List.first(variants)
  end

  defp variant_label(variant, option_types, vov_map) do
    if option_types == [] do
      variant.sku || "Default"
    else
      vovs = Map.get(vov_map, variant.id, [])

      Enum.map(vovs, fn vov -> vov.option_value.value end)
      |> Enum.join(" / ")
    end
  end

  defp load_root_categories(store) do
    Emakola.Catalog.list_root_categories!(store.id)
  end

  defp load_reviews(product_id) do
    Emakola.Catalog.Review
    |> Ash.Query.for_read(:list_published_by_product, %{product_id: product_id})
    |> Ash.Query.limit(20)
    |> Ash.read!(authorize?: false)
  end

  defp assign_review_eligibility(socket, store, product) do
    customer = socket.assigns[:current_customer]

    if customer do
      case Emakola.Catalog.Review.eligible?(store.id, product.id, customer.id) do
        {:ok, order_id} ->
          socket
          |> assign(:can_review, true)
          |> assign(:already_reviewed, false)
          |> assign(:review_customer_id, customer.id)
          |> assign(:review_order_id, order_id)

        {:error, :already_reviewed} ->
          socket
          |> assign(:can_review, false)
          |> assign(:already_reviewed, true)
          |> assign(:review_customer_id, customer.id)
          |> assign(:review_order_id, nil)

        _ ->
          assign_no_review(socket)
      end
    else
      assign_no_review(socket)
    end
  end

  defp assign_no_review(socket) do
    socket
    |> assign(:can_review, false)
    |> assign(:already_reviewed, false)
    |> assign(:review_customer_id, nil)
    |> assign(:review_order_id, nil)
  end

  # The PDP's delivery callouts state the store's own terms rather than a
  # hardcoded promise, so it needs the same zones the home page loads. A
  # failure here must not take the product page down — the callouts simply
  # fall back to linking the store's policies page.
  defp load_delivery_zones(store) do
    Emakola.Shipping.list_delivery_zones!(store.id)
    |> Enum.filter(& &1.active)
  rescue
    exception ->
      Logger.error(
        "[product_detail_live] loading delivery zones raised: #{Exception.message(exception)}"
      )

      []
  end

  # -- SEO --

  # Assigns meta_description, og_image, og_type, and json_ld for the PDP.
  # These flow to the root layout and get rendered as OG/Twitter/JSON-LD
  # tags. Without these, WhatsApp link unfurling shows plain URLs instead
  # of a product preview card — a significant conversion loss for West
  # African merchants who rely on WhatsApp for sharing.
  defp assign_seo_metadata(socket, store, product) do
    description = product_description_for_seo(product, store)
    og_image = first_product_image_url(product)
    product_json_ld = SEOHelpers.json_ld_product(product, product.variants || [], store)

    breadcrumb_json_ld =
      SEOHelpers.json_ld_breadcrumb([
        %{name: store.name, url: "/s/#{store.slug}"},
        %{name: "Products", url: "/s/#{store.slug}/products"},
        %{name: product.title, url: "/s/#{store.slug}/products/#{product.slug}"}
      ])

    combined_json_ld = [product_json_ld, breadcrumb_json_ld]

    socket
    |> assign(:meta_description, description)
    |> assign(:og_image, og_image)
    |> assign(:og_type, "product")
    |> assign(:og_site_name, store.name)
    |> assign(:json_ld, combined_json_ld)
  end

  # Prefer the SEO-specific description, fall back to the main description,
  # then to a generic store-anchored fallback. Truncated to keep under
  # ~155 chars so social platforms don't cut mid-sentence.
  defp product_description_for_seo(product, store) do
    raw =
      Map.get(product, :seo_description) ||
        Map.get(product, :description) ||
        "Shop #{product.title} at #{store.name} — authentic products, delivered across Ghana."

    raw
    |> to_string()
    |> String.trim()
    |> truncate_at_word(155)
  end

  defp truncate_at_word(str, max) when byte_size(str) <= max, do: str

  defp truncate_at_word(str, max) do
    str
    |> binary_part(0, max)
    |> String.trim_trailing()
    |> String.replace(~r/\s+\S*$/, "")
    |> Kernel.<>("…")
  end

  # Returns the URL of the product's first image (sorted by position),
  # preferring medium_url over url for social-preview-appropriate sizing.
  # Returns nil when the product has no images — the SEO component
  # gracefully omits og:image in that case.
  defp first_product_image_url(%{images: images}) when is_list(images) and images != [] do
    images
    |> Enum.sort_by(&Map.get(&1, :position, 0))
    |> List.first()
    |> then(fn img -> Map.get(img, :medium_url) || Map.get(img, :url) end)
  end

  defp first_product_image_url(_), do: nil

  # Consumes the LiveView upload entries for :review_photos, copies each
  # file to priv/static/uploads/reviews, and returns the list of image
  # maps in the shape Review.images expects.
  #
  # Returns [] when no entries — safe to call unconditionally.
  defp consume_review_photo_uploads(socket) do
    consume_uploaded_entries(socket, :review_photos, fn %{path: path}, entry ->
      filename =
        "#{System.os_time(:millisecond)}_#{entry.client_name}"
        |> String.replace(~r/[^a-zA-Z0-9._-]/, "_")

      dest = Path.join(reviews_upload_dir(), filename)
      File.cp!(path, dest)

      url = "/uploads/reviews/#{filename}"
      {:ok, %{"url" => url, "thumbnail_url" => url, "alt" => ""}}
    end)
  end

  defp reviews_upload_dir do
    dir = Path.join([:code.priv_dir(:emakola), "static", "uploads", "reviews"])
    File.mkdir_p!(dir)
    dir
  end
end
