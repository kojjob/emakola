defmodule EmakolaWeb.Storefront.PdpPortraitGalleryTest do
  @moduledoc """
  Every theme's product gallery must be framed for the photos merchants
  actually take.

  Makola's catalogue is shot on phones, held in one hand, in a stall — Nova
  market's watch is 427x760. A square frame with `object-cover` cuts a third
  off a photo that tall, and it cuts it on the one page where a shopper is
  deciding to buy. Six themes already framed portrait; the rest were square
  because a square is the tidy default, not because anyone chose it for this
  catalogue.

  Thumbnails stay square on purpose: they are small, uniform, and their job is
  to be a row, not to show the goods.
  """
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest

  alias Emakola.Themes.ThemeResolver

  @themes ThemeResolver.theme_ids()

  # 4:5 and 3:4 are both portrait and both already in use across the themes.
  @portrait_frames ["aspect-[4/5]", "aspect-[3/4]"]

  defp seed(theme) do
    store = create_store!(%{theme_config: %{"theme" => theme}, currency: "GHS"})
    product = create_product!(store, %{title: "Sankofa Stool", status: :active})
    create_variant!(product, store, %{price: 45_000, stock_quantity: 4})

    # A theme that renders a placeholder instead of the photo must not be able
    # to satisfy this test. The assertion below pins the seeded URL, so a
    # gallery that never drew the merchant's photo fails no matter what classes
    # its empty state happens to carry.
    image = create_image!(product, store)

    {store, product, image}
  end

  for theme <- @themes do
    @theme theme

    test "#{theme} frames its product gallery portrait, not square", %{conn: conn} do
      {store, product, image} = seed(@theme)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ image.url,
             "the #{@theme} product page never rendered the merchant's photo, so anything " <>
               "this test asserts about the gallery would be asserted about a placeholder"

      assert Enum.any?(@portrait_frames, &String.contains?(html, &1)),
             "the #{@theme} product page has no portrait gallery frame — a phone-shot " <>
               "photo will be cropped on the page where the shopper decides to buy"

      # A portrait frame that a breakpoint squares again is the live bug: the
      # phone looks right, the desktop crops. Three themes read as passing on
      # the assertion above while doing exactly this.
      refute html =~ "lg:aspect-square",
             "the #{@theme} product page is portrait on a phone and square on a desktop"
    end
  end
end
