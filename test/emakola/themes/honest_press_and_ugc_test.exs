defmodule Emakola.Themes.HonestPressAndUgcTest do
  @moduledoc """
  Two strips that showed proof nobody had earned.

  Beauty's "as featured in" strip repeated the literal words *As featured in*
  five times, in italics, styled as a row of press logos. It named no
  publication and read no store data — it was the SHAPE of press coverage with
  nothing inside it, and a shopper skimming the page read it as five magazines.

  Fashion's "Worn by you." strip laid out six camera glyphs where customer
  photographs should be, under an invitation to tag the store.

  Both shipped switched off, which is why they were only ever a trap: a
  merchant who opened the new section editor, saw "Featured in" or "Customer
  photos" in the list and enabled it got fabricated social proof on their
  storefront in one click, with no way to fill it with anything true.

  A strip shows real proof now, or it does not render:

    * the press strip names the publications the MERCHANT named (its only
      possible honest source — there is no press data model, so this is their
      claim, like their About page), and renders nothing when they've named
      none;
    * the UGC strip shows photographs real customers attached to real reviews
      (`Catalog.Review.images`, already rendered on the PDP), and renders
      nothing when there are none.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Beauty, Fashion, ThemeResolver}

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Beauty, Fashion])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
    :ok
  end

  defp render_section(section, store, overrides \\ %{}, extra \\ %{}) do
    defaults =
      for setting <- section.settings_schema(), into: %{}, do: {setting.key, setting.default}

    %{
      store: store,
      products: [],
      categories: [],
      testimonials: [],
      review_photos: [],
      theme: ThemeResolver.resolve(store.theme_config || %{}, store),
      settings: Map.merge(defaults, overrides),
      section_meta: %{},
      cart_count: 0,
      __changed__: nil
    }
    |> Map.merge(extra)
    |> section.render()
    |> rendered_to_string()
  end

  # Both strips ship off; force them on, which is exactly what a merchant does
  # in one click from the section editor.
  defp store_with(theme, section_key) do
    {_merchant, store} =
      create_merchant_with_store!(%{
        theme_config: %{"theme" => theme, "sections" => %{section_key => true}}
      })

    store
  end

  describe "Beauty's press strip" do
    test "a merchant who has named no publication gets no press strip" do
      store = store_with("beauty", "featured_in")

      html = render_section(Beauty.Sections.FeaturedIn, store)

      refute html =~ "As featured in"
      refute html =~ "<section"
    end

    test "it names the publications the merchant actually named" do
      store = store_with("beauty", "featured_in")

      html =
        render_section(Beauty.Sections.FeaturedIn, store, %{
          "publications" => "Vogue Ghana, Citi FM, Graphic Showbiz"
        })

      assert html =~ "As featured in"
      assert html =~ "Vogue Ghana"
      assert html =~ "Citi FM"
      assert html =~ "Graphic Showbiz"
    end

    test "blank entries between commas never become empty logos" do
      store = store_with("beauty", "featured_in")

      html =
        render_section(Beauty.Sections.FeaturedIn, store, %{"publications" => "Citi FM, ,  ,"})

      assert html =~ "Citi FM"
      # One publication named, so one is listed.
      assert length(String.split(html, "<li")) == 2
    end
  end

  describe "Fashion's UGC strip" do
    test "a store with no customer photos gets no photo strip" do
      store = store_with("fashion", "ugc")

      html = render_section(Fashion.Sections.Ugc, store)

      refute html =~ "Worn by you"
      refute html =~ "photo_camera"
      refute html =~ "<section"
    end

    test "it shows the photographs real customers attached to their reviews" do
      store = store_with("fashion", "ugc")

      photos = [
        %{"url" => "/uploads/ama-wearing-it.jpg", "alt" => "Ama in the wrap dress"},
        %{"url" => "/uploads/kofi-fit.jpg", "alt" => "Kofi in the smock"}
      ]

      html = render_section(Fashion.Sections.Ugc, store, %{}, %{review_photos: photos})

      assert html =~ "Worn by you"
      assert html =~ "/uploads/ama-wearing-it.jpg"
      assert html =~ "/uploads/kofi-fit.jpg"
      assert html =~ "Ama in the wrap dress"
      # No placeholder glyphs padding the grid out to six.
      refute html =~ "photo_camera"
    end
  end

  describe "Catalog.store_review_photos/2" do
    test "returns the photographs customers attached to their reviews" do
      {_merchant, store} = create_merchant_with_store!()
      product = create_product!(store, %{status: :active})

      review!(store, product, [%{"url" => "/uploads/published.jpg", "alt" => "worn"}])

      assert [%{"url" => "/uploads/published.jpg"}] =
               Emakola.Catalog.store_review_photos(store.id)
    end

    test "a review the merchant hid takes its photos off the storefront with it" do
      {_merchant, store} = create_merchant_with_store!()
      product = create_product!(store, %{status: :active})

      store
      |> review!(product, [%{"url" => "/uploads/hidden.jpg", "alt" => "hidden"}])
      |> Ash.Changeset.for_update(:hide, %{})
      |> Ash.update!(authorize?: false)

      assert Emakola.Catalog.store_review_photos(store.id) == []
    end

    test "reviews without photographs contribute nothing" do
      {_merchant, store} = create_merchant_with_store!()
      product = create_product!(store, %{status: :active})

      review!(store, product, [])

      assert Emakola.Catalog.store_review_photos(store.id) == []
    end
  end

  # Only a real purchaser can review: the resource requires a customer AND the
  # order they bought it on.
  defp review!(store, product, images) do
    customer = create_customer!(store)
    order = create_order!(store, %{customer_id: customer.id})

    Emakola.Catalog.Review
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      product_id: product.id,
      customer_id: customer.id,
      order_id: order.id,
      rating: 5,
      body: "Wore it to a wedding in Kumasi.",
      images: images
    })
    |> Ash.create!(authorize?: false)
  end
end
