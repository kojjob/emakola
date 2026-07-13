defmodule Emakola.Themes.HomeLiving.Sections.SaleBand do
  @moduledoc """
  Home Living terracotta feature band — extracted verbatim from
  home_living/home.ex.

  The items come from `@theme.sale_band.items` (icon/title/subtitle maps),
  which no flat setting type can express, so the section declares no settings
  and keeps reading the theme config. Still gated by the legacy
  `@theme.sections.sale_band` toggle underneath the section editor's own
  `enabled` flag.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Delivery
  alias Emakola.Themes.HomeLiving.Shared

  @impl true
  def key, do: "home_living/sale_band"
  @impl true
  def label, do: "Feature band"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :items, sale_band_items(assigns))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :sale_band)}
      class="bg-[#C2410C] py-6 sm:py-8 text-white"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 sm:gap-6">
          <div :for={item <- @items} class="flex items-center gap-3">
            <span class="material-symbols-outlined text-white" style="font-size: 32px;">
              {item.icon}
            </span>
            <div>
              <p class="text-sm font-bold leading-tight">{item.title}</p>
              <p class="text-[11px] text-white/75 leading-tight">{item.subtitle}</p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp sale_band_items(assigns) do
    case get_in(assigns.theme, [:sale_band, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_sale_band(assigns)
    end
  end

  # The band used to open with "Free Delivery — Orders GHS 500+" on every Home
  # Living store, a threshold no merchant had set. The delivery tile is now the
  # store's own (see `Emakola.Themes.Delivery`), and a store with no configured
  # zones simply doesn't get one.
  defp default_sale_band(assigns) do
    zones = Delivery.zones(assigns)

    delivery =
      cond do
        line = Delivery.free_delivery_detail(zones, assigns.store.currency) ->
          %{icon: "local_shipping", title: "Free delivery", subtitle: line}

        estimate = Delivery.estimate(zones) ->
          %{icon: "local_shipping", title: estimate, subtitle: Delivery.zone_names(zones)}

        true ->
          nil
      end

    Enum.reject(
      [
        delivery,
        %{icon: "verified_user", title: "Safe Payment", subtitle: "MoMo & cards"},
        %{icon: "schedule", title: "Daily Curation", subtitle: "Hand-picked"}
      ],
      &is_nil/1
    )
  end
end
