defmodule Emakola.Themes.AdwumaTest do
  @moduledoc """
  Adwuma sells files, so what can go wrong here is different from a
  photo-led theme. Two rules carry most of the weight:

  * the offer band must render **nothing** unless a real merchant-authored
    deadline exists — a countdown nothing enforces is fabricated urgency, and
  * the PDP's fulfilment line must branch on the product's own type, with the
    delivery path as the default, so a physical product can never lose its
    delivery terms and a download can never be promised delivery it has none of.
  """
  use Emakola.DataCase, async: false

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Adwuma
  alias Emakola.Themes.Adwuma.Sections.{Collection, Formats, Hero, Offer, Testimonials}

  @store %{
    slug: "adwuma",
    name: "Kwame Beats",
    currency: "GHS",
    description: nil,
    whatsapp_number: nil,
    enabled_product_types: [:physical, :digital_download]
  }

  defp settings_for(module) do
    Map.new(module.settings_schema(), &{&1.key, &1.default})
  end

  defp render_section(module, extra \\ %{}) do
    base = %{
      __changed__: nil,
      store: @store,
      theme: Adwuma.defaults(),
      settings: settings_for(module),
      section_meta: %{},
      products: [],
      categories: []
    }

    base |> Map.merge(extra) |> module.render() |> rendered_to_string()
  end

  describe "identity" do
    test "declares the contract functions callers invoke unguarded" do
      assert Adwuma.id() == "adwuma"
      assert Adwuma.name() == "Adwuma"
      assert Adwuma.renderer(:home) == Emakola.Themes.Adwuma.Home
      assert Adwuma.renderer(:product_list) == Emakola.Themes.Adwuma.ProductList
      assert Adwuma.renderer(:product_detail) == Emakola.Themes.Adwuma.ProductDetail
      assert Adwuma.renderer(:shared) == Emakola.Themes.Adwuma.Shared
    end

    # ThemeResolver.resolve/2 dot-accesses these. A missing one raises a
    # KeyError on every storefront request, not just one section.
    test "defaults carry every key the resolver and pickers dot-access" do
      defaults = Adwuma.defaults()

      assert defaults.colors.primary
      assert defaults.colors.accent
      assert defaults.fonts.heading
      assert defaults.trust
      assert defaults.newsletter
      assert defaults.hero
      assert defaults.nav
      assert defaults.sections
      assert defaults.footer
    end

    test "every font URL asks for display=swap" do
      for url <- Adwuma.fonts(), do: assert(url =~ "display=swap")
    end

    test "section keys are prefixed and unique" do
      keys = Enum.map(Adwuma.sections(), & &1.key())

      assert Enum.all?(keys, &String.starts_with?(&1, "adwuma/"))
      assert keys == Enum.uniq(keys)
    end

    # One schema entry without a default crashes DesignSectionsLive's
    # coerce_value/2 — and a merchant's draft lives only in socket assigns
    # until Publish, so the crash destroys unpublished work.
    test "every setting declares a default" do
      for module <- Adwuma.sections(), setting <- module.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{module}.#{setting.key} has no default"
      end
    end
  end

  describe "zero-input completeness" do
    test "the hero renders a heading with nothing configured" do
      html = render_section(Hero)

      assert html =~ "adwuma-hero-heading"
      assert html =~ "Kwame Beats"
    end

    test "the hero subheading is the store description when the merchant set none" do
      refute render_section(Hero) =~ "mt-4 max-w-xl"

      html = render_section(Hero, %{store: %{@store | description: "Beats cut in Kumasi."}})

      assert html =~ "Beats cut in Kumasi."
    end

    test "formats derives from the store's own enabled types" do
      assert render_section(Formats) =~ "Downloads"
    end

    test "formats renders nothing for a physical-only shop" do
      html = render_section(Formats, %{store: %{@store | enabled_product_types: [:physical]}})

      refute html =~ "Downloads"
    end

    test "the collection band renders nothing with no products" do
      refute render_section(Collection) =~ "New in"
    end

    test "testimonials render nothing without real reviews" do
      refute render_section(Testimonials) =~ "What buyers say"
    end
  end

  describe "the offer band is bound to a real deadline" do
    test "renders nothing when there is no public coupon" do
      html = render_section(Offer)

      refute html =~ "Ends soon"
      refute html =~ "Ends"
    end

    test "renders nothing when a public coupon has no expiry" do
      coupon = %{code: "WELCOME", discount_type: :percentage, discount_value: 10, expires_at: nil}

      refute render_section(Offer, %{public_coupons: [coupon]}) =~ "Ends soon"
    end

    test "renders the merchant's real code and deadline when one exists" do
      expires = DateTime.new!(~D[2026-08-08], ~T[18:00:00], "Etc/UTC")

      coupon = %{
        code: "AUGUST10",
        discount_type: :percentage,
        discount_value: 10,
        expires_at: expires
      }

      html = render_section(Offer, %{public_coupons: [coupon]})

      assert html =~ "AUGUST10"
      assert html =~ "10% off"
      assert html =~ "Ends"
    end
  end
end
