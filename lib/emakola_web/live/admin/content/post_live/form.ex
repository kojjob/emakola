defmodule EmakolaWeb.Admin.Content.PostLive.Form do
  use EmakolaWeb, :live_view

  require Ash.Query

  @impl true
  def mount(params, _session, socket) do
    store = socket.assigns[:current_store]

    case socket.assigns.live_action do
      :new ->
        {:ok,
         socket
         |> assign(:page_title, "New Post")
         |> assign(:active_nav, :content)
         |> assign(:post, nil)
         |> assign(:form_data, %{
           "title" => "",
           "type" => "blog_post",
           "body" => "",
           "excerpt" => "",
           "tags" => "",
           "seo_title" => "",
           "seo_description" => ""
         })
         |> assign(:store, store)
         |> assign(:saving, false)
         |> assign(:errors, %{})}

      :edit ->
        case load_post(params["id"], store) do
          {:ok, post} ->
            {:ok,
             socket
             |> assign(:page_title, "Edit: #{post.title}")
             |> assign(:active_nav, :content)
             |> assign(:post, post)
             |> assign(:form_data, %{
               "title" => post.title || "",
               "type" => to_string(post.type),
               "body" => post.body || "",
               "excerpt" => post.excerpt || "",
               "tags" => Enum.join(post.tags || [], ", "),
               "seo_title" => post.seo_title || "",
               "seo_description" => post.seo_description || ""
             })
             |> assign(:store, store)
             |> assign(:saving, false)
             |> assign(:errors, %{})}

          {:error, _} ->
            {:ok,
             socket
             |> put_flash(:error, "Post not found")
             |> redirect(to: ~p"/admin/content/posts")}
        end
    end
  end

  @impl true
  def handle_event("update_form", %{"post" => params}, socket) do
    {:noreply, assign(socket, :form_data, Map.merge(socket.assigns.form_data, params))}
  end

  @impl true
  def handle_event("save", %{"post" => params}, socket) do
    socket = assign(socket, :saving, true)
    store = socket.assigns.store
    form_data = Map.merge(socket.assigns.form_data, params)

    tags =
      form_data["tags"]
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    attrs = %{
      store_id: store && store.id,
      author_id: socket.assigns[:current_merchant] && socket.assigns.current_merchant.id,
      type: String.to_existing_atom(form_data["type"]),
      title: form_data["title"],
      body: form_data["body"],
      excerpt: form_data["excerpt"],
      tags: tags,
      seo_title: form_data["seo_title"],
      seo_description: form_data["seo_description"]
    }

    result =
      if socket.assigns.post do
        socket.assigns.post
        |> Ash.Changeset.for_update(:update, Map.drop(attrs, [:store_id, :author_id, :type]))
        |> Ash.update()
      else
        Emakola.Content.Post
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.create()
      end

    case result do
      {:ok, post} ->
        action = if socket.assigns.post, do: "updated", else: "created"

        {:noreply,
         socket
         |> assign(:saving, false)
         |> put_flash(:info, "Post #{action} successfully")
         |> redirect(to: ~p"/admin/content/posts/#{post.id}/edit")}

      {:error, changeset} ->
        errors =
          changeset
          |> Map.get(:errors, [])
          |> Enum.map(fn e -> {e.field, e.message} end)
          |> Map.new()

        {:noreply,
         socket
         |> assign(:saving, false)
         |> assign(:errors, errors)
         |> put_flash(:error, "Please fix the errors below")}
    end
  end

  @impl true
  def handle_event("publish", _params, socket) do
    if socket.assigns.post do
      case socket.assigns.post
           |> Ash.Changeset.for_update(:publish)
           |> Ash.update() do
        {:ok, post} ->
          {:noreply,
           socket
           |> assign(:post, post)
           |> put_flash(:info, "Post published")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to publish")}
      end
    else
      {:noreply, put_flash(socket, :error, "Save the post first before publishing")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <a
            href={~p"/admin/content/posts"}
            class="p-2 rounded-xl hover:bg-slate-100 transition-colors"
          >
            <svg
              class="w-5 h-5 text-slate-500"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15.75 19.5L8.25 12l7.5-7.5"
              />
            </svg>
          </a>
          <h1 class="text-xl font-bold text-slate-900">{@page_title}</h1>
        </div>
        <div class="flex items-center gap-3">
          <button
            :if={@post && @post.status != :published}
            phx-click="publish"
            class="px-4 py-2 bg-emerald-600 text-white rounded-xl text-sm font-semibold hover:bg-emerald-700 transition-colors"
          >
            Publish
          </button>
          <span
            :if={@post && @post.status == :published}
            class="px-3 py-1.5 bg-emerald-100 text-emerald-700 rounded-full text-xs font-semibold"
          >
            Published
          </span>
        </div>
      </div>

      <form phx-submit="save" phx-change="update_form" class="space-y-6">
        <div class="bg-white border border-slate-200 rounded-xl p-6 space-y-5">
          <%!-- Type --%>
          <div :if={!@post}>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Type</label>
            <select
              name="post[type]"
              class="w-full border border-slate-200 rounded-lg px-3 py-2.5 text-sm"
            >
              <option value="blog_post" selected={@form_data["type"] == "blog_post"}>
                Blog Post
              </option>
              <option value="page" selected={@form_data["type"] == "page"}>Page</option>
              <option value="recipe" selected={@form_data["type"] == "recipe"}>Recipe</option>
              <option value="guide" selected={@form_data["type"] == "guide"}>Guide</option>
            </select>
          </div>

          <%!-- Title --%>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Title</label>
            <input
              type="text"
              name="post[title]"
              value={@form_data["title"]}
              placeholder="Enter post title..."
              class={"w-full border rounded-xl px-4 py-3 text-sm #{if @errors[:title], do: "border-red-400", else: "border-slate-200"}"}
            />
            <p :if={@errors[:title]} class="text-xs text-red-600 mt-1">{@errors[:title]}</p>
          </div>

          <%!-- Body --%>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Content</label>
            <textarea
              name="post[body]"
              rows="16"
              placeholder="Write your post content... (supports HTML)"
              class="w-full border border-slate-200 rounded-xl px-4 py-3 text-sm font-mono resize-y"
            >{@form_data["body"]}</textarea>
          </div>

          <%!-- Excerpt --%>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">
              Excerpt <span class="text-slate-400 font-normal">(shown in blog listing)</span>
            </label>
            <textarea
              name="post[excerpt]"
              rows="3"
              placeholder="Brief summary of the post..."
              class="w-full border border-slate-200 rounded-xl px-4 py-3 text-sm resize-none"
            >{@form_data["excerpt"]}</textarea>
          </div>

          <%!-- Tags --%>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">
              Tags <span class="text-slate-400 font-normal">(comma separated)</span>
            </label>
            <input
              type="text"
              name="post[tags]"
              value={@form_data["tags"]}
              placeholder="recipes, ghana, food"
              class="w-full border border-slate-200 rounded-xl px-4 py-3 text-sm"
            />
          </div>
        </div>

        <%!-- SEO Section --%>
        <div class="bg-white border border-slate-200 rounded-xl p-6 space-y-5">
          <h2 class="text-sm font-semibold text-slate-900 uppercase tracking-wide">
            SEO Settings
          </h2>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">SEO Title</label>
            <input
              type="text"
              name="post[seo_title]"
              value={@form_data["seo_title"]}
              placeholder="Override the page title for search engines"
              class="w-full border border-slate-200 rounded-xl px-4 py-3 text-sm"
            />
            <p class="text-xs text-slate-400 mt-1">
              {String.length(@form_data["seo_title"])}/60 characters
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">
              SEO Description
            </label>
            <textarea
              name="post[seo_description]"
              rows="2"
              placeholder="Override the meta description for search engines"
              class="w-full border border-slate-200 rounded-xl px-4 py-3 text-sm resize-none"
            >{@form_data["seo_description"]}</textarea>
            <p class="text-xs text-slate-400 mt-1">
              {String.length(@form_data["seo_description"])}/155 characters
            </p>
          </div>
        </div>

        <%!-- Submit --%>
        <div class="flex justify-end gap-3">
          <a
            href={~p"/admin/content/posts"}
            class="px-6 py-3 border border-slate-200 rounded-xl text-sm font-medium text-slate-600 hover:bg-slate-50 transition-colors"
          >
            Cancel
          </a>
          <button
            type="submit"
            disabled={@saving}
            class="px-8 py-3 bg-slate-900 text-white rounded-xl text-sm font-semibold hover:bg-slate-800 disabled:opacity-50 transition-colors"
          >
            {if @saving, do: "Saving...", else: if(@post, do: "Update Post", else: "Create Post")}
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp load_post(id, store) when is_binary(id) and not is_nil(store) do
    case Emakola.Content.Post
         |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
         |> Ash.Query.filter(id == ^id)
         |> Ash.read() do
      {:ok, [post]} -> {:ok, post}
      _ -> {:error, :not_found}
    end
  end

  defp load_post(_, _), do: {:error, :not_found}
end
