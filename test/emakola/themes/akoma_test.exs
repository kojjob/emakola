defmodule Emakola.Themes.AkomaTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeResolver

  describe "Shared" do
    setup do
      store = %{
        slug: "demo",
        name: "Demo Store",
        description: nil,
        currency: "GHS",
        whatsapp_number: "+233201234567"
      }

      theme = ThemeResolver.resolve(%{"theme" => "akoma"})
      %{store: store, theme: theme}
    end

    defp html(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

    test "nav renders the store name and cart count", %{store: store} do
      out =
        html(
          Emakola.Themes.Akoma.Shared.akoma_nav(%{__changed__: nil, store: store, cart_count: 2})
        )

      assert out =~ "Demo Store"
      assert out =~ "/s/demo/cart"
      assert out =~ "2"
    end

    test "footer renders the store name", %{store: store} do
      out = html(Emakola.Themes.Akoma.Shared.akoma_footer(%{__changed__: nil, store: store}))
      assert out =~ "Demo Store"
    end

    test "product_card links to the product and shows price", %{store: store} do
      product = %{
        slug: "tee",
        title: "Cotton Tee",
        min_price: 12_000,
        images: [],
        featured_rank: nil
      }

      out =
        html(
          Emakola.Themes.Akoma.Shared.product_card(%{
            __changed__: nil,
            store: store,
            product: product
          })
        )

      assert out =~ "/s/demo/products/tee"
      assert out =~ "Cotton Tee"
      assert out =~ "GH₵ 120"
    end

    test "whatsapp_link builds a wa.me url with digits only", %{store: store} do
      assert Emakola.Themes.Akoma.Shared.whatsapp_link(store, "Cotton Tee") =~
               "https://wa.me/233201234567"
    end

    test "whatsapp_link encodes special characters so the message isn't truncated", %{
      store: store
    } do
      link = Emakola.Themes.Akoma.Shared.whatsapp_link(store, "Salt & Pepper")
      text_param = link |> String.split("?text=") |> List.last()
      # The ampersand from the title must be percent-encoded, not a raw query separator
      refute String.contains?(text_param, "&")
      assert String.contains?(text_param, "Salt")
      assert String.contains?(text_param, "Pepper")
    end

    test "current_image/2 returns the medium url at the given index, falling back to url" do
      product = %{
        images: [
          %{medium_url: "m0.jpg", url: "u0.jpg"},
          %{medium_url: nil, url: "u1.jpg"}
        ]
      }

      assert Emakola.Themes.Akoma.Shared.current_image(product, 0) == "m0.jpg"
      assert Emakola.Themes.Akoma.Shared.current_image(product, 1) == "u1.jpg"
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

      theme = ThemeResolver.resolve(%{"theme" => "akoma"})

      ot = %{
        id: "ot1",
        name: "Size",
        option_values: [
          %{id: "ov_s", value: "S"},
          %{id: "ov_m", value: "M"},
          %{id: "ov_l", value: "L"}
        ]
      }

      product = %{
        title: "Linen Overshirt",
        slug: "linen-overshirt",
        description: "Garment-dyed linen.",
        images: [],
        min_price: 42_000,
        avg_rating: 4.5,
        review_count: 12,
        share_count: 0
      }

      variant = %{price: 42_000, compare_at_price: 52_000, stock_quantity: 3}

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
        selected_options: %{"ot1" => "ov_m"},
        quantity: 1,
        current_image_index: 0
      }

      %{assigns: assigns}
    end

    defp pdp_html(assigns),
      do:
        Emakola.Themes.Akoma.ProductDetail.render(assigns)
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

    test "renders title, formatted price, and the two CTAs", %{assigns: a} do
      out = pdp_html(a)
      assert out =~ "Linen Overshirt"
      assert out =~ "GH₵ 420"
      assert out =~ "Add to cart"
      assert out =~ "WhatsApp"
      assert out =~ "https://wa.me/233201234567"
    end

    test "renders option pills with the select_option contract", %{assigns: a} do
      out = pdp_html(a)
      assert out =~ ~s(phx-click="select_option")
      assert out =~ ~s(phx-value-option_type_id="ot1")
      assert out =~ ~s(phx-value-value="ov_m")
      assert out =~ "S"
      assert out =~ "M"
      assert out =~ "L"
    end

    test "shows sale badge and compare-at price when on sale", %{assigns: a} do
      out = pdp_html(a)
      assert out =~ "GH₵ 520"
      assert out =~ "Save"
    end

    test "renders a Decimal avg_rating correctly (Ash aggregate type)", %{assigns: a} do
      product = Map.put(a.product, :avg_rating, Decimal.new("4.5"))
      out = pdp_html(Map.put(a, :product, product))
      assert out =~ "4.5"
      refute out =~ "— ·"
      assert out =~ "★"
    end

    test "renders without raising when review assigns are absent (variants-test shape)", %{
      assigns: a
    } do
      assert is_binary(pdp_html(a))
    end

    test "renders the reviews block when review assigns are present", %{assigns: a} do
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

      out = pdp_html(a)
      assert out =~ "review" or out =~ "Review"
    end
  end

  describe "Home" do
    test "renders hero and featured products" do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS"}
      theme = ThemeResolver.resolve(%{"theme" => "akoma"})

      product = %{
        slug: "tee",
        title: "Cotton Tee",
        min_price: 12_000,
        images: [],
        featured_rank: nil
      }

      assigns = %{
        __changed__: nil,
        store: store,
        theme: theme,
        cart_count: 0,
        featured_products: [product],
        categories: []
      }

      out =
        Emakola.Themes.Akoma.Home.render(assigns)
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert out =~ "Demo Store"
      assert out =~ "Cotton Tee"
      assert out =~ "Shop the collection"
    end
  end

  describe "ProductList" do
    test "renders a grid of products" do
      store = %{slug: "demo", name: "Demo Store", description: nil, currency: "GHS"}
      theme = ThemeResolver.resolve(%{"theme" => "akoma"})

      products = [
        %{slug: "tee", title: "Cotton Tee", min_price: 12_000, images: [], featured_rank: nil},
        %{slug: "cap", title: "Wool Cap", min_price: 9_500, images: [], featured_rank: nil}
      ]

      assigns = %{
        __changed__: nil,
        store: store,
        theme: theme,
        cart_count: 0,
        products: products,
        categories: []
      }

      out =
        Emakola.Themes.Akoma.ProductList.render(assigns)
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert out =~ "Cotton Tee"
      assert out =~ "Wool Cap"
      assert out =~ "/s/demo/products/tee"
    end
  end

  describe "registration & contract" do
    test "resolver resolves the akoma theme with Forest colours" do
      config = ThemeResolver.resolve(%{"theme" => "akoma"})
      assert config.theme_id == "akoma"
      assert config.theme_name == "Akoma"
      assert config.colors.primary == "#1A1A1A"
      assert config.colors.accent == "#2F5D50"
      assert config.colors.background == "#F8F9F7"
    end

    test "implements the required ThemeBehaviour callbacks" do
      Code.ensure_loaded!(Emakola.Themes.Akoma)
      assert Emakola.Themes.Akoma.name() == "Akoma"

      for {fun, arity} <- [
            render_home: 1,
            render_product_list: 1,
            render_product_detail: 1,
            css_variables: 0,
            name: 0
          ] do
        assert function_exported?(Emakola.Themes.Akoma, fun, arity),
               "missing #{fun}/#{arity}"
      end
    end

    test "css_variables exposes the theme custom properties" do
      vars = Emakola.Themes.Akoma.css_variables()
      assert vars["--theme-primary"] == "#1A1A1A"
      assert vars["--theme-accent"] == "#2F5D50"
      assert vars["--theme-bg"] == "#F8F9F7"
    end
  end
end
