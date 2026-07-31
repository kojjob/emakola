defmodule Emakola.Themes.DefaultRendererConsistencyTest do
  @moduledoc """
  Pins the default-renderer pattern so future LiveViews and renderer
  modules stay consistent. Two contracts:

    1. Every default renderer module exports a `render/1` function.
    2. Every default renderer's source mounts both nav (`Chrome.navbar`)
       and footer (`Chrome.footer`) — the dispatcher that renders the
       active theme's own chrome and falls back to Atelier's.

  These checks would have caught the cart-without-navbar bug at PR
  time instead of in production. They're cheap (read source files,
  no module loading) and run with the rest of `mix test`.
  """
  use ExUnit.Case, async: true

  @default_renderers_dir "lib/emakola/themes/default_renderers"

  # Renderers that intentionally don't carry the shared nav+footer
  # (focused conversion-flow pages where site chrome would distract
  # the customer from completing the action).
  @nav_footer_exempt ~w(checkout.ex)

  defp renderer_files do
    @default_renderers_dir
    |> Path.expand()
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".ex"))
    # chrome.ex is the shared nav/footer dispatcher, not a page renderer
    |> Enum.reject(&(&1 == "chrome.ex"))
    |> Enum.map(&Path.join(@default_renderers_dir, &1))
  end

  defp nav_footer_renderer_files do
    Enum.reject(renderer_files(), &(Path.basename(&1) in @nav_footer_exempt))
  end

  describe "default renderer pattern" do
    test "every renderer module exports render/1" do
      for file <- renderer_files() do
        source = File.read!(file)

        assert source =~ ~r/def render\(assigns\)/,
               "#{Path.basename(file)} must define `def render(assigns)`"
      end
    end

    test "every renderer mounts the shared navbar" do
      for file <- nav_footer_renderer_files() do
        source = File.read!(file)

        assert source =~ ~r/Chrome\.navbar/,
               """
               #{Path.basename(file)} must mount the theme-dispatched navbar.

               Add at the top of render/1:

                   <Emakola.Themes.DefaultRenderers.Chrome.navbar
                     theme_module={assigns[:theme_module]}
                     store={@store}
                     categories={@categories}
                     cart_count={@cart_count}
                   />
               """
      end
    end

    test "every renderer mounts the shared footer" do
      for file <- nav_footer_renderer_files() do
        source = File.read!(file)

        assert source =~ ~r/Chrome\.footer/,
               """
               #{Path.basename(file)} must mount the theme-dispatched footer.

               Add at the bottom of render/1:

                   <Emakola.Themes.DefaultRenderers.Chrome.footer
                     theme_module={assigns[:theme_module]}
                     store={@store}
                     categories={@categories}
                   />
               """
      end
    end
  end

  describe "storefront LiveView delegation" do
    @storefront_lvs_dir "lib/emakola_web/live/storefront"

    # LiveViews that legitimately render their own content (not via the
    # theme delegation pattern). These don't need a default renderer.
    @exempt ~w(
      checkout_live.ex
      customer_login_live.ex
      customer_register_live.ex
      customer_whats_app_live.ex
      product_detail_live.ex
      product_list_live.ex
      store_live.ex
      about_live.ex
      page_live.ex
      account_downloads_live.ex
      saved_stores_live.ex
      pay_link_live.ex
      susu_link_live.ex
    )

    defp storefront_lv_files do
      @storefront_lvs_dir
      |> Path.expand()
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".ex"))
      |> Enum.reject(&(&1 in @exempt))
      |> Enum.map(&Path.join(@storefront_lvs_dir, &1))
    end

    test "non-exempt storefront LiveViews delegate to a default renderer" do
      for file <- storefront_lv_files() do
        source = File.read!(file)

        assert source =~ ~r/(theme_render|DefaultRenderers\.\w+\.render)/,
               """
               #{Path.basename(file)} must delegate render/1 to a default renderer.

               Add to the LiveView's render/1:

                   case Emakola.Themes.ThemeRenderer.theme_render(assigns, :page_name) do
                     {:ok, rendered} -> rendered
                     :default -> Emakola.Themes.DefaultRenderers.PageName.render(assigns)
                   end

               Or add `#{Path.basename(file)}` to the @exempt list in this test
               if it intentionally renders inline (login forms, checkout, etc.).
               """
      end
    end
  end
end
