defmodule EmakolaWeb.Admin.SettingsLive do
  @moduledoc """
  Store settings page with tabbed sections: General, Contact, Delivery, Notifications.
  Matches the emakola-admin-settings.html design prototype.
  """
  use EmakolaWeb, :live_view

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
        saved: false
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab, saved: false)}
  end

  @impl true
  def handle_event("save_general", %{"store" => params}, socket) do
    save_settings(socket, params)
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

  defp save_settings(socket, params) do
    store = socket.assigns.store
    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]

    case store
         |> Ash.Changeset.for_update(:update_settings, params)
         |> Ash.update(actor: actor) do
      {:ok, updated_store} ->
        {:noreply,
         socket
         |> assign(store: updated_store, saved: true)
         |> put_flash(:info, "Settings saved")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save settings")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.admin_page_header title="Settings" subtitle="Manage your store preferences" />

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
            <.general_tab store={@store} />
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
        "flex items-center gap-2.5 px-4 py-2.5 rounded-xl text-sm font-medium whitespace-nowrap cursor-pointer transition-all",
        if(@tab == @active_tab,
          do: "bg-emerald-50 text-emerald-700 font-semibold",
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

  defp general_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <h3 class="text-base font-bold text-slate-900 mb-5">Store Information</h3>
        <.form for={%{}} as={:store} id="general-form" phx-submit="save_general" class="space-y-5">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Store Name</label>
            <input
              type="text"
              name="store[name]"
              value={@store && @store.name}
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Store URL</label>
            <div class="flex items-center gap-2">
              <div class="flex-1 flex items-center bg-slate-50 border border-slate-200 rounded-xl overflow-hidden">
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
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Description</label>
            <textarea
              name="store[description]"
              rows="3"
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all resize-none"
            >{@store && @store.description}</textarea>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Store Logo</label>
            <div class="flex items-center gap-4">
              <div class="w-20 h-20 rounded-xl bg-emerald-600 flex items-center justify-center">
                <span class="text-2xl font-bold text-white">
                  {logo_initials(@store)}
                </span>
              </div>
              <button
                type="button"
                class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
              >
                <.icon name="hero-arrow-up-tray" class="size-4" /> Change Logo
              </button>
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Currency</label>
              <input
                type="text"
                value={format_currency(@store && @store.currency)}
                class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-500"
                disabled
              />
            </div>
          </div>

          <div class="flex justify-end pt-2">
            <button
              type="submit"
              class="inline-flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
            >
              <.icon name="hero-check" class="size-4" /> Save Changes
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  # -- Contact tab --

  attr :store, :map, required: true
  attr :ghana_regions, :list, required: true

  defp contact_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
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
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Phone</label>
              <input
                type="tel"
                name="store[contact_phone]"
                value={@store && @store.contact_phone}
                placeholder="+233 24 123 4567"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">WhatsApp Number</label>
              <input
                type="tel"
                name="store[whatsapp_number]"
                value={@store && @store.whatsapp_number}
                placeholder="+233 24 123 4567"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Address</label>
              <input
                type="text"
                name="store[address]"
                value={@store && @store.address}
                placeholder="15 Oxford Street, Osu"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">City</label>
              <input
                type="text"
                name="store[city]"
                value={@store && @store.city}
                placeholder="Accra"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Region</label>
              <select
                name="store[region]"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all cursor-pointer"
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

          <div class="flex justify-end pt-2">
            <button
              type="submit"
              class="inline-flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
            >
              <.icon name="hero-check" class="size-4" /> Save Changes
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  # -- Social tab --

  attr :store, :map, required: true

  defp social_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
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
            <button
              type="submit"
              class="inline-flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
            >
              <.icon name="hero-check" class="size-4" /> Save changes
            </button>
          </div>
        </.form>
      </div>

      <%!-- WhatsApp Catalog connection (Phase 2) --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <h3 class="text-base font-bold text-slate-900 mb-1">WhatsApp Catalog</h3>
        <p class="text-sm text-slate-500 mb-5">
          Mirror your products to your WhatsApp Business Catalog so customers can browse
          and shop without leaving WhatsApp.
          <a
            href="https://business.whatsapp.com/products/whatsapp-catalog"
            target="_blank"
            rel="noopener noreferrer"
            class="text-emerald-700 hover:underline"
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
              class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
            />
            <p class="mt-1.5 text-xs text-slate-500">
              Found in Meta Commerce Manager → Catalog → Settings. Leave blank to disable sync.
            </p>
          </div>
          <div class="flex justify-end pt-2">
            <button
              type="submit"
              class="inline-flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
            >
              <.icon name="hero-check" class="size-4" /> Save catalog connection
            </button>
          </div>
        </.form>
      </div>
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
        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
      />
    </div>
    """
  end

  # -- Delivery tab (links to dedicated page) --

  defp delivery_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <div class="flex items-center justify-between mb-5">
          <div>
            <h3 class="text-base font-bold text-slate-900">Delivery Zones</h3>
            <p class="text-sm text-slate-500 mt-1">Configure delivery areas and fees</p>
          </div>
          <.link
            navigate={~p"/admin/settings/delivery"}
            class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors"
          >
            <.icon name="hero-truck" class="size-4" /> Manage Zones
          </.link>
        </div>
        <p class="text-sm text-slate-500">
          Set up delivery zones with fees for different geographic areas.
          Customers will see these options during checkout.
        </p>
      </div>
    </div>
    """
  end

  # -- Notifications tab (placeholder) --

  defp notifications_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <h3 class="text-base font-bold text-slate-900 mb-5">Notification Preferences</h3>
        <p class="text-sm text-slate-500">
          Notification settings will be available soon. You will be able to configure
          SMS, WhatsApp, and email notifications for orders and inventory alerts.
        </p>
      </div>
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
