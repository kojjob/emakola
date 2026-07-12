defmodule Emakola.Themes.AtelierSectionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Atelier, ThemeResolver}

  test "sections/0 lists the seven home sections in today's visual order" do
    keys = Enum.map(Atelier.sections(), & &1.key())

    assert keys == [
             "atelier/hero",
             "atelier/category_circles",
             "atelier/featured_products",
             "atelier/new_arrivals",
             "atelier/trust",
             "atelier/delivery_zones",
             "atelier/newsletter"
           ]
  end

  test "default render carries each section's landmark content" do
    {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "atelier"}})
    create_category!(store)
    for _ <- 1..4, do: create_product!(store, %{status: :active})

    html = render_home(store)

    # Landmarks -- one distinctive literal per block, picked from the
    # CURRENT atelier/home.ex before extraction (Task 7 reuses these).
    # Hero -- no static literal exists in the moved markup itself, so this
    # falls back to the theme default (badge subtitle text), same
    # theme-default indirection Task 5 used for Starter's Hero.
    assert html =~ "The 2024 Collection"
    # Category Circles
    assert html =~ "Shop by Category"
    # Featured Products
    assert html =~ "Featured Masterpieces"
    # New Arrivals
    assert html =~ "New Arrivals"
    # Trust
    assert html =~ "We Accept"
    # Delivery Zones
    assert html =~ "Delivery across Ghana"
    # Newsletter -- falls back to the hardcoded literal because the theme's
    # newsletter map has no :heading key (only :title/:subtitle/:button_text)
    assert html =~ "Stay Updated."
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
    |> Atelier.render_home()
    |> rendered_to_string()
  end
end
