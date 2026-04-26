defmodule EmakolaWeb.Admin.ProductLive.Index do
  @moduledoc """
  Lists all products for the current store with search, status filtering,
  quick view modal, archive/activate confirmation modals, and slide-over
  panels for adding/editing products and bulk CSV upload.
  Mobile-responsive layout optimized for West African merchants.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Admin.ProductLive.BulkUploadModal, only: [bulk_upload_modal: 1]

  require Ash.Query

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
      case product |> Ash.Changeset.for_update(:archive) |> Ash.update(authorize?: false) do
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
      case product |> Ash.Changeset.for_update(:activate) |> Ash.update(authorize?: false) do
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
    errors = validate_form(Map.delete(params, "_action"))

    if map_size(errors) > 0 do
      {:noreply, assign(socket, form_data: params, form_errors: errors)}
    else
      attrs = build_product_attrs(Map.delete(params, "_action"), socket.assigns.store_id)

      result =
        if socket.assigns.editing_product do
          update_product(socket.assigns.editing_product, attrs, action)
        else
          create_product(attrs, action)
        end

      case result do
        {:ok, product} ->
          # Upload images for the product
          save_uploaded_images(socket, product)

          {:noreply,
           socket
           |> assign(
             show_product_form: false,
             editing_product: nil,
             form_data: empty_form_data(),
             form_errors: %{}
           )
           |> load_products()
           |> put_flash(:info, "Product saved successfully")}

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
    case Ash.get(Emakola.Catalog.Image, image_id) do
      {:ok, image} ->
        Ash.destroy!(image)

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
     |> cancel_uploads(:csv_file)}
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

      {success_count, error_count, errors} =
        Emakola.Catalog.CsvImporter.import_rows(rows, store_id)

      if success_count > 0 do
        Emakola.Catalog.CachedCatalog.invalidate_store(store_id)
      end

      socket =
        socket
        |> assign(bulk_importing: false)
        |> load_products()

      if error_count > 0 do
        {:noreply,
         socket
         |> assign(csv_errors: errors)
         |> put_flash(
           :info,
           "Imported #{success_count} product(s). #{error_count} failed."
         )}
      else
        {:noreply,
         socket
         |> assign(
           show_bulk_upload: false,
           csv_preview: [],
           csv_errors: [],
           bulk_importing: false
         )
         |> put_flash(:info, "Successfully imported #{success_count} product(s).")}
      end
    end
  end

  # ── Render ──

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold font-headline tracking-tight">Products</h1>
          <p class="text-sm text-on-surface-variant mt-1">
            Manage your store catalog
          </p>
        </div>
        <div class="flex items-center gap-2">
          <button
            phx-click={
              JS.push("open_bulk_upload")
              |> show_modal("bulk-upload-modal")
            }
            class="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-semibold
                   border border-slate-300 text-slate-600 hover:bg-slate-50
                   active:scale-95 transition-all"
          >
            <.icon name="hero-arrow-up-tray" class="size-3.5" /> Bulk
          </button>
          <button
            phx-click={
              JS.push("open_new_product")
              |> show_modal("product-form-modal")
            }
            class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg text-xs font-semibold
                   bg-emerald-600 text-white hover:bg-emerald-700 active:scale-95 transition-all
                   shadow-sm"
          >
            <.icon name="hero-plus" class="size-3.5" /> New Product
          </button>
        </div>
      </div>

      <%!-- Search & Filters --%>
      <div class="flex flex-col sm:flex-row gap-3">
        <form phx-change="search" phx-debounce="300" class="flex-1">
          <div class="relative">
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-on-surface-variant"
            />
            <input
              type="text"
              name="search"
              value={@search_query}
              placeholder="Search products..."
              class="w-full pl-10 pr-4 py-2.5 text-sm rounded-lg border border-surface-container-highest
                     bg-surface-container-lowest focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500
                     placeholder:text-on-surface-variant/50"
              autocomplete="off"
            />
          </div>
        </form>

        <div class="flex gap-1 bg-surface-container rounded-lg p-1 overflow-x-auto">
          <.status_tab status={:all} current={@status_filter} label="All" />
          <.status_tab status={:draft} current={@status_filter} label="Draft" />
          <.status_tab status={:active} current={@status_filter} label="Active" />
          <.status_tab status={:archived} current={@status_filter} label="Archived" />
        </div>
      </div>

      <%!-- Product List --%>
      <%= if @products == [] do %>
        <div id="product-empty-state" class="text-center py-16 bg-surface-container-lowest rounded-lg">
          <.icon name="hero-cube" class="size-12 mx-auto text-on-surface-variant/30 mb-3" />
          <p class="text-on-surface-variant font-medium">No products found</p>
          <p class="text-sm text-on-surface-variant/60 mt-1">
            <%= if @search_query != "" or @status_filter != :all do %>
              Try adjusting your search or filters
            <% else %>
              Get started by adding your first product
            <% end %>
          </p>
        </div>
      <% else %>
        <%!-- Desktop Table (hidden on mobile) --%>
        <div class="hidden md:block bg-surface-container-lowest rounded-lg overflow-hidden">
          <table class="w-full">
            <thead>
              <tr class="border-b border-surface-container text-left text-xs font-mono uppercase tracking-wider text-on-surface-variant">
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
                class="border-b border-surface-container/50 hover:bg-surface-container-high/30 transition-colors"
              >
                <td class="px-4 py-3">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-lg bg-surface-container flex items-center justify-center flex-shrink-0 overflow-hidden">
                      <%= if first_image_url(product) do %>
                        <img
                          src={first_image_url(product)}
                          alt={product.title}
                          class="w-full h-full object-cover"
                        />
                      <% else %>
                        <.icon name="hero-photo" class="size-5 text-on-surface-variant/40" />
                      <% end %>
                    </div>
                    <span class="font-medium text-sm truncate max-w-[200px]">{product.title}</span>
                  </div>
                </td>
                <td class="px-4 py-3">
                  <.status_badge status={product.status} />
                </td>
                <td class="px-4 py-3 text-sm text-on-surface-variant">
                  {category_name(product.category_id, @categories)}
                </td>
                <td class="px-4 py-3 text-sm text-right font-mono text-on-surface-variant">
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
                      class="text-emerald-600 hover:text-emerald-700 text-sm font-medium"
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
                      class="text-emerald-500 hover:text-emerald-700 text-xs font-medium px-2 py-1 rounded hover:bg-emerald-50"
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
            class="bg-surface-container-lowest rounded-lg p-4 space-y-3"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="flex items-center gap-3 min-w-0">
                <div class="w-12 h-12 rounded-lg bg-surface-container flex items-center justify-center flex-shrink-0 overflow-hidden">
                  <%= if first_image_url(product) do %>
                    <img
                      src={first_image_url(product)}
                      alt={product.title}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <.icon name="hero-photo" class="size-6 text-on-surface-variant/40" />
                  <% end %>
                </div>
                <div class="min-w-0">
                  <p class="font-medium text-sm truncate">{product.title}</p>
                  <p class="text-xs text-on-surface-variant">
                    {category_name(product.category_id, @categories)}
                  </p>
                </div>
              </div>
              <.status_badge status={product.status} />
            </div>
            <div class="flex items-center justify-between text-sm">
              <span class="text-on-surface-variant font-mono">
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
                class="flex-1 text-center py-2 rounded-lg border border-emerald-200 text-emerald-700
                       text-sm font-medium hover:bg-emerald-50 transition-colors"
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
              <div class="w-16 h-16 rounded-xl bg-surface-container flex items-center justify-center flex-shrink-0 overflow-hidden">
                <%= if first_image_url(@quick_view_product) do %>
                  <img
                    src={first_image_url(@quick_view_product)}
                    alt={@quick_view_product.title}
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <.icon name="hero-photo" class="size-8 text-on-surface-variant/40" />
                <% end %>
              </div>
              <div class="min-w-0 flex-1">
                <h3 class="text-lg font-semibold text-slate-900">
                  {@quick_view_product.title}
                </h3>
                <div class="flex items-center gap-2 mt-1">
                  <.status_badge status={@quick_view_product.status} />
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
            <button
              type="button"
              phx-click={hide_modal("quick-view-modal")}
              class="px-4 py-2.5 text-sm font-medium text-slate-700 bg-white border border-slate-300
                     rounded-xl hover:bg-slate-50 transition-colors"
            >
              Close
            </button>
            <button
              :if={@quick_view_product}
              phx-click={
                JS.push("open_edit_product", value: %{id: @quick_view_product.id})
                |> hide_modal("quick-view-modal")
                |> show_modal("product-form-modal")
              }
              class="px-4 py-2.5 text-sm font-semibold bg-emerald-600 text-white
                     rounded-xl hover:bg-emerald-700 transition-colors"
            >
              Edit Product
            </button>
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
          confirm_class="bg-emerald-600 hover:bg-emerald-700 text-white"
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
          </div>

          <%!-- Images --%>
          <div class="space-y-4 border-t border-slate-200 pt-5">
            <h3 class="text-sm font-semibold text-slate-500 uppercase tracking-wide">
              Images
            </h3>
            <p class="text-xs text-slate-400 -mt-2">
              Upload up to 5 images (JPG, PNG, WebP, max 10MB each)
            </p>

            <%!-- Existing images (edit mode) --%>
            <%= if @editing_product && Map.get(@editing_product, :images, []) != [] do %>
              <div class="grid grid-cols-3 gap-2">
                <%= for img <- @editing_product.images do %>
                  <div class="relative group rounded-lg overflow-hidden bg-slate-100 aspect-square">
                    <img
                      src={img.thumbnail_url || img.url}
                      alt={img.alt_text || ""}
                      class="w-full h-full object-cover"
                    />
                    <button
                      type="button"
                      phx-click="delete_image"
                      phx-value-id={img.id}
                      class="absolute top-1 right-1 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity text-xs"
                    >
                      <.icon name="hero-x-mark" class="size-3.5" />
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>

            <%!-- Upload area --%>
            <div
              class="border-2 border-dashed border-slate-300 rounded-lg p-4 text-center hover:border-emerald-400 transition-colors"
              phx-drop-target={@uploads.product_images.ref}
            >
              <.icon name="hero-cloud-arrow-up" class="size-8 mx-auto text-slate-400 mb-2" />
              <p class="text-sm text-slate-600 font-medium">
                Drag & drop images here
              </p>
              <p class="text-xs text-slate-400 mt-1">or</p>
              <label class="inline-block mt-2 px-3 py-1.5 text-xs font-semibold bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg cursor-pointer transition-colors">
                Browse files <.live_file_input upload={@uploads.product_images} class="sr-only" />
              </label>
            </div>

            <%!-- Upload previews --%>
            <%= if @uploads.product_images.entries != [] do %>
              <div class="grid grid-cols-3 gap-2">
                <%= for entry <- @uploads.product_images.entries do %>
                  <div class="relative rounded-lg overflow-hidden bg-slate-100 aspect-square">
                    <.live_img_preview entry={entry} class="w-full h-full object-cover" />
                    <button
                      type="button"
                      phx-click="cancel_image_upload"
                      phx-value-ref={entry.ref}
                      class="absolute top-1 right-1 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center text-xs"
                    >
                      <.icon name="hero-x-mark" class="size-3.5" />
                    </button>
                    <%!-- Progress bar --%>
                    <div class="absolute bottom-0 left-0 right-0 h-1 bg-slate-200">
                      <div
                        class="h-full bg-emerald-500 transition-all"
                        style={"width: #{entry.progress}%"}
                      >
                      </div>
                    </div>
                    <%!-- Errors --%>
                    <%= for err <- upload_errors(@uploads.product_images, entry) do %>
                      <p class="absolute bottom-1 left-1 right-1 text-[9px] text-red-500 bg-white/90 px-1 rounded">
                        {upload_error_to_string(err)}
                      </p>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

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
              class="flex-1 px-4 py-2.5 rounded-lg text-sm font-semibold border-2 border-emerald-600
                     text-emerald-700 hover:bg-emerald-50 active:scale-95 transition-all"
            >
              Save as Draft
            </button>
            <button
              type="submit"
              form="product-slide-over-form"
              phx-click={JS.set_attribute({"value", "activate"}, to: "#pf_action_field")}
              class="flex-1 px-4 py-2.5 rounded-lg text-sm font-semibold bg-emerald-600 text-white
                     hover:bg-emerald-700 active:scale-95 transition-all shadow-sm"
            >
              Save &amp; Activate
            </button>
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
          do: "bg-surface-container-lowest text-on-surface shadow-sm",
          else: "text-on-surface-variant hover:text-on-surface"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
      status_badge_class(@status)
    ]}>
      {@status |> to_string() |> String.capitalize()}
    </span>
    """
  end

  # ── Data Loading ──

  @admin_products_limit 100

  defp load_products(%{assigns: %{store_id: nil}} = socket) do
    assign(socket, products: [])
  end

  defp load_products(socket) do
    require Ash.Query
    %{store_id: store_id, search_query: query, status_filter: status} = socket.assigns

    products =
      try do
        base =
          Emakola.Catalog.Product
          |> Ash.Query.filter(store_id == ^store_id)
          |> Ash.Query.sort(inserted_at: :desc)
          |> Ash.Query.load([:variant_count, :min_price, :max_price, :images])
          |> Ash.Query.limit(@admin_products_limit)

        base =
          if query != "" do
            Ash.Query.filter(base, contains(title, ^query))
          else
            base
          end

        base =
          if status != :all do
            Ash.Query.filter(base, status == ^status)
          else
            base
          end

        Ash.read!(base, authorize?: false)
      rescue
        _ -> []
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
        _ -> []
      end

    categories_map = Map.new(categories_list, fn cat -> {cat.id, cat.name} end)

    assign(socket, categories: categories_map, categories_list: categories_list)
  end

  # ── Product CRUD ──

  defp create_product(attrs, :draft) do
    Emakola.Catalog.create_product(attrs)
  end

  defp create_product(attrs, :active) do
    case Emakola.Catalog.create_product(attrs) do
      {:ok, product} ->
        case Ash.Changeset.for_update(product, :activate) |> Ash.update(authorize?: false) do
          {:ok, activated} -> {:ok, activated}
          {:error, _} -> {:ok, product}
        end

      error ->
        error
    end
  end

  defp update_product(product, attrs, :draft) do
    product
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  defp update_product(product, attrs, :active) do
    case product |> Ash.Changeset.for_update(:update, attrs) |> Ash.update(authorize?: false) do
      {:ok, updated} ->
        case updated |> Ash.Changeset.for_update(:activate) |> Ash.update(authorize?: false) do
          {:ok, activated} -> {:ok, activated}
          {:error, _} -> {:ok, updated}
        end

      error ->
        error
    end
  end

  defp load_product(id) do
    case Ash.get(Emakola.Catalog.Product, id) do
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

  # ── Form Helpers ──

  defp empty_form_data do
    %{
      "title" => "",
      "description" => "",
      "category_id" => "",
      "tags" => "",
      "seo_title" => "",
      "seo_description" => ""
    }
  end

  defp product_to_form_data(nil), do: empty_form_data()

  defp product_to_form_data(product) do
    %{
      "title" => product.title || "",
      "description" => product.description || "",
      "category_id" => if(product.category_id, do: to_string(product.category_id), else: ""),
      "tags" => Enum.join(product.tags || [], ", "),
      "seo_title" => product.seo_title || "",
      "seo_description" => product.seo_description || ""
    }
  end

  defp validate_form(params) do
    errors = %{}

    if String.trim(params["title"] || "") == "" do
      Map.put(errors, :title, "Title is required")
    else
      errors
    end
  end

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

  defp status_badge_class(:draft), do: "bg-gray-100 text-gray-700"
  defp status_badge_class(:active), do: "bg-green-100 text-green-700"
  defp status_badge_class(:archived), do: "bg-red-100 text-red-700"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-700"

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
      other -> inspect(other)
    end)
    |> Enum.join(", ")
  end

  defp format_error(error), do: inspect(error)

  defp upload_error_to_string(:too_large), do: "File is too large"
  defp upload_error_to_string(:not_accepted), do: "Only .csv files are accepted"
  defp upload_error_to_string(:too_many_files), do: "Only one file at a time"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"

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

  defp save_uploaded_images(socket, product) do
    store_id = socket.assigns.store_id

    consume_uploaded_entries(socket, :product_images, fn %{path: tmp_path}, entry ->
      ext = Path.extname(entry.client_name)
      filename = "#{Ecto.UUID.generate()}#{ext}"
      s3_path = "stores/#{store_id}/products/#{filename}"
      binary = File.read!(tmp_path)

      {:ok, url} =
        Emakola.Storage.upload(binary, s3_path, content_type: entry.client_type)

      Emakola.Catalog.Image
      |> Ash.Changeset.for_create(:create, %{
        url: url,
        product_id: product.id,
        store_id: store_id,
        content_type: entry.client_type,
        file_size_bytes: entry.client_size,
        alt_text: Path.rootname(entry.client_name)
      })
      |> Ash.create()

      {:ok, url}
    end)
  end
end
