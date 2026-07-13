defmodule Emakola.Themes.Beauty.Sections.Testimonials do
  @moduledoc """
  Beauty testimonials — the store's own published reviews.

  This section used to print four invented ones: named strangers ("Akua M.",
  Accra) saying things nobody said, under a hardcoded five-star row, shipped as
  theme defaults and rendered on every Beauty storefront that had not
  overridden them. A shop that had never sold a single jar opened with four
  glowing reviews and twenty stars.

  A testimonial is a real review now, or there is no section. The quote is the
  reviewer's words, the name is theirs (first name only, as the product page
  does it), and the stars are the rating they actually gave.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Testimonial

  @impl true
  def key, do: "beauty/testimonials"

  @impl true
  def label, do: "Testimonials"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :reviews, Testimonial.list(assigns))

    ~H"""
    <section
      :if={@reviews != [] && section_enabled?(@theme, :testimonials)}
      class="bg-[#F5EFE5] py-16 sm:py-24"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-12">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#8C5A24] mb-3">
            Reviews
          </p>
          <h2 class="beauty-heading text-4xl sm:text-5xl font-semibold text-[#3D2F25]">
            {if @settings["heading"] not in [nil, ""],
              do: @settings["heading"],
              else: "What buyers say"}
          </h2>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          <div :for={review <- @reviews} class="beauty-card p-6">
            <div class="w-12 h-12 rounded-full bg-[#C9925E]/30 flex items-center justify-center mb-4 text-[#6B4423] beauty-heading font-semibold">
              {String.first(Testimonial.name(review))}
            </div>
            <Testimonial.stars rating={review.rating} class="text-[#8C5A24] mb-3" />
            <p class="text-sm text-[#3D2F25] leading-relaxed mb-4 line-clamp-5">
              "{review.body}"
            </p>
            <p class="text-sm font-semibold text-[#6B4423]">{Testimonial.name(review)}</p>
            <p :if={review.verified_purchase} class="text-xs text-[#6B4423]/60">
              Verified purchase
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp section_enabled?(theme, name) do
    case get_in(theme, [:sections, name]) do
      false -> false
      _ -> true
    end
  end
end
