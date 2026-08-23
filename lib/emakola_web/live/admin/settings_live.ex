defmodule EmakolaWeb.Admin.SettingsLive do
  @moduledoc """
  Store settings page with tabbed sections: General, Contact, Delivery, Notifications.
  Matches the emakola-admin-settings.html design prototype.
  """
  use EmakolaWeb, :live_view

  require Logger

  alias EmakolaWeb.AddressComponents

  @ghana_regions [
    "Greater Accra",
    "Ashanti",
    "Western",
    "Central",
    "Eastern",
    "Northern",
    "Volta",
    "Upper East",
    "Upper West",
    "Bono",
    "Bono East",
    "Ahafo",
    "Savannah",
    "North East",
    "Western North",
    "Oti"
  ]

  # Pictures, not URLs: a merchant who cannot comfortably read a link still has
  # to be able to put a face on their shop. `auto_upload: true` is deliberate —
  # a submit that waits on progress deadlocks without it (see
  # emakola-liveview-upload-progress-gate).
  @image_upload_opts [
    accept: ~w(.jpg .jpeg .png .webp),
    max_entries: 1,
    max_file_size: 5_000_000,
    auto_upload: true
  ]

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.current_store

    socket =
      socket
      |> assign(
        page_title: "Settings",
        active_nav: :settings,
        active_tab: "general",
        ghana_regions: @ghana_regions,
        store: store,
        general_errors: %{},
        saved: false
      )
      |> allow_upload(:logo, @image_upload_opts)
      |> allow_upload(:cover, @image_upload_opts)

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab, saved: false)}
  end

  # Runs on every keystroke in the General tab. It also registers upload
  # entries with LiveView — a form holding a live_file_input needs a
  # phx-change or the entries never arrive.
  @impl true
  def handle_event("validate_general", %{"store" => params}, socket) do
    {:noreply, assign(socket, general_errors: validate_general(params))}
  end

  def handle_event("validate_general", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref, "slot" => slot}, socket) do
    {:noreply, cancel_upload(socket, upload_slot(slot), ref)}
  end

  @impl true
  def handle_event("save_general", %{"store" => params}, socket) do
    case validate_general(params) do
      errors when errors == %{} ->
        params =
          params
          |> put_uploaded_image(socket, :logo, "logo_url")
          |> put_uploaded_image(socket, :cover, "cover_image_url")

        save_settings(assign(socket, general_errors: %{}), params)

      errors ->
        # Field errors stay on the field. A flash saying "Could not save
        # settings" never told the merchant WHICH box was wrong.
        {:noreply, assign(socket, general_errors: errors)}
    end
  end

  @impl true
  def handle_event("save_contact", %{"store" => params}, socket) do
    save_settings(socket, params)
  end

  # Phase 1.5 of social media integration. Same auth + persistence path
  # as save_contact / save_general (inherited security posture); the
  # update_settings action's `accept` list gates which Store fields can
  # be mutated, so additional params in the form payload are ignored.
  @impl true
  def handle_event("save_social", %{"store" => params}, socket) do
    save_settings(socket, params)
  end

  # The slot comes from the client, so it is matched against the two names this
  # page allows rather than converted with String.to_atom/1.
  defp upload_slot("cover"), do: :cover
  defp upload_slot(_logo), do: :logo

  # Consumes a picture, if one was chosen, and merges its stored URL into the
  # params under the Store attribute name. No entry means the key is untouched,
  # so saving other fields never wipes an existing picture.
  defp put_uploaded_image(params, socket, slot, attribute) do
    store_id = socket.assigns.store.id

    url =
      socket
      |> consume_uploaded_entries(slot, fn %{path: tmp_path}, entry ->
        extension = Path.extname(entry.client_name)
        path = "stores/#{store_id}/branding/#{slot}-#{Ecto.UUID.generate()}#{extension}"

        case Emakola.Storage.upload(File.read!(tmp_path), path, content_type: entry.client_type) do
          {:ok, url} ->
            {:ok, url}

          {:error, reason} ->
            Logger.error("[settings_live] #{slot} upload failed: #{inspect(reason)}")
            {:ok, nil}
        end
      end)
      |> List.first()

    if is_nil(url), do: params, else: Map.put(params, attribute, url)
  end

  # Field-level messages in the merchant's own words — the Store resource
  # carries the same limits (name max 255, tagline max 140) but surfaces them
  # only after a failed write, as one flash for the whole form.
  defp validate_general(params) do
    %{}
    |> check(:name, blank?(params["name"]), "Your shop needs a name")
    |> check(:name, too_long?(params["name"], 255), "That name is too long")
    |> check(:tagline, too_long?(params["tagline"], 140), "Keep it under 140 letters")
  end

  defp check(errors, field, true, message), do: Map.put_new(errors, field, message)
  defp check(errors, _field, false, _message), do: errors

  defp blank?(nil), do: false
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""

  defp too_long?(value, limit) when is_binary(value), do: String.length(value) > limit
  defp too_long?(_value, _limit), do: false

  defp save_settings(socket, params) do
    store = socket.assigns.store
    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]

    case Emakola.Stores.update_store_settings(store, params, actor: actor) do
      {:ok, updated_store} ->
        {:noreply,
         socket
         |> assign(store: updated_store, saved: true)
         |> put_flash(:info, "Settings saved")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, format_error(error))}
    end
  end

  # Surfaces the friendly per-field message an Ash validation attaches (e.g.
  # NormalizeDigitalAddress's "Check the digital address — it looks like
  # GA-183-8164") instead of collapsing every failure to a generic string.
  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map_join(", ", &error_message/1)
    |> case do
      "" -> "Could not save settings"
      msg -> msg
    end
  end

  defp format_error(_error), do: "Could not save settings"

  defp error_message(%{message: msg}) when is_binary(msg), do: msg
  defp error_message(_), do: "invalid"

  defp upload_error_message(:too_large), do: "That picture is too big (5MB max)"
  defp upload_error_message(:not_accepted), do: "Use a JPG, PNG or WebP picture"
  defp upload_error_message(:too_many_files), do: "Choose one picture"
  defp upload_error_message(_), do: "Could not use that picture"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.admin_page_header
        title="Settings"
        subtitle="Manage your store preferences"
        icon="hero-cog-6-tooth"
      />

      <%!-- Settings layout: tabs + content --%>
      <div class="flex flex-col md:flex-row gap-6">
        <%!-- Left tabs --%>
        <div class="md:w-56 shrink-0">
          <div class="flex md:flex-col gap-1 overflow-x-auto md:overflow-x-visible pb-2 md:pb-0">
            <.tab_button tab="general" active_tab={@active_tab} icon="hero-cog-6-tooth">
              General
            </.tab_button>
            <.tab_button tab="contact" active_tab={@active_tab} icon="hero-phone">
              Contact
            </.tab_button>
            <.tab_button tab="delivery" active_tab={@active_tab} icon="hero-truck">
              Delivery
            </.tab_button>
            <.tab_button tab="social" active_tab={@active_tab} icon="hero-share">
              Social
            </.tab_button>
            <.tab_button tab="notifications" active_tab={@active_tab} icon="hero-bell">
              Notifications
            </.tab_button>
          </div>
        </div>

        <%!-- Right content --%>
        <div class="flex-1 min-w-0">
          <div :if={@active_tab == "general"}>
            <.general_tab store={@store} uploads={@uploads} errors={@general_errors} />
          </div>
          <div :if={@active_tab == "contact"}>
            <.contact_tab store={@store} ghana_regions={@ghana_regions} />
          </div>
          <div :if={@active_tab == "delivery"}>
            <.delivery_tab />
          </div>
          <div :if={@active_tab == "social"}>
            <.social_tab store={@store} />
          </div>
          <div :if={@active_tab == "notifications"}>
            <.notifications_tab />
          </div>
        </div>
      </div>
    </div>
    """
  end

  # -- Tab button component --

  attr :tab, :string, required: true
  attr :active_tab, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp tab_button(assigns) do
    ~H"""
    <button
      phx-click="switch_tab"
      phx-value-tab={@tab}
      class={[
        "flex items-center gap-2.5 px-4 py-2.5 rounded-control text-sm font-medium whitespace-nowrap cursor-pointer transition-all",
        if(@tab == @active_tab,
          do: "bg-primary-soft text-primary font-semibold",
          else: "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
        )
      ]}
    >
      <.icon name={@icon} class="size-4 shrink-0" />
      {render_slot(@inner_block)}
    </button>
    """
  end

  # -- General tab --

  attr :store, :map, required: true
  attr :uploads, :map, required: true
  attr :errors, :map, default: %{}

  defp general_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <.admin_card>
        <h3 class="text-base font-bold text-slate-900 mb-5">Store Information</h3>
        <.form
          for={%{}}
          as={:store}
          id="general-form"
          phx-change="validate_general"
          phx-submit="save_general"
          class="space-y-5"
        >
          <%!-- Shop picture. The tile used to show initials beside a button
                that did nothing — there was no upload wired to this page. --%>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Shop picture</label>
            <div class="flex items-center gap-4">
              <div class="relative w-20 h-20 shrink-0">
                <.live_img_preview
                  :for={entry <- @uploads.logo.entries}
                  entry={entry}
                  class="w-20 h-20 rounded-control object-cover border border-slate-200"
                />
                <img
                  :if={@uploads.logo.entries == [] && @store && @store.logo_url}
                  src={@store.logo_url}
                  alt="Your shop picture"
                  class="w-20 h-20 rounded-control object-cover border border-slate-200"
                />
                <div
                  :if={@uploads.logo.entries == [] && !(@store && @store.logo_url)}
                  class="w-20 h-20 rounded-control bg-primary flex items-center justify-center text-white text-2xl font-bold"
                >
                  {logo_initials(@store)}
                </div>
                <%!-- A full-size opacity-0 input, not sr-only: an sr-only file
                      input will not open the picker on iOS Safari, and these
                      merchants are on phones. --%>
                <label class="absolute -right-1.5 -bottom-1.5 w-9 h-9 rounded-full bg-surface border border-border shadow-sm flex items-center justify-center cursor-pointer hover:bg-slate-50">
                  <.icon name="hero-camera" class="size-4 text-slate-700" />
                  <.live_file_input
                    upload={@uploads.logo}
                    class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
                  />
                </label>
              </div>
              <div class="min-w-0">
                <p class="text-sm text-slate-600">Tap the camera to change it.</p>
                <p class="text-xs text-slate-400 mt-1">JPG or PNG, up to 5MB.</p>
                <p :for={err <- upload_errors(@uploads.logo)} class="text-xs text-red-600 mt-1">
                  {upload_error_message(err)}
                </p>
              </div>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Store Name</label>
            <input
              type="text"
              name="store[name]"
              value={@store && @store.name}
              class={[
                "w-full px-4 py-2.5 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 transition-all",
                if(@errors[:name],
                  do: "bg-red-50 border border-red-300 focus:ring-red-500/30",
                  else:
                    "bg-white border border-slate-200 focus:ring-emerald-500/30 focus:border-emerald-500"
                )
              ]}
            />
            <p :if={@errors[:name]} class="mt-1.5 flex items-center gap-1.5 text-sm text-red-600">
              <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
              {@errors[:name]}
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Store URL</label>
            <div class="flex items-center gap-2">
              <div class="flex-1 flex items-center bg-slate-50 border border-slate-200 rounded-control overflow-hidden">
                <span class="px-4 py-2.5 text-sm text-slate-400 bg-slate-50 border-r border-slate-200 shrink-0">
                  https://
                </span>
                <input
                  type="text"
                  value={@store && "#{@store.slug}.emakola.com"}
                  class="flex-1 px-3 py-2.5 bg-white text-sm text-slate-800 font-mono focus:outline-none"
                  readonly
                />
              </div>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">
              Tagline
              <span class="text-xs text-slate-400 font-normal">— shown on the marketplace card</span>
            </label>
            <input
              type="text"
              name="store[tagline]"
              value={@store && @store.tagline}
              maxlength="140"
              placeholder="One line that captures your shop in 140 characters"
              class={[
                "w-full px-4 py-2.5 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 transition-all",
                if(@errors[:tagline],
                  do: "bg-red-50 border border-red-300 focus:ring-red-500/30",
                  else:
                    "bg-white border border-slate-200 focus:ring-emerald-500/30 focus:border-emerald-500"
                )
              ]}
            />
            <p :if={@errors[:tagline]} class="mt-1.5 flex items-center gap-1.5 text-sm text-red-600">
              <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
              {@errors[:tagline]}
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Description</label>
            <textarea
              name="store[description]"
              rows="3"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all resize-none"
            >{@store && @store.description}</textarea>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">
              Cover picture
              <span class="text-xs text-slate-400 font-normal">
                — the wide banner buyers see on the marketplace
              </span>
            </label>

            <div
              class="relative border-2 border-dashed border-slate-300 rounded-control hover:border-emerald-400 transition-colors overflow-hidden"
              phx-drop-target={@uploads.cover.ref}
            >
              <.live_img_preview
                :for={entry <- @uploads.cover.entries}
                entry={entry}
                class="w-full aspect-[16/9] object-cover"
              />
              <img
                :if={
                  @uploads.cover.entries == [] && @store && @store.cover_image_url &&
                    @store.cover_image_url != ""
                }
                src={@store.cover_image_url}
                alt="Cover preview"
                class="w-full aspect-[16/9] object-cover"
                loading="lazy"
              />
              <div
                :if={
                  @uploads.cover.entries == [] &&
                    !(@store && @store.cover_image_url && @store.cover_image_url != "")
                }
                class="aspect-[16/9] flex flex-col items-center justify-center gap-2 bg-slate-50 text-center px-4"
              >
                <div class="w-14 h-14 rounded-control bg-info-soft flex items-center justify-center">
                  <.icon name="hero-photo" class="size-7 text-info" />
                </div>
                <p class="text-sm font-semibold text-slate-700">Add a wide picture</p>
                <p class="text-xs text-slate-500">Tap to take one or choose a photo</p>
              </div>
              <.live_file_input
                upload={@uploads.cover}
                class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
              />
            </div>

            <p :for={err <- upload_errors(@uploads.cover)} class="mt-1.5 text-xs text-red-600">
              {upload_error_message(err)}
            </p>

            <%!-- Kept as the secondary path: a merchant whose picture already
                  lives on a CDN can still paste the link. --%>
            <details class="mt-2">
              <summary class="text-xs text-slate-500 cursor-pointer">Or paste a picture link</summary>
              <input
                type="url"
                name="store[cover_image_url]"
                value={@store && @store.cover_image_url}
                placeholder="https://your-cdn.com/cover.jpg"
                inputmode="url"
                class="mt-2 w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </details>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Currency</label>
              <input
                type="text"
                value={format_currency(@store && @store.currency)}
                class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-control text-sm text-slate-500"
                disabled
              />
            </div>
          </div>

          <div class="flex items-start gap-3 p-4 bg-slate-50 border border-slate-200 rounded-control">
            <input type="hidden" name="store[buyer_protection_enabled]" value="false" />
            <input
              type="checkbox"
              id="store-buyer-protection-enabled"
              name="store[buyer_protection_enabled]"
              value="true"
              checked={@store && @store.buyer_protection_enabled == true}
              class="mt-0.5 w-4 h-4 text-emerald-600 rounded focus:ring-emerald-500"
            />
            <label for="store-buyer-protection-enabled" class="cursor-pointer">
              <span class="block text-sm font-medium text-slate-700">Buyer Protection</span>
              <span class="block text-xs text-slate-500 mt-0.5">
                Hold payments until delivery is confirmed. Slower cash-out, stronger buyer trust.
              </span>
            </label>
          </div>
          
    <!-- What this shop is allowed to sell. The hidden input is load-bearing:
               an all-unticked checkbox group submits no key at all, and a store
               without :physical cannot edit its own existing catalogue, because
               ProductTypeAcceptedByStore runs on Product :update too. -->
          <div class="pt-2">
            <span class="block text-sm font-medium text-slate-700 mb-1.5">What you sell</span>
            <input type="hidden" name="store[enabled_product_types][]" value="physical" />
            <div
              :for={type <- Emakola.Catalog.Product.sellable_types() -- [:physical]}
              class="flex items-start gap-3"
            >
              <input
                type="checkbox"
                id={"store-product-type-#{type}"}
                name="store[enabled_product_types][]"
                value={to_string(type)}
                checked={@store && Emakola.Stores.Store.accepts?(@store, type)}
                class="mt-0.5 w-4 h-4 text-emerald-600 rounded focus:ring-emerald-500"
              />
              <label for={"store-product-type-#{type}"} class="cursor-pointer">
                <span class="block text-sm font-medium text-slate-700">Digital downloads</span>
                <span class="block text-xs text-slate-500 mt-0.5">
                  Sell files — ebooks, beats, presets, courses. No address, no delivery fee.
                </span>
              </label>
            </div>
          </div>

          <div class="flex justify-end pt-2">
            <.admin_button type="submit">
              <.icon name="hero-check" class="size-4" /> Save Changes
            </.admin_button>
          </div>
        </.form>
      </.admin_card>
    </div>
    """
  end

  # -- Contact tab --

  attr :store, :map, required: true
  attr :ghana_regions, :list, required: true

  defp contact_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <.admin_card>
        <h3 class="text-base font-bold text-slate-900 mb-5">Contact Information</h3>
        <.form for={%{}} as={:store} id="contact-form" phx-submit="save_contact" class="space-y-5">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-5">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Email</label>
              <input
                type="email"
                name="store[contact_email]"
                value={@store && @store.contact_email}
                placeholder="store@example.com"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Phone</label>
              <input
                type="tel"
                name="store[contact_phone]"
                value={@store && @store.contact_phone}
                placeholder="+233 24 123 4567"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">WhatsApp Number</label>
              <input
                type="tel"
                name="store[whatsapp_number]"
                value={@store && @store.whatsapp_number}
                placeholder="+233 24 123 4567"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Address</label>
              <input
                type="text"
                name="store[address]"
                value={@store && @store.address}
                placeholder="15 Oxford Street, Osu"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">City</label>
              <input
                type="text"
                name="store[city]"
                value={@store && @store.city}
                placeholder="Accra"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Region</label>
              <select
                name="store[region]"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all cursor-pointer"
              >
                <option value="">Select region</option>
                <option
                  :for={region <- @ghana_regions}
                  value={region}
                  selected={@store && @store.region == region}
                >
                  {region}
                </option>
              </select>
            </div>
          </div>

          <AddressComponents.gh_address_fields
            digital_address={@store && @store.digital_address}
            landmark={@store && @store.landmark}
            field_prefix="store"
            show_hint={false}
          />

          <div class="flex justify-end pt-2">
            <.admin_button type="submit">
              <.icon name="hero-check" class="size-4" /> Save Changes
            </.admin_button>
          </div>
        </.form>
      </.admin_card>
    </div>
    """
  end

  # -- Social tab --

  attr :store, :map, required: true

  defp social_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <.admin_card>
        <h3 class="text-base font-bold text-slate-900 mb-1">Social media</h3>
        <p class="text-sm text-slate-500 mb-5">
          These appear as icons in your storefront footer and help shoppers verify
          your brand. Leave any field blank to hide its icon.
        </p>
        <.form for={%{}} as={:store} id="social-form" phx-submit="save_social" class="space-y-5">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-5">
            <.social_url_input
              field="instagram_url"
              label="Instagram"
              placeholder="https://instagram.com/your_store"
              value={@store && @store.instagram_url}
              icon="hero-camera"
            />
            <.social_url_input
              field="tiktok_url"
              label="TikTok"
              placeholder="https://tiktok.com/@your_store"
              value={@store && @store.tiktok_url}
              icon="hero-musical-note"
            />
            <.social_url_input
              field="facebook_url"
              label="Facebook"
              placeholder="https://facebook.com/your_store"
              value={@store && @store.facebook_url}
              icon="hero-user-group"
            />
            <.social_url_input
              field="x_url"
              label="X (Twitter)"
              placeholder="https://x.com/your_store"
              value={@store && @store.x_url}
              icon="hero-hashtag"
            />
            <.social_url_input
              field="youtube_url"
              label="YouTube"
              placeholder="https://youtube.com/@your_store"
              value={@store && @store.youtube_url}
              icon="hero-play"
            />
          </div>

          <div class="flex justify-end pt-2">
            <.admin_button type="submit">
              <.icon name="hero-check" class="size-4" /> Save changes
            </.admin_button>
          </div>
        </.form>
      </.admin_card>

      <%!-- WhatsApp Catalog connection (Phase 2) --%>
      <.admin_card>
        <h3 class="text-base font-bold text-slate-900 mb-1">WhatsApp Catalog</h3>
        <p class="text-sm text-slate-500 mb-5">
          Mirror your products to your WhatsApp Business Catalog so customers can browse
          and shop without leaving WhatsApp.
          <a
            href="https://business.whatsapp.com/products/whatsapp-catalog"
            target="_blank"
            rel="noopener noreferrer"
            class="text-primary-hover hover:underline"
          >
            Learn how to create a catalog →
          </a>
        </p>
        <.form
          for={%{}}
          as={:store}
          id="whatsapp-catalog-form"
          phx-submit="save_social"
          class="space-y-5"
        >
          <div>
            <label class="flex items-center gap-1.5 text-sm font-medium text-slate-700 mb-1.5">
              <.icon name="hero-link" class="size-4 text-slate-400" /> WhatsApp Catalog ID
            </label>
            <input
              type="text"
              name="store[whatsapp_catalog_id]"
              value={@store && @store.whatsapp_catalog_id}
              placeholder="e.g. 1234567890123456"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
            />
            <p class="mt-1.5 text-xs text-slate-500">
              Found in Meta Commerce Manager → Catalog → Settings. Leave blank to disable sync.
            </p>
          </div>
          <div class="flex justify-end pt-2">
            <.admin_button type="submit">
              <.icon name="hero-check" class="size-4" /> Save catalog connection
            </.admin_button>
          </div>
        </.form>
      </.admin_card>
    </div>
    """
  end

  attr :field, :string, required: true
  attr :label, :string, required: true
  attr :placeholder, :string, required: true
  attr :value, :any, default: nil
  attr :icon, :string, required: true

  defp social_url_input(assigns) do
    ~H"""
    <div>
      <label class="flex items-center gap-1.5 text-sm font-medium text-slate-700 mb-1.5">
        <.icon name={@icon} class="size-4 text-slate-400" /> {@label}
      </label>
      <input
        type="url"
        name={"store[#{@field}]"}
        value={@value}
        placeholder={@placeholder}
        inputmode="url"
        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
      />
    </div>
    """
  end

  # -- Delivery tab (links to dedicated page) --

  defp delivery_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <.admin_card>
        <div class="flex items-center justify-between mb-5">
          <div>
            <h3 class="text-base font-bold text-slate-900">Delivery Zones</h3>
            <p class="text-sm text-slate-500 mt-1">Configure delivery areas and fees</p>
          </div>
          <.link
            navigate={~p"/admin/settings/delivery"}
            class="inline-flex items-center gap-2 px-4 py-2.5 bg-primary hover:bg-primary-hover text-white rounded-control text-sm font-semibold transition-colors"
          >
            <.icon name="hero-truck" class="size-4" /> Manage Zones
          </.link>
        </div>
        <p class="text-sm text-slate-500">
          Set up delivery zones with fees for different geographic areas.
          Customers will see these options during checkout.
        </p>
      </.admin_card>
    </div>
    """
  end

  # -- Notifications tab (placeholder) --

  defp notifications_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <.admin_card>
        <h3 class="text-base font-bold text-slate-900 mb-5">Notification Preferences</h3>
        <p class="text-sm text-slate-500">
          Notification settings will be available soon. You will be able to configure
          SMS, WhatsApp, and email notifications for orders and inventory alerts.
        </p>
      </.admin_card>
    </div>
    """
  end

  # -- Helpers --

  defp logo_initials(nil), do: "?"

  defp logo_initials(store) do
    store.name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp format_currency("GHS"), do: "GH\u20B5 (Ghana Cedi)"
  defp format_currency("NGN"), do: "\u20A6 (Nigerian Naira)"
  defp format_currency("USD"), do: "$ (US Dollar)"
  defp format_currency(nil), do: ""
  defp format_currency(c), do: c
end
