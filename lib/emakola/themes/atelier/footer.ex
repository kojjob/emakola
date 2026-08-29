defmodule Emakola.Themes.Atelier.Footer do
  @moduledoc """
  Footer component family for the Atelier artisan craft theme.

  Three variants selected via `theme.design_tokens.footer_style`:
  `:minimal` (single-row brand + social), `:columns` (default — 4-column
  link grid + brand block), `:mega` (full-width newsletter + categories +
  payment badges).

  Extracted from `Emakola.Themes.Atelier.Shared` so the shared module
  is comprehensible at a glance — the footer alone was ~740 lines.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.DesignTokens

  # ── Footer ──

  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :theme, :map, default: %{}
  attr :hide_newsletter, :boolean, default: false

  def footer(assigns) do
    theme = assigns[:theme] || %{}
    footer_config = get_in(theme, [:footer]) || %{}
    slug = assigns.store.slug
    tokens = Map.get(theme, :design_tokens, %{})
    footer_variant = DesignTokens.footer_style(tokens[:footer_style])
    heading_font = DesignTokens.heading_font_family(tokens[:heading_font])
    btn_classes = DesignTokens.button_classes(tokens[:button_style])

    brand_description =
      Map.get(
        footer_config,
        :description,
        # Was "Curating excellence from West Africa's finest artisans." — a claim
        # about who makes the goods and how they were chosen, given to any store
        # that had not written its own description.
        if(assigns.store.description,
          do: assigns.store.description,
          else: assigns.store.tagline || "Shop the collection at #{assigns.store.name}."
        )
      )

    # Company links with sensible defaults that work for any merchant.
    # All routes flow through store_path/2 so they stay correct on both the
    # apex (/s/:slug/...) and a store subdomain (<slug>.<base>/...).
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

    social_links =
      Map.get(footer_config, :social_links, %{
        instagram: nil,
        twitter: nil,
        facebook: nil,
        tiktok: nil
      })

    # Newsletter config
    newsletter = get_in(theme, [:newsletter]) || %{}
    show_newsletter = Map.get(newsletter, :enabled, true) and not assigns.hide_newsletter

    assigns =
      assigns
      |> assign(:brand_description, brand_description)
      |> assign(:company_links, company_links)
      |> assign(:social_links, social_links)
      |> assign(:show_newsletter, show_newsletter)
      |> assign(:newsletter, newsletter)
      |> assign(:footer_variant, footer_variant)
      |> assign(:heading_font, heading_font)
      |> assign(:btn_classes, btn_classes)

    ~H"""
    <%!-- Newsletter Section (above footer) --%>
    <section :if={@show_newsletter} class="bg-gray-50 border-t border-gray-100">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="max-w-2xl mx-auto text-center">
          <h3
            class="text-2xl sm:text-3xl font-black text-gray-900 mb-3"
            style={"font-family: #{@heading_font};"}
          >
            {Map.get(@newsletter, :title, "Stay in the Loop")}
          </h3>
          <p class="text-gray-500 text-sm sm:text-base mb-6">
            {Map.get(
              @newsletter,
              :subtitle,
              "Be the first to know about new collections, exclusive offers, and artisan stories."
            )}
          </p>
          <form
            class="flex flex-col sm:flex-row gap-3 max-w-lg mx-auto"
            phx-submit="subscribe_newsletter"
          >
            <input
              type="email"
              name="email"
              placeholder="Enter your email"
              required
              class={"flex-1 px-4 py-3.5 text-sm #{@btn_classes} border border-gray-200 bg-white text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:border-transparent min-h-[48px]"}
              style="focus:ring-color: var(--theme-primary);"
            />
            <button
              type="submit"
              class={"px-6 py-3.5 text-sm font-bold uppercase tracking-wider #{@btn_classes} text-white transition-all duration-200 hover:opacity-90 cursor-pointer min-h-[48px] whitespace-nowrap"}
              style="background: var(--theme-accent, #166534);"
            >
              {Map.get(@newsletter, :button_text, "Subscribe")}
            </button>
          </form>
          <p class="text-xs text-gray-400 mt-3">No spam. Unsubscribe anytime.</p>
        </div>
      </div>
    </section>

    <%= case @footer_variant do %>
      <% :minimal -> %>
        <.footer_minimal
          store={@store}
          brand_description={@brand_description}
          social_links={@social_links}
        />
      <% :mega -> %>
        <.footer_mega
          store={@store}
          categories={@categories}
          brand_description={@brand_description}
          company_links={@company_links}
          social_links={@social_links}
          heading_font={@heading_font}
          btn_classes={@btn_classes}
        />
      <% _ -> %>
        <.footer_columns
          store={@store}
          categories={@categories}
          brand_description={@brand_description}
          company_links={@company_links}
          social_links={@social_links}
        />
    <% end %>
    """
  end

  # ── Footer: Minimal Variant ──

  attr :store, :map, required: true
  attr :brand_description, :string, required: true
  attr :social_links, :map, required: true

  defp footer_minimal(assigns) do
    ~H"""
    <footer class="text-white" style="background-color: #111111;">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-14">
        <div class="flex flex-col items-center text-center gap-6">
          <%!-- Brand --%>
          <a
            href={store_path(@store.slug, "/")}
            class="text-xl font-black tracking-tight cursor-pointer transition-opacity duration-200 hover:opacity-80"
            style="color: var(--theme-primary);"
          >
            {@store.name}
          </a>
          <p class="text-gray-400 text-sm leading-relaxed max-w-md">
            {@brand_description}
          </p>

          <%!-- Social Icons --%>
          <div class="flex items-center gap-3">
            <.footer_social_icon url={Map.get(@social_links, :instagram)} label="Instagram">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
              </svg>
            </.footer_social_icon>
            <.footer_social_icon url={Map.get(@social_links, :twitter)} label="Twitter">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
              </svg>
            </.footer_social_icon>
            <.footer_social_icon url={Map.get(@social_links, :facebook)} label="Facebook">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
              </svg>
            </.footer_social_icon>
            <.footer_social_icon url={Map.get(@social_links, :tiktok)} label="TikTok">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d="M19.59 6.69a4.83 4.83 0 01-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 01-2.88 2.5 2.89 2.89 0 01-2.89-2.89 2.89 2.89 0 012.89-2.89c.28 0 .54.04.79.1v-3.5a6.37 6.37 0 00-.79-.05A6.34 6.34 0 003.15 15.2a6.34 6.34 0 0010.86 4.46V12.8a8.28 8.28 0 005.58 2.17V11.5a4.85 4.85 0 01-3.77-1.85V6.69h3.77z" />
              </svg>
            </.footer_social_icon>
          </div>

          <%!-- Payment + Copyright --%>
          <div class="border-t border-gray-800/60 w-full pt-6 mt-2">
            <div class="flex items-center justify-center gap-2 flex-wrap mb-4">
              <.payment_badge label="MTN MoMo" color="#FFCC00" text_color="#000" />
              <.payment_badge label="Telecel Cash" color="#E60000" text_color="#fff" />
              <.payment_badge label="Visa" color="#1A1F71" text_color="#fff" />
              <.payment_badge label="Mastercard" color="#FF5F00" text_color="#fff" />
            </div>
            <p class="text-gray-500 text-xs">
              &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
            </p>
            <p class="text-gray-600 text-[10px] mt-1">
              Powered by
              <span class="font-semibold" style="color: var(--theme-primary);">Makola</span>
            </p>
          </div>
        </div>
      </div>
    </footer>
    """
  end

  # ── Footer: Columns Variant (default) ──

  attr :store, :map, required: true
  attr :categories, :list, required: true
  attr :brand_description, :string, required: true
  attr :company_links, :list, required: true
  attr :social_links, :map, required: true

  defp footer_columns(assigns) do
    ~H"""
    <footer class="text-white" style="background-color: #111111;">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-14 sm:py-20">
        <div class="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.5fr_1fr_1fr_1fr] lg:gap-8">
          <%!-- Brand / Description --%>
          <div>
            <a
              href={store_path(@store.slug, "/")}
              class="inline-block text-xl font-black tracking-tight mb-4 cursor-pointer transition-opacity duration-200 hover:opacity-80 min-h-[44px] flex items-center"
              style="color: var(--theme-primary);"
            >
              {@store.name}
            </a>
            <p class="text-gray-400 text-sm leading-relaxed max-w-xs mb-6">
              {@brand_description}
            </p>

            <%!-- Social Icons --%>
            <div class="flex items-center gap-3">
              <.footer_social_icon url={Map.get(@social_links, :instagram)} label="Instagram">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
                </svg>
              </.footer_social_icon>
              <.footer_social_icon url={Map.get(@social_links, :twitter)} label="Twitter">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                </svg>
              </.footer_social_icon>
              <.footer_social_icon url={Map.get(@social_links, :facebook)} label="Facebook">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
                </svg>
              </.footer_social_icon>
              <.footer_social_icon url={Map.get(@social_links, :tiktok)} label="TikTok">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M19.59 6.69a4.83 4.83 0 01-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 01-2.88 2.5 2.89 2.89 0 01-2.89-2.89 2.89 2.89 0 012.89-2.89c.28 0 .54.04.79.1v-3.5a6.37 6.37 0 00-.79-.05A6.34 6.34 0 003.15 15.2a6.34 6.34 0 0010.86 4.46V12.8a8.28 8.28 0 005.58 2.17V11.5a4.85 4.85 0 01-3.77-1.85V6.69h3.77z" />
                </svg>
              </.footer_social_icon>
            </div>
          </div>

          <%!-- Shop Links --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">
              Shop
            </h4>
            <ul class="space-y-3">
              <li>
                <a
                  href={store_path(@store.slug, "/products")}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  All Products
                </a>
              </li>
              <li :for={category <- Enum.take(@categories, 5)}>
                <a
                  href={store_path(@store.slug, "/category/#{category.slug}")}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  {category.name}
                </a>
              </li>
            </ul>
          </div>

          <%!-- Company --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">Company</h4>
            <ul class="space-y-3">
              <li :for={link <- @company_links}>
                <%= if Map.get(link, :url) do %>
                  <a
                    href={Map.get(link, :url)}
                    class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                  >
                    {Map.get(link, :label)}
                  </a>
                <% else %>
                  <span class="text-gray-500 text-sm inline-flex items-center min-h-[44px]">
                    {Map.get(link, :label)}
                  </span>
                <% end %>
              </li>
            </ul>
          </div>

          <%!-- Contact --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">
              Get in Touch
            </h4>
            <ul class="space-y-3">
              <li :if={Map.get(@store, :whatsapp_number)}>
                <a
                  href={"https://wa.me/#{@store.whatsapp_number}"}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center gap-2 min-h-[44px]"
                >
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
                </a>
              </li>
              <li :if={Map.get(@store, :contact_email)}>
                <a
                  href={"mailto:#{@store.contact_email}"}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center gap-2 min-h-[44px]"
                >
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    aria-hidden="true"
                  >
                    <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" /><polyline points="22,6 12,13 2,6" />
                  </svg>
                  {@store.contact_email}
                </a>
              </li>
              <li :if={Map.get(@store, :contact_phone)}>
                <a
                  href={"tel:#{@store.contact_phone}"}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center gap-2 min-h-[44px]"
                >
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    aria-hidden="true"
                  >
                    <path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72c.127.96.361 1.903.7 2.81a2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0122 16.92z" />
                  </svg>
                  {@store.contact_phone}
                </a>
              </li>
              <li>
                <a
                  href={store_path(@store.slug, "/about")}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  About Us
                </a>
              </li>
            </ul>
          </div>
        </div>

        <%!-- Payment Methods --%>
        <div class="border-t border-gray-800/60 mt-12 pt-8">
          <div class="flex flex-col sm:flex-row items-center justify-between gap-6">
            <div class="flex items-center gap-2 flex-wrap justify-center">
              <span class="text-[10px] uppercase tracking-widest text-gray-500 mr-2">We Accept</span>
              <.payment_badge label="MTN MoMo" color="#FFCC00" text_color="#000" />
              <.payment_badge label="Telecel Cash" color="#E60000" text_color="#fff" />
              <.payment_badge label="Visa" color="#1A1F71" text_color="#fff" />
              <.payment_badge label="Mastercard" color="#FF5F00" text_color="#fff" />
            </div>
            <div class="flex items-center gap-1.5 text-gray-500">
              <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              >
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0110 0v4" />
              </svg>
              <span class="text-[10px] uppercase tracking-widest">Secure Checkout</span>
            </div>
          </div>
        </div>

        <%!-- Bottom bar --%>
        <div class="border-t border-gray-800/60 mt-8 pt-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p class="text-gray-500 text-xs">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p class="text-gray-600 text-[10px]">
            Powered by <span class="font-semibold" style="color: var(--theme-primary);">Makola</span>
          </p>
        </div>
      </div>
    </footer>
    """
  end

  # ── Footer: Mega Variant ──

  attr :store, :map, required: true
  attr :categories, :list, required: true
  attr :brand_description, :string, required: true
  attr :company_links, :list, required: true
  attr :social_links, :map, required: true
  attr :heading_font, :string, required: true
  attr :btn_classes, :string, required: true

  defp footer_mega(assigns) do
    ~H"""
    <footer class="text-white" style="background-color: #111111;">
      <%!-- Top band: large brand statement --%>
      <div class="border-b border-gray-800/60">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-14 sm:py-20">
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-10 items-center">
            <div>
              <a
                href={store_path(@store.slug, "/")}
                class="inline-block text-2xl sm:text-3xl font-black tracking-tight mb-4 cursor-pointer transition-opacity duration-200 hover:opacity-80"
                style={"color: var(--theme-primary); font-family: #{@heading_font};"}
              >
                {@store.name}
              </a>
              <p class="text-gray-400 text-base sm:text-lg leading-relaxed max-w-lg">
                {@brand_description}
              </p>
            </div>
            <div class="lg:text-right">
              <a
                href={store_path(@store.slug, "/products")}
                class={"inline-flex items-center gap-2 px-8 py-4 text-sm font-bold uppercase tracking-wider #{@btn_classes} text-white transition-all duration-300 hover:opacity-90"}
                style="background: var(--theme-accent, #166534);"
              >
                Shop Now
                <svg
                  class="w-4 h-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2.5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                  />
                </svg>
              </a>
            </div>
          </div>
        </div>
      </div>

      <%!-- Middle: 5-column link grid --%>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div class="grid gap-8 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 lg:gap-6">
          <%!-- Shop --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">Shop</h4>
            <ul class="space-y-3">
              <li>
                <a
                  href={store_path(@store.slug, "/products")}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  All Products
                </a>
              </li>
              <li :for={category <- Enum.take(@categories, 5)}>
                <a
                  href={store_path(@store.slug, "/category/#{category.slug}")}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  {category.name}
                </a>
              </li>
            </ul>
          </div>

          <%!-- Collections --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">
              Collections
            </h4>
            <ul class="space-y-3">
              <li>
                <a
                  href={store_path(@store.slug, "/products")}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  View All
                </a>
              </li>
              <%!-- Both links carried a ?sort= param that nothing reads — the
                   product list has no sort handling at all — so "Best Sellers"
                   showed the plain catalogue under a bestseller label, ranked by
                   nothing. There is no sales ranking to link to, so that link is
                   gone. The list is already newest-first, so New Arrivals is
                   true once the dead param comes off. --%>
              <li>
                <a
                  href={store_path(@store.slug, "/products")}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  New Arrivals
                </a>
              </li>
            </ul>
          </div>

          <%!-- Company --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">Company</h4>
            <ul class="space-y-3">
              <li :for={link <- @company_links}>
                <%= if Map.get(link, :url) do %>
                  <a
                    href={Map.get(link, :url)}
                    class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                  >
                    {Map.get(link, :label)}
                  </a>
                <% else %>
                  <span class="text-gray-500 text-sm inline-flex items-center min-h-[44px]">
                    {Map.get(link, :label)}
                  </span>
                <% end %>
              </li>
            </ul>
          </div>

          <%!-- Contact --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">
              Get in Touch
            </h4>
            <ul class="space-y-3">
              <li :if={Map.get(@store, :whatsapp_number)}>
                <a
                  href={"https://wa.me/#{@store.whatsapp_number}"}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center gap-2 min-h-[44px]"
                >
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
                </a>
              </li>
              <li :if={Map.get(@store, :contact_email)}>
                <a
                  href={"mailto:#{@store.contact_email}"}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center gap-2 min-h-[44px]"
                >
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    aria-hidden="true"
                  >
                    <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" /><polyline points="22,6 12,13 2,6" />
                  </svg>
                  {@store.contact_email}
                </a>
              </li>
              <li :if={Map.get(@store, :contact_phone)}>
                <a
                  href={"tel:#{@store.contact_phone}"}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center gap-2 min-h-[44px]"
                >
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    aria-hidden="true"
                  >
                    <path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72c.127.96.361 1.903.7 2.81a2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0122 16.92z" />
                  </svg>
                  {@store.contact_phone}
                </a>
              </li>
              <li>
                <a
                  href={store_path(@store.slug, "/about")}
                  class="text-gray-400 hover:text-white text-sm transition-colors duration-200 cursor-pointer inline-flex items-center min-h-[44px]"
                >
                  About Us
                </a>
              </li>
            </ul>
          </div>

          <%!-- Social --%>
          <div>
            <h4 class="text-white text-xs font-semibold uppercase tracking-widest mb-5">Follow Us</h4>
            <div class="flex items-center gap-3 flex-wrap">
              <.footer_social_icon url={Map.get(@social_links, :instagram)} label="Instagram">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
                </svg>
              </.footer_social_icon>
              <.footer_social_icon url={Map.get(@social_links, :twitter)} label="Twitter">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                </svg>
              </.footer_social_icon>
              <.footer_social_icon url={Map.get(@social_links, :facebook)} label="Facebook">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
                </svg>
              </.footer_social_icon>
              <.footer_social_icon url={Map.get(@social_links, :tiktok)} label="TikTok">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <path d="M19.59 6.69a4.83 4.83 0 01-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 01-2.88 2.5 2.89 2.89 0 01-2.89-2.89 2.89 2.89 0 012.89-2.89c.28 0 .54.04.79.1v-3.5a6.37 6.37 0 00-.79-.05A6.34 6.34 0 003.15 15.2a6.34 6.34 0 0010.86 4.46V12.8a8.28 8.28 0 005.58 2.17V11.5a4.85 4.85 0 01-3.77-1.85V6.69h3.77z" />
                </svg>
              </.footer_social_icon>
            </div>
          </div>
        </div>

        <%!-- Payment Methods --%>
        <div class="border-t border-gray-800/60 mt-8 pt-8">
          <div class="flex flex-col sm:flex-row items-center justify-between gap-6">
            <div class="flex items-center gap-2 flex-wrap justify-center">
              <span class="text-[10px] uppercase tracking-widest text-gray-500 mr-2">We Accept</span>
              <.payment_badge label="MTN MoMo" color="#FFCC00" text_color="#000" />
              <.payment_badge label="Telecel Cash" color="#E60000" text_color="#fff" />
              <.payment_badge label="Visa" color="#1A1F71" text_color="#fff" />
              <.payment_badge label="Mastercard" color="#FF5F00" text_color="#fff" />
            </div>
            <div class="flex items-center gap-1.5 text-gray-500">
              <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              >
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0110 0v4" />
              </svg>
              <span class="text-[10px] uppercase tracking-widest">Secure Checkout</span>
            </div>
          </div>
        </div>

        <%!-- Bottom bar --%>
        <div class="border-t border-gray-800/60 mt-8 pt-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p class="text-gray-500 text-xs">
            &copy; {Date.utc_today().year} {@store.name}. All rights reserved.
          </p>
          <p class="text-gray-600 text-[10px]">
            Powered by <span class="font-semibold" style="color: var(--theme-primary);">Makola</span>
          </p>
        </div>
      </div>
    </footer>
    """
  end

  # ── Footer Social Icon ──

  attr :url, :string, default: nil
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp footer_social_icon(assigns) do
    ~H"""
    <%= if @url do %>
      <a
        href={@url}
        class="flex items-center justify-center w-11 h-11 rounded-full text-gray-500 hover:text-white transition-colors duration-200 cursor-pointer hover:bg-white/10"
        aria-label={@label}
        target="_blank"
        rel="noopener noreferrer"
      >
        {render_slot(@inner_block)}
      </a>
    <% else %>
      <span
        class="flex items-center justify-center w-11 h-11 rounded-full text-gray-500 hover:text-white transition-colors duration-200 cursor-pointer hover:bg-white/10"
        aria-label={@label}
      >
        {render_slot(@inner_block)}
      </span>
    <% end %>
    """
  end

  # ── Payment Badge ──

  attr :label, :string, required: true
  attr :color, :string, required: true
  attr :text_color, :string, default: "#fff"

  defp payment_badge(assigns) do
    ~H"""
    <span
      class="inline-flex items-center px-2.5 py-1 rounded text-[10px] font-bold tracking-wide"
      style={"background: #{@color}; color: #{@text_color};"}
    >
      {@label}
    </span>
    """
  end
end
