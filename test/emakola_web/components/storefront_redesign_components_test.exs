defmodule EmakolaWeb.StorefrontComponents.TrustBadgeTest do
  @moduledoc """
  Pins the contract for `<.trust_badge>` and `<.trust_badges_strip>` —
  the small icon+label pills used across the redesigned storefront to
  signal provenance, scarcity, and social proof.
  """
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  import EmakolaWeb.StorefrontComponents

  describe "trust_badge/1" do
    test "renders icon, label, and default neutral palette" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.trust_badge icon="verified" label="Verified Artisan" />
        """)

      assert html =~ "verified"
      assert html =~ "Verified Artisan"
      assert html =~ "material-symbols-outlined"
      assert html =~ "bg-slate-100"
      assert html =~ "text-slate-600"
    end

    test ":scarcity variant uses amber palette" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.trust_badge icon="bolt" label="Only 3 left" variant={:scarcity} />
        """)

      assert html =~ "bg-store-accent-light"
      assert html =~ "text-store-accent"
    end

    test ":provenance variant uses emerald palette" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.trust_badge icon="public" label="Made in Ghana" variant={:provenance} />
        """)

      assert html =~ "bg-emerald-100"
      assert html =~ "text-emerald-800"
    end

    test "merges caller-supplied class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.trust_badge icon="star" label="Bestseller" class="ml-2" />
        """)

      assert html =~ "ml-2"
    end
  end

  describe "trust_badges_strip/1" do
    test "renders one badge per entry with mixed variants" do
      assigns = %{
        badges: [
          %{icon: "public", label: "Made in Ghana", variant: :provenance},
          %{icon: "bolt", label: "Limited Edition", variant: :scarcity},
          %{icon: "verified", label: "Authenticated"}
        ]
      }

      html =
        rendered_to_string(~H"""
        <.trust_badges_strip badges={@badges} />
        """)

      assert html =~ "Made in Ghana"
      assert html =~ "Limited Edition"
      assert html =~ "Authenticated"
      assert html =~ "bg-emerald-100"
      assert html =~ "bg-store-accent-light"
      assert html =~ "bg-slate-100"
      assert html =~ ~s(role="list")
    end

    test "renders empty container when given an empty list" do
      assigns = %{badges: []}

      html =
        rendered_to_string(~H"""
        <.trust_badges_strip badges={@badges} />
        """)

      refute html =~ "trust-badge"
      assert html =~ ~s(role="list")
    end
  end
end

defmodule EmakolaWeb.StorefrontComponents.OccasionCollectionTileTest do
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  import EmakolaWeb.StorefrontComponents

  describe "occasion_collection_tile/1" do
    test "links to the category and shows category name by default" do
      assigns = %{
        category: %{name: "Kente", slug: "kente", image_url: nil},
        store_slug: "akosua-boutique"
      }

      html =
        rendered_to_string(~H"""
        <.occasion_collection_tile category={@category} store_slug={@store_slug} />
        """)

      assert html =~ ~s|href="/s/akosua-boutique/category/kente"|
      assert html =~ "Kente"
      assert html =~ "Browse"
    end

    test "occasion_label overrides display label" do
      assigns = %{
        category: %{name: "Special Occasions", slug: "special", image_url: nil},
        store_slug: "shop"
      }

      html =
        rendered_to_string(~H"""
        <.occasion_collection_tile
          category={@category}
          store_slug={@store_slug}
          occasion_label="For Celebrations"
        />
        """)

      assert html =~ "For Celebrations"
      refute html =~ ">Special Occasions<"
    end

    test "renders gradient fallback when image_url is nil" do
      assigns = %{
        category: %{name: "Bridal", slug: "bridal", image_url: nil},
        store_slug: "shop"
      }

      html =
        rendered_to_string(~H"""
        <.occasion_collection_tile category={@category} store_slug={@store_slug} />
        """)

      assert html =~ "from-(--color-store-accent)"
      assert html =~ "to-(--color-store-accent-bright)"
      refute html =~ "<img"
    end

    test "renders optimized image when image_url is present" do
      assigns = %{
        category: %{name: "Bridal", slug: "bridal", image_url: "/uploads/bridal.jpg"},
        store_slug: "shop"
      }

      html =
        rendered_to_string(~H"""
        <.occasion_collection_tile category={@category} store_slug={@store_slug} />
        """)

      assert html =~ ~s(src="/uploads/bridal.jpg")
      assert html =~ ~s(alt="Bridal")
    end
  end
end

