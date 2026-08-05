defmodule EmakolaWeb.Storefront.ProductListStreamTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Themes.ThemeResolver

  @themes ThemeResolver.theme_ids()
  @renderer_files Path.wildcard(
                    Path.expand("../../../../lib/emakola/themes/*/product_list.ex", __DIR__)
                  )

  test "every registered product-list renderer consumes the stream contract" do
    assert length(@renderer_files) == length(@themes)

    assert @renderer_files
           |> Enum.map(&(&1 |> Path.dirname() |> Path.basename()))
           |> MapSet.new() == MapSet.new(@themes)

    for file <- @renderer_files do
      source = File.read!(file)

      assert source =~ ~s(id="product-list"), "#{file} has no stable stream parent"
      assert source =~ ~s(phx-update="stream"), "#{file} is not a LiveView stream container"
      assert source =~ "@streams.products", "#{file} does not consume the product stream"
      assert source =~ "id={dom_id}", "#{file} does not apply streamed child DOM IDs"
      assert source =~ ~s(id="product-list-empty"), "#{file} has no stable empty-state child"
      refute source =~ ~r/@products(?!_count)/, "#{file} still reads a retained @products list"
      refute source =~ "attr :products,", "#{file} still declares the old list contract"
    end

    live_source =
      File.read!(
        Path.expand(
          "../../../../lib/emakola_web/live/storefront/product_list_live.ex",
          __DIR__
        )
      )

    refute live_source =~ "assign(:products,"
    refute live_source =~ ~r/socket\.assigns\.products(?!_count)/
    refute live_source =~ "++ new_products"
    assert live_source =~ "assign(:products_count"
    assert live_source =~ "reset_product_stream(products)"
    assert live_source =~ "product_stream_items(new_products, socket.assigns.products_count)"
  end

  for theme <- @themes do
    @theme theme

    test "#{theme} resets URL/event filters and appends page two without duplicates", %{
      conn: conn
    } do
      %{store: store, category: category} = seed_catalogue(@theme)
      path = "/s/#{store.slug}/products"

      {:ok, view, html} = live(conn, path)

      assert has_element?(view, "#product-list[phx-update=stream]")
      assert has_element?(view, ~s(#product-list > [id^="products-"]))
      assert has_element?(view, ~s([phx-click="load_more"]))
      assert streamed_product_count(html) == 12

      loaded = render_click(view, "load_more")
      assert streamed_product_count(loaded) == 13
      assert loaded =~ "General 01"

      url_searched = render_patch(view, "#{path}?q=Needle")
      assert streamed_product_count(url_searched) == 1
      assert url_searched =~ "Needle #{@theme}"

      url_reset = render_patch(view, path)
      assert streamed_product_count(url_reset) == 12

      event_searched = render_change(view, "search", %{"query" => "General 12"})
      assert streamed_product_count(event_searched) == 1
      assert event_searched =~ "General 12"
      refute event_searched =~ "Needle #{@theme}"

      filtered = render_click(view, "filter_category", %{"category_id" => category.id})
      assert streamed_product_count(filtered) == 1
      assert filtered =~ "Needle #{@theme}"
      refute filtered =~ "General 12"

      reset = render_click(view, "filter_category", %{"category_id" => "all"})
      assert streamed_product_count(reset) == 12

      reloaded = render_click(view, "load_more")
      assert streamed_product_count(reloaded) == 13
      assert reloaded =~ "General 01"
    end
  end

  defp seed_catalogue(theme) do
    store =
      Factory.create_store!(%{
        name: "#{theme} Stream Shop",
        slug: "#{theme}-stream-shop",
        theme_config: %{"theme" => theme}
      })

    category = Factory.create_category!(store, %{name: "Needles"})

    for number <- 1..12 do
      product =
        Factory.create_product!(store, %{
          title: "General #{number |> Integer.to_string() |> String.pad_leading(2, "0")}",
          status: :active
        })

      Factory.create_variant!(product, store, %{price: number * 1000, stock_quantity: 5})
    end

    needle =
      Factory.create_product!(store, %{
        title: "Needle #{theme}",
        category_id: category.id,
        status: :active
      })

    Factory.create_variant!(needle, store, %{price: 50_000, stock_quantity: 5})

    %{store: store, category: category}
  end

  defp streamed_product_count(html) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query(~s(#product-list > [id^="products-"]))
    |> Enum.count()
  end
end
