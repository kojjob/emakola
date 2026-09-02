defmodule EmakolaWeb.Admin.ProductLive.IndexComponents do
  @moduledoc """
  Render components for the product admin index page. Markup extracted
  verbatim from `Index` (decomposition pass) — all events bubble to the
  parent LiveView unchanged.
  """

  use EmakolaWeb, :html

  import EmakolaWeb.Admin.ProductLive.BulkUploadModal, only: [bulk_upload_modal: 1]

  alias EmakolaWeb.Admin.ProductLive.Shared

  @doc """
  Narrows the list to one category.

  A merchant with 82 categories and 272 products cannot answer "show me my
  shoes" with a status tab and a search box. Counts ride along because an
  empty category is information — "Shoes (0)" tells a merchant where their
  stock is not.
  """
  attr :categories, :list, required: true
  attr :current, :string, default: nil

  def category_filter_select(assigns) do
    assigns = assign(assigns, :form, to_form(%{"category_id" => assigns.current || ""}))

    ~H"""
    <.form :if={@categories != []} for={@form} phx-change="filter_category" class="shrink-0">
      <select
        id="product-category-filter"
        name="category_id"
        class="h-9 rounded-control border border-border bg-surface px-3 text-sm text-slate-700 cursor-pointer focus:ring-2 focus:ring-primary/20 focus:border-primary"
      >
        <option value="" selected={is_nil(@current)}>All categories</option>
        <option
          :for={category <- @categories}
          value={category.id}
          selected={@current == category.id}
        >
          {category.name}{category_count_suffix(category)}
        </option>
      </select>
    </.form>
    """
  end

  # A merchant looking at an empty CATEGORY has products — just not here. That
  # is "no products found", not "add your first product".
  defp filtering?(search_query, status_filter, category_filter) do
    search_query != "" or status_filter != :all or not is_nil(category_filter)
  end

  defp category_count_suffix(category) do
    case Map.get(category, :product_count) do
      count when is_integer(count) -> " (#{count})"
      _not_loaded_or_missing -> ""
    end
  end

  attr :products, :list, required: true
  attr :categories, :map, required: true
  attr :search_query, :string, required: true
  attr :status_filter, :atom, required: true
  attr :category_filter, :string, default: nil

  def product_list(assigns) do
    ~H"""
    <%= if @products == [] do %>
      <%!-- A brand-new merchant gets directions and a photo-first way in; a
            search that matched nothing gets told it was the search. --%>
      <div id="product-empty-state">
        <.empty_state
          :if={filtering?(@search_query, @status_filter, @category_filter)}
          icon="hero-cube"
          title="No products found"
          description="Try adjusting your search or filters"
        />
        <%!-- Photo first: a merchant who reads slowly can point a camera long
              before they can fill a form. The snap flow only exists when the
              AI key is set, so fall back to the form as the primary. --%>
        <.empty_state
          :if={
            not filtering?(@search_query, @status_filter, @category_filter) and
              EmakolaWeb.AiGate.enabled?()
          }
          icon="hero-camera"
          tone={:warning}
          title="Add your first product"
          description="Take a photo — Makola writes the listing"
          action_label="Snap a photo"
          action_icon="hero-camera"
          action_path="/admin/products/snap"
        />
        <.empty_state
          :if={
            not filtering?(@search_query, @status_filter, @category_filter) and
              not EmakolaWeb.AiGate.enabled?()
          }
          icon="hero-camera"
          tone={:warning}
          title="Add your first product"
          description="Add pictures of what you sell"
          action_label="Add a product"
          action_icon="hero-plus"
          action_path="/admin/products/new"
        />
      </div>
    <% else %>
      <%!-- Desktop Table (hidden on mobile) --%>
      <div class="hidden md:block bg-surface rounded-card border border-border shadow-sm overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-slate-200 bg-slate-50/50 text-left text-xs font-semibold uppercase tracking-wider text-slate-500">
              <th class="px-4 py-3">Product</th>
              <th class="px-4 py-3">Status</th>
              <th class="px-4 py-3">Stock</th>
              <th class="px-4 py-3 text-right">Variants</th>
              <th class="px-4 py-3 text-right">Price</th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={product <- @products}
              class="border-b border-slate-100/50 hover:bg-slate-50 transition-colors"
            >
              <td class="px-4 py-3">
                <div class="flex items-center gap-3">
                  <.product_thumb url={first_image_url(product)} alt={product.title} />
                  <div class="min-w-0">
                    <p class="font-semibold text-sm text-slate-900 truncate max-w-[220px]">
                      {product.title}
                    </p>
                    <p class="text-xs text-slate-400 truncate">
                      {category_name(product.category_id, @categories)}
                    </p>
                  </div>
                </div>
              </td>
              <td class="px-4 py-3">
                <.status_badge status={product.status} variant={:product} />
              </td>
              <td class="px-4 py-3">
                <.stock_meter quantity={total_stock(product)} tracked={tracks_stock?(product)} />
              </td>
              <td class="px-4 py-3 text-sm text-right font-mono text-slate-500">
                {Emakola.Plural.count(variant_count(product), "variant")}
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
          class="bg-surface rounded-card border border-border shadow-sm p-4 space-y-3"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="flex items-center gap-3 min-w-0">
              <.product_thumb url={first_image_url(product)} alt={product.title} class="w-12 h-12" />
              <div class="min-w-0">
                <p class="font-semibold text-sm text-slate-900 truncate">{product.title}</p>
                <p class="text-xs text-slate-400">
                  {category_name(product.category_id, @categories)}
                </p>
              </div>
            </div>
            <.status_badge status={product.status} variant={:product} />
          </div>
          <div class="flex items-center justify-between text-sm">
            <.stock_meter quantity={total_stock(product)} tracked={tracks_stock?(product)} />
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
            <%!-- Archive/Activate must exist here too: this card is the ONLY
            product UI on phones (the table above is `hidden md:block`), and
            most merchants are on mobile. Same events and modal as desktop. --%>
            <button
              :if={product.status != :archived}
              phx-click={
                JS.push("open_archive", value: %{id: product.id})
                |> show_modal("product-action-modal")
              }
              class="flex-1 text-center py-2 rounded-lg border border-red-200 text-red-600
                       text-sm font-medium hover:bg-red-50 transition-colors"
            >
              Archive
            </button>
            <button
              :if={product.status == :archived}
              phx-click={
                JS.push("open_activate", value: %{id: product.id})
                |> show_modal("product-action-modal")
              }
              class="flex-1 text-center py-2 rounded-lg border border-emerald-200 text-primary
                       text-sm font-medium hover:bg-primary-soft transition-colors"
            >
              Activate
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  attr :quick_view_product, :any, required: true
  attr :categories, :map, required: true

  def quick_view_modal(assigns) do
    ~H"""
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
                <.status_badge status={@quick_view_product.status} variant={:product} />
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
    """
  end

  attr :action_product, :any, required: true
  attr :action_type, :atom, required: true

  def confirm_action_modal(assigns) do
    ~H"""
    <div>
      <%!-- Archive/Activate confirmation. ALWAYS rendered and nil-safe (same
      pattern as the platform merchant drawer). It must not be wrapped in an
      `if @action_product`: the trigger fires
      `JS.push("open_archive") |> show_modal("product-action-modal")`, and
      JS.show runs on the client immediately while the push that sets
      @action_product is a server round-trip. A conditionally-rendered modal
      therefore does not exist yet when show runs — the first click did
      nothing and the merchant had to click Archive twice. --%>
      <.confirm_modal
        id="product-action-modal"
        title={action_title(@action_type)}
        message={action_message(@action_type, @action_product)}
        confirm_text={action_confirm_text(@action_type)}
        confirm_class={action_confirm_class(@action_type)}
        on_confirm={action_event(@action_type)}
        icon={action_icon(@action_type)}
        icon_class={action_icon_class(@action_type)}
      />
    </div>
    """
  end

  defp action_title(:activate), do: "Activate Product"
  defp action_title(_), do: "Archive Product"

  defp action_message(:activate, %{title: title}),
    do:
      "Activate \"#{title}\"? It must have at least one variant to be published. It will become visible in your storefront."

  defp action_message(_type, %{title: title}),
    do:
      "Are you sure you want to archive \"#{title}\"? It will no longer be visible in your storefront."

  # No product selected yet — the modal is hidden, so the copy is never seen.
  defp action_message(_type, _product), do: ""

  defp action_confirm_text(:activate), do: "Activate"
  defp action_confirm_text(_), do: "Archive"

  defp action_confirm_class(:activate), do: "bg-primary hover:bg-primary-hover text-white"
  defp action_confirm_class(_), do: "bg-red-600 hover:bg-red-700 text-white"

  defp action_event(:activate), do: "activate_product"
  defp action_event(_), do: "archive_product"

  defp action_icon(:activate), do: nil
  defp action_icon(_), do: "warning"

  defp action_icon_class(:activate), do: "text-amber-500"
  defp action_icon_class(_), do: "text-red-500"

  attr :editing_product, :any, required: true
  attr :form_data, :map, required: true
  attr :product_form, Phoenix.HTML.Form, required: true
  attr :form_errors, :map, required: true
  attr :categories_list, :list, required: true
  attr :uploads, :any, required: true
  attr :bulk_upload_form, :any, required: true
  attr :show_bulk_upload, :boolean, required: true
  attr :csv_preview, :any, required: true
  attr :csv_errors, :list, required: true
  attr :bulk_importing, :boolean, required: true

  def product_form_slideover(assigns) do
    ~H"""
    <div>
      <%!-- Product Form Slide-Over --%>
      <.modal
        id="product-form-modal"
        title={if @editing_product, do: "Edit Product", else: "New Product"}
        kind={:slide_over}
        on_cancel={JS.push("cancel_product_form")}
      >
        <.form
          for={@product_form}
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
              <.input
                field={@product_form[:title]}
                type="text"
                id="pf_title"
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
              <.input
                field={@product_form[:description]}
                type="textarea"
                id="pf_description"
                rows="4"
                placeholder="Describe your product..."
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
            </div>

            <div>
              <label
                for="pf_category_id"
                class="block text-sm font-medium text-slate-700 mb-1.5"
              >
                Category
              </label>
              <.input
                field={@product_form[:category_id]}
                type="select"
                id="pf_category_id"
                prompt="No category"
                options={Enum.map(@categories_list, &{&1.name, &1.id})}
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
            </div>

            <div>
              <label for="pf_tags" class="block text-sm font-medium text-slate-700 mb-1.5">
                Tags
              </label>
              <.input
                field={@product_form[:tags]}
                type="text"
                id="pf_tags"
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
              <.input
                field={@product_form[:price]}
                type="text"
                inputmode="decimal"
                id="pf_price"
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

          <%!-- The slide-over is the quick-edit path and deliberately has no
               product-type field. Without this link the Products list is a dead
               end to the full form, where type and digital files live. --%>
          <div :if={@editing_product} class="border-t border-slate-200 pt-5">
            <.link
              navigate={"/admin/products/#{@editing_product.id}/edit"}
              class="text-sm text-primary font-medium underline"
            >
              Edit full details
            </.link>
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
                <.input
                  type="text"
                  inputmode="decimal"
                  id={"pf_price_#{variant.id}"}
                  name={"#{@product_form.name}[variant_prices][#{variant.id}]"}
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
              <.input
                field={@product_form[:seo_title]}
                type="text"
                id="pf_seo_title"
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
              <.input
                field={@product_form[:seo_description]}
                type="textarea"
                id="pf_seo_description"
                rows="2"
                maxlength="160"
                placeholder="Brief description for search results"
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
              <p class="mt-1 text-xs text-slate-500">
                {String.length(@form_data["seo_description"] || "")}/160 characters
              </p>
            </div>
          </div>

          <%!-- Hidden action field for button differentiation --%>
          <.input field={@product_form[:_action]} type="hidden" id="pf_action_field" value="draft" />
        </.form>
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
        form={@bulk_upload_form}
        show={@show_bulk_upload}
        uploads={@uploads}
        csv_preview={@csv_preview}
        csv_errors={@csv_errors}
        bulk_importing={@bulk_importing}
      />
    </div>
    """
  end

  # ── Display helpers (moved with the markup that uses them) ──

  defp sorted_variants(product), do: Shared.sorted_variants(product)

  defp category_name(nil, _categories), do: "Uncategorized"
  defp category_name(id, categories), do: Map.get(categories, id, "Uncategorized")

  defp variant_count(product) do
    Map.get(product, :variant_count, 0)
  end

  # A product with no variants has a nil sum — read that as no stock.
  defp total_stock(product) do
    Map.get(product, :total_stock) || 0
  end

  # A product with no stock-tracking variant is stocked by somebody else —
  # an imported supplier listing. Its zero is not an empty shelf.
  defp tracks_stock?(product) do
    case Map.get(product, :tracked_variant_count) do
      nil -> true
      count -> count > 0
    end
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

  defp first_image_url(product) do
    case Map.get(product, :images) do
      [%{thumbnail_url: url} | _] when is_binary(url) and url != "" -> url
      [%{url: url} | _] when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end
end
