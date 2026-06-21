defmodule Emakola.Themes.DefaultRenderers.Contact do
  @moduledoc """
  Default render for the storefront contact page.

  Used by `EmakolaWeb.Storefront.ContactLive` when no theme overrides
  `:render_contact`. Theme-aware via the `--theme-*` CSS variables injected by
  the storefront layout. Reads the store's own contact fields and layers on the
  optional per-store note/hours from `StorePageContent`.
  """

  use Phoenix.Component

  alias EmakolaWeb.Storefront.ContentLoader

  def render(assigns) do
    pc = Map.get(assigns, :page_content) || %{}
    store = assigns.store
    address = store_address(store)
    contact_hours = ContentLoader.field(pc, :contact_hours)

    assigns =
      assigns
      |> assign(
        :contact_note,
        ContentLoader.field(pc, :contact_note) ||
          "Have a question, or just want to say hello? We'd love to hear from you."
      )
      |> assign(:contact_hours, contact_hours)
      |> assign(:address, address)
      |> assign(
        :has_contact_methods?,
        Enum.any?(
          [
            store.contact_email,
            store.contact_phone,
            store.whatsapp_number,
            address,
            contact_hours
          ],
          &present?/1
        )
      )

    ~H"""
    <Emakola.Themes.Atelier.Shared.navbar
      store={@store}
      categories={@categories}
      cart_count={@cart_count}
      active_path="contact"
    />

    <div class="max-w-3xl mx-auto px-4 sm:px-6 py-12 sm:py-16">
      <span
        class="text-xs font-semibold uppercase tracking-[0.2em] block mb-3"
        style="color: var(--theme-primary);"
      >
        Contact {@store.name}
      </span>
      <h1 class="text-3xl sm:text-4xl font-black text-stone-900 mb-3">Get in touch</h1>
      <p class="text-stone-600 leading-relaxed mb-10 max-w-xl">{@contact_note}</p>

      <div class="grid gap-4 sm:grid-cols-2">
        <.contact_row
          :if={present?(@store.contact_email)}
          icon="mail"
          label="Email"
          value={@store.contact_email}
          href={"mailto:#{@store.contact_email}"}
        />
        <.contact_row
          :if={present?(@store.contact_phone)}
          icon="call"
          label="Phone"
          value={@store.contact_phone}
          href={"tel:#{@store.contact_phone}"}
        />
        <.contact_row
          :if={present?(@store.whatsapp_number)}
          icon="chat"
          label="WhatsApp"
          value={@store.whatsapp_number}
          href={"https://wa.me/#{@store.whatsapp_number}"}
        />
        <.contact_row :if={@address} icon="location_on" label="Visit us" value={@address} href={nil} />
        <.contact_row
          :if={@contact_hours}
          icon="schedule"
          label="Opening hours"
          value={@contact_hours}
          href={nil}
        />
      </div>

      <div :if={not @has_contact_methods?} class="text-stone-500 text-sm">
        Contact details for this store are coming soon.
      </div>
    </div>

    <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :href, :string, default: nil

  defp contact_row(assigns) do
    ~H"""
    <div class="flex items-start gap-3 p-5 rounded-xl border border-stone-200 bg-white">
      <span
        class="material-symbols-outlined shrink-0"
        style="font-size: 22px; color: var(--theme-primary);"
      >
        {@icon}
      </span>
      <div class="min-w-0">
        <p class="text-xs font-semibold uppercase tracking-wide text-stone-400 mb-1">{@label}</p>
        <a
          :if={@href}
          href={@href}
          class="text-sm font-medium text-stone-900 hover:underline break-words"
        >
          {@value}
        </a>
        <p :if={@href == nil} class="text-sm font-medium text-stone-900 break-words">{@value}</p>
      </div>
    </div>
    """
  end

  defp store_address(store) do
    [store.address, store.city, store.region]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
    |> case do
      "" -> nil
      address -> address
    end
  end

  defp present?(value), do: value not in [nil, ""]
end
