defmodule Emakola.Themes.Market.Sections.About do
  @moduledoc """
  Market home store story — initial avatar, description (neutral fallback),
  WhatsApp CTA when the store has a number.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Market.Components

  @impl true
  def key, do: "market/about"
  @impl true
  def label, do: "About"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-4 sm:px-6 sm:py-5 lg:px-8">
      <div class="mx-auto max-w-[1280px]">
        <Components.about_card store={@store} />
      </div>
    </div>
    """
  end
end
