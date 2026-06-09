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
