defmodule EmakolaWeb.Admin.CategoryLive.Index do
  @moduledoc """
  Category management with tree view, modal-based add/edit, and delete confirmation.
  Optimized for mobile with collapsible tree structure.
  """
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Categories",
        active_nav: :categories,
        store_id: store_id,
        category_tree: [],
        edit_category_id: nil,
        form_name: "",
        form_description: "",
        form_parent_id: nil,
        form_errors: %{},
        all_categories: [],
        delete_category: nil
      )
      |> load_category_tree()

    {:ok, socket}
  end

  @impl true
  def handle_event("open_add_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(
       edit_category_id: nil,
       form_name: "",
       form_description: "",
       form_parent_id: nil,
       form_errors: %{}
     )
     |> push_event("js-exec", %{to: "#category-modal", attr: "phx-mounted"})}
  end

  @impl true
  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    category = Enum.find(socket.assigns.all_categories, &(&1.id == id))

    if category do
      {:noreply,
       assign(socket,
         edit_category_id: id,
         form_name: category.name,
         form_description: Map.get(category, :description, "") || "",
         form_parent_id: category.parent_id,
         form_errors: %{}
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_delete_modal", %{"id" => id}, socket) do
    category = Enum.find(socket.assigns.all_categories, &(&1.id == id))
    {:noreply, assign(socket, delete_category: category)}
  end

  @impl true
  def handle_event("validate_category", %{"name" => name}, socket) do
    errors =
      if String.trim(name) == "",
        do: %{name: "Name is required"},
        else: %{}

    {:noreply, assign(socket, form_name: name, form_errors: errors)}
  end

  @impl true
  def handle_event("save_category", params, socket) do
    name = String.trim(params["name"] || "")

    if name == "" do
      {:noreply, assign(socket, form_errors: %{name: "Name is required"})}
    else
      attrs = build_category_attrs(params, name, socket)

      case socket.assigns.edit_category_id do
        nil -> do_create_category(socket, attrs)
        id -> do_update_category(socket, id, attrs)
      end
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    case Emakola.Catalog.get_category(id) do
      {:ok, category} ->
        case Emakola.Catalog.destroy_category(category, authorize?: false) do
          :ok ->
            Emakola.Catalog.CachedCatalog.invalidate_store(socket.assigns.store_id)

            {:noreply,
             socket
             |> assign(delete_category: nil)
             |> load_category_tree()
             |> put_flash(:info, "Category deleted")}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, format_error(error))}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Category not found")}
    end
  end

  defp build_category_attrs(params, name, socket) do
    parent_id = if params["parent_id"] in ["", nil], do: nil, else: params["parent_id"]

    %{
      name: name,
      description: params["description"] || "",
      parent_id: parent_id,
      store_id: socket.assigns.store_id,
      position: next_position(socket.assigns.all_categories, parent_id)
    }
  end

  defp do_create_category(socket, attrs) do
    case Emakola.Catalog.create_category(attrs, authorize?: false) do
      {:ok, _category} ->
        Emakola.Catalog.CachedCatalog.invalidate_store(socket.assigns.store_id)

        {:noreply,
         socket
         |> assign(form_name: "", form_description: "", form_parent_id: nil, form_errors: %{})
         |> load_category_tree()
         |> put_flash(:info, "Category created")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, format_error(error))}
    end
  end

  defp do_update_category(socket, id, attrs) do
    case Emakola.Catalog.get_category(id) do
      {:ok, category} ->
        update_attrs = Map.take(attrs, [:name, :description, :parent_id])

        case Emakola.Catalog.update_category(category, update_attrs, authorize?: false) do
          {:ok, _updated} ->
            Emakola.Catalog.CachedCatalog.invalidate_store(socket.assigns.store_id)

            {:noreply,
             socket
             |> assign(
               edit_category_id: nil,
               form_name: "",
               form_description: "",
               form_parent_id: nil,
               form_errors: %{}
             )
             |> load_category_tree()
             |> put_flash(:info, "Category updated")}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, format_error(error))}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Category not found")}
    end
  end

  @category_icons %{
    "fashion" => "checkroom",
    "clothing" => "checkroom",
    "beauty" => "spa",
    "food" => "restaurant",
    "electronics" => "devices",
    "home" => "home",
    "accessories" => "watch",
    "shoes" => "steps",
    "bags" => "shopping_bag",
    "jewelry" => "diamond",
    "health" => "favorite",
    "sports" => "sports_soccer",
    "kids" => "child_care",
    "books" => "menu_book"
  }

  @category_colors [
    {"bg-emerald-500", "bg-emerald-50", "text-emerald-700"},
    {"bg-blue-500", "bg-blue-50", "text-blue-700"},
    {"bg-amber-500", "bg-amber-50", "text-amber-700"},
    {"bg-purple-500", "bg-purple-50", "text-purple-700"},
    {"bg-rose-500", "bg-rose-50", "text-rose-700"},
    {"bg-teal-500", "bg-teal-50", "text-teal-700"},
    {"bg-orange-500", "bg-orange-50", "text-orange-700"},
    {"bg-indigo-500", "bg-indigo-50", "text-indigo-700"}
  ]

  defp category_icon(name) do
    key = name |> String.downcase()

    Enum.find_value(@category_icons, "category", fn {k, v} ->
      if String.contains?(key, k), do: v
    end)
  end

  defp category_color(index) do
    Enum.at(@category_colors, rem(index, length(@category_colors)))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <%!-- Header --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900">Categories</h1>
          <p class="text-sm text-slate-500 mt-1">
            Organize your products into groups
          </p>
        </div>
        <button
          phx-click={show_modal("category-modal")}
          phx-value-action="add"
          class="inline-flex items-center gap-2 px-5 py-3 rounded-xl text-sm font-semibold
                 bg-emerald-600 text-white hover:bg-emerald-700 active:scale-95 transition-all
                 shadow-sm w-full sm:w-auto justify-center"
        >
          <span class="material-symbols-outlined text-lg">add</span> Add Category
        </button>
      </div>

      <%!-- Stats Bar --%>
      <div class="flex items-center gap-6 px-1">
        <div class="flex items-center gap-2">
          <div class="w-8 h-8 rounded-lg bg-emerald-100 flex items-center justify-center">
            <span class="material-symbols-outlined text-sm text-emerald-600">folder</span>
          </div>
          <div>
            <p class="text-lg font-bold text-slate-900">{length(@all_categories)}</p>
            <p class="text-[11px] text-slate-400 -mt-0.5">Total</p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-8 h-8 rounded-lg bg-blue-100 flex items-center justify-center">
            <span class="material-symbols-outlined text-sm text-blue-600">account_tree</span>
          </div>
          <div>
            <p class="text-lg font-bold text-slate-900">{length(@category_tree)}</p>
            <p class="text-[11px] text-slate-400 -mt-0.5">Main</p>
          </div>
        </div>
      </div>

      <%!-- Category Grid --%>
      <%= if @category_tree == [] do %>
        <div class="text-center py-20 bg-white rounded-2xl shadow-sm">
          <div class="w-16 h-16 rounded-2xl bg-slate-100 flex items-center justify-center mx-auto mb-4">
            <span class="material-symbols-outlined text-3xl text-slate-300">folder_open</span>
          </div>
          <p class="text-slate-700 font-semibold text-lg">No categories yet</p>
          <p class="text-sm text-slate-400 mt-1 mb-6">
            Add categories to organize your products
          </p>
          <button
            phx-click={show_modal("category-modal")}
            class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold
                   bg-emerald-600 text-white hover:bg-emerald-700 transition-all"
          >
            <span class="material-symbols-outlined text-lg">add</span> Create First Category
          </button>
        </div>
      <% else %>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <.category_card
            :for={{node, index} <- Enum.with_index(@category_tree)}
            node={node}
            index={index}
          />
        </div>
      <% end %>

      <%!-- Add/Edit Category Modal --%>
      <.modal
        id="category-modal"
        title={if @edit_category_id, do: "Edit Category", else: "Add Category"}
        size={:md}
      >
        <form phx-submit="save_category" phx-change="validate_category" class="space-y-4">
          <div>
            <label for="category-name" class="block text-sm font-medium text-slate-700 mb-1.5">
              Name <span class="text-red-500">*</span>
            </label>
            <input
              type="text"
              id="category-name"
              name="name"
              value={@form_name}
              placeholder="Category name"
              class={[
                "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500",
                if(@form_errors[:name], do: "border-red-300 bg-red-50", else: "border-slate-300")
              ]}
              autocomplete="off"
              autofocus
            />
            <p :if={@form_errors[:name]} class="mt-1 text-xs text-red-600">{@form_errors[:name]}</p>
          </div>

          <div>
            <label for="category-description" class="block text-sm font-medium text-slate-700 mb-1.5">
              Description
            </label>
            <textarea
              id="category-description"
              name="description"
              rows="3"
              placeholder="Optional description"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                     focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 resize-none"
            >{@form_description}</textarea>
          </div>

          <div>
            <label for="category-parent" class="block text-sm font-medium text-slate-700 mb-1.5">
              Parent Category
            </label>
            <select
              id="category-parent"
              name="parent_id"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                     focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            >
              <option value="">No parent (root)</option>
              <option
                :for={cat <- Enum.reject(@all_categories, &(&1.id == @edit_category_id))}
                value={cat.id}
                selected={to_string(@form_parent_id) == to_string(cat.id)}
              >
                {cat.name}
              </option>
            </select>
          </div>

          <div class="flex items-center justify-end gap-3 pt-2">
            <button
              type="button"
              phx-click={hide_modal("category-modal")}
              class="px-4 py-2.5 text-sm font-medium text-slate-700 bg-white border border-slate-300
                     rounded-xl hover:bg-slate-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="px-4 py-2.5 text-sm font-semibold bg-emerald-600 text-white
                     rounded-xl hover:bg-emerald-700 transition-colors"
            >
              {if @edit_category_id, do: "Update", else: "Create"}
            </button>
          </div>
        </form>
      </.modal>

      <%!-- Delete Confirmation Modal --%>
      <.confirm_modal
        :if={@delete_category}
        id="delete-category-modal"
        title="Delete Category"
        message={"Are you sure you want to delete \"#{if @delete_category, do: @delete_category.name, else: ""}\"? This action cannot be undone."}
        confirm_text="Delete"
        confirm_class="bg-red-600 hover:bg-red-700 text-white"
        on_confirm="delete_category"
        value={if @delete_category, do: @delete_category.id}
        icon="warning"
        icon_class="text-red-500"
      />
    </div>
    """
  end

  # ── Components ──

  attr :node, :map, required: true
  attr :index, :integer, required: true

  defp category_card(assigns) do
    {icon_bg, card_bg, text_color} = category_color(assigns.index)
    icon = category_icon(assigns.node.category.name)
    child_count = length(assigns.node.children)

    assigns =
      assigns
      |> assign(:icon_bg, icon_bg)
      |> assign(:card_bg, card_bg)
      |> assign(:text_color, text_color)
      |> assign(:icon, icon)
      |> assign(:child_count, child_count)

    ~H"""
    <div class="group bg-white rounded-2xl shadow-sm hover:shadow-md transition-all p-5">
      <%!-- Top: Icon + Actions --%>
      <div class="flex items-start justify-between mb-4">
        <div class={"w-12 h-12 rounded-xl #{@icon_bg} flex items-center justify-center"}>
          <span class="material-symbols-outlined text-2xl text-white">{@icon}</span>
        </div>
        <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            phx-click={
              JS.push("open_edit_modal", value: %{id: @node.category.id})
              |> show_modal("category-modal")
            }
            class="w-8 h-8 rounded-lg hover:bg-slate-100 flex items-center justify-center transition-colors"
            title="Edit"
          >
            <span class="material-symbols-outlined text-base text-slate-400">edit</span>
          </button>
          <button
            phx-click={
              JS.push("open_delete_modal", value: %{id: @node.category.id})
              |> show_modal("delete-category-modal")
            }
            class="w-8 h-8 rounded-lg hover:bg-red-50 flex items-center justify-center transition-colors"
            title="Delete"
          >
            <span class="material-symbols-outlined text-base text-slate-400 hover:text-red-500">
              delete
            </span>
          </button>
        </div>
      </div>

      <%!-- Name --%>
      <h3 class="text-base font-bold text-slate-900 mb-1">{@node.category.name}</h3>
      <p
        :if={@node.category.description && @node.category.description != ""}
        class="text-xs text-slate-400 line-clamp-2 mb-3"
      >
        {@node.category.description}
      </p>

      <%!-- Sub-categories --%>
      <%= if @child_count > 0 do %>
        <div class="mt-3 pt-3 border-t border-slate-100">
          <p class="text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-2">
            {@child_count} sub-categories
          </p>
          <div class="flex flex-wrap gap-1.5">
            <span
              :for={child <- @node.children}
              class={"inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-medium #{@card_bg} #{@text_color}"}
            >
              <span class="material-symbols-outlined text-xs">
                {category_icon(child.category.name)}
              </span>
              {child.category.name}
            </span>
          </div>
        </div>
      <% else %>
        <div class="mt-3 pt-3 border-t border-slate-100">
          <p class="text-[11px] text-slate-300">No sub-categories</p>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Data Loading ──

  defp load_category_tree(socket) do
    store_id = socket.assigns.store_id

    all_categories =
      try do
        Emakola.Catalog.list_categories_by_store!(store_id)
      rescue
        _ -> []
      end

    tree = build_tree(all_categories, nil)

    assign(socket, category_tree: tree, all_categories: all_categories)
  end

  defp build_tree(categories, parent_id) do
    categories
    |> Enum.filter(&(&1.parent_id == parent_id))
    |> Enum.sort_by(& &1.position)
    |> Enum.map(fn cat ->
      %{
        category: cat,
        children: build_tree(categories, cat.id)
      }
    end)
  end

  defp next_position(categories, parent_id) do
    categories
    |> Enum.filter(&(&1.parent_id == parent_id))
    |> Enum.map(& &1.position)
    |> Enum.max(fn -> -1 end)
    |> Kernel.+(1)
  end

  # ── Helpers ──

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
      other -> inspect(other)
    end)
    |> Enum.join(", ")
  end

  defp format_error(error), do: inspect(error)
end
