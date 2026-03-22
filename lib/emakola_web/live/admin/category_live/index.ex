defmodule EmakolaWeb.Admin.CategoryLive.Index do
  @moduledoc """
  Category management with tree view, modal-based add/edit, and delete confirmation.
  Optimized for mobile with collapsible tree structure.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

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
      parent_id =
        case params["parent_id"] do
          "" -> nil
          nil -> nil
          id -> id
        end

      description = params["description"] || ""

      attrs = %{
        name: name,
        description: description,
        parent_id: parent_id,
        store_id: socket.assigns.store_id,
        position: next_position(socket.assigns.all_categories, parent_id)
      }

      case socket.assigns.edit_category_id do
        nil ->
          case Emakola.Catalog.create_category(attrs) do
            {:ok, _category} ->
              {:noreply,
               socket
               |> assign(
                 form_name: "",
                 form_description: "",
                 form_parent_id: nil,
                 form_errors: %{}
               )
               |> load_category_tree()
               |> put_flash(:info, "Category created")}

            {:error, error} ->
              {:noreply, put_flash(socket, :error, format_error(error))}
          end

        id ->
          case Ash.get(Emakola.Catalog.Category, id) do
            {:ok, category} ->
              update_attrs = %{name: name, description: description, parent_id: parent_id}

              case category |> Ash.Changeset.for_update(:update, update_attrs) |> Ash.update() do
                {:ok, _updated} ->
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
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    case Ash.get(Emakola.Catalog.Category, id) do
      {:ok, category} ->
        case Ash.destroy(category) do
          :ok ->
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold font-headline tracking-tight">Categories</h1>
          <p class="text-sm text-on-surface-variant mt-1">
            Organize your product catalog
          </p>
        </div>
        <button
          phx-click={show_modal("category-modal")}
          phx-value-action="add"
          class="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg text-sm font-semibold
                 bg-emerald-600 text-white hover:bg-emerald-700 active:scale-95 transition-all
                 shadow-sm w-full sm:w-auto justify-center"
        >
          <.icon name="hero-plus" class="size-4" /> Add Category
        </button>
      </div>

      <%!-- Category Tree --%>
      <%= if @category_tree == [] do %>
        <div class="text-center py-16 bg-surface-container-lowest rounded-lg">
          <.icon name="hero-folder" class="size-12 mx-auto text-on-surface-variant/30 mb-3" />
          <p class="text-on-surface-variant font-medium">No categories yet</p>
          <p class="text-sm text-on-surface-variant/60 mt-1">
            Add categories to organize your products
          </p>
        </div>
      <% else %>
        <div class="bg-surface-container-lowest rounded-lg overflow-hidden divide-y divide-surface-container/50">
          <.category_row
            :for={node <- @category_tree}
            node={node}
            depth={0}
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
  attr :depth, :integer, required: true

  defp category_row(assigns) do
    ~H"""
    <div>
      <div
        class="flex items-center justify-between px-4 py-3 hover:bg-surface-container-high/30 transition-colors group"
        style={"padding-left: #{@depth * 24 + 16}px"}
      >
        <div class="flex items-center gap-3 min-w-0">
          <span class="text-xs font-mono text-on-surface-variant/50 w-6 text-center flex-shrink-0">
            {@node.category.position}
          </span>
          <.icon
            name={if @node.children != [], do: "hero-folder-open", else: "hero-folder"}
            class="size-4 text-on-surface-variant/60 flex-shrink-0"
          />
          <span class="text-sm font-medium truncate">{@node.category.name}</span>
          <span
            :if={@depth > 0}
            class="text-xs text-on-surface-variant/40 hidden sm:inline"
          >
            (sub-category)
          </span>
        </div>
        <div class="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity focus-within:opacity-100">
          <button
            phx-click={
              JS.push("open_edit_modal", value: %{id: @node.category.id})
              |> show_modal("category-modal")
            }
            class="text-xs text-emerald-600 hover:text-emerald-700 font-medium px-2 py-1 rounded hover:bg-emerald-50"
          >
            Edit
          </button>
          <button
            phx-click={
              JS.push("open_delete_modal", value: %{id: @node.category.id})
              |> show_modal("delete-category-modal")
            }
            class="text-xs text-red-600 hover:text-red-700 font-medium px-2 py-1 rounded hover:bg-red-50"
          >
            Delete
          </button>
        </div>
      </div>

      <%!-- Children --%>
      <.category_row
        :for={child <- @node.children}
        node={child}
        depth={@depth + 1}
      />
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
