defmodule EmakolaWeb.Admin.ProductLive.Index do
  @moduledoc """
  Lists all products for the current store with search, status filtering,
  quick view modal, archive/activate confirmation modals, and slide-over
  panels for adding/editing products and bulk CSV upload.
  Mobile-responsive layout optimized for West African merchants.
  """
  use EmakolaWeb, :live_view

  # Page window for the product list; "Load more" grows it by this much.
  @admin_products_limit 100

  require Logger

  import EmakolaWeb.Admin.ProductLive.IndexComponents

  alias EmakolaWeb.Admin.ProductLive.Shared

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Products",
        active_nav: :products,
        store_id: store_id,
        search_query: "",
        status_filter: :all,
        products: [],
        products_limit: @admin_products_limit,
        more_products?: false,
        categories: %{},
        categories_list: [],
        quick_view_product: nil,
        action_product: nil,
        action_type: nil,
        # Product form slide-over
        show_product_form: false,
        form_data: empty_form_data(),
        form_errors: %{},
        editing_product: nil,
        # Bulk upload slide-over
        show_bulk_upload: false,
        csv_preview: [],
        csv_errors: [],
        bulk_importing: false
      )
      |> allow_upload(:csv_file,
        accept: ~w(.csv),
        max_entries: 1,
        max_file_size: 2_000_000
      )
      |> allow_upload(:product_images,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 5,
        max_file_size: 10_000_000
      )
      |> allow_upload(:bulk_images,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 50,
        max_file_size: 10_000_000
      )
      |> load_products()
      |> load_categories()

    {:ok, socket}
  end

  # ── Search & Filter Events ──

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    socket =
      socket
      |> assign(search_query: query, products_limit: @admin_products_limit)
      |> load_products()

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more_products", _params, socket) do
    {:noreply,
     socket
     |> assign(products_limit: socket.assigns.products_limit + @admin_products_limit)
     |> load_products()}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "draft" -> :draft
        "active" -> :active
        "archived" -> :archived
        _ -> :all
      end

    socket =
      socket
      |> assign(status_filter: status_atom, products_limit: @admin_products_limit)
      |> load_products()

    {:noreply, socket}
  end

  # ── Quick View Events ──

  @impl true
  def handle_event("quick_view", %{"id" => id}, socket) do
    product = Enum.find(socket.assigns.products, &(&1.id == id))
    {:noreply, assign(socket, quick_view_product: product)}
  end

  # ── Archive/Activate Events ──

  @impl true
  def handle_event("open_archive", %{"id" => id}, socket) do
    product = Enum.find(socket.assigns.products, &(&1.id == id))
    {:noreply, assign(socket, action_product: product, action_type: :archive)}
  end

  @impl true
  def handle_event("open_activate", %{"id" => id}, socket) do
    product = Enum.find(socket.assigns.products, &(&1.id == id))
    {:noreply, assign(socket, action_product: product, action_type: :activate)}
  end

  @impl true
  def handle_event("archive_product", _params, socket) do
    product = socket.assigns.action_product

    if product do
      case Emakola.Catalog.archive_product(product, authorize?: false) do
        {:ok, _} ->
          Emakola.Catalog.CachedCatalog.invalidate_store(socket.assigns.store_id)

          {:noreply,
           socket
           |> assign(action_product: nil, action_type: nil)
           |> load_products()
           |> put_flash(:info, "Product archived")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to archive product")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("activate_product", _params, socket) do
    product = socket.assigns.action_product

    if product do
      case Emakola.Catalog.activate_product(product, authorize?: false) do
        {:ok, _} ->
          Emakola.Catalog.CachedCatalog.invalidate_store(socket.assigns.store_id)

          {:noreply,
           socket
           |> assign(action_product: nil, action_type: nil)
           |> load_products()
           |> put_flash(:info, "Product activated")}

        {:error, _} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Failed to activate product. Ensure it has at least one variant."
           )}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Product Form Slide-Over Events ──

  @impl true
  def handle_event("open_new_product", _params, socket) do
    {:noreply,
     assign(socket,
       show_product_form: true,
       editing_product: nil,
       form_data: empty_form_data(),
       form_errors: %{}
     )}
  end

  @impl true
  def handle_event("open_edit_product", %{"id" => id}, socket) do
    product = load_product(id)

    if product do
      {:noreply,
       assign(socket,
         show_product_form: true,
         editing_product: product,
         form_data: product_to_form_data(product),
         form_errors: %{}
       )}
    else
      {:noreply, put_flash(socket, :error, "Product not found")}
    end
  end

  @impl true
  def handle_event("validate_product", %{"product" => params}, socket) do
    errors = validate_form(params)
    {:noreply, assign(socket, form_data: params, form_errors: errors)}
  end

  @impl true
  def handle_event("save_product", %{"product" => params}, socket) do
    action = if params["_action"] == "activate", do: :active, else: :draft
    editing = socket.assigns.editing_product

    # Pop price on the create path; edit path uses variant_prices instead
    {price_result, product_params} =
      if is_nil(editing) do
        {price_str, rest} = Map.pop(params, "price")
        {Shared.parse_price_input(price_str), rest}
      else
        {:skip, params}
      end

    errors =
      validate_form(Map.delete(product_params, "_action"))
      |> apply_price_error(price_result)

    if map_size(errors) > 0 do
      {:noreply, assign(socket, form_data: params, form_errors: errors)}
    else
      attrs = build_product_attrs(Map.delete(product_params, "_action"), socket.assigns.store_id)
      pesewas = pesewas_from_price_result(price_result)

      result =
        if editing do
          # The :update action does not accept :store_id (tenancy is fixed
          # at creation) — passing it fails the whole save with NoSuchInput.
          update_product_with_result(editing, Map.delete(attrs, :store_id), action)
        else
          Shared.create_product_with_price(attrs, pesewas, action)
        end

      case result do
        {:ok, product, result_atom} ->
          {:noreply,
           socket
           |> finalize_product_save(product, editing, params)
           |> put_flash(:info, save_success_msg(result_atom))}

        {:error, error} ->
          {:noreply,
           socket
           |> assign(form_data: params)
           |> put_flash(:error, format_error(error))}
      end
    end
  end

  @impl true
  def handle_event("cancel_product_form", _params, socket) do
    {:noreply,
     assign(socket,
       show_product_form: false,
       editing_product: nil,
       form_data: empty_form_data(),
       form_errors: %{}
     )}
  end

  @impl true
  def handle_event("cancel_image_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :product_images, ref)}
  end

  @impl true
  def handle_event("delete_image", %{"id" => image_id}, socket) do
    store_id = socket.assigns.store_id

    case Emakola.Catalog.get_image(image_id) do
      {:ok, image} when image.store_id == store_id ->
        Emakola.Catalog.destroy_image!(image, authorize?: false)

        # Reload the editing product with fresh images
        updated =
          if socket.assigns.editing_product do
            Ash.load!(socket.assigns.editing_product, [:images], lazy?: false)
          end

        {:noreply,
         socket
         |> assign(editing_product: updated)
         |> load_products()}

      _ ->
        {:noreply, socket}
    end
  end

  # ── Bulk Upload Slide-Over Events ──

  @impl true
  def handle_event("open_bulk_upload", _params, socket) do
    {:noreply,
     assign(socket,
       show_bulk_upload: true,
       csv_preview: [],
       csv_errors: [],
       bulk_importing: false
     )}
  end

  @impl true
  def handle_event("cancel_bulk_upload", _params, socket) do
    {:noreply,
     socket
     |> assign(
       show_bulk_upload: false,
       csv_preview: [],
       csv_errors: [],
       bulk_importing: false
     )
     |> cancel_uploads(:csv_file)
     |> cancel_uploads(:bulk_images)}
  end

  @impl true
  def handle_event("cancel_bulk_image", %{"ref" => ref}, socket) do
    {:noreply, Phoenix.LiveView.cancel_upload(socket, :bulk_images, ref)}
  end

  @impl true
  def handle_event("validate_csv", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, Phoenix.LiveView.cancel_upload(socket, :csv_file, ref)}
  end

  @impl true
  def handle_event("parse_csv", _params, socket) do
    {csv_content, socket} = read_uploaded_csv(socket)

    case csv_content do
      nil ->
        {:noreply, assign(socket, csv_errors: ["No file uploaded"])}

      content ->
        {rows, errors} = Emakola.Catalog.CsvImporter.parse(content, socket.assigns.categories)
        {:noreply, assign(socket, csv_preview: rows, csv_errors: errors)}
    end
  end

  @impl true
  def handle_event("import_products", _params, socket) do
    rows = socket.assigns.csv_preview

    if rows == [] do
      {:noreply, assign(socket, csv_errors: ["No rows to import. Upload and parse a CSV first."])}
    else
      socket = assign(socket, bulk_importing: true)
      store_id = socket.assigns.store_id

      referenced =
        rows
        |> Enum.flat_map(&(&1["images"] || []))
        |> Enum.map(&String.downcase/1)
        |> MapSet.new()

      {image_urls, socket} = upload_referenced_images(socket, referenced, store_id)

      {imported, skipped, warnings} =
        Emakola.Catalog.CsvImporter.import_rows(rows, store_id, image_urls)

      if imported > 0, do: Emakola.Catalog.CachedCatalog.invalidate_store(store_id)

      socket =
        socket
        |> assign(bulk_importing: false, csv_errors: warnings, csv_preview: [])
        |> load_products()
        |> put_flash(:info, bulk_summary(imported, skipped))

      {:noreply, socket}
    end
  end

  # ── Render ──

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <%!-- Header --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold font-headline tracking-tight">Products</h1>
          <p class="text-sm text-slate-500 mt-1">
            Manage your store catalog
          </p>
        </div>
        <div class="flex items-center gap-2">
          <.link
            navigate={~p"/admin/products/bulk"}
            class="inline-flex items-center justify-center gap-2 font-semibold transition-colors rounded-control cursor-pointer px-3 py-1.5 text-xs bg-primary hover:bg-primary-hover text-white"
          >
            <.icon name="hero-photo" class="size-3.5" /> Add many products
          </.link>
          <.admin_button
            variant={:secondary}
            size={:sm}
            phx-click={
              JS.push("open_bulk_upload")
              |> show_modal("bulk-upload-modal")
            }
          >
            <.icon name="hero-arrow-up-tray" class="size-3.5" /> Bulk
          </.admin_button>
          <.admin_button
            size={:sm}
            phx-click={
              JS.push("open_new_product")
              |> show_modal("product-form-modal")
            }
          >
            <.icon name="hero-plus" class="size-3.5" /> New Product
          </.admin_button>
        </div>
      </div>

      <%!-- Search & Filters --%>
      <.table_toolbar search_query={@search_query} placeholder="Search products...">
        <:filters>
          <div class="flex gap-1 bg-slate-100 rounded-lg p-1 overflow-x-auto">
            <.status_tab status={:all} current={@status_filter} label="All" />
            <.status_tab status={:draft} current={@status_filter} label="Draft" />
            <.status_tab status={:active} current={@status_filter} label="Active" />
            <.status_tab status={:archived} current={@status_filter} label="Archived" />
          </div>
        </:filters>
      </.table_toolbar>

      <%!-- Product List --%>
      <.product_list
        products={@products}
        categories={@categories}
        search_query={@search_query}
        status_filter={@status_filter}
      />

      <%!-- The list is a window, not the whole catalogue. Without this the page
      stopped at the limit with no hint that more products existed. --%>
      <div :if={@more_products?} class="mt-4 flex flex-col items-center gap-2">
        <p class="text-xs text-slate-500">Showing {length(@products)} products.</p>
        <.admin_button
          id="load-more-products"
          variant={:secondary}
          phx-click="load_more_products"
          phx-disable-with="Loading..."
        >
          Load more products
        </.admin_button>
      </div>

      <%!-- Quick View Modal --%>
      <.quick_view_modal quick_view_product={@quick_view_product} categories={@categories} />

      <%!-- Archive/Activate Confirmation Modal --%>
      <.confirm_action_modal action_product={@action_product} action_type={@action_type} />

      <%!-- Product Form Slide-Over (+ bulk CSV upload modal) --%>
      <.product_form_slideover
        editing_product={@editing_product}
        form_data={@form_data}
        form_errors={@form_errors}
        categories_list={@categories_list}
        uploads={@uploads}
        csv_preview={@csv_preview}
        csv_errors={@csv_errors}
        bulk_importing={@bulk_importing}
      />
    </div>
    """
  end

  defp load_products(%{assigns: %{store_id: nil}} = socket) do
    assign(socket, products: [], more_products?: false)
  end

  defp load_products(socket) do
    %{store_id: store_id, search_query: query, status_filter: status} = socket.assigns
    limit = socket.assigns[:products_limit] || @admin_products_limit

    products =
      try do
        search = if query != "", do: query, else: nil
        status_arg = if status != :all, do: status, else: nil

        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_admin, %{
          store_id: store_id,
          search: search,
          status: status_arg
        })
        |> Ash.Query.limit(limit + 1)
        |> Ash.read!(authorize?: false)
      rescue
        exception ->
          Logger.error(
            "[product_live.index] load_products loading products raised: #{Exception.message(exception)}"
          )

          []
      end

    # One row past the window answers "is there more?" without a second COUNT.
    {products, more?} =
      if length(products) > limit,
        do: {Enum.take(products, limit), true},
        else: {products, false}

    assign(socket, products: products, products_limit: limit, more_products?: more?)
  end

  defp load_categories(%{assigns: %{store_id: nil}} = socket) do
    assign(socket, categories: %{}, categories_list: [])
  end

  defp load_categories(socket) do
    categories_list =
      try do
        Emakola.Catalog.list_categories_by_store!(socket.assigns.store_id)
      rescue
        exception ->
          Logger.error(
            "[product_live.index] load_categories loading categories raised: #{Exception.message(exception)}"
          )

          []
      end

    categories_map = Map.new(categories_list, fn cat -> {cat.id, cat.name} end)

    assign(socket, categories: categories_map, categories_list: categories_list)
  end

  # ── Product CRUD ──

  defp update_product_with_result(product, attrs, :draft) do
    case Emakola.Catalog.update_product(product, attrs, authorize?: false) do
      {:ok, updated} -> {:ok, updated, :draft_requested}
      error -> error
    end
  end

  defp update_product_with_result(product, attrs, :active) do
    case Emakola.Catalog.update_product(product, attrs, authorize?: false) do
      {:ok, updated} ->
        case Emakola.Catalog.activate_product(updated, authorize?: false) do
          {:ok, activated} -> {:ok, activated, :activated}
          {:error, _} -> {:ok, updated, :activation_failed}
        end

      error ->
        error
    end
  end

  defp finalize_product_save(socket, product, editing, params) do
    {_ok, upload_failed} = Shared.save_uploaded_images(socket, product)
    if editing, do: save_variant_prices(editing, params["variant_prices"] || %{})
    Emakola.Catalog.CachedCatalog.invalidate_store(socket.assigns.store_id)

    socket =
      socket
      |> assign(
        show_product_form: false,
        editing_product: nil,
        form_data: empty_form_data(),
        form_errors: %{}
      )
      |> load_products()

    if upload_failed > 0 do
      put_flash(
        socket,
        :error,
        "Some images failed to upload — you can add them by editing the product."
      )
    else
      socket
    end
  end

  defp load_product(id) do
    # The edit slide-over renders @editing_product.images and .variants —
    # load them here or the render crashes with Enumerable not implemented
    # for Ash.NotLoaded.
    case Emakola.Catalog.get_product(id, load: [:images, :variants]) do
      {:ok, product} -> product
      _ -> nil
    end
  end

  # ── CSV Parsing & Import ──

  defp read_uploaded_csv(socket) do
    case consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
           {:ok, File.read!(path)}
         end) do
      [content | _] -> {content, socket}
      [] -> {nil, socket}
    end
  end

  defp upload_referenced_images(socket, referenced, store_id) do
    urls =
      Phoenix.LiveView.consume_uploaded_entries(socket, :bulk_images, fn %{path: tmp}, entry ->
        name = String.downcase(entry.client_name)

        if MapSet.member?(referenced, name) do
          s3_path =
            "stores/#{store_id}/products/#{Ecto.UUID.generate()}#{Path.extname(entry.client_name)}"

          case Emakola.Storage.upload(File.read!(tmp), s3_path, content_type: entry.client_type) do
            {:ok, url} -> {:ok, {name, %{url: url, content_type: entry.client_type}}}
            {:error, _} -> {:ok, nil}
          end
        else
          {:postpone, nil}
        end
      end)

    map = urls |> Enum.reject(&is_nil/1) |> Map.new()
    {map, socket}
  end

  defp bulk_summary(imported, 0), do: "Imported #{imported} product(s)."
  defp bulk_summary(imported, skipped), do: "Imported #{imported} product(s). #{skipped} skipped."

  # ── Form Helpers ──

  defp empty_form_data do
    %{
      "title" => "",
      "description" => "",
      "category_id" => "",
      "tags" => "",
      "price" => "",
      "seo_title" => "",
      "seo_description" => "",
      "variant_prices" => %{}
    }
  end

  defp product_to_form_data(product) do
    %{
      "title" => product.title || "",
      "description" => product.description || "",
      "category_id" => if(product.category_id, do: to_string(product.category_id), else: ""),
      "tags" => Enum.join(product.tags || [], ", "),
      "seo_title" => product.seo_title || "",
      "seo_description" => product.seo_description || "",
      "variant_prices" =>
        Map.new(sorted_variants(product), &{&1.id, Shared.format_pesewas(&1.price)})
    }
  end

  defp validate_form(params) do
    errors = %{}

    errors =
      if String.trim(params["title"] || "") == "" do
        Map.put(errors, :title, "Title is required")
      else
        errors
      end

    Enum.reduce(params["variant_prices"] || %{}, errors, fn {variant_id, value}, acc ->
      case Shared.parse_price_input(value) do
        :error -> Map.put(acc, {:variant_price, variant_id}, "must be a valid amount")
        :zero -> Map.put(acc, {:variant_price, variant_id}, "must be greater than 0.00")
        _ -> acc
      end
    end)
  end

  defp sorted_variants(product), do: Shared.sorted_variants(product)

  # Only the editing product's own variants are updated — submitted ids
  # that don't belong to it are ignored (no cross-product/tenant writes).
  defp save_variant_prices(product, submitted) do
    product
    |> sorted_variants()
    |> Enum.each(fn variant ->
      with {:ok, pesewas} <- Shared.parse_price_input(submitted[variant.id]),
           true <- pesewas != variant.price do
        Emakola.Catalog.update_variant(variant, %{price: pesewas}, authorize?: false)
      else
        _ -> :ok
      end
    end)
  end

  defp apply_price_error(errors, :error),
    do: Map.put(errors, :price, "must be a valid amount, e.g. 25.00")

  defp apply_price_error(errors, :zero),
    do: Map.put(errors, :price, "must be greater than 0.00")

  defp apply_price_error(errors, _), do: errors

  defp pesewas_from_price_result({:ok, p}), do: p
  defp pesewas_from_price_result(_), do: nil

  defp save_success_msg(:activated), do: "Product published — it's live on your store."
  defp save_success_msg(:activation_failed), do: "Saved as draft — add a price to publish it."
  defp save_success_msg(:draft_requested), do: "Product saved successfully"

  defp build_product_attrs(params, store_id) do
    tags =
      (params["tags"] || "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    category_id =
      case params["category_id"] do
        "" -> nil
        nil -> nil
        id -> id
      end

    %{
      title: params["title"] || "",
      description: params["description"],
      category_id: category_id,
      tags: tags,
      seo_title: params["seo_title"],
      seo_description: params["seo_description"],
      store_id: store_id
    }
  end

  # ── General Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(fn
      %{message: msg} -> msg
      _other -> "Something went wrong. Please try again."
    end)
    |> Enum.join(", ")
  end

  defp format_error(_error), do: "Something went wrong. Please try again."

  defp cancel_uploads(socket, upload_name) do
    Enum.reduce(socket.assigns.uploads[upload_name].entries, socket, fn entry, sock ->
      Phoenix.LiveView.cancel_upload(sock, upload_name, entry.ref)
    end)
  end
end
