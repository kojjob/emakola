defmodule Emakola.Themes.Market.Footer do
  @moduledoc """
  Market's own footer — warm stone chrome for the Stall elevation (spec:
  docs/superpowers/specs/2026-07-12-market-theme-elevation.md). Market
  previously borrowed Atelier's footer, leaving a cold seam under the
  warm stone home.

  Content parity with the Atelier columns footer it replaces: brand block,
  shop / company / contact link columns, social links, payment badges,
  secure-checkout mark, copyright. Email capture is NOT here — the
  `market/newsletter` section owns it, so merchants can toggle/reorder it
  and the page never carries two subscribe forms. Differences by design:
  one variant (no `footer_style` token switching), social icons render
  only when the merchant configured a URL, and the brand description
  renders only when the store has one — no invented prose.
  """
  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :theme, :map, default: %{}

  def footer(assigns) do
    theme = assigns[:theme] || %{}
    footer_config = get_in(theme, [:footer]) || %{}
    slug = assigns.store.slug

    company_links =
      Map.get(footer_config, :company_links, [
        %{label: "Our Story", url: store_path(slug, "/about")},
        %{label: "Contact", url: store_path(slug, "/contact")},
        %{label: "FAQ", url: store_path(slug, "/faq")},
        %{label: "Blog", url: store_path(slug, "/blog")},
        %{label: "Recipes", url: store_path(slug, "/recipes")},
        %{label: "Shipping & Returns", url: store_path(slug, "/policies#shipping")},
        %{label: "Privacy Policy", url: store_path(slug, "/policies#privacy")},
        %{label: "Terms of Service", url: store_path(slug, "/policies#terms")}
      ])

    social_links = Map.get(footer_config, :social_links) || %{}

    assigns =
      assigns
      |> assign(:company_links, company_links)
      |> assign(:social_links, social_links)

    ~H"""
    <%!-- Explicit role: the layout nests theme content inside <main>,
    which strips <footer>'s implicit contentinfo landmark. --%>
    <footer role="contentinfo" class="bg-stone-900 text-white">
      <%!-- Mobile bottom padding clears the fixed market_bottom_nav tab bar. --%>
      <div class="mx-auto max-w-[1280px] px-4 pb-28 pt-14 sm:px-6 sm:py-20 lg:px-8">
        <div class="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.5fr_1fr_1fr_1fr] lg:gap-8">
          <div>
            <a
              href={store_path(@store.slug, "/")}
              class="inline-flex min-h-[44px] items-center rounded text-xl font-bold tracking-tight text-white [font-family:var(--dt-heading-font,inherit)] hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70 motion-safe:transition-opacity"
            >
              {@store.name}
            </a>
            <p
              :if={@store.description}
              class="mb-6 mt-3 max-w-xs text-sm leading-relaxed text-stone-400"
            >
              {@store.description}
            </p>
            <div :if={social_urls(@social_links) != []} class="mt-4 flex items-center gap-3">
              <.social_icon
                :for={{label, url, icon} <- social_urls(@social_links)}
                url={url}
                label={label}
                icon={icon}
              />
            </div>
          </div>

          <div>
            <h4 class="mb-5 text-xs font-semibold uppercase tracking-widest text-stone-100">
              Shop
            </h4>
            <ul class="space-y-3">
              <li>
                <.footer_link href={store_path(@store.slug, "/products")}>
                  All Products
                </.footer_link>
              </li>
              <li :for={category <- Enum.take(@categories, 5)}>
                <.footer_link href={store_path(@store.slug, "/category/#{category.slug}")}>
                  {category.name}
                </.footer_link>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="mb-5 text-xs font-semibold uppercase tracking-widest text-stone-100">
              Company
            </h4>
            <ul class="space-y-3">
              <li :for={link <- @company_links}>
                <.footer_link :if={Map.get(link, :url)} href={Map.get(link, :url)}>
                  {Map.get(link, :label)}
                </.footer_link>
                <span
                  :if={!Map.get(link, :url)}
                  class="inline-flex min-h-[44px] items-center text-sm text-stone-500"
                >
                  {Map.get(link, :label)}
                </span>
              </li>
            </ul>
          </div>

          <div>
            <h4 class="mb-5 text-xs font-semibold uppercase tracking-widest text-stone-100">
              Get in Touch
            </h4>
            <ul class="space-y-3">
              <li :if={Map.get(@store, :whatsapp_number)}>
                <.footer_link href={"https://wa.me/#{@store.whatsapp_number}"}>
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                    <path d="M12 0C5.373 0 0 5.373 0 12c0 2.625.846 5.059 2.284 7.034L.789 23.492a.5.5 0 00.613.613l4.458-1.495A11.952 11.952 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-2.24 0-4.31-.726-5.99-1.956l-.418-.312-2.65.888.888-2.65-.312-.418A9.935 9.935 0 012 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z" />
                  </svg>
                  WhatsApp
                </.footer_link>
              </li>
              <li :if={Map.get(@store, :contact_email)}>
                <.footer_link href={"mailto:#{@store.contact_email}"}>
                  {@store.contact_email}
                </.footer_link>
              </li>
              <li :if={Map.get(@store, :contact_phone)}>
                <.footer_link href={"tel:#{@store.contact_phone}"}>
                  {@store.contact_phone}
                </.footer_link>
              </li>
              <li>
                <.footer_link href={store_path(@store.slug, "/about")}>
                  About Us
                </.footer_link>
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-12 border-t border-stone-800 pt-8">
          <div class="flex flex-col items-center justify-between gap-6 sm:flex-row">
            <div class="flex flex-wrap items-center justify-center gap-2">
              <span class="mr-2 text-[10px] uppercase tracking-widest text-stone-500">
                We Accept
              </span>
              <span class={[payment_badge_classes(), "bg-[#FFCC00] text-black"]}>MTN MoMo</span>
              <span class={[payment_badge_classes(), "bg-[#E60000] text-white"]}>Telecel Cash</span>
              <span class={[payment_badge_classes(), "bg-[#1A1F71] text-white"]}>Visa</span>
              <span class={[payment_badge_classes(), "bg-[#FF5F00] text-white"]}>Mastercard</span>
            </div>
            <div class="flex items-center gap-1.5 text-stone-500">
              <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                aria-hidden="true"
              >
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0110 0v4" />
              </svg>
              <span class="text-[10px] uppercase tracking-widest">Secure Checkout</span>
            </div>
          </div>
        </div>

        <div class="mt-8 flex flex-col items-center justify-between gap-4 border-t border-stone-800 pt-8 sm:flex-row">
          <p class="text-xs text-stone-500">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p class="text-[10px] text-stone-500">
            Powered by <span class="font-semibold text-stone-300">Makola</span>
          </p>
        </div>
      </div>
    </footer>
    """
  end

  attr :href, :string, required: true
  slot :inner_block, required: true

  defp footer_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="inline-flex min-h-[44px] items-center gap-2 rounded text-sm text-stone-400 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70 motion-safe:transition-colors"
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  attr :url, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true

  defp social_icon(assigns) do
    ~H"""
    <a
      href={@url}
      class="flex h-11 w-11 items-center justify-center rounded-full text-stone-400 hover:bg-white/10 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70 motion-safe:transition-colors"
      aria-label={@label}
      target="_blank"
      rel="noopener noreferrer"
    >
      <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path d={@icon} />
      </svg>
    </a>
    """
  end

  @social_icons [
    {:instagram, "Instagram",
     "M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"},
    {:twitter, "Twitter",
     "M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"},
    {:facebook, "Facebook",
     "M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"},
    {:tiktok, "TikTok",
     "M19.59 6.69a4.83 4.83 0 01-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 01-2.88 2.5 2.89 2.89 0 01-2.89-2.89 2.89 2.89 0 012.89-2.89c.28 0 .54.04.79.1v-3.5a6.37 6.37 0 00-.79-.05A6.34 6.34 0 003.15 15.2a6.34 6.34 0 0010.86 4.46V12.8a8.28 8.28 0 005.58 2.17V11.5a4.85 4.85 0 01-3.77-1.85V6.69h3.77z"}
  ]

  # Only socials the merchant actually configured — no dead placeholder
  # icons. Theme defaults store "" for unset socials, so blank counts as
  # absent alongside nil.
  defp social_urls(social_links) do
    for {key, label, icon} <- @social_icons,
        url = Map.get(social_links, key),
        is_binary(url) and url != "",
        do: {label, url, icon}
  end

  defp payment_badge_classes,
    do: "inline-flex items-center rounded px-2.5 py-1 text-[10px] font-bold tracking-wide"
end
