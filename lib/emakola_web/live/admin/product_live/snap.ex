defmodule EmakolaWeb.Admin.ProductLive.Snap do
  @moduledoc """
  Camera-first "snap to shop" capture flow.

  A merchant takes or picks a photo, Claude vision reads it into draft product
  fields (title, description, category, tags, alt text), and the merchant
  reviews the result before publishing. States: `:capture → :reading →
  :review | :retry`. This LiveView owns the whole flow: capture, AI read,
  review, and submission into a real product.

  Two upload configs (`:photo_camera`, `:photo_gallery`) back the two
  full-size, opacity-0 overlay inputs in the capture state (the iOS-safe
  pattern — a clipped `sr-only` input proxied by a label fails to open the
  picker on iOS Safari). Separate configs — rather than one shared config
  with a source marker — because `live_file_input`'s `id` cannot be
  overridden, so two inputs pointing at the same config would render with a
  duplicate DOM id.
  """
  use EmakolaWeb, :live_view

  require Logger

  alias EmakolaWeb.Admin.ProductLive.Shared

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_store do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Create your store first")
         |> push_navigate(to: ~p"/dashboard")}

      store ->
        mount_with_store(store, socket)
    end
  end

  defp mount_with_store(store, socket) do
    categories = load_store_categories(store.id)

    socket =
      socket
      |> assign(
        page_title: "Add by photo",
        active_nav: :products,
        ai_enabled: EmakolaWeb.AiGate.enabled?(),
        state: :capture,
        source: :gallery,
        photo_url: nil,
        photo_content_type: nil,
        retry_message: nil,
        categories: categories,
        ai: nil,
        category_id: nil,
        flags_clean?: false,
        price_error: nil,
        snap_form: to_form(%{})
      )
      |> allow_upload(:photo_camera, upload_opts())
      |> allow_upload(:photo_gallery, upload_opts())

    {:ok, socket}
  end

  # A module attribute can't hold `&handle_progress/3` — module attributes are
  # evaluated top-to-bottom at compile time, before the function further down
  # this file exists. A function is evaluated at call time (mount/3, after the
  # whole module is compiled), so the capture resolves fine.
  defp upload_opts do
    [
      accept: ~w(.jpg .jpeg .png .webp),
      max_entries: 1,
      max_file_size: 10_000_000,
      auto_upload: true,
      progress: &handle_progress/3
    ]
  end

  # ── Upload progress ──

  # `allow_upload` stays registered even when AI is gated off (mount doesn't
  # branch on it) so a client sending raw upload-channel messages — bypassing
  # the DOM, where the gated render shows no file input at all — could still
  # reach an S3 upload and burn a rate-limit slot without this guard.
  def handle_progress(name, %{done?: true} = entry, %{assigns: %{ai_enabled: false}} = socket)
      when name in [:photo_camera, :photo_gallery] do
    {:noreply, cancel_if_present(socket, name, entry.ref)}
  end

  def handle_progress(name, _entry, %{assigns: %{ai_enabled: false}} = socket)
      when name in [:photo_camera, :photo_gallery],
      do: {:noreply, socket}

  # Both configs stay `allow_upload`ed for the whole LiveView lifetime, so a
  # stale progress event (e.g. the other input firing after the flow has
  # already moved on) must not restart the read mid-:reading/:review/:retry.
  # A finished stray entry is cancelled so it doesn't strand the config's
  # single `max_entries: 1` slot; a not-yet-done one is left alone (no
  # explicit action needed until it either finishes — hitting this same
  # clause — or `retry_photo` cancels it wholesale).
  def handle_progress(name, %{done?: true} = entry, %{assigns: %{state: state}} = socket)
      when name in [:photo_camera, :photo_gallery] and state != :capture do
    {:noreply, cancel_if_present(socket, name, entry.ref)}
  end

  def handle_progress(name, _entry, %{assigns: %{state: state}} = socket)
      when name in [:photo_camera, :photo_gallery] and state != :capture,
      do: {:noreply, socket}

  def handle_progress(:photo_camera, %{done?: true} = entry, socket),
    do: complete_upload(socket, :camera, entry)

  def handle_progress(:photo_camera, _entry, socket), do: {:noreply, socket}

  def handle_progress(:photo_gallery, %{done?: true} = entry, socket),
    do: complete_upload(socket, :gallery, entry)

  def handle_progress(:photo_gallery, _entry, socket), do: {:noreply, socket}

  # ── Events ──

  # No other fields on the capture form — the change event just needs a home.
  @impl true
  def handle_event("validate_snap_photo", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("retry_photo", _params, socket) do
    {:noreply,
     socket
     |> cancel_all_uploads()
     |> assign(
       state: :capture,
       photo_url: nil,
       photo_content_type: nil,
       retry_message: nil,
       ai: nil,
       category_id: nil,
       flags_clean?: false,
       price_error: nil
     )}
  end

  # A rejected file (too large / wrong type) sits in the config's single
  # max_entries: 1 slot showing its error until the merchant dismisses it —
  # without this, the "Remove" button next to the error message would have
  # nothing to fire, and the slot would stay stuck.
  @impl true
  def handle_event("cancel_snap_entry", %{"config" => "photo_camera", "ref" => ref}, socket),
    do: {:noreply, cancel_if_present(socket, :photo_camera, ref)}

  @impl true
  def handle_event("cancel_snap_entry", %{"config" => "photo_gallery", "ref" => ref}, socket),
    do: {:noreply, cancel_if_present(socket, :photo_gallery, ref)}

  @impl true
  def handle_event("cancel_snap_entry", _params, socket), do: {:noreply, socket}

  # Guarded to :review: a directly-pushed event before AI has completed (ai
  # is nil pre-:review) would crash create_snap_product's use of @ai. Not
  # DOM-reachable — the submit button only exists in review_state's markup —
  # but a raw phx-click/JS-pushed event bypasses that.
  @impl true
  def handle_event("save_snap_product", params, %{assigns: %{state: :review}} = socket) do
    action = if params["action"] == "publish", do: :publish, else: :draft

    case Shared.parse_price_input(params["price"]) do
      {:ok, pesewas} -> create_snap_product(socket, params, pesewas, action)
      _ -> {:noreply, assign(socket, price_error: "Add your price")}
    end
  end

  @impl true
  def handle_event("save_snap_product", _params, socket), do: {:noreply, socket}

  # ── Async AI read ──

  @impl true
  def handle_async(
        :snap_ai,
        {:ok, {:ok, %Emakola.AI.Response{parsed: %{"identified" => true} = parsed}}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(ai_assigns(parsed, socket.assigns.categories))
     |> assign(state: :review)}
  end

  @impl true
  def handle_async(:snap_ai, {:ok, {:ok, %Emakola.AI.Response{}}}, socket) do
    {:noreply, assign(socket, state: :retry, retry_message: "Try a clearer photo")}
  end

  @impl true
  def handle_async(:snap_ai, {:ok, {:error, reason}}, socket) do
    Logger.warning("[product_live.snap] AI generate returned an error: #{inspect(reason)}")
    {:noreply, assign(socket, state: :retry, retry_message: "Try a clearer photo")}
  end

  @impl true
  def handle_async(:snap_ai, {:exit, reason}, socket) do
    Logger.error("[product_live.snap] snap_ai task exited: #{inspect(reason)}")
    {:noreply, assign(socket, state: :retry, retry_message: "Try a clearer photo")}
  end

  # ── Render ──

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto px-4 py-6 space-y-6">
      <div class="flex items-center gap-4">
        <.link
          navigate={~p"/admin/products"}
          class="p-2 rounded-lg hover:bg-slate-100 transition-colors"
          aria-label="Back to products"
        >
          <.icon name="hero-arrow-left" class="size-5 text-slate-500" />
        </.link>
        <div>
          <h1 class="text-2xl font-bold font-headline tracking-tight">Add by photo</h1>
          <p class="text-sm text-slate-500 mt-0.5">Snap it. We fill it in.</p>
        </div>
      </div>

      <div :if={not @ai_enabled} class="rounded-lg border border-amber-200 bg-amber-50 p-4">
        <p class="text-sm font-medium text-amber-800">AI generation isn't switched on yet</p>
        <p class="mt-1 text-sm text-amber-700">Photo capture lights up once AI is enabled.</p>
      </div>

      <.capture_state :if={@ai_enabled and @state == :capture} uploads={@uploads} form={@snap_form} />
      <.reading_state :if={@ai_enabled and @state == :reading} photo_url={@photo_url} />
      <.review_state
        :if={@ai_enabled and @state == :review}
        photo_url={@photo_url}
        ai={@ai}
        categories={@categories}
        category_id={@category_id}
        price_error={@price_error}
        flags_clean?={@flags_clean?}
        form={@snap_form}
      />
      <.retry_state :if={@ai_enabled and @state == :retry} message={@retry_message} />
    </div>
    """
  end

  attr :uploads, :map, required: true
  attr :form, Phoenix.HTML.Form, required: true

  defp capture_state(assigns) do
    ~H"""
    <.form for={@form} id="snap-form" phx-change="validate_snap_photo" class="space-y-4">
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <label class="relative flex flex-col items-center justify-center gap-2 border-2 border-dashed border-emerald-300 bg-emerald-50/40 rounded-2xl p-8 text-center cursor-pointer hover:border-emerald-400 transition-colors">
          <.icon name="hero-camera" class="size-10 text-emerald-600" />
          <span class="text-sm font-semibold text-slate-700">Take a photo</span>
          <.live_file_input
            upload={@uploads.photo_camera}
            capture="environment"
            class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
          />
        </label>

        <label class="relative flex flex-col items-center justify-center gap-2 border-2 border-dashed border-slate-300 rounded-2xl p-8 text-center cursor-pointer hover:border-emerald-400 transition-colors">
          <.icon name="hero-photo" class="size-10 text-slate-400" />
          <span class="text-sm font-semibold text-slate-700">Choose from gallery</span>
          <.live_file_input
            upload={@uploads.photo_gallery}
            class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
          />
        </label>
      </div>

      <%!-- Config-level errors (:too_many_files — a slot is already occupied). --%>
      <p
        :for={err <- upload_errors(@uploads.photo_camera) ++ upload_errors(@uploads.photo_gallery)}
        class="text-sm text-red-600"
      >
        {upload_error_message(err)}
      </p>

      <%!-- Entry-level errors (:too_large, :not_accepted) — need a way to dismiss
      the rejected entry, since it otherwise occupies the config's only slot. --%>
      <div
        :for={item <- entry_errors(@uploads)}
        class="flex items-center justify-between gap-3 text-sm text-red-600"
      >
        <span>{Enum.join(item.messages, " ")}</span>
        <button
          type="button"
          phx-click="cancel_snap_entry"
          phx-value-config={item.config}
          phx-value-ref={item.entry.ref}
          class="shrink-0 text-xs font-semibold underline"
        >
          Remove
        </button>
      </div>
    </.form>
    """
  end

  attr :photo_url, :string, default: nil

  defp reading_state(assigns) do
    ~H"""
    <div id="snap-reading" class="flex flex-col items-center gap-4 py-10 text-center">
      <div class="relative w-40 h-40 rounded-2xl overflow-hidden bg-slate-100">
        <img :if={@photo_url} src={@photo_url} class="w-full h-full object-cover" />
        <div class="absolute inset-0 bg-white/40 animate-pulse"></div>
      </div>
      <p class="text-sm font-medium text-slate-600">Reading your photo…</p>
    </div>
    """
  end

  attr :photo_url, :string, default: nil
  attr :ai, :map, required: true
  attr :categories, :list, required: true
  attr :category_id, :any, default: nil
  attr :price_error, :string, default: nil
  attr :flags_clean?, :boolean, required: true
  attr :form, Phoenix.HTML.Form, required: true

  defp review_state(assigns) do
    ~H"""
    <div id="snap-review" class="space-y-4">
      <img :if={@photo_url} src={@photo_url} class="w-full h-56 object-cover rounded-2xl" />

      <div
        :if={not @flags_clean?}
        id="snap-photo-warning"
        class="flex items-center gap-3 rounded-lg border border-amber-200 bg-amber-50 p-4"
      >
        <.icon name="hero-camera" class="size-6 text-amber-600 shrink-0" />
        <p class="text-sm font-medium text-amber-800">Buyers trust real photos</p>
      </div>

      <.form
        for={@form}
        id="snap-review-form"
        phx-submit="save_snap_product"
        class="bg-white rounded-lg p-5 space-y-3"
      >
        <div>
          <label for="snap-title" class="block text-sm font-medium mb-1.5">Title</label>
          <input
            type="text"
            name="title"
            id="snap-title"
            value={@ai.title}
            class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200 bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
          />
        </div>

        <div>
          <label for="snap-description" class="block text-sm font-medium mb-1.5">Description</label>
          <textarea
            name="description"
            id="snap-description"
            rows="3"
            class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200 bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
          >{@ai.description}</textarea>
        </div>

        <div>
          <label for="snap-category" class="block text-sm font-medium mb-1.5">Category</label>
          <select
            name="category_id"
            id="snap-category"
            class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200 bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
          >
            <option value="">No category</option>
            <option
              :for={category <- @categories}
              value={category.id}
              selected={category.id == @category_id}
            >
              {category.name}
            </option>
          </select>
        </div>

        <div>
          <label for="snap-tags" class="block text-sm font-medium mb-1.5">Tags</label>
          <input
            type="text"
            name="tags"
            id="snap-tags"
            value={Enum.join(@ai.tags, ", ")}
            class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200 bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
          />
        </div>

        <div>
          <label for="snap-price" class="block text-sm font-medium mb-1.5">
            Price (GHS) <span class="text-red-500">*</span>
          </label>
          <input
            type="text"
            inputmode="decimal"
            name="price"
            id="snap-price"
            placeholder="e.g. 25.00"
            class={[
              "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500",
              if(@price_error, do: "border-red-300 bg-red-50", else: "border-slate-200 bg-white")
            ]}
          />
          <p :if={@price_error} class="mt-1 text-xs text-red-600">{@price_error}</p>
        </div>

        <div class="flex flex-col sm:flex-row gap-3 pt-2">
          <button
            type="submit"
            name="action"
            value="draft"
            class="flex-1 px-4 py-2.5 rounded-lg text-sm font-semibold border-2 border-emerald-600 text-emerald-700 hover:bg-emerald-50 active:scale-95 transition-all"
          >
            Save draft
          </button>
          <button
            type="submit"
            name="action"
            value="publish"
            class="flex-1 px-4 py-2.5 rounded-lg text-sm font-semibold bg-emerald-600 text-white hover:bg-emerald-700 active:scale-95 transition-all shadow-sm"
          >
            Publish
          </button>
        </div>
      </.form>
    </div>
    """
  end

  attr :message, :string, required: true

  defp retry_state(assigns) do
    ~H"""
    <div id="snap-retry" class="flex flex-col items-center gap-4 py-10 text-center">
      <.icon name="hero-exclamation-triangle" class="size-10 text-amber-500" />
      <p class="text-sm font-medium text-slate-700">{@message}</p>
      <button
        type="button"
        phx-click="retry_photo"
        class="px-4 py-2.5 rounded-lg text-sm font-semibold bg-emerald-600 text-white hover:bg-emerald-700"
      >
        Try again
      </button>
    </div>
    """
  end

  # ── Private ──

  # Entry-level errors (:too_large, :not_accepted) live on `upload_errors/2`,
  # not `upload_errors/1` (config-level: :too_many_files only) — the entry
  # must be iterated to see them. Combines both configs so the template
  # renders one list regardless of which input the merchant used.
  defp entry_errors(uploads) do
    for {name, config} <- [
          photo_camera: uploads.photo_camera,
          photo_gallery: uploads.photo_gallery
        ],
        entry <- config.entries,
        errors = upload_errors(config, entry),
        errors != [] do
      %{config: name, entry: entry, messages: Enum.map(errors, &upload_error_message/1)}
    end
  end

  defp cancel_all_uploads(socket) do
    socket
    |> cancel_entries(:photo_camera)
    |> cancel_entries(:photo_gallery)
  end

  defp cancel_entries(socket, name) do
    Enum.reduce(socket.assigns.uploads[name].entries, socket, fn entry, acc ->
      cancel_upload(acc, name, entry.ref)
    end)
  end

  # A duplicate `done?: true` progress message for an already-cancelled ref
  # would make `cancel_upload/3` raise — check presence first.
  defp cancel_if_present(socket, name, ref) do
    if Enum.any?(socket.assigns.uploads[name].entries, &(&1.ref == ref)) do
      cancel_upload(socket, name, ref)
    else
      socket
    end
  end

  defp complete_upload(socket, source, entry) do
    store = socket.assigns.current_store

    photo_url =
      consume_uploaded_entry(socket, entry, fn %{path: tmp_path} ->
        {:ok, upload_photo(store.id, tmp_path, entry)}
      end)

    case photo_url do
      nil ->
        {:noreply, assign(socket, state: :retry, retry_message: "Upload failed — try again")}

      url ->
        start_snap_ai(
          assign(socket,
            photo_url: url,
            photo_content_type: entry.client_type,
            source: source,
            state: :reading
          )
        )
    end
  end

  defp start_snap_ai(socket) do
    store = socket.assigns.current_store

    case Emakola.Content.RateLimiter.check_and_increment(store.id) do
      :ok ->
        merchant_id = socket.assigns.current_merchant.id
        photo_url = socket.assigns.photo_url
        category_names = Enum.map(socket.assigns.categories, & &1.name)

        {:noreply,
         start_async(socket, :snap_ai, fn ->
           Emakola.AI.generate(
             :snap_to_shop,
             %{image_url: photo_url, store: store, category_names: category_names},
             store: store,
             actor_id: merchant_id
           )
         end)}

      {:error, :rate_limit_exceeded} ->
        {:noreply, assign(socket, state: :retry, retry_message: "Daily AI limit reached")}
    end
  end

  defp upload_photo(store_id, tmp_path, entry) do
    ext = Path.extname(entry.client_name)
    filename = "#{Ecto.UUID.generate()}#{ext}"
    s3_path = "stores/#{store_id}/snap/#{filename}"

    case Emakola.Storage.upload(File.read!(tmp_path), s3_path, content_type: entry.client_type) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  rescue
    exception ->
      Logger.error("[product_live.snap] photo upload failed: #{Exception.message(exception)}")
      nil
  end

  # ── Product creation (review card submit) ──

  # Sequence: product -> variant -> image -> (activate if publishing) ->
  # award. The award MUST run last: Image's :create fires a revocation hook
  # (Emakola.Catalog.Changes.RevokeSnapVerified) that flips snap_verified
  # false on any product it touches, so awarding before the image is attached
  # would be immediately undone.
  #
  # Wrapped in Ash.transact/2 so a failed step rolls back everything already
  # written — no orphaned draft product left behind. The `with` chain's
  # success arm must return the bare product (not `{:ok, product}`): Ecto
  # wraps a transaction function's normal return in `{:ok, _}`, so returning
  # an already-tagged tuple here would double-wrap it.
  defp create_snap_product(socket, params, pesewas, action) do
    %{
      current_store: store,
      current_merchant: merchant,
      photo_url: photo_url,
      photo_content_type: content_type,
      source: source,
      ai: ai,
      flags_clean?: flags_clean?
    } = socket.assigns

    attrs = build_snap_attrs(params, store.id)

    result =
      Ash.transact(
        [Emakola.Catalog.Product, Emakola.Catalog.Variant, Emakola.Catalog.Image],
        fn ->
          with {:ok, product} <-
                 Emakola.Catalog.create_product(attrs, tenant: store.id, actor: merchant),
               {:ok, _variant} <- create_snap_variant(product, pesewas, store, merchant),
               {:ok, _image} <-
                 create_snap_image(product, photo_url, content_type, ai.alt_text, store, merchant),
               {:ok, product} <- maybe_activate_snap_product(product, action, store, merchant),
               {:ok, product} <- award_snap_badge(product, store, source, flags_clean?) do
            product
          end
        end
      )

    case result do
      {:ok, product} ->
        Emakola.Catalog.CachedCatalog.invalidate_store(store.id)

        {:noreply,
         socket
         |> put_flash(:info, "Product created")
         |> push_navigate(to: ~p"/admin/products/#{product.id}/edit")}

      {:error, error} ->
        Logger.error("[product_live.snap] product creation failed: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Something went wrong — try again")}
    end
  end

  defp build_snap_attrs(params, store_id) do
    tags =
      (params["tags"] || "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    %{
      title: params["title"] || "",
      description: params["description"],
      category_id: normalize_category_id(params["category_id"]),
      tags: tags,
      store_id: store_id
    }
  end

  defp normalize_category_id(""), do: nil
  defp normalize_category_id(nil), do: nil
  defp normalize_category_id(id), do: id

  defp create_snap_variant(product, pesewas, store, merchant) do
    sku = "SKU-" <> String.slice(Ecto.UUID.generate(), 0, 8)

    Emakola.Catalog.create_variant(
      %{
        product_id: product.id,
        store_id: store.id,
        price: pesewas,
        # Sellable by default, same rationale as the Form page's default variant.
        track_inventory: false,
        position: 0,
        sku: sku
      },
      tenant: store.id,
      actor: merchant
    )
  end

  defp create_snap_image(product, photo_url, content_type, alt_text, store, merchant) do
    Emakola.Catalog.create_image(
      %{
        url: photo_url,
        alt_text: alt_text,
        content_type: content_type,
        product_id: product.id,
        store_id: store.id
      },
      tenant: store.id,
      actor: merchant
    )
  end

  defp maybe_activate_snap_product(product, :publish, store, merchant) do
    Emakola.Catalog.activate_product(product, tenant: store.id, actor: merchant)
  end

  defp maybe_activate_snap_product(product, :draft, _store, _merchant), do: {:ok, product}

  # :set_snap_verified is forbidden to every actor by policy (badge
  # integrity — see Emakola.Catalog.Product's policies), so this is the one
  # write in the sequence that runs with authorize?: false.
  defp award_snap_badge(product, store, source, flags_clean?) do
    snap_verified = source == :camera and flags_clean?

    product
    |> Ash.Changeset.for_update(:set_snap_verified, %{snap_verified: snap_verified},
      tenant: store.id,
      authorize?: false
    )
    |> Ash.update()
  end

  defp ai_assigns(parsed, categories) do
    [
      ai: %{
        title: parsed["title"],
        description: parsed["description"],
        tags: parsed["tags"] || [],
        alt_text: parsed["alt_text"]
      },
      category_id: resolve_category_id(parsed["category"], categories),
      flags_clean?: flags_clean?(parsed["photo_flags"])
    ]
  end

  defp resolve_category_id(nil, _categories), do: nil

  defp resolve_category_id(name, categories) do
    case Enum.find(categories, &(&1.name == name)) do
      nil -> nil
      category -> category.id
    end
  end

  # Fail closed: badge eligibility (Task 5) depends on this, so anything but
  # an explicit all-clear reads as "not clean".
  defp flags_clean?(%{"stock_photo" => false, "watermark" => false, "screenshot" => false}),
    do: true

  defp flags_clean?(_flags), do: false

  defp load_store_categories(store_id) do
    try do
      Emakola.Catalog.list_categories_by_store!(store_id)
    rescue
      exception ->
        Logger.error(
          "[product_live.snap] load_store_categories loading store categories raised: #{Exception.message(exception)}"
        )

        []
    end
  end

  defp upload_error_message(:too_large), do: "File is too large (max 10 MB)"

  defp upload_error_message(:not_accepted),
    do: "Only image files are accepted (.jpg, .png, .webp)"

  defp upload_error_message(:too_many_files), do: "Only one photo at a time"
  defp upload_error_message(err), do: "Upload error: #{inspect(err)}"
end
