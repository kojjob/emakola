defmodule EmakolaWeb.Admin.ProductLive.BulkPhoto do
  use EmakolaWeb, :live_view

  @max_photos 30

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:store_id, socket.assigns.current_store.id)
     |> assign(:max_photos, @max_photos)
     |> assign(:cards, %{})
     |> assign(:publishing, false)
     |> allow_upload(:photos,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: @max_photos,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-slate-900">Add many products</h1>
          <p class="text-sm text-slate-500">
            Pick all your product photos, give each a name and price, then publish.
          </p>
        </div>
        <.link navigate={~p"/admin/products"} class="text-sm text-slate-500 hover:text-slate-900">
          Back to products
        </.link>
      </div>

      <form id="bulk-photo-form" phx-change="validate" phx-submit="publish_all">
        <label
          class="block border-2 border-dashed border-slate-300 rounded-2xl p-8 text-center cursor-pointer hover:border-emerald-400 transition-colors"
          phx-drop-target={@uploads.photos.ref}
        >
          <.icon name="hero-photo" class="size-10 mx-auto text-slate-400 mb-2" />
          <p class="text-sm font-medium text-slate-700">Tap to choose product photos</p>
          <p class="text-xs text-slate-400 mt-1">Up to {@max_photos} photos at once</p>
          <.live_file_input upload={@uploads.photos} class="sr-only" />
        </label>

        <div :for={err <- upload_errors(@uploads.photos)} class="text-sm text-red-600 mt-2">
          {bulk_upload_error(err)}
        </div>

        <%!-- cards render here in Task 2 --%>

        <div
          :if={@uploads.photos.entries != []}
          class="sticky bottom-0 mt-6 bg-white/95 backdrop-blur border-t border-slate-200 py-4 flex justify-end"
        >
          <button
            type="submit"
            disabled={@publishing}
            class="px-6 py-3 bg-emerald-600 text-white text-sm font-semibold rounded-xl hover:bg-emerald-700 disabled:opacity-50"
          >
            {if @publishing,
              do: "Publishing…",
              else: "Publish #{length(@uploads.photos.entries)} products"}
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp bulk_upload_error(:too_large), do: "One photo is too large (max 10 MB)."
  defp bulk_upload_error(:not_accepted), do: "Only image files are accepted (.jpg, .png, .webp)."
  defp bulk_upload_error(:too_many_files), do: "Up to #{@max_photos} photos at a time."
  defp bulk_upload_error(_), do: "There was a problem with a photo."
end
