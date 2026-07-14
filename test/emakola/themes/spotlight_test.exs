defmodule Emakola.Themes.SpotlightTest do
  # async: false — the Home tests render through SectionRenderer, which
  # resolves "spotlight/*" keys through the section registry. Spotlight is
  # registered centrally (Sections.@sectionized_themes) once the theme
  # fan-out lands; until then this test registers it through the
  # :extra_sectionized_themes application-env seam (global state), the same
  # way sika_test.exs does.
  use ExUnit.Case, async: false

  alias Emakola.Themes.ThemeResolver

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Emakola.Themes.Spotlight])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  describe "registration & contract" do
    test "resolver resolves spotlight with the light palette" do
      config = ThemeResolver.resolve(%{"theme" => "spotlight"})
      assert config.theme_id == "spotlight"
      assert config.theme_name == "Spotlight"
      assert config.colors.background == "#FBF9F5"
      assert config.colors.accent == "#7C3AED"
    end

    test "implements required ThemeBehaviour callbacks" do
      Code.ensure_loaded!(Emakola.Themes.Spotlight)
      assert Emakola.Themes.Spotlight.name() == "Spotlight"

      for {fun, arity} <- [
            render_home: 1,
            render_product_list: 1,
            render_product_detail: 1,
            css_variables: 0,
            name: 0
          ] do
        assert function_exported?(Emakola.Themes.Spotlight, fun, arity), "missing #{fun}/#{arity}"
      end
    end

    test "css_variables exposes theme custom properties" do
      vars = Emakola.Themes.Spotlight.css_variables()
      assert vars["--theme-bg"] == "#FBF9F5"
      assert vars["--theme-accent"] == "#7C3AED"
    end

    test "ingredients/1 returns what the merchant wrote, and nothing otherwise" do
      # Five were hardcoded here ("Made simply — clean, honest components",
      # "Fairly priced", "Made to last") and printed on every Spotlight store's
      # products. Claims about manufacture, materials and pricing, for goods the
      # platform has never seen.
      assert Emakola.Themes.Spotlight.ingredients() == []
      assert Emakola.Themes.Spotlight.ingredients(%{ingredients: %{items: []}}) == []

      written = [%{name: "Cold-pressed", description: "Pressed the morning it ships."}]

      assert Emakola.Themes.Spotlight.ingredients(%{ingredients: %{items: written}}) == written
    end
  end

  describe "Shared" do
    setup do
      store = %{
        slug: "demo",
        name: "Demo Store",
        description: nil,
        currency: "GHS",
        whatsapp_number: "+233201234567"
      }

      theme = ThemeResolver.resolve(%{"theme" => "spotlight"})
      %{store: store, theme: theme}
    end

    defp shtml(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

    test "nav renders store name + cart link/count", %{store: store} do
      out =
        shtml(
          Emakola.Themes.Spotlight.Shared.nav(%{__changed__: nil, store: store, cart_count: 3})
        )

      assert out =~ "Demo Store"
      assert out =~ "/s/demo/cart"
      assert out =~ "3"
    end

    test "footer renders store name", %{store: store} do
      out = shtml(Emakola.Themes.Spotlight.Shared.footer(%{__changed__: nil, store: store}))
      assert out =~ "Demo Store"
    end

    test "product_card links + price", %{store: store} do
      product = %{slug: "tee", title: "Cotton Tee", min_price: 12_000, images: []}

      out =
        shtml(
          Emakola.Themes.Spotlight.Shared.product_card(%{
            __changed__: nil,
            store: store,
            product: product
          })
        )

      assert out =~ "/s/demo/products/tee"
      assert out =~ "Cotton Tee"
      assert out =~ "GH₵ 120"
    end

    test "whatsapp_link encodes special chars (no raw &)", %{store: store} do
      link = Emakola.Themes.Spotlight.Shared.whatsapp_link(store, "Salt & Pepper")
      text = link |> String.split("?text=") |> List.last()
      refute String.contains?(text, "&")
    end

    test "section_enabled? respects toggles" do
      theme =
        ThemeResolver.resolve(%{"theme" => "spotlight", "sections" => %{"newsletter" => false}})

      refute Emakola.Themes.Spotlight.Shared.section_enabled?(theme, :newsletter)
      assert Emakola.Themes.Spotlight.Shared.section_enabled?(theme, :testimonials)
    end
  end

  describe "ProductDetail" do
    setup do
      store = %{
        slug: "demo",
        name: "Demo Store",
        description: nil,
        currency: "GHS",
        whatsapp_number: "+233201234567"
      }

      theme = ThemeResolver.resolve(%{"theme" => "spotlight"})

      ot = %{
        id: "ot1",
        name: "Taste",
        option_values: [%{id: "ov_b", value: "Blueberry"}, %{id: "ov_m", value: "Mint"}]
      }

      product = %{
        title: "Lively Drink",
        slug: "lively",
        description: "A sparkling drink.",
        images: [],
        min_price: 9900,
        avg_rating: 4.8,
        review_count: 18,
        share_count: 0
      }

      variant = %{price: 9900, compare_at_price: nil, stock_quantity: 12}

      assigns = %{
        __changed__: nil,
        store: store,
        theme: theme,
        product: product,
        related_products: [],
        categories: [],
        cart_count: 0,
        selected_variant: variant,
        option_types: [ot],
        selected_options: %{"ot1" => "ov_b"},
        quantity: 1,
        current_image_index: 0
      }

      %{assigns: assigns}
    end

    defp spdp(assigns),
      do:
        Emakola.Themes.Spotlight.ProductDetail.render(assigns)
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

    test "renders title, price, CTAs, taste pills, sections", %{assigns: a} do
      out = spdp(a)
      assert out =~ "Lively Drink"
      assert out =~ "GH₵ 99"
      assert out =~ "Add to cart"
      assert out =~ "https://wa.me/233201234567"
      assert out =~ ~s(phx-click="select_option")
      assert out =~ ~s(phx-value-value="ov_b")
      assert out =~ "Blueberry"
      assert out =~ "Mint"
    end

    test "renders the benefits and ingredients the MERCHANT wrote", %{assigns: a} do
      theme =
        a.theme
        |> Map.put(:trust, %{
          title: "What makes it different",
          items: [
            %{icon: "eco", title: "Cold-pressed", description: "Pressed the morning it ships."}
          ]
        })
        |> Map.put(:ingredients, %{
          items: [%{name: "Two ingredients", description: "Fruit and water. That is the list."}]
        })

      out = spdp(%{a | theme: theme})

      assert out =~ "Cold-pressed"
      assert out =~ "Two ingredients"
    end

    test "a merchant who wrote no claims has none made for them", %{assigns: a} do
      out = spdp(a)

      # "Radical transparency", "Made simply", "Fairly priced" and the rest were
      # theme defaults on every Spotlight product page.
      refute out =~ "Radical transparency"
      refute out =~ "reasons it works"
    end

    test "no raise when review assigns absent (variants-test shape)", %{assigns: a} do
      assert is_binary(spdp(a))
    end

    test "renders reviews block when review assigns present", %{assigns: a} do
      a =
        Map.merge(a, %{
          reviews: [],
          can_review: false,
          already_reviewed: false,
          review_form_rating: 0,
          review_form_title: "",
          review_form_body: "",
          review_submitting: false,
          uploads: nil
        })

      assert spdp(a) =~ "review" or spdp(a) =~ "Review"
    end

    test "handles Decimal avg_rating", %{assigns: a} do
      a = put_in(a, [:product, :avg_rating], Decimal.new("4.8"))
      out = spdp(a)
      assert out =~ "4.8"
      assert out =~ "★"
    end
  end

  describe "ProductList" do
    test "renders product grid + empty state" do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS"}
      theme = ThemeResolver.resolve(%{"theme" => "spotlight"})

      products = [
        %{slug: "a", title: "Alpha", min_price: 1000, images: []},
        %{slug: "b", title: "Beta", min_price: 2000, images: []}
      ]

      out =
        Emakola.Themes.Spotlight.ProductList.render(%{
          __changed__: nil,
          store: store,
          theme: theme,
          cart_count: 0,
          products: products,
          categories: []
        })
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert out =~ "Alpha"
      assert out =~ "Beta"
      assert out =~ "/s/demo/products/a"

      empty =
        Emakola.Themes.Spotlight.ProductList.render(%{
          __changed__: nil,
          store: store,
          theme: theme,
          cart_count: 0,
          products: [],
          categories: []
        })
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert empty =~ "No products yet"
    end
  end

  describe "Home" do
    test "renders hero from first product and funnels to its page" do
      # The home renders its blocks through SectionRenderer, which reads the
      # store's saved section layout — so the stand-in store carries the
      # :id and :theme_config every real Store has. Empty theme_config means
      # "never touched the editor", i.e. the theme's default section order.
      store = %{
        id: "store-demo",
        slug: "demo",
        name: "Demo Store",
        description: nil,
        currency: "GHS",
        theme_config: %{}
      }

      theme = ThemeResolver.resolve(%{"theme" => "spotlight"})
      product = %{slug: "lively", title: "Lively Drink", min_price: 9900, images: []}

      assigns = %{
        __changed__: nil,
        store: store,
        theme: theme,
        cart_count: 0,
        products: [product],
        categories: []
      }

      out =
        Emakola.Themes.Spotlight.Home.render(assigns)
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert out =~ "Lively Drink"
      assert out =~ "/s/demo/products/lively"
    end

    test "empty products renders a coming-soon hero without raising" do
      store = %{
        id: "store-demo",
        slug: "demo",
        name: "Demo Store",
        description: nil,
        currency: "GHS",
        theme_config: %{}
      }

      theme = ThemeResolver.resolve(%{"theme" => "spotlight"})

      assigns = %{
        __changed__: nil,
        store: store,
        theme: theme,
        cart_count: 0,
        products: [],
        categories: []
      }

      out =
        Emakola.Themes.Spotlight.Home.render(assigns)
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert is_binary(out)
      assert out =~ "Demo Store"
    end

    test "hides newsletter when disabled" do
      store = %{
        id: "store-demo",
        slug: "demo",
        name: "Demo Store",
        description: nil,
        currency: "GHS",
        theme_config: %{}
      }

      theme =
        ThemeResolver.resolve(%{"theme" => "spotlight", "sections" => %{"newsletter" => false}})

      assigns = %{
        __changed__: nil,
        store: store,
        theme: theme,
        cart_count: 0,
        products: [],
        categories: []
      }

      out =
        Emakola.Themes.Spotlight.Home.render(assigns)
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      refute out =~ (get_in(theme, [:newsletter, :title]) || "Stay in the loop")
    end
  end
end
