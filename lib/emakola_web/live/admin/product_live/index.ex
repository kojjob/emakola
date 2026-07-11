defmodule EmakolaWeb.Admin.ProductLive.Index do
  @moduledoc """
  Lists all products for the current store with search, status filtering,
  quick view modal, archive/activate confirmation modals, and slide-over
  panels for adding/editing products and bulk CSV upload.
  Mobile-responsive layout optimized for West African merchants.
  """
  use EmakolaWeb, :live_view

  require Logger

  import EmakolaWeb.Admin.ProductLive.BulkUploadModal, only: [bulk_upload_modal: 1]

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
      |> assign(search_query: query)
      |> load_products()

    {:noreply, socket}
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
      |> assign(status_filter: status_atom)
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
      <div class="flex flex-col sm:flex-row gap-3">
        <form phx-change="search" phx-debounce="300" class="flex-1">
          <div class="relative">
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-slate-500"
            />
            <input
              type="text"
              name="search"
              value={@search_query}
              placeholder="Search products..."
              class="w-full pl-10 pr-4 py-2.5 text-sm rounded-lg border border-slate-200
                     bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500
                     placeholder:text-slate-500/50"
              autocomplete="off"
            />
          </div>
        </form>

        <div class="flex gap-1 bg-slate-100 rounded-lg p-1 overflow-x-auto">
          <.status_tab status={:all} current={@status_filter} label="All" />
          <.status_tab status={:draft} current={@status_filter} label="Draft" />
          <.status_tab status={:active} current={@status_filter} label="Active" />
          <.status_tab status={:archived} current={@status_filter} label="Archived" />
        </div>
      </div>

      <%!-- Product List --%>
      <%= if @products == [] do %>
        <div id="product-empty-state" class="text-center py-16 bg-white rounded-lg">
          <.icon name="hero-cube" class="size-12 mx-auto text-slate-500/30 mb-3" />
          <p class="text-slate-500 font-medium">No products found</p>
          <p class="text-sm text-slate-500/60 mt-1">
            <%= if @search_query != "" or @status_filter != :all do %>
              Try adjusting your search or filters
            <% else %>
              Get started by adding your first product
            <% end %>
          </p>
        </div>
      <% else %>
        <%!-- Desktop Table (hidden on mobile) --%>
        <div class="hidden md:block bg-white rounded-lg overflow-hidden">
          <table class="w-full">
            <thead>
              <tr class="border-b border-slate-100 text-left text-xs font-mono uppercase tracking-wider text-slate-500">
                <th class="px-4 py-3">Product</th>
                <th class="px-4 py-3">Status</th>
                <th class="px-4 py-3">Category</th>
                <th class="px-4 py-3 text-right">Variants</th>
                <th class="px-4 py-3 text-right">Price</th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={product <- @products}
                class="border-b border-slate-100/50 hover:bg-slate-200/30 transition-colors"
              >
                <td class="px-4 py-3">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-lg bg-slate-100 flex items-center justify-center flex-shrink-0 overflow-hidden">
                      <%= if first_image_url(product) do %>
                        <img
                          src={first_image_url(product)}
                          alt={product.title}
                          class="w-full h-full object-cover"
                        />
                      <% else %>
                        <.icon name="hero-photo" class="size-5 text-slate-500/40" />
                      <% end %>
                    </div>
                    <span class="font-medium text-sm truncate max-w-[200px]">{product.title}</span>
                  </div>
                </td>
                <td class="px-4 py-3">
                  <.status_pill status={product.status} variant={:product} />
                </td>
                <td class="px-4 py-3 text-sm text-slate-500">
                  {category_name(product.category_id, @categories)}
                </td>
                <td class="px-4 py-3 text-sm text-right font-mono text-slate-500">
                  {variant_count(product)} variants
                </td>
                <td class="px-4 py-3 text-sm text-right font-mono font-medium">
                  {price_range(product)}
                </td>
                <td class="px-4 py-3 text-right">
                  <div class="flex items-center justify-end gap-2">
                    <button
                      phx-click={
                        JS.push("quick_view", value: %{id: product.id})
                        |> show_modal("quick-view-modal")
                      }
                      class="text-slate-500 hover:text-slate-700 text-xs font-medium px-2 py-1 rounded hover:bg-slate-100"
                      title="Quick View"
                    >
                      <.icon name="hero-eye" class="size-4" />
                    </button>
                    <button
                      phx-click={
                        JS.push("open_edit_product", value: %{id: product.id})
                        |> show_modal("product-form-modal")
                      }
                      class="text-primary hover:text-primary-hover text-sm font-medium"
                    >
                      Edit
                    </button>
                    <button
                      :if={product.status != :archived}
                      phx-click={
                        JS.push("open_archive", value: %{id: product.id})
                        |> show_modal("product-action-modal")
                      }
                      class="text-red-500 hover:text-red-700 text-xs font-medium px-2 py-1 rounded hover:bg-red-50"
                      title="Archive"
                    >
                      Archive
                    </button>
                    <button
                      :if={product.status == :archived}
                      phx-click={
                        JS.push("open_activate", value: %{id: product.id})
                        |> show_modal("product-action-modal")
                      }
                      class="text-primary hover:text-primary-hover text-xs font-medium px-2 py-1 rounded hover:bg-primary-soft"
                      title="Activate"
                    >
                      Activate
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Mobile Cards (hidden on desktop) --%>
        <div class="md:hidden space-y-3">
          <div
            :for={product <- @products}
            class="bg-white rounded-lg p-4 space-y-3"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="flex items-center gap-3 min-w-0">
                <div class="w-12 h-12 rounded-lg bg-slate-100 flex items-center justify-center flex-shrink-0 overflow-hidden">
                  <%= if first_image_url(product) do %>
                    <img
                      src={first_image_url(product)}
                      alt={product.title}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <.icon name="hero-photo" class="size-6 text-slate-500/40" />
                  <% end %>
                </div>
                <div class="min-w-0">
                  <p class="font-medium text-sm truncate">{product.title}</p>
                  <p class="text-xs text-slate-500">
                    {category_name(product.category_id, @categories)}
                  </p>
                </div>
              </div>
              <.status_pill status={product.status} variant={:product} />
            </div>
            <div class="flex items-center justify-between text-sm">
              <span class="text-slate-500 font-mono">
                {variant_count(product)} variants
              </span>
              <span class="font-mono font-medium">{price_range(product)}</span>
            </div>
            <div class="flex gap-2">
              <button
                phx-click={
                  JS.push("quick_view", value: %{id: product.id})
                  |> show_modal("quick-view-modal")
                }
                class="flex-1 text-center py-2 rounded-lg border border-slate-200 text-slate-600
                       text-sm font-medium hover:bg-slate-50 transition-colors"
              >
                Quick View
              </button>
              <button
                phx-click={
                  JS.push("open_edit_product", value: %{id: product.id})
                  |> show_modal("product-form-modal")
                }
                class="flex-1 text-center py-2 rounded-lg border border-emerald-200 text-primary
                       text-sm font-medium hover:bg-primary-soft transition-colors"
              >
                Edit
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Quick View Modal --%>
      <.modal id="quick-view-modal" title="Product Summary" size={:md}>
        <%= if @quick_view_product do %>
          <div class="space-y-4">
            <div class="flex items-start gap-4">
              <div class="w-16 h-16 rounded-control bg-slate-100 flex items-center justify-center flex-shrink-0 overflow-hidden">
                <%= if first_image_url(@quick_view_product) do %>
                  <img
                    src={first_image_url(@quick_view_product)}
                    alt={@quick_view_product.title}
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <.icon name="hero-photo" class="size-8 text-slate-500/40" />
                <% end %>
              </div>
              <div class="min-w-0 flex-1">
                <h3 class="text-lg font-semibold text-slate-900">
                  {@quick_view_product.title}
                </h3>
                <div class="flex items-center gap-2 mt-1">
                  <.status_pill status={@quick_view_product.status} variant={:product} />
                  <span class="text-xs text-slate-500">
                    {category_name(@quick_view_product.category_id, @categories)}
                  </span>
                </div>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4 py-3 border-t border-slate-100">
              <div>
                <p class="text-xs text-slate-500 uppercase tracking-wide font-medium">Variants</p>
                <p class="text-lg font-mono font-semibold text-slate-900 mt-1">
                  {variant_count(@quick_view_product)}
                </p>
              </div>
              <div>
                <p class="text-xs text-slate-500 uppercase tracking-wide font-medium">Price Range</p>
                <p class="text-lg font-mono font-semibold text-slate-900 mt-1">
                  {price_range(@quick_view_product)}
                </p>
              </div>
            </div>

            <div :if={@quick_view_product.description} class="border-t border-slate-100 pt-3">
              <p class="text-xs text-slate-500 uppercase tracking-wide font-medium mb-1">
                Description
              </p>
              <p class="text-sm text-slate-600 line-clamp-3">
                {@quick_view_product.description}
              </p>
            </div>
          </div>
        <% else %>
          <p class="text-sm text-slate-400">No product selected</p>
        <% end %>
        <:footer>
          <div class="flex items-center justify-end gap-3">
            <.admin_button variant={:secondary} phx-click={hide_modal("quick-view-modal")}>
              Close
            </.admin_button>
            <.admin_button
              :if={@quick_view_product}
              phx-click={
                JS.push("open_edit_product", value: %{id: @quick_view_product.id})
                |> hide_modal("quick-view-modal")
                |> show_modal("product-form-modal")
              }
            >
              Edit Product
            </.admin_button>
          </div>
        </:footer>
      </.modal>

      <%!-- Archive/Activate Confirmation Modal --%>
      <%= if @action_product && @action_type == :archive do %>
        <.confirm_modal
          id="product-action-modal"
          title="Archive Product"
          message={"Are you sure you want to archive \"#{@action_product.title}\"? It will no longer be visible in your storefront."}
          confirm_text="Archive"
          confirm_class="bg-red-600 hover:bg-red-700 text-white"
          on_confirm="archive_product"
          icon="warning"
          icon_class="text-red-500"
        />
      <% end %>

      <%= if @action_product && @action_type == :activate do %>
        <.confirm_modal
          id="product-action-modal"
          title="Activate Product"
          message={"Activate \"#{@action_product.title}\"? It must have at least one variant to be published. It will become visible in your storefront."}
          confirm_text="Activate"
          confirm_class="bg-primary hover:bg-primary-hover text-white"
          on_confirm="activate_product"
        />
      <% end %>

      <%!-- Product Form Slide-Over --%>
      <.modal
        id="product-form-modal"
        title={if @editing_product, do: "Edit Product", else: "New Product"}
        kind={:slide_over}
        on_cancel={JS.push("cancel_product_form")}
      >
        <form
          phx-change="validate_product"
          phx-submit="save_product"
          id="product-slide-over-form"
          class="space-y-5"
        >
          <%!-- Basic Information --%>
          <div class="space-y-4">
            <h3 class="text-sm font-semibold text-slate-500 uppercase tracking-wide">
              Basic Information
            </h3>

            <div>
              <label for="pf_title" class="block text-sm font-medium text-slate-700 mb-1.5">
                Title <span class="text-red-500">*</span>
              </label>
              <input
                type="text"
                id="pf_title"
                name="product[title]"
                value={@form_data["title"]}
                placeholder="e.g., Ankara Print Fabric"
                class={[
                  "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500",
                  if(@form_errors[:title],
                    do: "border-red-300 bg-red-50",
                    else: "border-slate-300 bg-white"
                  )
                ]}
              />
              <p :if={@form_errors[:title]} class="mt-1 text-xs text-red-600">
                {@form_errors[:title]}
              </p>
            </div>

            <div>
              <label
                for="pf_description"
                class="block text-sm font-medium text-slate-700 mb-1.5"
              >
                Description
              </label>
              <textarea
                id="pf_description"
                name="product[description]"
                rows="4"
                placeholder="Describe your product..."
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              >{@form_data["description"]}</textarea>
            </div>

            <div>
              <label
                for="pf_category_id"
                class="block text-sm font-medium text-slate-700 mb-1.5"
              >
                Category
              </label>
              <select
                id="pf_category_id"
                name="product[category_id]"
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              >
                <option value="">No category</option>
                <option
                  :for={cat <- @categories_list}
                  value={cat.id}
                  selected={@form_data["category_id"] == to_string(cat.id)}
                >
                  {cat.name}
                </option>
              </select>
            </div>

            <div>
              <label for="pf_tags" class="block text-sm font-medium text-slate-700 mb-1.5">
                Tags
              </label>
              <input
                type="text"
                id="pf_tags"
                name="product[tags]"
                value={@form_data["tags"]}
                placeholder="e.g., ankara, fabric, fashion (comma-separated)"
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
              <p class="mt-1 text-xs text-slate-500">Separate tags with commas</p>
            </div>

            <%!-- Price field: only when creating a new product --%>
            <div :if={is_nil(@editing_product)}>
              <label for="pf_price" class="block text-sm font-medium text-slate-700 mb-1.5">
                Price (GHS)
              </label>
              <input
                type="text"
                inputmode="decimal"
                id="pf_price"
                name="product[price]"
                value={@form_data["price"]}
                placeholder="e.g. 25.00"
                class={[
                  "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500",
                  if(@form_errors[:price],
                    do: "border-red-300 bg-red-50",
                    else: "border-slate-300 bg-white"
                  )
                ]}
              />
              <p :if={@form_errors[:price]} class="mt-1 text-xs text-red-600">
                {@form_errors[:price]}
              </p>
              <p :if={!@form_errors[:price]} class="mt-1 text-xs text-slate-500">
                Required to publish. You can add more pricing options later.
              </p>
            </div>
          </div>

          <%!-- Pricing (edit mode — prices live on variants) --%>
          <div :if={@editing_product} class="space-y-4 border-t border-slate-200 pt-5">
            <h3 class="text-sm font-semibold text-slate-500 uppercase tracking-wide">
              Pricing
            </h3>
            <%= if sorted_variants(@editing_product) == [] do %>
              <p class="text-xs text-slate-400 -mt-2">
                This product has no variants yet — it needs at least one variant
                before it can be priced and activated.
              </p>
            <% else %>
              <p class="text-xs text-slate-400 -mt-2">Amounts in GH&#8373;</p>
              <div :for={{variant, idx} <- Enum.with_index(sorted_variants(@editing_product))}>
                <label
                  for={"pf_price_#{variant.id}"}
                  class="block text-sm font-medium text-slate-700 mb-1.5"
                >
                  {variant.sku || "Variant #{idx + 1}"}
                </label>
                <input
                  type="text"
                  inputmode="decimal"
                  id={"pf_price_#{variant.id}"}
                  name={"product[variant_prices][#{variant.id}]"}
                  value={
                    get_in(@form_data, ["variant_prices", variant.id]) ||
                      Shared.format_pesewas(variant.price)
                  }
                  placeholder="0.00"
                  class={[
                    "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500",
                    if(@form_errors[{:variant_price, variant.id}],
                      do: "border-red-300 bg-red-50",
                      else: "border-slate-300 bg-white"
                    )
                  ]}
                />
                <p
                  :if={@form_errors[{:variant_price, variant.id}]}
                  class="mt-1 text-xs text-red-600"
                >
                  {@form_errors[{:variant_price, variant.id}]}
                </p>
              </div>
            <% end %>
          </div>

          <%!-- Images --%>
          <Shared.upload_area
            uploads={@uploads}
            existing_images={
              if @editing_product, do: Map.get(@editing_product, :images, []), else: []
            }
          />

          <%!-- SEO --%>
          <div class="space-y-4 border-t border-slate-200 pt-5">
            <h3 class="text-sm font-semibold text-slate-500 uppercase tracking-wide">SEO</h3>
            <p class="text-xs text-slate-400 -mt-2">
              Optimize how your product appears in search results
            </p>

            <div>
              <label
                for="pf_seo_title"
                class="block text-sm font-medium text-slate-700 mb-1.5"
              >
                SEO Title
              </label>
              <input
                type="text"
                id="pf_seo_title"
                name="product[seo_title]"
                value={@form_data["seo_title"]}
                placeholder="Custom title for search engines"
                maxlength="70"
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
              <p class="mt-1 text-xs text-slate-500">
                {String.length(@form_data["seo_title"] || "")}/70 characters
              </p>
            </div>

            <div>
              <label
                for="pf_seo_description"
                class="block text-sm font-medium text-slate-700 mb-1.5"
              >
                SEO Description
              </label>
              <textarea
                id="pf_seo_description"
                name="product[seo_description]"
                rows="2"
                maxlength="160"
                placeholder="Brief description for search results"
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              >{@form_data["seo_description"]}</textarea>
              <p class="mt-1 text-xs text-slate-500">
                {String.length(@form_data["seo_description"] || "")}/160 characters
              </p>
            </div>
          </div>

          <%!-- Hidden action field for button differentiation --%>
          <input type="hidden" name="product[_action]" id="pf_action_field" value="draft" />
        </form>
        <:footer>
          <div class="flex flex-col sm:flex-row gap-3">
            <button
              type="submit"
              form="product-slide-over-form"
              phx-click={JS.set_attribute({"value", "draft"}, to: "#pf_action_field")}
              class="flex-1 px-4 py-2.5 rounded-control text-sm font-semibold border-2 border-primary
                     text-primary hover:bg-primary-soft active:scale-95 transition-all"
            >
              Save as Draft
            </button>
            <.admin_button
              type="submit"
              form="product-slide-over-form"
              phx-click={JS.set_attribute({"value", "activate"}, to: "#pf_action_field")}
              class="flex-1"
            >
              Save &amp; Activate
            </.admin_button>
          </div>
        </:footer>
      </.modal>

      <.bulk_upload_modal
        uploads={@uploads}
        csv_preview={@csv_preview}
        csv_errors={@csv_errors}
        bulk_importing={@bulk_importing}
      />
    </div>
    """
  end

  # ── Components ──

  attr :status, :atom, required: true
  attr :current, :atom, required: true
  attr :label, :string, required: true

  defp status_tab(assigns) do
    ~H"""
    <button
      phx-click="filter_status"
      phx-value-status={@status}
      class={[
        "px-3 py-1.5 text-sm font-medium rounded-md transition-colors whitespace-nowrap",
        if(@status == @current,
          do: "bg-white text-slate-900 shadow-sm",
          else: "text-slate-500 hover:text-slate-900"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  # ── Data Loading ──

  @admin_products_limit 100

  defp load_products(%{assigns: %{store_id: nil}} = socket) do
    assign(socket, products: [])
  end

  defp load_products(socket) do
    %{store_id: store_id, search_query: query, status_filter: status} = socket.assigns

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
        |> Ash.read!(authorize?: false)
        |> Enum.take(@admin_products_limit)
      rescue
        exception ->
          Logger.error(
            "[product_live.index] load_products loading products raised: #{Exception.message(exception)}"
          )

          []
      end

    assign(socket, products: products)
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

  defp sorted_variants(product) do
    case product.variants do
      %Ash.NotLoaded{} -> []
      variants -> Enum.sort_by(variants, & &1.position)
    end
  end

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

  defp category_name(nil, _categories), do: "Uncategorized"
  defp category_name(id, categories), do: Map.get(categories, id, "Uncategorized")

  defp variant_count(product) do
    Map.get(product, :variant_count, 0)
  end

  defp price_range(product) do
    min = Map.get(product, :min_price, 0) || 0
    max = Map.get(product, :max_price, 0) || 0

    cond do
      min == 0 and max == 0 ->
        "GH\u20B5 0.00"

      min == max ->
        "GH\u20B5 #{format_price(min)}"

      true ->
        "GH\u20B5 #{format_price(min)} \u2013 #{format_price(max)}"
    end
  end

  defp format_price(amount) when is_integer(amount) do
    whole = div(amount, 100)
    cents = rem(amount, 100)
    "#{whole}.#{String.pad_leading(Integer.to_string(cents), 2, "0")}"
  end

  defp format_price(_), do: "0.00"

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

  # ── Image Helpers ──

  defp first_image_url(product) do
    case Map.get(product, :images) do
      [%{thumbnail_url: url} | _] when is_binary(url) and url != "" -> url
      [%{url: url} | _] when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end
end
