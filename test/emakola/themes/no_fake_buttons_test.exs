defmodule Emakola.Themes.NoFakeButtonsTest do
  @moduledoc """
  A control that says "Add to bag" must add to bag.

  Vibrant's featured card shipped a full-width black pill reading "Add to bag",
  bag icon and all, as a `<span>` inside the card's `<a>`. Pressing it added
  nothing to any bag — it navigated to the product page, where the shopper had
  to find the real button and press it again. The one product every Vibrant
  store puts front and centre had a checkout control that was a picture of a
  checkout control.

  This walks EVERY sectionized theme rather than the one that was broken,
  because the next theme is the one that will get it wrong.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Sections, ThemeResolver}

  # The labels a shopper reads as "this button puts the item in my bag".
  @cart_labels ["add to bag", "add to cart", "add to basket"]

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, Sections.sectionized_themes())
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
    :ok
  end

  defp seed_store(theme_id) do
    {_merchant, store} =
      create_merchant_with_store!(%{
        theme_config: %{"theme" => theme_id},
        description: "Woven in Kumasi, sold from a stall in Makola."
      })

    create_category!(store, %{name: "Kente Cloth"})

    for {title, price} <- [{"Adinkra Wrapper", 12_345}, {"Bolga Basket", 6_500}] do
      product = create_product!(store, %{title: title, status: :active})
      create_variant!(product, store, %{price: price, stock_quantity: 4})
    end

    store
  end

  # Mirrors EmakolaWeb.Storefront.StoreLive: it loads :variants, which is what
  # lets a theme know a product is sold out.
  defp render_home(store, theme_module) do
    products =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
      |> Ash.Query.load(:variants)
      |> Ash.read!(authorize?: false)

    %{
      store: store,
      products: products,
      categories: Emakola.Catalog.list_root_categories!(store.id),
      theme: ThemeResolver.resolve(store.theme_config || %{}, store),
      testimonials: [],
      cart_count: 0,
      __changed__: nil
    }
    |> theme_module.render_home()
    |> rendered_to_string()
  end

  # An element is a FAKE cart control when its entire visible text is one of
  # the labels above and it contains no <button> or <a> of its own — i.e. it is
  # the thing carrying the label, and it is not interactive.
  defp fake_cart_controls(html) do
    doc = LazyHTML.from_fragment(html)

    for node <- Enum.to_list(LazyHTML.query(doc, "span, div, p, li")),
        text = node |> LazyHTML.text() |> String.trim(),
        String.downcase(text) in @cart_labels,
        LazyHTML.query(node, "button, a") |> Enum.to_list() |> Enum.empty?(),
        do: "<#{LazyHTML.tag(node)}> labelled #{inspect(text)}"
  end

  test "no theme renders a cart button that isn't one" do
    theme_ids =
      for id <- ThemeResolver.theme_ids(),
          module = ThemeResolver.theme_module(id),
          Code.ensure_loaded?(module),
          function_exported?(module, :sections, 0),
          do: {id, module}

    # If this ever finds nothing, the walk broke — not the themes.
    assert length(theme_ids) >= 15

    fakes =
      for {id, module} <- theme_ids,
          fake <- module |> then(&render_home(seed_store(id), &1)) |> fake_cart_controls(),
          do: "#{id}: #{fake}"

    assert fakes == [],
           """
           These render a control a shopper reads as "add this to my bag", and it
           adds nothing to any bag:

               #{Enum.join(fakes, "\n    ")}

           A control with a cart label must be a <button> wired to
           phx-click="add_to_cart" (handled by EmakolaWeb.Storefront.StoreLive).
           If it is only meant to open the product page, label it for what it
           does — "View product" — and let the product page take the order.
           """
  end
end
