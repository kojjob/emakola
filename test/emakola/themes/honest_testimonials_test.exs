defmodule Emakola.Themes.HonestTestimonialsTest do
  @moduledoc """
  Beauty and Spotlight shipped invented testimonials as theme defaults: named
  strangers ("Akua M., Accra") saying things nobody said, under a hardcoded
  five-star row, on every storefront that had not overridden them. A shop that
  had never sold a single item opened with four glowing reviews.

  This file is the lock on that door. A testimonial is a real review or it is
  not rendered.
  """
  use Emakola.DataCase, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Beauty.Sections.Testimonials, as: BeautyTestimonials
  alias Emakola.Themes.Spotlight.Sections.Testimonials, as: SpotlightTestimonials

  # Every invented person and phrase the two themes used to print.
  @invented [
    "Akua M.",
    "Nana A.",
    "Yaa K.",
    "Ama D.",
    "Kofi B.",
    "Esi M.",
    "My skin has never felt this soft",
    "Beautiful packaging, beautiful results",
    "Glow in a bottle",
    "Customer service is top-tier",
    "Exactly what I was looking for",
    "Quality you can feel",
    "Beautiful, honest product",
    "Loved by our community",
    "Loved by everyday people"
  ]

  defp review(attrs) do
    Map.merge(
      %{
        rating: 4,
        body: "The soap lasted a month. Worth it.",
        verified_purchase: true,
        customer: %{name: "Akosua Mensah"}
      },
      attrs
    )
  end

  defp render_section(module, testimonials) do
    %{
      store: %{slug: "shop", name: "Shop", currency: "GHS", description: nil},
      theme: %{},
      testimonials: testimonials,
      settings: %{"heading" => ""},
      __changed__: nil
    }
    |> module.render()
    |> rendered_to_string()
  end

  for {theme, module} <- [
        {"Beauty", BeautyTestimonials},
        {"Spotlight", SpotlightTestimonials}
      ] do
    describe "#{theme} testimonials" do
      @module module

      test "a store with no reviews shows no testimonials — and invents none" do
        html = render_section(@module, [])

        for lie <- @invented do
          refute html =~ lie, "still printing invented copy: #{lie}"
        end

        # No empty shell either: nothing to show means nothing rendered.
        refute html =~ "★"
        refute html =~ "<section"
      end

      test "a real review is quoted, in the reviewer's own words" do
        html =
          render_section(@module, [
            review(%{
              body: "The soap lasted a month. Worth it.",
              customer: %{name: "Akosua Mensah"}
            })
          ])

        assert html =~ "The soap lasted a month. Worth it."
        # First name only — the same convention the product page already uses.
        assert html =~ "Akosua"

        for lie <- @invented do
          refute html =~ lie
        end
      end

      # The stars were the sharpest lie: five of them, hardcoded, over quotes
      # that had no rating behind them at all.
      test "the stars are the reviewer's own rating, never a fixed five" do
        html = render_section(@module, [review(%{rating: 3})])

        assert html =~ ~s(aria-label="Rated 3 out of 5")
        refute html =~ "★★★★★"
      end

      test "an unnamed reviewer is not given an invented name" do
        html = render_section(@module, [review(%{customer: nil})])

        assert html =~ "Customer"

        for lie <- @invented do
          refute html =~ lie
        end
      end
    end
  end
end
