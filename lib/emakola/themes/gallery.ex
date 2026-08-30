defmodule Emakola.Themes.Gallery do
  @moduledoc """
  The product gallery every theme draws: a swipeable strip of photos with a
  thumbnail rail standing vertically beside it.

  Twenty-two themes each drew their own before this — `grid-cols-4` here,
  `grid-cols-5` there, a horizontal scroller in a third, and Market with a
  separate mobile path. Three consequences: the rail sat under the photo
  where a shopper's eye does not look for it, a phone could not swipe
  between photos at all, and a fix had to be made twenty-two times.

  ## The two things it has to do

  **Swipe.** The strip is a native scroll-snap container, so the gesture is
  the browser's own — no touch handlers, no momentum maths, and it works with
  a trackpad, a wheel and a keyboard as well as a thumb. On a slow Ghanaian
  connection that matters more than the code saved: nothing has to load
  before a swipe works.

  **A rail on the left.** From `sm` up the thumbnails stand vertically beside
  the photo. A phone has no width to spare, so `order-*` drops them to a
  horizontal strip beneath — the DOM order stays the reading order either
  way, so a screen reader meets the photo first on both.

  ## Keeping the two in step

  `GallerySwipe` (assets/js/hooks/gallery_swipe.js) carries the selection in
  the two directions the browser cannot: a thumbnail click reaches the server,
  which sets `data-current`, which scrolls the strip; a settled swipe pushes
  the landed index back. Both sides guard on the same comparison, so they
  never chase each other.

  The event is `select_image` with `%{"index" => "2"}` — the shape all
  twenty-two themes already handle, so adopting this component needs no new
  `handle_event`.

  ## Keeping each theme itself

  Everything a theme differs on is an attribute: the frame's shape, its
  ground, the aspect ratio, the thumbnail's active border. A theme passes its
  own and keeps its own look; only the behaviour is shared.
  """

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  attr :id, :string,
    default: "product-gallery",
    doc: """
    The hook keys on this. A product page shows one gallery, so the default
    is enough; it is not derived from the product because a theme's tests
    render bare maps that carry no id.
    """

  attr :images, :list,
    required: true,
    doc: "Ordered image structs with :url and optional variants."

  attr :current_index, :integer, default: 0
  attr :alt, :string, required: true, doc: "Product title; each slide gets its position appended."

  attr :aspect_class, :string,
    default: "aspect-square",
    doc: "The frame's shape. Tall themes pass aspect-[4/5]."

  attr :frame_class, :string,
    default: "rounded-2xl bg-slate-100",
    doc: "Radius and ground behind a photo that has not painted yet."

  attr :thumb_class, :string,
    default: "h-20 w-20 rounded-xl",
    doc: "Thumbnail size and radius."

  attr :thumb_active_class, :string, default: "border-slate-900"
  attr :thumb_idle_class, :string, default: "border-transparent hover:border-slate-300"
  attr :rail_class, :string, default: "sm:w-20", doc: "Rail width from sm up."

  slot :placeholder, doc: "Drawn in the frame when the product has no photo at all."

  def product_gallery(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 sm:flex-row sm:gap-4">
      <div
        :if={length(@images) > 1}
        class={[
          "order-2 flex gap-3 overflow-x-auto sm:order-1 sm:max-h-[560px] sm:flex-col",
          "sm:overflow-y-auto sm:overflow-x-visible",
          "[scrollbar-width:none] [&::-webkit-scrollbar]:hidden",
          @rail_class
        ]}
        aria-label="Product images"
      >
        <button
          :for={{image, index} <- Enum.with_index(@images)}
          type="button"
          phx-click="select_image"
          phx-value-index={index}
          aria-label={"Show image #{index + 1} of #{length(@images)}"}
          aria-current={index == @current_index && "true"}
          class={[
            "shrink-0 overflow-hidden border-2 bg-white transition-colors",
            @thumb_class,
            if(index == @current_index, do: @thumb_active_class, else: @thumb_idle_class)
          ]}
        >
          <img
            src={thumb_src(image)}
            alt={"#{@alt} #{index + 1}"}
            loading="lazy"
            class="h-full w-full object-cover"
          />
        </button>
      </div>

      <div class="order-1 min-w-0 flex-1 sm:order-2">
        <div
          :if={@images != []}
          id={@id}
          phx-hook="GallerySwipe"
          data-current={@current_index}
          role="group"
          aria-roledescription="carousel"
          aria-label={"#{@alt} photos"}
          class={[
            "flex snap-x snap-mandatory overflow-x-auto overflow-y-hidden",
            "[scrollbar-width:none] [&::-webkit-scrollbar]:hidden",
            @aspect_class,
            @frame_class
          ]}
        >
          <div
            :for={{image, index} <- Enum.with_index(@images)}
            class="h-full w-full shrink-0 snap-center"
            aria-label={"Image #{index + 1} of #{length(@images)}"}
          >
            <.optimized_image
              src={main_src(image)}
              alt={"#{@alt} #{index + 1}"}
              priority={if index == 0, do: :high, else: :auto}
              class="h-full w-full object-cover"
            />
          </div>
        </div>

        <div
          :if={@images == []}
          class={["flex items-center justify-center", @aspect_class, @frame_class]}
        >
          {render_slot(@placeholder)}
        </div>
      </div>
    </div>
    """
  end

  # Themes hand this component either an Image struct or a bare URL string —
  # Atelier resolves its own list to strings before rendering — so both are
  # accepted rather than forcing every theme to convert.
  #
  # The webp variant is preferred when the processor has made one; it is what
  # the card grids already use, and the strip loads every slide.
  defp main_src(image) when is_binary(image), do: image
  defp main_src(image), do: Map.get(image, :medium_url) || Map.get(image, :url)

  defp thumb_src(image) when is_binary(image), do: image
  defp thumb_src(image), do: Map.get(image, :thumbnail_url) || Map.get(image, :url)
end
