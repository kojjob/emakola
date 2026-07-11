defmodule EmakolaWeb.Admin.ProductLive.IndexComponents do
  @moduledoc """
  Render components for the product admin index page. Markup extracted
  verbatim from `Index` (decomposition pass) — all events bubble to the
  parent LiveView unchanged.
  """

  use EmakolaWeb, :html

  import EmakolaWeb.Admin.ProductLive.BulkUploadModal, only: [bulk_upload_modal: 1]

  alias EmakolaWeb.Admin.ProductLive.Shared

  attr :products, :list, required: true
  attr :categories, :map, required: true
  attr :search_query, :string, required: true
  attr :status_filter, :atom, required: true

  def product_list(assigns) do
    ~H"""
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
    """
  end

  attr :action_product, :any, required: true
  attr :action_type, :atom, required: true

  def confirm_action_modal(assigns) do
    ~H"""
    <div>
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
    </div>
    """
  end

  attr :editing_product, :any, required: true
  attr :form_data, :map, required: true
  attr :form_errors, :map, required: true
  attr :categories_list, :list, required: true
  attr :uploads, :any, required: true
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

  attr :status, :atom, required: true
  attr :current, :atom, required: true
  attr :label, :string, required: true

  def status_tab(assigns) do
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

  # ── Display helpers (moved with the markup that uses them) ──

  defp sorted_variants(product), do: Shared.sorted_variants(product)

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

  defp first_image_url(product) do
    case Map.get(product, :images) do
      [%{thumbnail_url: url} | _] when is_binary(url) and url != "" -> url
      [%{url: url} | _] when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end
end
