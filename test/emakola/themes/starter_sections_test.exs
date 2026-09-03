defmodule Emakola.Themes.StarterSectionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Starter, ThemeResolver}

  test "sections/0 lists the five home sections in today's visual order" do
    keys = Enum.map(Starter.sections(), & &1.key())

    assert keys == [
             "starter/hero",
             "starter/category_pills",
             "starter/featured_products",
             "starter/trust",
             "starter/newsletter"
           ]
  end

  test "default render carries each section's landmark content" do
    {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "starter"}})
    create_category!(store)
    # A full stall: category pills and the newsletter join the page at four
    # or more products.
    for _ <- 1..4, do: create_product!(store, %{status: :active})

    html = render_home(store)

    # Landmarks -- one distinctive literal per block, picked from the
    # CURRENT starter/home.ex before extraction (Task 7 reuses these).
    # Hero -- the store's own name is the h1; the theme ships no invented
    # headline for it to fall back to.
    assert html =~ ~r/<h1[^>]*id="starter-hero-heading"[^>]*>\s*#{Regex.escape(store.name)}/
    # Category Pills
    assert html =~ "Shop by Category"
    # Featured Products
    assert html =~ "Featured Products"
    # Trust
    assert html =~ "Secure Payment"
    # Newsletter
    assert html =~ "Stay in the Know"
  end

  describe "the home finishes at one product" do
    test "one product: no category pills, no newsletter, no invented hero copy" do
      {_merchant, store} =
        create_merchant_with_store!(%{theme_config: %{"theme" => "starter"}, description: nil})

      create_category!(store)
      create_product!(store, %{title: "Kente Tote Bag", status: :active})

      html = render_home(store)

      assert html =~ "Kente Tote Bag"
      assert html =~ ~s(id="starter-hero-heading")
      refute html =~ "Your New Favorite Store"
      refute html =~ "Quality products, curated for you."
      refute html =~ "Shop by Category"
      refute html =~ ~s(phx-submit="subscribe_newsletter")
    end

    test "the merchant's own hero words still win" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{
            "theme" => "starter",
            "hero" => %{"title" => "Fresh stock, every Friday", "subtitle" => "Since 2011"}
          }
        })

      html = render_home(store)

      assert html =~ "Fresh stock, every Friday"
      assert html =~ "Since 2011"
    end
  end

  defp render_home(store) do
    theme = ThemeResolver.resolve(store.theme_config || %{}, store)

    products =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
      |> Ash.read!(authorize?: false)

    categories = Emakola.Catalog.list_root_categories!(store.id)

    %{
      store: store,
      products: products,
      categories: categories,
      theme: theme,
      cart_count: 0,
      __changed__: nil
    }
    |> Starter.render_home()
    |> rendered_to_string()
  end
end
