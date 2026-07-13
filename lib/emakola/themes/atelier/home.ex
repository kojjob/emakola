defmodule Emakola.Themes.Atelier.Home do
  @moduledoc """
  Atelier theme home page renderer — Stitch design reference.

  Sections (gated by `@theme.sections`):
  - Hero: Full-screen image bg, bold sans-serif heading, green CTAs
  - Categories: Horizontal scrolling circles
  - Products: Featured hero card + 2 smaller cards
  - Trust: Secure commerce section with payment partners
  - Newsletter: Email signup "Join the Artisan Circle"
  - Footer: Dark bg with store info and links
  """
  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]

  alias Phoenix.LiveView.JS
  alias Emakola.Themes.Atelier.Shared
  alias Emakola.Themes.Delivery
  alias Emakola.Themes.SectionRenderer

  @doc """
  Renders the full Atelier home page.

  Required assigns:
  - `@store` - Store struct
  - `@theme` - Theme config map with `:sections` map
  - `@products` - List of products
  - `@categories` - List of categories
  - `@cart_count` - Integer cart count
  """
  attr :store, :map, required: true
  attr :theme, :map, required: true
  attr :products, :list, default: []
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0

  def render(assigns) do
    assigns = assign(assigns, :theme_module, Emakola.Themes.Atelier)

    ~H"""
    <div class="atelier-body">
      <Shared.theme_styles theme={@theme} />

      <%!-- Announcement / Coupon Bar --%>
      <.announcement_bar
        public_coupons={assigns[:public_coupons] || []}
        store={@store}
        delivery_zones={assigns[:delivery_zones] || []}
      />

      <Shared.navbar
        store={@store}
        categories={@categories}
        cart_count={@cart_count}
        transparent={true}
      />

      {SectionRenderer.home(assigns)}

      <%!-- Footer --%>
      <Shared.footer
        store={@store}
        categories={@categories}
        theme={@theme}
        hide_newsletter={Shared.section_enabled?(@theme, :newsletter)}
      />
    </div>
    """
  end

  # ── Announcement Bar ──

  attr :public_coupons, :list, default: []
  attr :store, :map, required: true
  attr :delivery_zones, :list, default: []

  defp announcement_bar(assigns) do
    coupon = List.first(assigns.public_coupons)

    message =
      if coupon do
        format_coupon_message(coupon)
      else
        nil
      end

    assigns =
      assigns
      |> assign(:coupon, coupon)
      |> assign(:message, message)
      |> assign(:delivery_note, Delivery.callout(assigns))

    ~H"""
    <%!-- With no coupon running, this bar used to read "Free delivery in Accra &
         Kumasi on orders over GHS 100" — a promise every Atelier store made and
         none had authored. It now carries the store's own delivery terms, and
         when the store has neither a coupon nor a configured zone the bar has
         nothing true to say, so it does not render. --%>
    <div
      :if={@coupon || @delivery_note}
      id="announcement-bar"
      class="py-2 text-white text-center text-xs sm:text-sm relative"
      style="background-color: #B45309;"
    >
      <div class="max-w-7xl mx-auto px-8 sm:px-10">
        <%= if @coupon do %>
          <p>
            Use code <span class="font-bold">{@coupon.code}</span> for {@message}
          </p>
        <% else %>
          <p>{@delivery_note}</p>
        <% end %>
      </div>
      <button
        type="button"
        phx-click={
          JS.hide(
            to: "#announcement-bar",
            transition: {"ease-out duration-200", "opacity-100", "opacity-0"}
          )
        }
        class="absolute right-2 sm:right-4 top-1/2 -translate-y-1/2 text-white/80 hover:text-white p-1"
        aria-label="Dismiss announcement"
      >
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
        </svg>
      </button>
    </div>
    """
  end

  defp format_coupon_message(coupon) do
    case coupon.discount_type do
      :percentage ->
        percent = div(coupon.discount_value, 100)
        "#{percent}% off!"

      :fixed_amount ->
        cedis = div(coupon.discount_value, 100)
        pesewas = rem(coupon.discount_value, 100)

        if pesewas == 0 do
          "GHS #{cedis} off!"
        else
          "GHS #{cedis}.#{String.pad_leading("#{pesewas}", 2, "0")} off!"
        end

      :free_shipping ->
        "free shipping!"

      _ ->
        "a discount!"
    end
  end

  # ── Helpers ──

  @doc """
  Renders the merchant-supplied hero title safely: the text is HTML-escaped
  first (so markup in the title — e.g. `<img onerror=...>` — can't inject
  script onto the public storefront), then literal newlines become `<br>`
  breaks. Escaping before the replace means the only live tag in the output is
  the `<br>` we add.
  """
  def hero_title_html(title) do
    title
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace("\n", "<br>")
    |> raw()
  end
end
