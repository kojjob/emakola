defmodule Emakola.Themes.Atelier.Sections.DeliveryZones do
  @moduledoc "Atelier home delivery zones bar -- extracted verbatim from atelier/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "atelier/delivery_zones"
  @impl true
  def label, do: "Delivery Zones"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    zone_names =
      case assigns[:delivery_zones] || [] do
        [] -> nil
        zones -> zones |> Enum.map(& &1.name) |> Enum.join(", ")
      end

    assigns = assign(assigns, :zone_names, zone_names)

    ~H"""
    <div class="bg-gray-50 border-y border-gray-100">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3 sm:py-4">
        <div class="flex items-center justify-center gap-2 text-gray-600 text-xs sm:text-sm">
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="flex-shrink-0 text-gray-400"
          >
            <rect x="1" y="3" width="15" height="13" rx="2" ry="2" />
            <polygon points="16 8 20 8 23 11 23 16 16 16 16 8" />
            <circle cx="5.5" cy="18.5" r="2.5" />
            <circle cx="18.5" cy="18.5" r="2.5" />
          </svg>
          <%= if @zone_names do %>
            <span>We deliver to: <span class="font-medium text-gray-700">{@zone_names}</span></span>
          <% else %>
            <span>Delivery across Ghana</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
