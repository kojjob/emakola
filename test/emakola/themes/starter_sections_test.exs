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
    create_product!(store, %{status: :active})

    html = render_home(store)

    # Landmarks -- one distinctive literal per block, picked from the
    # CURRENT starter/home.ex before extraction (Task 7 reuses these).
    # Hero
    assert html =~ "Your New Favorite Store"
    # Category Pills
    assert html =~ "Shop by Category"
    # Featured Products
    assert html =~ "Featured Products"
    # Trust
    assert html =~ "Secure Payment"
    # Newsletter
    assert html =~ "Stay in the Know"
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
