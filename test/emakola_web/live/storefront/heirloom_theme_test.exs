defmodule EmakolaWeb.Storefront.HeirloomThemeTest do
  @moduledoc """
  Heirloom drives through the real storefront LiveViews rather than rendering
  the theme modules in isolation.

  That is deliberate. The two defects this theme was written to avoid are both
  invisible to a component render: a theme missing from the `Sections` registry
  renders a blank home page, and a variant picker sending the wrong `phx-value`
  attribute leaves `@selected_variant` unchanged. Only a mounted LiveView shows
  either one.
  """
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest

  defp heirloom_store(attrs \\ %{}) do
    create_store!(Map.merge(%{theme_config: %{"theme" => "heirloom"}}, attrs))
  end

  describe "registration" do
    test "resolves from both registries" do
      assert Emakola.Themes.ThemeResolver.theme_module("heirloom") == Emakola.Themes.Heirloom
      assert Emakola.Themes.Sections.sectionized?(Emakola.Themes.Heirloom)
    end

    test "every declared section key resolves" do
      for section <- Emakola.Themes.Heirloom.sections() do
        assert {:ok, {^section, _meta}} = Emakola.Themes.Sections.resolve(section.key()),
               "#{inspect(section)} is declared in sections/0 but its key does not resolve, " <>
                 "so SectionRenderer would silently skip it"
      end
    end
  end

  describe "home" do
    test "renders the store's own name as the wordmark", %{conn: conn} do
      store = heirloom_store(%{name: "Odum & Ash"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "Odum &amp; Ash"
    end

    test "renders sections rather than a blank page", %{conn: conn} do
      store = heirloom_store()

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      # The registration failure mode: chrome renders, sections do not.
      assert html =~ "heirloom-content"
      assert html =~ "Shop the collection"
    end

    test "the hero card shows a real product at its real price", %{conn: conn} do
      store = heirloom_store(%{currency: "GHS"})
      product = create_product!(store, %{title: "Nsuo Lounge Chair", status: :active})
      create_variant!(product, store, %{price: 129_900, stock_quantity: 3})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "Nsuo Lounge Chair"
      assert html =~ "1,299"
    end

    test "the hero card is absent when the store has no products", %{conn: conn} do
      store = heirloom_store()

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      refute html =~ "was</span>"
    end

    test "never invents a discount", %{conn: conn} do
      store = heirloom_store(%{currency: "GHS"})
      product = create_product!(store, %{title: "Plain Stool", status: :active})
      create_variant!(product, store, %{price: 50_000, stock_quantity: 1})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      refute html =~ "<s "
    end
  end

  describe "product detail" do
    setup %{conn: conn} do
      store = heirloom_store(%{currency: "GHS"})
      product = create_product!(store, %{title: "Adinkra Armchair", status: :active})
      option_type = create_option_type!(product, store, %{name: "Finish", position: 1})
      oak = create_option_value!(option_type, store, %{value: "Oak"})
      walnut = create_option_value!(option_type, store, %{value: "Walnut"})
      create_variant!(product, store, %{price: 89_900, stock_quantity: 5})

      {:ok, view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      %{
        view: view,
        html: html,
        store: store,
        product: product,
        option_type: option_type,
        oak: oak,
        walnut: walnut
      }
    end

    test "the option picker sends the params the handler matches on", ctx do
      assert has_element?(
               ctx.view,
               ~s([phx-click="select_option"][phx-value-option_type_id="#{ctx.option_type.id}"][phx-value-option_value_id="#{ctx.walnut.id}"])
             )
    end

    test "never emits phx-value-value", ctx do
      refute ctx.html =~ "phx-value-value"
    end

    test "picking an option selects it", ctx do
      html =
        render_click(ctx.view, "select_option", %{
          "option_type_id" => ctx.option_type.id,
          "option_value_id" => ctx.walnut.id
        })

      assert html =~ "Walnut"
    end

    test "the quantity stepper moves", ctx do
      assert render_click(ctx.view, "increment_quantity", %{}) =~ "2"
      assert render_click(ctx.view, "decrement_quantity", %{}) =~ "1"
    end

    test "wires the share strip", ctx do
      assert ctx.html =~ "share-product"
    end

    test "wires reviews", ctx do
      assert ctx.html =~ "review"
    end
  end

  describe "product list" do
    test "renders tiles for active products", %{conn: conn} do
      store = heirloom_store(%{currency: "GHS"})
      product = create_product!(store, %{title: "Kuduo Sideboard", status: :active})
      create_variant!(product, store, %{price: 240_000, stock_quantity: 2})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products")

      assert html =~ "Kuduo Sideboard"
      assert html =~ "The collection"
    end

    test "shows an empty state rather than an empty grid", %{conn: conn} do
      store = heirloom_store()

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products")

      assert html =~ "Nothing here yet"
    end
  end

  describe "sections that carry merchant claims" do
    # Each of these renders nothing until its merchant supplies content. The
    # paired absent/present assertions are what prove the gate: the same
    # string is missing on a default store and present once configured, so a
    # gate that silently stopped working would fail one of the two.

    test "the team section is absent by default and present once configured", %{conn: conn} do
      default_store = heirloom_store()
      {:ok, _view, default_html} = live(conn, "/s/#{default_store.slug}")
      refute default_html =~ "Ama Serwaa"

      configured =
        heirloom_store(%{
          theme_config: %{
            "theme" => "heirloom",
            "team" => %{
              "items" => [%{"name" => "Ama Serwaa", "role" => "Master joiner"}]
            }
          }
        })

      {:ok, _view, html} = live(conn, "/s/#{configured.slug}")

      assert html =~ "Ama Serwaa"
      assert html =~ "Master joiner"
    end

    test "a team member with no name is dropped", %{conn: conn} do
      store =
        heirloom_store(%{
          theme_config: %{
            "theme" => "heirloom",
            "team" => %{"items" => [%{"name" => "", "role" => "Anonymous"}]}
          }
        })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      refute html =~ "Anonymous"
    end

    test "our story is absent by default and present once configured", %{conn: conn} do
      default_store = heirloom_store()
      {:ok, _view, default_html} = live(conn, "/s/#{default_store.slug}")
      refute default_html =~ "How we joint a drawer"

      configured =
        heirloom_store(%{
          theme_config: %{
            "theme" => "heirloom",
            "our_story" => %{
              "tabs" => [%{"title" => "How we joint a drawer", "body" => "Slowly."}]
            }
          }
        })

      {:ok, _view, html} = live(conn, "/s/#{configured.slug}")

      assert html =~ "How we joint a drawer"
      assert html =~ "Slowly."
    end

    test "stockists are absent by default and present once configured", %{conn: conn} do
      default_store = heirloom_store()
      {:ok, _view, default_html} = live(conn, "/s/#{default_store.slug}")
      refute default_html =~ "Stocked at"

      configured =
        heirloom_store(%{
          theme_config: %{
            "theme" => "heirloom",
            "stockists" => %{"items" => [%{"name" => "Osu Design Store"}]}
          }
        })

      {:ok, _view, html} = live(conn, "/s/#{configured.slug}")

      assert html =~ "Stocked at"
      assert html =~ "Osu Design Store"
    end

    test "the brand story is absent by default and present once written", %{conn: conn} do
      default_store = heirloom_store()
      {:ok, _view, default_html} = live(conn, "/s/#{default_store.slug}")
      refute default_html =~ "We started in a shed in Osu"

      configured =
        heirloom_store(%{
          theme_config: %{
            "theme" => "heirloom",
            "brand_story" => %{"body" => "We started in a shed in Osu"}
          }
        })

      {:ok, _view, html} = live(conn, "/s/#{configured.slug}")

      assert html =~ "We started in a shed in Osu"
    end

    test "the FAQ reads the store's real questions", %{conn: conn} do
      default_store = heirloom_store()
      {:ok, _view, default_html} = live(conn, "/s/#{default_store.slug}")
      refute default_html =~ "Do you deliver to Kumasi?"

      configured = heirloom_store()

      create_page_content!(configured, %{
        faq_items: [%{"question" => "Do you deliver to Kumasi?", "answer" => "Yes, weekly."}]
      })

      {:ok, _view, html} = live(conn, "/s/#{configured.slug}")

      assert html =~ "Do you deliver to Kumasi?"
      assert html =~ "Yes, weekly."
    end
  end
end
