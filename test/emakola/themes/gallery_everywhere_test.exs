defmodule Emakola.Themes.GalleryEverywhereTest do
  @moduledoc """
  Every theme draws its product gallery with `Emakola.Themes.Gallery`.

  Twenty-two themes each had their own before this, and the differences were
  not cosmetic: some put the thumbnails under the photo, some in a four-column
  grid, some as dots, and none let a phone swipe between photos. A shopper met
  a different gallery in every shop, and a fix had to be made twenty-two
  times.

  This is a source sweep rather than a render test on purpose — it catches a
  theme added next month that quietly rolls its own, which no render test of
  today's themes would.
  """
  use ExUnit.Case, async: true

  @detail_files Path.wildcard("lib/emakola/themes/*/product_detail.ex")

  test "the sweep sees every theme's product detail" do
    assert length(@detail_files) >= 20,
           "expected 20+ product_detail.ex files, found #{length(@detail_files)}"
  end

  test "every product detail uses the shared gallery" do
    offenders =
      for path <- @detail_files,
          not String.contains?(File.read!(path), "Gallery.product_gallery"),
          do: path

    assert offenders == [],
           """
           These themes do not use the shared gallery:

           #{Enum.map_join(offenders, "\n", &"  - #{&1}")}

           Product galleries go through Emakola.Themes.Gallery so the swipe and
           the left-hand thumbnail rail behave the same in every shop.
           """
  end

  test "no theme keeps a hand-rolled thumbnail strip beside the shared one" do
    # `select_image` is the gallery's own event. A theme still emitting it from
    # its own markup means a second, competing set of thumbnails.
    offenders =
      for path <- @detail_files,
          String.contains?(File.read!(path), ~s(phx-click="select_image")),
          do: path

    assert offenders == [], "hand-rolled thumbnails remain in:\n#{Enum.join(offenders, "\n")}"
  end

  test "the gallery is swipeable and its rail stands to the left" do
    source = File.read!("lib/emakola/themes/gallery.ex")

    # Native scroll-snap: the swipe is the browser's own gesture, so it works
    # before any JavaScript loads — which on a slow connection is the point.
    assert source =~ "snap-x snap-mandatory"
    assert source =~ "snap-center"

    # Vertical from sm up, horizontal underneath on a phone.
    assert source =~ "sm:flex-col"
    assert source =~ "sm:order-1"
    assert source =~ "order-2"

    # The hook that carries the selection both ways.
    assert source =~ ~s(phx-hook="GallerySwipe")
    assert File.exists?("assets/js/hooks/gallery_swipe.js")
    assert File.read!("assets/js/app.js") =~ "GallerySwipe"
  end
end
