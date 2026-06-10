defmodule EmakolaWeb.Admin.PageLive.Form do
  @moduledoc """
  Page editor — title + slug + status + ordered list of blocks.

  Block builder (left pane):
  - Each block is a row with type label + drag handle + delete + collapse
  - "Add block" picker shows all registered block types
  - Per-block fields rendered inline (text, image upload, video URL, etc.)

  Live preview (right pane): renders the page through the same
  `Emakola.PageBuilder.Renderer` pipeline used on the storefront.

  Media uploads (image/audio/video) go to local disk under
  `priv/static/uploads/pages/` for now. Production will swap to S3
  via `Emakola.S3` (existing AWS config).
  """

  use EmakolaWeb, :live_view

  alias Emakola.PageBuilder

  @upload_dir_segment "pages"

  @impl true
  def mount(params, _session, socket) do
    store = socket.assigns[:current_store]

    case {socket.assigns.live_action, store} do
      {_, nil} ->
        {:ok, redirect(socket, to: ~p"/admin/pages")}

      {:new, store} ->
        page = blank_page(store.id)

        {:ok, init_form(socket, store, page, :new)}

      {:edit, store} ->
        case fetch_owned_page(store, params["id"]) do
          {:ok, page} -> {:ok, init_form(socket, store, page, :edit)}
          :forbidden -> {:ok, redirect(socket, to: ~p"/admin/pages")}
          _ -> {:ok, redirect(socket, to: ~p"/admin/pages")}
        end
    end
  end

  defp init_form(socket, store, page, action) do
    socket
    |> assign(
      page_title: if(action == :new, do: "New page", else: "Edit page"),
      active_nav: :pages,
      store: store,
      action: action,
      page_id: Map.get(page, :id),
      title: page.title,
      slug: page.slug,
      published: page.published,
      blocks: normalize_blocks(page.blocks),
      open_block_id: nil,
      block_picker_open: false,
      saving: false,
      saved: false
    )
    |> allow_upload(:block_media,
      accept: ~w(.jpg .jpeg .png .webp .mp4 .webm .mov .mp3 .m4a .wav .ogg),
      max_entries: 1,
      max_file_size: 100_000_000
    )
  end

  defp blank_page(store_id) do
    %{
      id: nil,
      store_id: store_id,
      title: "",
      slug: "",
      published: false,
      blocks: []
    }
  end

  # Pages stored on disk have keys as binaries. The form uses them as-is —
  # so `block["data"]`, `block["type"]`, `block["id"]` all stay strings.
  defp normalize_blocks(blocks) when is_list(blocks) do
    Enum.map(blocks, fn b ->
      %{
        "id" => Map.get(b, "id") || Ash.UUID.generate(),
        "type" => Map.get(b, "type"),
        "content" => Map.get(b, "content") || %{}
      }
    end)
  end

  defp normalize_blocks(_), do: []

  # ── Title / slug / status ──

  @impl true
  def handle_event("update_field", %{"field" => "title", "value" => value}, socket) do
    auto_slug =
      if socket.assigns.slug == "", do: Slug.slugify(value || ""), else: socket.assigns.slug

    {:noreply, assign(socket, title: value, slug: auto_slug, saved: false)}
  end

  def handle_event("update_field", %{"field" => "slug", "value" => value}, socket) do
    {:noreply, assign(socket, slug: Slug.slugify(value || ""), saved: false)}
  end

  def handle_event("update_field", %{"field" => "published", "value" => value}, socket) do
    {:noreply, assign(socket, published: value == "true", saved: false)}
  end

  # ── Block picker ──

  def handle_event("toggle_block_picker", _params, socket) do
    {:noreply, assign(socket, block_picker_open: !socket.assigns.block_picker_open)}
  end

  def handle_event("add_block", %{"type" => type}, socket) do
    case PageBuilder.block_module_for(type) do
      nil ->
        {:noreply, put_flash(socket, :error, "Unknown block type")}

      module ->
        new_block = %{
          "id" => Ash.UUID.generate(),
          "type" => type,
          "content" => stringify_keys(module.default_content())
        }

        {:noreply,
         socket
         |> assign(
           blocks: socket.assigns.blocks ++ [new_block],
           block_picker_open: false,
           open_block_id: new_block["id"],
           saved: false
         )}
    end
  end

  # ── Per-block events ──

  def handle_event("toggle_block", %{"id" => id}, socket) do
    open = if socket.assigns.open_block_id == id, do: nil, else: id
    {:noreply, assign(socket, open_block_id: open)}
  end

  def handle_event("delete_block", %{"id" => id}, socket) do
    blocks = Enum.reject(socket.assigns.blocks, &(&1["id"] == id))
    {:noreply, assign(socket, blocks: blocks, saved: false)}
  end

  def handle_event("move_block_up", %{"id" => id}, socket) do
    {:noreply, assign(socket, blocks: move(socket.assigns.blocks, id, -1), saved: false)}
  end

  def handle_event("move_block_down", %{"id" => id}, socket) do
    {:noreply, assign(socket, blocks: move(socket.assigns.blocks, id, 1), saved: false)}
  end

  def handle_event(
        "update_block_content",
        %{"id" => id, "key" => key, "value" => value},
        socket
      ) do
    blocks =
      Enum.map(socket.assigns.blocks, fn b ->
        if b["id"] == id do
          content = Map.put(b["content"] || %{}, key, value)
          Map.put(b, "content", content)
        else
          b
        end
      end)

    {:noreply, assign(socket, blocks: blocks, saved: false)}
  end

  # Multi-row collection editing (FAQ items, testimonials items)
  def handle_event(
        "update_block_item",
        %{"id" => id, "field" => field, "index" => index_str, "value" => value},
        socket
      ) do
    case Integer.parse(index_str) do
      {index, _} ->
        blocks =
          Enum.map(socket.assigns.blocks, fn b ->
            if b["id"] == id do
              update_item(b, "items", index, field, value)
            else
              b
            end
          end)

        {:noreply, assign(socket, blocks: blocks, saved: false)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("add_block_item", %{"id" => id}, socket) do
    blocks =
      Enum.map(socket.assigns.blocks, fn b ->
        if b["id"] == id do
          items = (b["content"]["items"] || []) ++ [%{}]
          content = Map.put(b["content"] || %{}, "items", items)
          Map.put(b, "content", content)
        else
          b
        end
      end)

    {:noreply, assign(socket, blocks: blocks, saved: false)}
  end

  def handle_event("remove_block_item", %{"id" => id, "index" => index_str}, socket) do
    case Integer.parse(index_str) do
      {index, _} ->
        blocks =
          Enum.map(socket.assigns.blocks, fn b ->
            if b["id"] == id do
              items = b["content"]["items"] || []
              new_items = List.delete_at(items, index)
              content = Map.put(b["content"] || %{}, "items", new_items)
              Map.put(b, "content", content)
            else
              b
            end
          end)

        {:noreply, assign(socket, blocks: blocks, saved: false)}

      :error ->
        {:noreply, socket}
    end
  end

  # ── Media upload ──

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :block_media, ref)}
  end

  def handle_event("save_block_media", %{"id" => id, "key" => key}, socket) do
    store_id = socket.assigns.store.id

    uploaded =
      consume_uploaded_entries(socket, :block_media, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name) |> String.downcase()
        filename = "#{store_id}_#{System.os_time(:millisecond)}#{ext}"
        sanitized = String.replace(filename, ~r/[^a-zA-Z0-9._-]/, "_")
        dest = Path.join(media_upload_dir(), sanitized)
        File.cp!(path, dest)
        {:ok, "/uploads/#{@upload_dir_segment}/#{sanitized}"}
      end)

    case uploaded do
      [url | _] ->
        blocks =
          Enum.map(socket.assigns.blocks, fn b ->
            if b["id"] == id do
              content = Map.put(b["content"] || %{}, key, url)
              Map.put(b, "content", content)
            else
              b
            end
          end)

        {:noreply, assign(socket, blocks: blocks, saved: false)}

      _ ->
        {:noreply, put_flash(socket, :error, "Upload failed")}
    end
  end

  # ── Save ──

  def handle_event("save", _params, socket) do
    socket = assign(socket, saving: true)

    attrs = %{
      title: socket.assigns.title,
      slug: socket.assigns.slug,
      published: socket.assigns.published,
      blocks: socket.assigns.blocks
    }

    case socket.assigns.action do
      :new ->
        attrs = Map.put(attrs, :store_id, socket.assigns.store.id)

        case Emakola.Pages.create_page(attrs, authorize?: false) do
          {:ok, page} ->
            {:noreply,
             socket
             |> put_flash(:info, "Page created")
             |> push_navigate(to: ~p"/admin/pages/#{page.id}/edit")}

          {:error, error} ->
            {:noreply,
             socket
             |> assign(saving: false)
             |> put_flash(:error, format_error(error))}
        end

      :edit ->
        case Emakola.Pages.get_page(socket.assigns.page_id, authorize?: false) do
          {:ok, %{store_id: store_id} = page} when store_id == socket.assigns.store.id ->
            Emakola.Pages.update_page(page, attrs, authorize?: false)
            |> case do
              {:ok, _} ->
                {:noreply,
                 assign(socket, saving: false, saved: true) |> put_flash(:info, "Saved")}

              {:error, error} ->
                {:noreply,
                 socket |> assign(saving: false) |> put_flash(:error, format_error(error))}
            end

          _ ->
            {:noreply, redirect(socket, to: ~p"/admin/pages")}
        end
    end
  end

  # ── Render ──

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 py-6">
      <%!-- Header --%>
      <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3 mb-6">
        <div>
          <a
            href={~p"/admin/pages"}
            class="text-xs text-slate-500 hover:text-slate-700 inline-flex items-center gap-1 mb-2"
          >
            <span class="material-symbols-outlined text-sm">arrow_back</span> All pages
          </a>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">
            {if @action == :new, do: "New page", else: "Edit page"}
          </h1>
        </div>
        <div class="flex items-center gap-3">
          <a
            :if={@action == :edit && @published}
            href={"/s/#{@store.slug}/p/#{@slug}"}
            target="_blank"
            class="inline-flex items-center gap-2 text-sm text-emerald-600 hover:text-emerald-700 font-medium"
          >
            <span class="material-symbols-outlined text-base">open_in_new</span> View live
          </a>
          <button
            phx-click="save"
            disabled={@saving || @title == ""}
            class={[
              "inline-flex items-center gap-2 px-6 py-2.5 rounded-xl text-sm font-semibold transition-colors min-h-[44px]",
              if(@saved,
                do: "bg-emerald-500 text-white",
                else:
                  "bg-emerald-600 text-white hover:bg-emerald-700 disabled:bg-slate-200 disabled:text-slate-400"
              )
            ]}
          >
            {cond do
              @saving -> "Saving..."
              @saved -> "Saved"
              true -> "Save"
            end}
          </button>
        </div>
      </div>

      <%!-- 3-column: settings | blocks editor | preview --%>
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-5">
        <%!-- Settings panel --%>
        <aside class="lg:col-span-3 space-y-4 lg:sticky lg:top-4 lg:self-start">
          <div class="bg-white rounded-2xl p-4 shadow-sm">
            <h2 class="text-base font-bold text-slate-800 mb-3">Page settings</h2>

            <div class="mb-3">
              <label class="block text-xs font-medium text-slate-700 mb-1">Title</label>
              <input
                type="text"
                value={@title}
                phx-change="update_field"
                phx-value-field="title"
                phx-debounce="300"
                name="value"
                placeholder="About us"
                class="w-full bg-white border border-slate-300 rounded-lg px-3 py-2 text-sm text-slate-900 focus:ring-2 focus:ring-emerald-500"
              />
            </div>

            <div class="mb-3">
              <label class="block text-xs font-medium text-slate-700 mb-1">Slug (URL)</label>
              <div class="flex items-center bg-white border border-slate-300 rounded-lg overflow-hidden">
                <span class="text-xs text-slate-400 px-2 py-2 bg-slate-50 border-r border-slate-300">
                  /p/
                </span>
                <input
                  type="text"
                  value={@slug}
                  phx-change="update_field"
                  phx-value-field="slug"
                  phx-debounce="300"
                  name="value"
                  placeholder="about-us"
                  class="flex-1 px-2 py-2 text-sm text-slate-900 focus:outline-none"
                />
              </div>
              <p :if={@slug == ""} class="text-xs text-amber-600 mt-1">Slug auto-fills from title</p>
            </div>

            <div class="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
              <div>
                <p class="text-sm font-medium text-slate-700">Published</p>
                <p class="text-xs text-slate-500">Visible in storefront footer</p>
              </div>
              <button
                type="button"
                phx-click="update_field"
                phx-value-field="published"
                phx-value-value={if @published, do: "false", else: "true"}
                class={[
                  "relative w-11 h-6 rounded-full transition-colors",
                  if(@published, do: "bg-emerald-500", else: "bg-slate-300")
                ]}
              >
                <span class={[
                  "absolute top-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform",
                  if(@published, do: "translate-x-5", else: "translate-x-0.5")
                ]}>
                </span>
              </button>
            </div>
          </div>
        </aside>

        <%!-- Block editor --%>
        <section class="lg:col-span-5 space-y-3">
          <div
            :for={{block, index} <- Enum.with_index(@blocks)}
            class="bg-white rounded-2xl shadow-sm overflow-hidden"
          >
            <%!-- Block header --%>
            <div class="flex items-center gap-2 px-4 py-3 border-b border-slate-200 bg-slate-50">
              <span class="material-symbols-outlined text-emerald-600 text-lg">
                {block_icon(block["type"])}
              </span>
              <p class="flex-1 text-sm font-semibold text-slate-800">
                {block_label(block["type"])}
              </p>
              <button
                phx-click="move_block_up"
                phx-value-id={block["id"]}
                disabled={index == 0}
                class="w-8 h-8 rounded-lg hover:bg-slate-200 flex items-center justify-center text-slate-500 disabled:text-slate-300 disabled:cursor-not-allowed"
                title="Move up"
              >
                <span class="material-symbols-outlined text-sm">arrow_upward</span>
              </button>
              <button
                phx-click="move_block_down"
                phx-value-id={block["id"]}
                disabled={index == length(@blocks) - 1}
                class="w-8 h-8 rounded-lg hover:bg-slate-200 flex items-center justify-center text-slate-500 disabled:text-slate-300 disabled:cursor-not-allowed"
                title="Move down"
              >
                <span class="material-symbols-outlined text-sm">arrow_downward</span>
              </button>
              <button
                phx-click="toggle_block"
                phx-value-id={block["id"]}
                class="w-8 h-8 rounded-lg hover:bg-slate-200 flex items-center justify-center text-slate-500"
                title="Toggle"
              >
                <span class="material-symbols-outlined text-sm">
                  {if @open_block_id == block["id"], do: "expand_less", else: "expand_more"}
                </span>
              </button>
              <button
                phx-click="delete_block"
                phx-value-id={block["id"]}
                data-confirm="Remove this block?"
                class="w-8 h-8 rounded-lg hover:bg-red-50 flex items-center justify-center text-red-500"
                title="Delete"
              >
                <span class="material-symbols-outlined text-sm">delete</span>
              </button>
            </div>

            <%!-- Block fields --%>
            <div :if={@open_block_id == block["id"]} class="p-4 space-y-3">
              <.block_fields block={block} uploads={@uploads} />
            </div>
          </div>

          <%!-- Add block --%>
          <div class="relative">
            <button
              phx-click="toggle_block_picker"
              class="w-full inline-flex items-center justify-center gap-2 px-5 py-4 rounded-2xl border-2 border-dashed border-emerald-300 bg-emerald-50/50 text-emerald-700 text-sm font-semibold hover:bg-emerald-50 hover:border-emerald-400 transition-colors min-h-[56px]"
            >
              <span class="material-symbols-outlined">add</span> Add block
            </button>

            <div
              :if={@block_picker_open}
              class="absolute left-0 right-0 top-full mt-2 bg-white rounded-2xl shadow-xl border border-slate-200 p-3 z-10"
            >
              <p class="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3 px-2">
                Pick a block type
              </p>
              <div class="grid grid-cols-3 gap-2">
                <button
                  :for={module <- PageBuilder.blocks()}
                  phx-click="add_block"
                  phx-value-type={module.type()}
                  class="flex flex-col items-center gap-1.5 p-3 rounded-xl hover:bg-emerald-50 text-slate-700 hover:text-emerald-700 transition-colors"
                >
                  <span class="material-symbols-outlined text-2xl">{module.icon()}</span>
                  <span class="text-xs font-medium text-center">{module.name()}</span>
                </button>
              </div>
            </div>
          </div>

          <div
            :if={@blocks == []}
            class="bg-white rounded-2xl p-12 text-center border-2 border-dashed border-slate-200"
          >
            <span class="material-symbols-outlined text-emerald-300" style="font-size: 56px;">
              widgets
            </span>
            <h3 class="text-base font-semibold text-slate-900 mt-3 mb-1">No blocks yet</h3>
            <p class="text-xs text-slate-500">
              Click "Add block" to start building. Each block is a section of your page.
            </p>
          </div>
        </section>

        <%!-- Live preview --%>
        <aside class="lg:col-span-4 lg:sticky lg:top-4 lg:self-start">
          <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
            <div class="flex items-center justify-between px-4 py-3 border-b border-slate-200">
              <div class="flex items-center gap-2">
                <span class="material-symbols-outlined text-emerald-600">preview</span>
                <h3 class="text-sm font-bold text-slate-800">Preview</h3>
              </div>
              <span class="inline-flex items-center gap-1 text-[10px] font-medium text-emerald-600 bg-emerald-50 px-2 py-1 rounded-full">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span> Live
              </span>
            </div>
            <div class="max-h-[80vh] overflow-y-auto bg-stone-50 text-stone-900">
              <div :if={@blocks == []} class="p-12 text-center text-sm text-slate-400">
                Add blocks to see your page come together.
              </div>
              <Emakola.PageBuilder.Renderer.page
                :if={@blocks != []}
                page={%{blocks: @blocks}}
                store={@store}
                products={[]}
                categories={[]}
              />
            </div>
          </div>
        </aside>
      </div>
    </div>
    """
  end

  # ── Block field rendering ──

  attr :block, :map, required: true
  attr :uploads, :map, required: true

  defp block_fields(%{block: %{"type" => type}} = assigns) do
    case type do
      "hero_banner" ->
        hero_fields(assigns)

      "text_section" ->
        text_section_fields(assigns)

      "image_banner" ->
        image_banner_fields(assigns)

      "split" ->
        split_fields(assigns)

      "video" ->
        video_fields(assigns)

      "audio" ->
        audio_fields(assigns)

      "product_grid" ->
        product_grid_fields(assigns)

      "faq" ->
        list_fields(assigns, "items", [{"question", "Question"}, {"answer", "Answer"}])

      "testimonials" ->
        list_fields(assigns, "items", [
          {"name", "Name"},
          {"location", "Location"},
          {"quote", "Quote"}
        ])

      "spacer" ->
        spacer_fields(assigns)

      _ ->
        generic_message(assigns)
    end
  end

  defp hero_fields(assigns) do
    ~H"""
    <.text_field block={@block} key="headline" label="Headline" />
    <.text_field block={@block} key="subheadline" label="Subheadline" type="textarea" rows={2} />
    <.media_field
      block={@block}
      key="image_url"
      label="Background image"
      accept="image"
      uploads={@uploads}
    />
    <.text_field block={@block} key="cta_label" label="Button text" />
    <.text_field block={@block} key="cta_url" label="Button URL" placeholder="/products" />
    <.text_field block={@block} key="secondary_cta_label" label="Second button (optional)" />
    <.text_field
      block={@block}
      key="secondary_cta_url"
      label="Second button URL"
      placeholder="/about"
    />
    <.select_field
      block={@block}
      key="text_align"
      label="Text alignment"
      options={[{"left", "Left"}, {"center", "Center"}, {"right", "Right"}]}
    />
    """
  end

  defp text_section_fields(assigns) do
    ~H"""
    <.text_field block={@block} key="heading" label="Heading" />
    <.text_field block={@block} key="body" label="Body" type="textarea" rows={6} />
    """
  end

  defp image_banner_fields(assigns) do
    ~H"""
    <.media_field block={@block} key="image_url" label="Image" accept="image" uploads={@uploads} />
    <.text_field block={@block} key="caption" label="Caption (optional)" />
    """
  end

  defp split_fields(assigns) do
    ~H"""
    <.media_field block={@block} key="image_url" label="Image" accept="image" uploads={@uploads} />
    <.select_field
      block={@block}
      key="image_position"
      label="Image position"
      options={[{"left", "Left"}, {"right", "Right"}]}
    />
    <.text_field block={@block} key="heading" label="Heading" />
    <.text_field block={@block} key="body" label="Body" type="textarea" rows={5} />
    <.text_field block={@block} key="cta_label" label="Button text (optional)" />
    <.text_field block={@block} key="cta_url" label="Button URL" />
    """
  end

  defp video_fields(assigns) do
    ~H"""
    <.text_field
      block={@block}
      key="video_url"
      label="YouTube / Vimeo URL or upload"
      placeholder="https://www.youtube.com/watch?v=..."
    />
    <.media_field
      block={@block}
      key="video_url"
      label="...or upload a video file"
      accept="video"
      uploads={@uploads}
    />
    <.media_field
      block={@block}
      key="poster_url"
      label="Poster image (optional)"
      accept="image"
      uploads={@uploads}
    />
    <.text_field block={@block} key="caption" label="Caption (optional)" />
    """
  end

  defp audio_fields(assigns) do
    ~H"""
    <.media_field block={@block} key="audio_url" label="Audio file" accept="audio" uploads={@uploads} />
    <.text_field block={@block} key="title" label="Title" />
    <.text_field block={@block} key="subtitle" label="Subtitle (optional)" />
    """
  end

  defp product_grid_fields(assigns) do
    ~H"""
    <.text_field block={@block} key="heading" label="Heading" />
    <.select_field
      block={@block}
      key="columns"
      label="Columns"
      options={[{"2", "2"}, {"3", "3"}, {"4", "4"}]}
    />
    <.select_field
      block={@block}
      key="limit"
      label="Number of products"
      options={[{"4", "4"}, {"6", "6"}, {"8", "8"}, {"12", "12"}]}
    />
    """
  end

  defp spacer_fields(assigns) do
    ~H"""
    <.select_field
      block={@block}
      key="height"
      label="Spacing"
      options={[{"sm", "Small"}, {"md", "Medium"}, {"lg", "Large"}, {"xl", "Extra large"}]}
    />
    """
  end

  defp generic_message(assigns) do
    ~H"""
    <p class="text-xs text-slate-500 italic">
      No editor for this block type yet.
    </p>
    """
  end

  attr :block, :map, required: true
  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :rows, :integer, default: 2
  attr :placeholder, :string, default: ""

  defp text_field(assigns) do
    value = get_in(assigns.block, ["content", assigns.key]) || ""
    assigns = assign(assigns, :value, value)

    ~H"""
    <div>
      <label class="block text-xs font-medium text-slate-700 mb-1">{@label}</label>
      <%= if @type == "textarea" do %>
        <textarea
          phx-change="update_block_content"
          phx-value-id={@block["id"]}
          phx-value-key={@key}
          phx-debounce="300"
          name="value"
          rows={@rows}
          placeholder={@placeholder}
          class="w-full bg-white border border-slate-300 rounded-lg px-3 py-2 text-sm text-slate-900 focus:ring-2 focus:ring-emerald-500 resize-none"
        >{@value}</textarea>
      <% else %>
        <input
          type="text"
          value={@value}
          phx-change="update_block_content"
          phx-value-id={@block["id"]}
          phx-value-key={@key}
          phx-debounce="300"
          name="value"
          placeholder={@placeholder}
          class="w-full bg-white border border-slate-300 rounded-lg px-3 py-2 text-sm text-slate-900 focus:ring-2 focus:ring-emerald-500"
        />
      <% end %>
    </div>
    """
  end

  attr :block, :map, required: true
  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true

  defp select_field(assigns) do
    value = get_in(assigns.block, ["content", assigns.key])
    value = if is_nil(value), do: "", else: to_string(value)
    assigns = assign(assigns, :value, value)

    ~H"""
    <div>
      <label class="block text-xs font-medium text-slate-700 mb-1">{@label}</label>
      <select
        phx-change="update_block_content"
        phx-value-id={@block["id"]}
        phx-value-key={@key}
        name="value"
        class="w-full bg-white border border-slate-300 rounded-lg px-3 py-2 text-sm text-slate-900 focus:ring-2 focus:ring-emerald-500"
      >
        <option :for={{val, label} <- @options} value={val} selected={@value == val}>
          {label}
        </option>
      </select>
    </div>
    """
  end

  attr :block, :map, required: true
  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :accept, :string, required: true
  attr :uploads, :map, required: true

  defp media_field(assigns) do
    value = get_in(assigns.block, ["content", assigns.key]) || ""
    assigns = assign(assigns, :value, value)

    ~H"""
    <div>
      <label class="block text-xs font-medium text-slate-700 mb-1">{@label}</label>
      <input
        type="text"
        value={@value}
        phx-change="update_block_content"
        phx-value-id={@block["id"]}
        phx-value-key={@key}
        phx-debounce="300"
        name="value"
        placeholder="Paste a URL or upload below"
        class="w-full bg-white border border-slate-300 rounded-lg px-3 py-2 text-sm text-slate-900 focus:ring-2 focus:ring-emerald-500 mb-2"
      />
      <p :if={@value != ""} class="text-[11px] text-slate-500 mb-2 truncate">
        Current: <code class="text-emerald-700">{@value}</code>
      </p>
      <form
        phx-change="validate_upload"
        phx-submit="save_block_media"
        phx-value-id={@block["id"]}
        phx-value-key={@key}
      >
        <label class="flex items-center gap-2 px-3 py-2 bg-slate-50 hover:bg-slate-100 border border-dashed border-slate-300 rounded-lg cursor-pointer text-xs text-slate-600 transition-colors">
          <.live_file_input upload={@uploads.block_media} class="sr-only" />
          <span class="material-symbols-outlined text-base">upload</span>
          {accept_label(@accept)}
        </label>
        <div :if={@uploads.block_media.entries != []} class="mt-2 space-y-1.5">
          <div :for={entry <- @uploads.block_media.entries} class="flex items-center gap-2">
            <p class="flex-1 text-[11px] text-slate-600 truncate">{entry.client_name}</p>
            <span class="text-[11px] text-emerald-600 font-medium">{entry.progress}%</span>
            <button
              type="button"
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              class="text-slate-400 hover:text-red-500"
            >
              <span class="material-symbols-outlined text-sm">close</span>
            </button>
          </div>
          <button
            type="submit"
            class="w-full px-3 py-1.5 bg-emerald-600 text-white text-xs font-semibold rounded-lg hover:bg-emerald-700"
          >
            Save upload
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp accept_label("image"), do: "Choose image (jpg/png/webp)"
  defp accept_label("video"), do: "Choose video (mp4/webm/mov, max 100MB)"
  defp accept_label("audio"), do: "Choose audio (mp3/m4a/wav/ogg, max 100MB)"
  defp accept_label(_), do: "Choose file"

  defp list_fields(assigns, collection_key, fields) do
    items = get_in(assigns.block, ["content", collection_key]) || []
    assigns = assign(assigns, items: items, collection_key: collection_key, fields: fields)

    ~H"""
    <div class="space-y-3">
      <.text_field block={@block} key="heading" label="Heading" />

      <div
        :for={{item, idx} <- Enum.with_index(@items)}
        class="bg-slate-50 rounded-lg p-3 space-y-2 border border-slate-200"
      >
        <div class="flex items-center justify-between mb-1">
          <p class="text-xs font-semibold text-slate-600">Item {idx + 1}</p>
          <button
            phx-click="remove_block_item"
            phx-value-id={@block["id"]}
            phx-value-index={idx}
            class="text-red-500 hover:text-red-700"
          >
            <span class="material-symbols-outlined text-sm">delete</span>
          </button>
        </div>
        <div :for={{field_key, field_label} <- @fields}>
          <label class="block text-[11px] font-medium text-slate-600 mb-0.5">{field_label}</label>
          <input
            type="text"
            value={Map.get(item, field_key) || ""}
            phx-change="update_block_item"
            phx-value-id={@block["id"]}
            phx-value-field={field_key}
            phx-value-index={idx}
            phx-debounce="300"
            name="value"
            class="w-full bg-white border border-slate-300 rounded px-2 py-1.5 text-xs text-slate-900 focus:ring-2 focus:ring-emerald-500"
          />
        </div>
      </div>

      <button
        phx-click="add_block_item"
        phx-value-id={@block["id"]}
        class="w-full inline-flex items-center justify-center gap-1 px-3 py-2 rounded-lg border border-dashed border-slate-300 text-xs font-medium text-slate-600 hover:bg-slate-50"
      >
        <span class="material-symbols-outlined text-sm">add</span> Add another
      </button>
    </div>
    """
  end

  # ── Helpers ──

  defp move(blocks, id, delta) do
    case Enum.find_index(blocks, &(&1["id"] == id)) do
      nil ->
        blocks

      idx ->
        new_idx = max(0, min(length(blocks) - 1, idx + delta))

        if idx == new_idx do
          blocks
        else
          {block, rest} = List.pop_at(blocks, idx)
          List.insert_at(rest, new_idx, block)
        end
    end
  end

  defp update_item(block, collection_key, index, field, value) do
    items = block["content"][collection_key] || []
    item = Enum.at(items, index) || %{}
    new_item = Map.put(item, field, value)
    new_items = List.replace_at(items, index, new_item)
    content = Map.put(block["content"] || %{}, collection_key, new_items)
    Map.put(block, "content", content)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp block_label(type) do
    case PageBuilder.block_module_for(type) do
      nil -> "Unknown"
      mod -> mod.name()
    end
  end

  defp block_icon(type) do
    case PageBuilder.block_module_for(type) do
      nil -> "widgets"
      mod -> mod.icon()
    end
  end

  defp media_upload_dir do
    dir = Path.join([:code.priv_dir(:emakola), "static", "uploads", @upload_dir_segment])
    File.mkdir_p!(dir)
    dir
  end

  defp fetch_owned_page(store, id) when is_binary(id) do
    case Emakola.Pages.get_page(id, authorize?: false) do
      {:ok, %{store_id: store_id} = page} when store_id == store.id -> {:ok, page}
      {:ok, _} -> :forbidden
      err -> err
    end
  end

  defp fetch_owned_page(_, _), do: :forbidden

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map_join(", ", &error_message/1)
    |> case do
      "" -> "Could not save"
      msg -> msg
    end
  end

  defp format_error(_), do: "Could not save"

  defp error_message(%{message: msg}) when is_binary(msg), do: msg
  defp error_message(%{field: field}), do: "#{field} is invalid"
  defp error_message(_), do: "invalid"
end
