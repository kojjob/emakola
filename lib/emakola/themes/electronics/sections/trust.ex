defmodule Emakola.Themes.Electronics.Sections.Trust do
  @moduledoc """
  Electronics home trust statement — a centred statement on cream.

  Its default subheading used to read "Genuine products. 1-year warranty. Free
  shipping." — three promises the merchant never made, on a theme any reseller
  could install. There is no warranty data model, so the warranty claim is gone
  outright; the delivery line is now the store's OWN (see
  `Emakola.Themes.Delivery`), and a store with no configured zones points at
  its policies page instead.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import Emakola.Themes.Electronics.Sections.Helpers
  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Delivery

  @impl true
  def key, do: "electronics/trust"
  @impl true
  def label, do: "Trust statement"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :string, label: "Subheading", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    zones = Delivery.zones(assigns)

    assigns =
      assigns
      |> assign(:heading, setting(assigns[:settings], "heading", trust_title(assigns.theme)))
      |> assign(
        :subheading,
        setting(assigns[:settings], "subheading", trust_subtitle(assigns.theme, zones, assigns))
      )
      |> assign(:has_zones, zones != [])
      |> assign(:policies_href, store_path(assigns.store.slug, "/policies#shipping"))

    ~H"""
    <%!-- TRUST STATEMENT --%>
    <section :if={section_enabled?(@theme, :trust)} class="bg-[#F5EFE5] py-14 sm:py-20">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 class="electronics-heading text-2xl sm:text-3xl lg:text-4xl font-bold text-[#134E4A] leading-tight mb-3">
          {@heading}
        </h2>
        <p class="text-base text-[#4B5563] leading-relaxed">
          {@subheading}
        </p>
        <p :if={!@has_zones} class="mt-3 text-sm">
          <a
            href={@policies_href}
            class="text-[#4B5563] underline decoration-[#9CA3AF] underline-offset-2 hover:text-[#134E4A] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#0EA5E9] rounded"
          >
            See this store's delivery and returns policies
          </a>
        </p>
      </div>
    </section>
    """
  end

  defp trust_title(theme), do: get_in(theme, [:trust, :title]) || "Why thousands trust us"

  defp trust_subtitle(theme, zones, assigns) do
    get_in(theme, [:trust, :subtitle]) || derived_subtitle(zones, assigns)
  end

  defp derived_subtitle(zones, assigns) do
    delivery =
      Delivery.free_delivery_line(zones, assigns.store.currency) ||
        case Delivery.estimate(zones) do
          nil -> nil
          estimate -> "Delivery to #{Delivery.zone_names(zones)} — #{String.downcase(estimate)}"
        end

    case delivery do
      nil -> "Secure checkout with mobile money and card."
      line -> "#{line}. Secure checkout with mobile money and card."
    end
  end
end
