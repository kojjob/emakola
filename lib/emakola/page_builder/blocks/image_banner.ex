defmodule Emakola.PageBuilder.Blocks.ImageBanner do
  @moduledoc """
  Single inline image banner. Optionally wraps the image in a link and shows
  a caption beneath. Useful for promotional banners, brand statement
  imagery, or in-page editorial breaks.

  ## Content fields

  | Field | Type | Default |
  |---|---|---|
  | `image_url` | string \\| nil | nil |
  | `alt` | string | "" |
  | `caption` | string \\| nil | nil |
  | `link_url` | string \\| nil | nil |
  | `aspect_ratio` | "16/9" \\| "21/9" \\| "4/3" \\| "1/1" | "16/9" |
  """

  @behaviour Emakola.PageBuilder.Block

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  @impl true
  def type, do: "image_banner"

  @impl true
  def name, do: "Image Banner"

  @impl true
  def icon, do: "image"

  @impl true
  def default_content do
    %{
      image_url: nil,
      alt: "",
      caption: nil,
      link_url: nil,
      aspect_ratio: "16/9"
    }
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :aspect_class, aspect_class(assigns.content[:aspect_ratio]))

    ~H"""
    <section class="py-8 sm:py-10 bg-[#FFFBEB]">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <%= if @content[:image_url] do %>
          <%= if @content[:link_url] do %>
            <a href={@content[:link_url]} class="block">
              <.banner_image content={@content} aspect_class={@aspect_class} />
            </a>
          <% else %>
            <.banner_image content={@content} aspect_class={@aspect_class} />
          <% end %>
          <p
            :if={@content[:caption]}
            class="mt-3 text-center text-sm text-[#78716C] italic"
            style="font-family: 'Inter', sans-serif;"
          >
            {@content[:caption]}
          </p>
        <% else %>
          <div class={["bg-[#FEF3C7]/40 rounded-2xl flex items-center justify-center", @aspect_class]}>
            <span class="material-symbols-outlined text-5xl text-[#D97706]/50">image</span>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  @impl true
  def edit_form(assigns) do
    ~H"""
    <p class="text-sm text-[#78716C]">
      Edit form coming in Phase 2 of the page builder.
    </p>
    """
  end

  attr :content, :map, required: true
  attr :aspect_class, :string, required: true

  defp banner_image(assigns) do
    ~H"""
    <div class={["overflow-hidden rounded-2xl", @aspect_class]}>
      <.optimized_image
        src={@content[:image_url]}
        alt={@content[:alt] || ""}
        class="w-full h-full object-cover"
      />
    </div>
    """
  end

  defp aspect_class("21/9"), do: "aspect-[21/9]"
  defp aspect_class("4/3"), do: "aspect-[4/3]"
  defp aspect_class("1/1"), do: "aspect-square"
  defp aspect_class(_), do: "aspect-[16/9]"
end
