defmodule EmakolaWeb.Admin.Content.PostLive.Index do
  @moduledoc """
  Admin list page showing all posts for the current store with type and status filters.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Content",
        active_nav: :content,
        store_id: store_id,
        filter_type: :all,
        filter_status: :all,
        posts: []
      )
      |> load_posts()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    type_atom =
      case type do
        "all" -> :all
        "blog_post" -> :blog_post
        "page" -> :page
        "recipe" -> :recipe
        "guide" -> :guide
        _ -> :all
      end

    socket =
      socket
      |> assign(:filter_type, type_atom)
      |> load_posts()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "draft" -> :draft
        "ai_draft" -> :ai_draft
        "published" -> :published
        "archived" -> :archived
        _ -> :all
      end

    socket =
      socket
      |> assign(:filter_status, status_atom)
      |> load_posts()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_post", %{"id" => id}, socket) do
    case Emakola.Content.Post |> Ash.get(id) do
      {:ok, post} ->
        case Ash.destroy(post) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, "Post deleted")
             |> load_posts()}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Could not delete post")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Post not found")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-semibold text-slate-900">Content</h1>
        <.link
          navigate={~p"/admin/content/posts/new"}
          class="inline-flex items-center gap-2 rounded-xl bg-slate-900 px-4 py-2.5 text-sm font-medium text-white hover:bg-slate-800 transition-colors"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          New Post
        </.link>
      </div>

      <%!-- Type filter --%>
      <div class="flex flex-wrap gap-2 mb-4">
        <.filter_button
          label="All"
          value="all"
          current={@filter_type}
          event="filter_type"
          field="type"
        />
        <.filter_button
          label="Blog Posts"
          value="blog_post"
          current={@filter_type}
          event="filter_type"
          field="type"
        />
        <.filter_button
          label="Pages"
          value="page"
          current={@filter_type}
          event="filter_type"
          field="type"
        />
        <.filter_button
          label="Recipes"
          value="recipe"
          current={@filter_type}
          event="filter_type"
          field="type"
        />
        <.filter_button
          label="Guides"
          value="guide"
          current={@filter_type}
          event="filter_type"
          field="type"
        />
      </div>

      <%!-- Status filter --%>
      <div class="flex flex-wrap gap-2 mb-6">
        <.filter_button
          label="All"
          value="all"
          current={@filter_status}
          event="filter_status"
          field="status"
        />
        <.filter_button
          label="Draft"
          value="draft"
          current={@filter_status}
          event="filter_status"
          field="status"
        />
        <.filter_button
          label="AI Draft"
          value="ai_draft"
          current={@filter_status}
          event="filter_status"
          field="status"
        />
        <.filter_button
          label="Published"
          value="published"
          current={@filter_status}
          event="filter_status"
          field="status"
        />
        <.filter_button
          label="Archived"
          value="archived"
          current={@filter_status}
          event="filter_status"
          field="status"
        />
      </div>

      <%!-- Posts table --%>
      <div :if={@posts == []} class="text-center py-16 bg-white rounded-xl border border-slate-200">
        <p class="text-slate-500">No posts yet</p>
        <.link
          navigate={~p"/admin/content/posts/new"}
          class="mt-3 inline-block text-sm font-medium text-slate-700 hover:text-slate-900"
        >
          Create your first post
        </.link>
      </div>

      <div :if={@posts != []} class="bg-white rounded-xl border border-slate-200 overflow-hidden">
        <table class="min-w-full divide-y divide-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                Title
              </th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                Type
              </th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                Status
              </th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                Views
              </th>
              <th class="px-6 py-3 text-right text-xs font-semibold text-slate-600 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr :for={post <- @posts} class="hover:bg-slate-50 transition-colors">
              <td class="px-6 py-4 text-sm font-medium text-slate-900">{post.title}</td>
              <td class="px-6 py-4">
                <.type_badge type={post.type} />
              </td>
              <td class="px-6 py-4">
                <.status_badge status={post.status} />
              </td>
              <td class="px-6 py-4 text-sm text-slate-500">{post.view_count}</td>
              <td class="px-6 py-4 text-right">
                <.link
                  navigate={~p"/admin/content/posts/#{post.id}/edit"}
                  class="text-sm font-medium text-slate-600 hover:text-slate-900"
                >
                  Edit
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # ── Components ──

  defp filter_button(assigns) do
    active = to_string(assigns.current) == assigns.value

    assigns = assign(assigns, :active, active)

    ~H"""
    <button
      phx-click={@event}
      phx-value-type={if @field == "type", do: @value}
      phx-value-status={if @field == "status", do: @value}
      class={[
        "px-3 py-1.5 text-sm rounded-lg font-medium transition-colors",
        @active && "bg-slate-900 text-white",
        !@active && "bg-slate-100 text-slate-600 hover:bg-slate-200"
      ]}
    >
      {@label}
    </button>
    """
  end

  defp type_badge(assigns) do
    {label, color} =
      case assigns.type do
        :blog_post -> {"Blog", "bg-blue-50 text-blue-700"}
        :page -> {"Page", "bg-slate-100 text-slate-700"}
        :recipe -> {"Recipe", "bg-amber-50 text-amber-700"}
        :guide -> {"Guide", "bg-emerald-50 text-emerald-700"}
        _ -> {"Other", "bg-slate-100 text-slate-600"}
      end

    assigns = assign(assigns, label: label, color: color)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@color}"}>
      {@label}
    </span>
    """
  end

  defp status_badge(assigns) do
    {label, color} =
      case assigns.status do
        :draft -> {"Draft", "bg-slate-100 text-slate-600"}
        :ai_draft -> {"AI Draft", "bg-purple-50 text-purple-700"}
        :published -> {"Published", "bg-green-50 text-green-700"}
        :archived -> {"Archived", "bg-red-50 text-red-600"}
        _ -> {"Unknown", "bg-slate-100 text-slate-600"}
      end

    assigns = assign(assigns, label: label, color: color)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@color}"}>
      {@label}
    </span>
    """
  end

  # ── Data Loading ──

  defp load_posts(socket) do
    store_id = socket.assigns.store_id

    if is_nil(store_id) do
      assign(socket, :posts, [])
    else
      query =
        Emakola.Content.Post
        |> Ash.Query.for_read(:list_by_store, %{store_id: store_id})

      query =
        if socket.assigns.filter_type != :all do
          Ash.Query.filter(query, type == ^socket.assigns.filter_type)
        else
          query
        end

      query =
        if socket.assigns.filter_status != :all do
          Ash.Query.filter(query, status == ^socket.assigns.filter_status)
        else
          query
        end

      case Ash.read(query) do
        {:ok, posts} -> assign(socket, :posts, posts)
        {:error, _} -> assign(socket, :posts, [])
      end
    end
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end
end