defmodule EmakolaWeb.StorefrontComponents.ArtisanSignatureCardTest do
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  import EmakolaWeb.StorefrontComponents

  describe "artisan_signature_card/1" do
    test "renders default headline, name, and bio" do
      assigns = %{
        store: %{
          name: "Akosua's Boutique",
          description: "Handmade Ankara fashion from Accra.",
          logo_url: nil,
          city: nil,
          region: nil,
          whatsapp_number: nil
        }
      }

      html =
        rendered_to_string(~H"""
        <.artisan_signature_card store={@store} />
        """)

      assert html =~ "Meet the Artisan"
      assert html =~ "Akosua&#39;s Boutique"
      assert html =~ "Handmade Ankara fashion from Accra."
    end

    test "honors custom headline" do
      assigns = %{
        store: %{
          name: "Maker",
          description: nil,
          logo_url: nil,
          city: nil,
          region: nil,
          whatsapp_number: nil
        }
      }

      html =
        rendered_to_string(~H"""
        <.artisan_signature_card store={@store} headline="The Story Behind" />
        """)

      assert html =~ "The Story Behind"
      refute html =~ "Meet the Artisan"
    end

    test "renders initial avatar when logo_url is nil" do
      assigns = %{
        store: %{
          name: "Selasi",
          description: nil,
          logo_url: nil,
          city: nil,
          region: nil,
          whatsapp_number: nil
        }
      }

      html =
        rendered_to_string(~H"""
        <.artisan_signature_card store={@store} />
        """)

      refute html =~ "<img"
      # initial appears inside an avatar span; tolerate surrounding whitespace
      assert html =~ ~r/>\s*S\s*</
    end

    test "renders avatar image when logo_url is present" do
      assigns = %{
        store: %{
          name: "Studio Ako",
          description: nil,
          logo_url: "/uploads/avatar.jpg",
          city: nil,
          region: nil,
          whatsapp_number: nil
        }
      }

      html =
        rendered_to_string(~H"""
        <.artisan_signature_card store={@store} />
        """)

      assert html =~ ~s(src="/uploads/avatar.jpg")
    end

    test "renders city · region location line when both present" do
      assigns = %{
        store: %{
          name: "Maker",
          description: nil,
          logo_url: nil,
          city: "Accra",
          region: "Greater Accra",
          whatsapp_number: nil
        }
      }

      html =
        rendered_to_string(~H"""
        <.artisan_signature_card store={@store} />
        """)

      assert html =~ "Accra, Greater Accra"
      assert html =~ "location_on"
    end

    test "omits location line when both city and region are nil/blank" do
      assigns = %{
        store: %{
          name: "Maker",
          description: nil,
          logo_url: nil,
          city: nil,
          region: nil,
          whatsapp_number: nil
        }
      }

      html =
        rendered_to_string(~H"""
        <.artisan_signature_card store={@store} />
        """)

      refute html =~ "location_on"
    end

    test "renders WhatsApp link with normalised number when whatsapp_number present" do
      assigns = %{
        store: %{
          name: "Maker",
          description: nil,
          logo_url: nil,
          city: nil,
          region: nil,
          whatsapp_number: "+233 (24) 555-1234"
        }
      }

      html =
        rendered_to_string(~H"""
        <.artisan_signature_card store={@store} />
        """)

      assert html =~ ~s(href="https://wa.me/233245551234")
      assert html =~ "Message on WhatsApp"
    end

    test "omits WhatsApp link when whatsapp_number is nil" do
      assigns = %{
        store: %{
          name: "Maker",
          description: nil,
          logo_url: nil,
          city: nil,
          region: nil,
          whatsapp_number: nil
        }
      }

      html =
        rendered_to_string(~H"""
        <.artisan_signature_card store={@store} />
        """)

      refute html =~ "wa.me"
    end
  end
end

defmodule EmakolaWeb.StorefrontComponents.PatternDividerTest do
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  import EmakolaWeb.StorefrontComponents

  describe "pattern_divider/1" do
    test "renders kente motif by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pattern_divider />
        """)

      assert html =~ "<svg"
      assert html =~ "stroke-(--color-store-accent)"
      assert html =~ "stroke-(--color-store-accent-bright)"
      assert html =~ ~s(aria-hidden="true")
    end

    test ":ankara variant renders distinct motif" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pattern_divider variant={:ankara} />
        """)

      assert html =~ "<circle"
      assert html =~ "fill-(--color-store-accent)"
      assert html =~ "fill-(--color-store-accent-bright)"
    end

    test ":none variant renders only a hairline rule with a single dot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pattern_divider variant={:none} />
        """)

      refute html =~ "<svg"
      assert html =~ "rounded-full"
      assert html =~ "bg-stone-200"
    end

    test "merges caller-supplied class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.pattern_divider class="my-12" />
        """)

      assert html =~ "my-12"
    end
  end
end
