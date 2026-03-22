defmodule EmakolaWeb.Admin.CategoryLive.Index do
  @moduledoc """
  Category management with tree view, inline add/edit, and position display.
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
        show_add_form: false,
        edit_category_id: nil,
        form_name: "",
        form_parent_id: nil,
        form_errors: %{},
        all_categories: []
      )
      |> load_category_tree()

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_add_form", _params, socket) do
    {:noreply,
     assign(socket,
       show_add_form: !socket.assigns.show_add_form,
       edit_category_id: nil,
       form_name: "",
       form_parent_id: nil,
       form_errors: %{}
     )}
  end

  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    category = Enum.find(socket.assigns.all_categories, &(&1.id == id))

    if category do
      {:noreply,
       assign(socket,
         edit_category_id: id,
         show_add_form: false,
         form_name: category.name,
         form_parent_id: category.parent_id,
         form_errors: %{}
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     assign(socket,
       edit_category_id: nil,
       show_add_form: false,
       form_name: "",
       form_parent_id: nil,
       form_errors: %{}
     )}
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
  def handle_event("save_category", %{"name" => name, "parent_id" => parent_id}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, assign(socket, form_errors: %{name: "Name is required"})}
    else
      parent_id = if parent_id == "", do: nil, else: parent_id

      attrs = %{
        name: name,
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
                 show_add_form: false,
                 form_name: "",
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
              update_attrs = %{name: name, parent_id: parent_id}

              case category |> Ash.Changeset.for_update(:update, update_attrs) |> Ash.update() do
                {:ok, _updated} ->
                  {:noreply,
                   socket
                   |> assign(
                     edit_category_id: nil,
                     form_name: "",
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
  def handle_event("update_parent", %{"parent_id" => parent_id}, socket) do
    parent_id = if parent_id == "", do: nil, else: parent_id
    {:noreply, assign(socket, form_parent_id: parent_id)}
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
          phx-click="toggle_add_form"
          class="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg text-sm font-semibold
                 bg-emerald-600 text-white hover:bg-emerald-700 active:scale-95 transition-all
                 shadow-sm w-full sm:w-auto justify-center"
        >
          <.icon name={if @show_add_form, do: "hero-x-mark", else: "hero-plus"} class="size-4" />
          {if @show_add_form, do: "Cancel", else: "Add Category"}
        </button>
      </div>

      <%!-- Inline Add Form --%>
      <div
        :if={@show_add_form}
        class="bg-emerald-50 border border-emerald-200 rounded-lg p-4 space-y-3"
      >
        <h3 class="text-sm font-semibold text-emerald-800">New Category</h3>
        <.category_form
          name={@form_name}
          parent_id={@form_parent_id}
          categories={@all_categories}
          errors={@form_errors}
          exclude_id={nil}
        />
      </div>

      <%!-- Category Tree --%>
      <%= if @category_tree == [] and not @show_add_form do %>
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
            edit_id={@edit_category_id}
            form_name={@form_name}
            form_parent_id={@form_parent_id}
            form_errors={@form_errors}
            all_categories={@all_categories}
          />
        </div>
      <% end %>
    </div>
    """
  end

  # ── Components ──

  attr :name, :string, required: true
  attr :parent_id, :any, required: true
  attr :categories, :list, required: true
  attr :errors, :map, required: true
  attr :exclude_id, :any, default: nil

  defp category_form(assigns) do
    ~H"""
    <form
      phx-submit="save_category"
      phx-change="validate_category"
      class="flex flex-col sm:flex-row gap-3"
    >
      <div class="flex-1">
        <input
          type="text"
          name="name"
          value={@name}
          placeholder="Category name"
          class={[
            "w-full px-3 py-2 text-sm rounded-lg border focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500",
            if(@errors[:name], do: "border-red-300", else: "border-surface-container-highest")
          ]}
          autocomplete="off"
        />
        <p :if={@errors[:name]} class="mt-1 text-xs text-red-600">{@errors[:name]}</p>
      </div>
      <div class="sm:w-48">
        <select
          name="parent_id"
          phx-change="update_parent"
          class="w-full px-3 py-2 text-sm rounded-lg border border-surface-container-highest
                 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
        >
          <option value="">No parent (root)</option>
          <option
            :for={cat <- Enum.reject(@categories, &(&1.id == @exclude_id))}
            value={cat.id}
            selected={to_string(@parent_id) == to_string(cat.id)}
          >
            {cat.name}
          </option>
        </select>
      </div>
      <button
        type="submit"
        class="px-4 py-2 rounded-lg text-sm font-semibold bg-emerald-600 text-white
               hover:bg-emerald-700 active:scale-95 transition-all"
      >
        Save
      </button>
    </form>
    """
  end

  attr :node, :map, required: true
  attr :depth, :integer, required: true
  attr :edit_id, :any, required: true
  attr :form_name, :string, required: true
  attr :form_parent_id, :any, required: true
  attr :form_errors, :map, required: true
  attr :all_categories, :list, required: true

  defp category_row(assigns) do
    ~H"""
    <div>
      <%= if @edit_id == @node.category.id do %>
        <%!-- Inline Edit Form --%>
        <div class="px-4 py-3 bg-amber-50" style={"padding-left: #{@depth * 24 + 16}px"}>
          <.category_form
            name={@form_name}
            parent_id={@form_parent_id}
            categories={@all_categories}
            errors={@form_errors}
            exclude_id={@node.category.id}
          />
          <button
            phx-click="cancel_edit"
            class="mt-2 text-xs text-on-surface-variant hover:text-on-surface"
          >
            Cancel
          </button>
        </div>
      <% else %>
        <%!-- Category Display Row --%>
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
          <button
            phx-click="start_edit"
            phx-value-id={@node.category.id}
            class="text-xs text-emerald-600 hover:text-emerald-700 font-medium opacity-0 group-hover:opacity-100
                   transition-opacity focus:opacity-100"
          >
            Edit
          </button>
        </div>
      <% end %>

      <%!-- Children --%>
      <.category_row
        :for={child <- @node.children}
        node={child}
        depth={@depth + 1}
        edit_id={@edit_id}
        form_name={@form_name}
        form_parent_id={@form_parent_id}
        form_errors={@form_errors}
        all_categories={@all_categories}
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
