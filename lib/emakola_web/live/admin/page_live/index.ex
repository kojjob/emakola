defmodule EmakolaWeb.Admin.PageLive.Index do
  @moduledoc """
  Admin list page showing all merchant-built pages for the current store.
  Pages are powered by `Emakola.Pages.Page` (block-based) and rendered
  on the storefront via `Emakola.PageBuilder.Renderer`.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Pages",
        active_nav: :pages,
        store_id: store_id,
        pages: []
      )
      |> load_pages()

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_publish", %{"id" => id}, socket) do
    with {:ok, page} <- fetch_owned_page(socket, id) do
      page
      |> Ash.Changeset.for_update(:update, %{published: !page.published})
      |> Ash.update(authorize?: false)
      |> case do
        {:ok, _updated} ->
          {:noreply, socket |> put_flash(:info, "Page updated") |> load_pages()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update page")}
      end
    else
      :forbidden -> {:noreply, put_flash(socket, :error, "Page not found")}
      _ -> {:noreply, put_flash(socket, :error, "Page not found")}
    end
  end

  @impl true
  def handle_event("delete_page", %{"id" => id}, socket) do
    case fetch_owned_page(socket, id) do
      {:ok, page} ->
        case Ash.destroy(page, authorize?: false) do
          :ok ->
            {:noreply, socket |> put_flash(:info, "Page deleted") |> load_pages()}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not delete page")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Page not found")}
    end
  end

  # Fetches a page by id only if its store_id matches the merchant's
  # current_store. Prevents cross-store mutation by id-guessing.
  defp fetch_owned_page(socket, id) do
    case socket.assigns[:store_id] do
      nil ->
        :forbidden

      store_id ->
        case Ash.get(Emakola.Pages.Page, id, authorize?: false) do
          {:ok, %{store_id: ^store_id} = page} -> {:ok, page}
          {:ok, _other_store_page} -> :forbidden
          err -> err
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1200px] mx-auto px-4 sm:px-6 space-y-6 py-6">
      <%!-- Header --%>
      <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">Pages</h1>
          <p class="text-sm text-slate-500 mt-1">
            Build custom pages with images, video, audio, FAQs, and more.
          </p>
        </div>
        <a
          :if={@store_id}
          href={~p"/admin/pages/new"}
          class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-700 transition-colors min-h-[44px]"
        >
          <span class="material-symbols-outlined text-base">add</span> New page
        </a>
      </div>

      <%!-- Pages list --%>
      <div :if={@pages == []} class="bg-white rounded-2xl p-12 text-center border border-slate-200">
        <span class="material-symbols-outlined text-emerald-300" style="font-size: 64px;">
          description
        </span>
        <h2 class="text-lg font-semibold text-slate-900 mt-3 mb-1">No pages yet</h2>
        <p class="text-sm text-slate-500 mb-6">
          Create your first custom page — About, FAQ, Shipping, or anything you like.
        </p>
        <a
          :if={@store_id}
          href={~p"/admin/pages/new"}
          class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-700"
        >
          <span class="material-symbols-outlined text-base">add</span> Create your first page
        </a>
      </div>

      <div
        :if={@pages != []}
        class="bg-white rounded-2xl shadow-sm overflow-hidden border border-slate-200"
      >
        <div class="grid grid-cols-12 gap-3 px-5 py-3 text-xs font-semibold uppercase tracking-wider text-slate-500 border-b border-slate-200 bg-slate-50">
          <div class="col-span-5">Title</div>
          <div class="col-span-3">Slug</div>
          <div class="col-span-2">Status</div>
          <div class="col-span-2 text-right">Actions</div>
        </div>
        <div
          :for={page <- @pages}
          class="grid grid-cols-12 gap-3 px-5 py-4 items-center border-b border-slate-100 last:border-b-0 hover:bg-slate-50 transition-colors"
        >
          <div class="col-span-5">
            <p class="text-sm font-semibold text-slate-900">{page.title}</p>
            <p class="text-xs text-slate-500 mt-0.5">
              {length(page.blocks)} {if length(page.blocks) == 1, do: "block", else: "blocks"}
            </p>
          </div>
          <div class="col-span-3">
            <code class="text-xs text-slate-600 bg-slate-100 px-2 py-1 rounded">/{page.slug}</code>
          </div>
          <div class="col-span-2">
            <span class={status_class(page.published)}>
              {if page.published, do: "Published", else: "Draft"}
            </span>
          </div>
          <div class="col-span-2 flex items-center justify-end gap-2">
            <button
              phx-click="toggle_publish"
              phx-value-id={page.id}
              title={if page.published, do: "Unpublish", else: "Publish"}
              class="w-9 h-9 rounded-lg hover:bg-slate-200 flex items-center justify-center text-slate-600"
            >
              <span class="material-symbols-outlined text-base">
                {if page.published, do: "visibility_off", else: "visibility"}
              </span>
            </button>
            <a
              href={~p"/admin/pages/#{page.id}/edit"}
              class="w-9 h-9 rounded-lg hover:bg-slate-200 flex items-center justify-center text-slate-600"
              title="Edit"
            >
              <span class="material-symbols-outlined text-base">edit</span>
            </a>
            <button
              phx-click="delete_page"
              phx-value-id={page.id}
              data-confirm={"Delete \"#{page.title}\"?"}
              class="w-9 h-9 rounded-lg hover:bg-red-50 flex items-center justify-center text-red-500"
              title="Delete"
            >
              <span class="material-symbols-outlined text-base">delete</span>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_pages(socket) do
    case socket.assigns[:store_id] do
      nil ->
        assign(socket, :pages, [])

      store_id ->
        pages =
          Emakola.Pages.Page
          |> Ash.Query.for_read(:list_for_store, %{store_id: store_id})
          |> Ash.read!(authorize?: false)

        assign(socket, :pages, pages)
    end
  end

  defp status_class(true) do
    "inline-flex items-center px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-700 text-xs font-semibold"
  end

  defp status_class(_) do
    "inline-flex items-center px-2.5 py-1 rounded-full bg-slate-100 text-slate-600 text-xs font-semibold"
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end
end
