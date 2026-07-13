defmodule Emakola.Themes.Spotlight.Sections.Ingredients do
  @moduledoc """
  Spotlight home ingredient breakdown — extracted verbatim from
  spotlight/home.ex.

  The rows are the theme's own `Spotlight.ingredients/0` content (not yet
  admin-editable). The heading defaults to the derived "<n> reasons it
  works" and can be replaced by a merchant heading.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Spotlight

  @impl true
  def key, do: "spotlight/ingredients"
  @impl true
  def label, do: "Ingredients"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :ingredients, Spotlight.ingredients())

    ~H"""
    <section id="ingredients" phx-hook="ScrollReveal" class="bg-white border-y border-[#ECE7DE]">
      <div class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <h2 class="spot-heading text-3xl font-bold mb-10">
          <%= if @settings["heading"] not in [nil, ""] do %>
            {@settings["heading"]}
          <% else %>
            {length(@ingredients)} reasons it works
          <% end %>
        </h2>
        <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-x-10 gap-y-8">
          <div :for={ing <- @ingredients} data-reveal class="border-t border-[#ECE7DE] pt-4">
            <h3 class="spot-heading text-lg font-semibold">{ing.name}</h3>
            <p class="text-sm text-[#6B675F] mt-1 leading-relaxed">{ing.description}</p>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
