defmodule Emakola.Themes.Market.Sections.About do
  @moduledoc """
  Market home store story — the merchant's description and a WhatsApp CTA
  when the store has a number. Renders nothing when the merchant has not
  written a description: no stock sentence speaks for them.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Layout
  alias Emakola.Themes.Market.Components

  @impl true
  def key, do: "market/about"
  @impl true
  def label, do: "About"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.of(assigns))

    ~H"""
    <div :if={@layout.show_about?} class="px-4 py-4 sm:px-6 sm:py-5 lg:px-8">
      <div class="mx-auto max-w-[1280px]">
        <Components.about_card store={@store} />
      </div>
    </div>
    """
  end
end
