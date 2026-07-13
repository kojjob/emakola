defmodule Emakola.Themes.Spotlight.Sections.Testimonials do
  @moduledoc """
  Spotlight testimonials — the store's own published reviews.

  This section used to print three invented ones ("Ama D.", Accra — "Exactly
  what I was looking for.") shipped as theme defaults, under a literal
  `★★★★★` that stood for no rating at all. Every Spotlight storefront that
  had not overridden them opened with praise nobody had written.

  A testimonial is a real review now, or there is no section.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Spotlight.Shared
  alias Emakola.Themes.Testimonial

  @impl true
  def key, do: "spotlight/testimonials"
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
      :if={@reviews != [] && Shared.section_enabled?(@theme, :testimonials)}
      phx-hook="ScrollReveal"
      id="testimonials"
      class="max-w-[1200px] mx-auto px-4 sm:px-6 lg:px-8 py-16"
    >
      <h2 class="spot-heading text-3xl font-bold text-center mb-10">
        {if @settings["heading"] not in [nil, ""],
          do: @settings["heading"],
          else: "What buyers say"}
      </h2>
      <div class="grid md:grid-cols-3 gap-6">
        <figure
          :for={review <- @reviews}
          data-reveal
          class="rounded-2xl bg-white border border-[#ECE7DE] p-6"
        >
          <Testimonial.stars rating={review.rating} class="text-[var(--theme-accent,#7C3AED)]" />
          <blockquote class="text-sm text-[#16130F] mt-3 leading-relaxed">
            "{review.body}"
          </blockquote>
          <figcaption class="text-xs text-[#6B675F] mt-4 font-semibold">
            {Testimonial.name(review)}
            <span :if={review.verified_purchase} class="font-normal">· Verified purchase</span>
          </figcaption>
        </figure>
      </div>
    </section>
    """
  end
end
