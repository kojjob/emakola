defmodule EmakolaWeb.Admin.InventoryLive do
  @moduledoc """
  Inventory management dashboard for the merchant admin.

  Displays stock overview stats (total SKUs, in stock, low stock, out of stock),
  a filterable table of all variants with inline stock adjustment controls, and
  search by product title or SKU.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.InventoryComponents

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Inventory",
        active_nav: :inventory,
        store_id: store_id,
        status_filter: :all,
        search_query: "",
        variants: [],
        stats: %{total: 0, in_stock: 0, low_stock: 0, out_of_stock: 0},
        editing_variant_id: nil,
        edit_stock_value: "",
        suppliers: [],
        dropship_variant: nil
      )
      |> load_suppliers()
      |> load_variants()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "in_stock" -> :in_stock
        "low_stock" -> :low_stock
        "out_of_stock" -> :out_of_stock
        _ -> :all
      end

    socket =
      socket
      |> assign(status_filter: status_atom)
      |> apply_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_inventory", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(search_query: query)
      |> apply_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_event("adjust_stock", %{"id" => variant_id, "delta" => delta_str}, socket) do
    delta = String.to_integer(delta_str)

    case find_variant(socket.assigns.all_variants, variant_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Variant not found")}

      variant ->
        case Emakola.Catalog.adjust_variant_stock(variant, %{delta: delta}, authorize?: false) do
          {:ok, _updated} ->
            {:noreply, load_variants(socket)}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Could not adjust stock")}
        end
    end
  end

  @impl true
  def handle_event("start_edit", %{"id" => variant_id}, socket) do
    variant = find_variant(socket.assigns.all_variants, variant_id)
    current_stock = if variant, do: Integer.to_string(variant.stock_quantity), else: ""

    {:noreply,
     assign(socket,
       editing_variant_id: variant_id,
       edit_stock_value: current_stock
     )}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_variant_id: nil, edit_stock_value: "")}
  end

  @impl true
  def handle_event("save_stock", %{"variant_id" => variant_id, "stock" => stock_str}, socket) do
    case Integer.parse(stock_str) do
      {new_stock, _} when new_stock >= 0 ->
        variant = find_variant(socket.assigns.all_variants, variant_id)

        if variant do
          delta = new_stock - variant.stock_quantity

          case Emakola.Catalog.adjust_variant_stock(variant, %{delta: delta}, authorize?: false) do
            {:ok, _updated} ->
              socket =
                socket
                |> assign(editing_variant_id: nil, edit_stock_value: "")
                |> load_variants()

              {:noreply, socket}

            {:error, _error} ->
              {:noreply, put_flash(socket, :error, "Could not update stock")}
          end
        else
          {:noreply, put_flash(socket, :error, "Variant not found")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Please enter a valid non-negative number")}
    end
  end

  @impl true
  def handle_event("edit_dropship", %{"id" => variant_id}, socket) do
    variant = find_variant(socket.assigns.all_variants, variant_id)
    {:noreply, assign(socket, dropship_variant: variant)}
  end

  @impl true
  def handle_event("cancel_dropship", _params, socket) do
    {:noreply, assign(socket, dropship_variant: nil)}
  end

  @impl true
  def handle_event("save_dropship", %{"variant" => params}, socket) do
    variant = socket.assigns.dropship_variant
    supplier_id = blank_to_nil(params["supplier_id"])

    cond do
      is_nil(variant) ->
        {:noreply, put_flash(socket, :error, "Variant not found")}

      not valid_supplier?(socket.assigns.suppliers, supplier_id) ->
        {:noreply, put_flash(socket, :error, "Invalid supplier")}

      true ->
        save_dropship_variant(socket, variant, supplier_id, params)
    end
  end

  defp save_dropship_variant(socket, variant, supplier_id, params) do
    attrs = %{
      supplier_id: supplier_id,
      cost_price: parse_cost(params["cost_price"]),
      available: params["available"] == "true"
    }

    case Emakola.Catalog.update_variant(variant, attrs, authorize?: false) do
      {:ok, _updated} ->
        {:noreply,
         socket
         |> assign(dropship_variant: nil)
         |> load_variants()
         |> put_flash(:info, "Variant updated")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not update variant")}
    end
  end

  defp valid_supplier?(_suppliers, nil), do: true
  defp valid_supplier?(suppliers, supplier_id), do: Enum.any?(suppliers, &(&1.id == supplier_id))

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header title="Inventory" subtitle="Monitor stock levels and manage inventory" />

      <%!-- Stat Cards --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <.stat_card label="Total SKUs" value={Integer.to_string(@stats.total)} color="slate">
          <:icon>
            <svg
              class="w-5 h-5 text-slate-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"
              />
            </svg>
          </:icon>
        </.stat_card>
        <.stat_card label="In Stock" value={Integer.to_string(@stats.in_stock)} color="emerald">
          <:icon>
            <svg
              class="w-5 h-5 text-emerald-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </:icon>
        </.stat_card>
        <.stat_card label="Low Stock" value={Integer.to_string(@stats.low_stock)} color="amber">
          <:icon>
            <svg
              class="w-5 h-5 text-amber-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
              />
            </svg>
          </:icon>
        </.stat_card>
        <.stat_card
          label="Out of Stock"
          value={Integer.to_string(@stats.out_of_stock)}
          color="red"
        >
          <:icon>
            <svg
              class="w-5 h-5 text-red-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
              />
            </svg>
          </:icon>
        </.stat_card>
      </div>

      <%!-- Filter Bar --%>
      <div class="flex flex-col sm:flex-row items-start sm:items-center gap-3">
        <div class="flex gap-1 bg-slate-100 rounded-control p-1">
          <.filter_button
            :for={status <- [:all, :in_stock, :low_stock, :out_of_stock]}
            status={status}
            current={@status_filter}
          />
        </div>
        <div class="flex-1 w-full sm:w-auto">
          <form phx-change="search_inventory" class="relative">
            <svg
              class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
              />
            </svg>
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search by product or SKU..."
              phx-debounce="300"
              class="w-full pl-9 pr-4 py-2 text-sm border border-slate-200 rounded-control bg-white focus:outline-none focus:ring-2 focus:ring-slate-900/10 focus:border-slate-300"
            />
          </form>
        </div>
      </div>

      <%!-- Stock Table --%>
      <%= if @variants == [] do %>
        <.empty_state
          icon="hero-archive-box"
          title="No variants found"
          description={
            if @status_filter != :all or @search_query != "",
              do: "Try adjusting your filters or search query",
              else: "Add products with variants to start tracking inventory"
          }
        />
      <% else %>
        <%!-- Desktop Table --%>
        <.admin_card padding={:none} class="hidden md:block overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-200 bg-slate-50/50">
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Product
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Variant (SKU)
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Current Stock
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr
                  :for={variant <- @variants}
                  class="hover:bg-slate-50 transition-colors"
                >
                  <td class="px-4 py-3.5 text-slate-700 font-medium">
                    {product_title(variant)}
                    <span
                      :if={variant.supplier_id}
                      class="ml-2 inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold bg-violet-50 text-violet-700"
                      title={dropship_label(variant)}
                    >
                      Dropshipped
                    </span>
                  </td>
                  <td class="px-4 py-3.5 font-mono text-xs text-slate-500">
                    {variant.sku || "--"}
                  </td>
                  <td class="px-4 py-3.5">
                    <%= if @editing_variant_id == variant.id do %>
                      <form
                        phx-submit="save_stock"
                        phx-value-id={variant.id}
                        class="flex items-center gap-2"
                      >
                        <input type="hidden" name="variant_id" value={variant.id} />
                        <input
                          type="number"
                          name="stock"
                          value={@edit_stock_value}
                          min="0"
                          class="w-20 px-2 py-1 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-slate-900/10"
                          autofocus
                        />
                        <button
                          type="submit"
                          class="text-primary hover:text-primary-hover"
                          title="Save"
                        >
                          <svg
                            class="w-4 h-4"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="2"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M4.5 12.75l6 6 9-13.5"
                            />
                          </svg>
                        </button>
                        <button
                          type="button"
                          phx-click="cancel_edit"
                          class="text-slate-400 hover:text-slate-600"
                          title="Cancel"
                        >
                          <svg
                            class="w-4 h-4"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="2"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M6 18L18 6M6 6l12 12"
                            />
                          </svg>
                        </button>
                      </form>
                    <% else %>
                      <button
                        phx-click="start_edit"
                        phx-value-id={variant.id}
                        class="font-mono text-sm font-semibold text-slate-800 hover:text-slate-600 cursor-pointer"
                        title="Click to edit stock"
                      >
                        {variant.stock_quantity}
                      </button>
                    <% end %>
                  </td>
                  <td class="px-4 py-3.5">
                    <.stock_status_badge quantity={variant.stock_quantity} />
                  </td>
                  <td class="px-4 py-3.5">
                    <div class="flex items-center gap-1">
                      <button
                        phx-click="adjust_stock"
                        phx-value-id={variant.id}
                        phx-value-delta="-1"
                        class="inline-flex items-center justify-center w-7 h-7 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100 hover:text-slate-700 transition-colors disabled:opacity-50"
                        disabled={variant.stock_quantity == 0}
                        title="Decrease by 1"
                      >
                        <svg
                          class="w-3.5 h-3.5"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="2"
                          viewBox="0 0 24 24"
                        >
                          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 12h-15" />
                        </svg>
                      </button>
                      <button
                        phx-click="adjust_stock"
                        phx-value-id={variant.id}
                        phx-value-delta="1"
                        class="inline-flex items-center justify-center w-7 h-7 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100 hover:text-slate-700 transition-colors"
                        title="Increase by 1"
                      >
                        <svg
                          class="w-3.5 h-3.5"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="2"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M12 4.5v15m7.5-7.5h-15"
                          />
                        </svg>
                      </button>
                      <button
                        phx-click={
                          JS.push("edit_dropship", value: %{id: variant.id})
                          |> show_modal("dropship-modal")
                        }
                        class="inline-flex items-center justify-center w-7 h-7 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100 hover:text-slate-700 transition-colors"
                        title="Edit supplier / cost / availability"
                      >
                        <.icon name="hero-truck" class="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.admin_card>

        <%!-- Mobile Cards --%>
        <div class="md:hidden space-y-3">
          <.admin_card :for={variant <- @variants} padding={:none} class="p-4">
            <div class="flex items-start justify-between gap-3 mb-3">
              <div>
                <p class="text-sm font-medium text-slate-800">
                  {product_title(variant)}
                  <span
                    :if={variant.supplier_id}
                    class="ml-1 inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold bg-violet-50 text-violet-700"
                  >
                    Dropshipped
                  </span>
                </p>
                <p class="font-mono text-xs text-slate-400 mt-0.5">{variant.sku || "--"}</p>
              </div>
              <.stock_status_badge quantity={variant.stock_quantity} />
            </div>
            <div class="flex items-center justify-between">
              <p class="text-sm text-slate-600">
                <span class="text-slate-400">Stock:</span>
                <span class="font-mono font-semibold">{variant.stock_quantity}</span>
              </p>
              <div class="flex items-center gap-1">
                <button
                  phx-click="adjust_stock"
                  phx-value-id={variant.id}
                  phx-value-delta="-1"
                  class="inline-flex items-center justify-center w-8 h-8 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100"
                  disabled={variant.stock_quantity == 0}
                >
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 12h-15" />
                  </svg>
                </button>
                <button
                  phx-click="adjust_stock"
                  phx-value-id={variant.id}
                  phx-value-delta="1"
                  class="inline-flex items-center justify-center w-8 h-8 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100"
                >
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M12 4.5v15m7.5-7.5h-15"
                    />
                  </svg>
                </button>
                <button
                  phx-click={
                    JS.push("edit_dropship", value: %{id: variant.id})
                    |> show_modal("dropship-modal")
                  }
                  class="inline-flex items-center justify-center w-8 h-8 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100"
                  title="Edit supplier / cost / availability"
                >
                  <.icon name="hero-truck" class="w-4 h-4" />
                </button>
              </div>
            </div>
          </.admin_card>
        </div>
      <% end %>

      <%!-- Dropship editor modal --%>
      <.modal id="dropship-modal" title="Supplier & Dropshipping" size={:md}>
        <form :if={@dropship_variant} id="dropship-form" phx-submit="save_dropship" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Supplier</label>
            <select
              name="variant[supplier_id]"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            >
              <option value="" selected={is_nil(@dropship_variant.supplier_id)}>
                — Own stock —
              </option>
              <option
                :for={supplier <- @suppliers}
                value={supplier.id}
                selected={@dropship_variant.supplier_id == supplier.id}
              >
                {supplier.name}
              </option>
            </select>
            <p class="text-xs text-slate-400 mt-1">
              Assigning a supplier marks this variant as dropshipped (inventory no longer tracked).
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">
              Cost Price (GH&#8373;)
            </label>
            <input
              type="number"
              name="variant[cost_price]"
              value={cost_in_cedis(@dropship_variant.cost_price)}
              step="0.01"
              min="0"
              placeholder="0.00"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
          </div>
          <label class="flex items-center gap-2 text-sm text-slate-700">
            <input type="hidden" name="variant[available]" value="false" />
            <input
              type="checkbox"
              name="variant[available]"
              value="true"
              checked={@dropship_variant.available}
              class="rounded border-slate-300 text-primary focus:ring-emerald-500"
            /> Available for sale
          </label>
          <div class="flex items-center justify-end gap-3 pt-2">
            <.admin_button variant={:secondary} phx-click={hide_modal("dropship-modal")}>
              Cancel
            </.admin_button>
            <.admin_button type="submit" phx-click={hide_modal("dropship-modal")}>
              Save
            </.admin_button>
          </div>
        </form>
      </.modal>
    </div>
    """
  end

  defp dropship_label(%{supplier: %{name: name}}) when is_binary(name), do: "Supplier: #{name}"
  defp dropship_label(_), do: "Dropshipped"

  # ── Components ──

  attr :status, :atom, required: true
  attr :current, :atom, required: true

  defp filter_button(assigns) do
    ~H"""
    <button
      phx-click="filter_status"
      phx-value-status={@status}
      class={[
        "px-3 py-1.5 text-sm font-medium rounded-lg transition-colors whitespace-nowrap",
        if(@status == @current,
          do: "bg-white text-slate-900 shadow-sm",
          else: "text-slate-500 hover:text-slate-700"
        )
      ]}
    >
      {filter_label(@status)}
    </button>
    """
  end

  # ── Data Loading ──

  defp load_variants(socket) do
    store_id = socket.assigns.store_id
    all_variants = fetch_variants(store_id)
    stats = compute_stats(store_id)

    socket
    |> assign(all_variants: all_variants, stats: stats)
    |> apply_filters()
  end

  defp apply_filters(socket) do
    %{all_variants: all_variants, status_filter: status, search_query: query} = socket.assigns

    filtered =
      all_variants
      |> filter_by_status(status)
      |> filter_by_search(query)

    assign(socket, variants: filtered)
  end

  defp fetch_variants(nil), do: []

  defp fetch_variants(store_id) do
    try do
      Emakola.Catalog.list_variants_admin!(store_id, query: [limit: 200], authorize?: false)
    rescue
      _ -> []
    end
  end

  defp filter_by_status(variants, :all), do: variants

  defp filter_by_status(variants, :in_stock),
    do: Enum.filter(variants, &(&1.stock_quantity >= 10))

  defp filter_by_status(variants, :low_stock),
    do: Enum.filter(variants, &(&1.stock_quantity >= 1 and &1.stock_quantity < 10))

  defp filter_by_status(variants, :out_of_stock),
    do: Enum.filter(variants, &(&1.stock_quantity == 0))

  defp filter_by_search(variants, ""), do: variants
  defp filter_by_search(variants, nil), do: variants

  defp filter_by_search(variants, query) do
    downcased = String.downcase(query)

    Enum.filter(variants, fn variant ->
      product_name = product_title(variant) |> String.downcase()
      sku = (variant.sku || "") |> String.downcase()
      String.contains?(product_name, downcased) or String.contains?(sku, downcased)
    end)
  end

  defp compute_stats(nil) do
    %{total: 0, in_stock: 0, low_stock: 0, out_of_stock: 0}
  end

  defp compute_stats(store_id) do
    %{
      total: count_stock(store_id, nil, nil),
      in_stock: count_stock(store_id, 10, nil),
      low_stock: count_stock(store_id, 1, 9),
      out_of_stock: count_stock(store_id, nil, 0)
    }
  end

  defp count_stock(store_id, min, max) do
    Emakola.Catalog.Variant
    |> Ash.Query.for_read(:by_stock_range, %{store_id: store_id, min: min, max: max})
    |> Ash.count!(authorize?: false)
  end

  # ── Helpers ──

  defp load_suppliers(socket) do
    case socket.assigns.store_id do
      nil ->
        assign(socket, suppliers: [])

      store_id ->
        suppliers =
          Emakola.Suppliers.list_active_suppliers_by_store!(store_id, authorize?: false)

        assign(socket, suppliers: suppliers)
    end
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp parse_cost(value) when is_binary(value) do
    case value |> String.trim() |> Decimal.parse() do
      {%Decimal{} = amount, ""} ->
        amount
        |> Decimal.mult(100)
        |> Decimal.round(0, :down)
        |> Decimal.to_integer()

      _ ->
        nil
    end
  end

  defp parse_cost(_), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp blank_to_nil(_), do: nil

  defp cost_in_cedis(nil), do: ""

  defp cost_in_cedis(pesewas) when is_integer(pesewas),
    do: :erlang.float_to_binary(pesewas / 100, decimals: 2)

  defp product_title(%{product: %{title: title}}) when is_binary(title), do: title
  defp product_title(_), do: "Unknown Product"

  defp filter_label(:all), do: "All"
  defp filter_label(:in_stock), do: "In Stock"
  defp filter_label(:low_stock), do: "Low Stock"
  defp filter_label(:out_of_stock), do: "Out of Stock"

  defp find_variant(variants, id) do
    Enum.find(variants, &(&1.id == id))
  end
end
