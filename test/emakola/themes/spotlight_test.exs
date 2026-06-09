defmodule Emakola.Themes.SpotlightTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeResolver

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

    test "ingredients/0 returns a non-empty list of name+description maps" do
      items = Emakola.Themes.Spotlight.ingredients()
      assert is_list(items) and length(items) >= 3
      assert Enum.all?(items, &(is_binary(&1.name) and is_binary(&1.description)))
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
end
