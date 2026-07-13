defmodule Emakola.Themes.Fashion.Sections.Ugc do
  @moduledoc """
  Fashion home "Worn by you." strip — the store's real customer photographs.

  It used to lay out six camera glyphs on a grey gradient: the shape of customer
  photography with nothing inside it, under an invitation to tag the shop. The
  theme shipped it switched off, which made it a trap rather than a feature — a
  merchant who opened the section editor, saw "Customer photos" in the list and
  enabled it got a wall of fake proof in one click, with no way to fill it with
  anything true.

  The photographs are real now: the ones customers attached to their reviews
  (`Catalog.Review.images`, the same list the product page renders under each
  review). Only published reviews count, so a review the merchant hid takes its
  photos down with it, and only a real purchaser can leave one.

  A store whose customers have posted no photographs gets no strip.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Fashion.Shared

  @impl true
  def key, do: "fashion/ugc"

  @impl true
  def label, do: "Customer photos"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :photos, photos(assigns))

    ~H"""
    <section
      :if={@photos != [] && Shared.section_enabled?(@theme, :ugc)}
      class="bg-[#FAF6EE] py-14 sm:py-20"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <p class="text-[11px] uppercase tracking-[0.3em] text-[#9A5B00] mb-3">
          Tag &commat;{String.downcase(String.replace(@store.name, " ", ""))}
        </p>
        <h2 class="fashion-display text-3xl sm:text-4xl lg:text-5xl text-[#1C1917] mb-10">
          Worn by you.
        </h2>
        <ul class="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-2 sm:gap-3">
          <li :for={photo <- @photos} class="aspect-square overflow-hidden bg-[#E7E5E4]">
            <.optimized_image
              src={photo_url(photo)}
              alt={photo_alt(photo)}
              class="w-full h-full object-cover"
            />
          </li>
        </ul>
      </div>
    </section>
    """
  end

  # Review images arrive as maps with STRING keys (they are stored as JSON), and
  # an entry with no usable url is dropped rather than rendered as a broken tile.
  defp photos(assigns) do
    assigns
    |> Map.get(:review_photos)
    |> List.wrap()
    |> Enum.filter(&is_binary(photo_url(&1)))
  end

  defp photo_url(photo) when is_map(photo) do
    Map.get(photo, "thumbnail_url") || Map.get(photo, "url")
  end

  defp photo_url(_photo), do: nil

  defp photo_alt(photo) when is_map(photo) do
    case Map.get(photo, "alt") do
      alt when is_binary(alt) and alt != "" -> alt
      _ -> "A customer's photo of what they bought"
    end
  end
end
