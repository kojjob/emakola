defmodule EmakolaWeb.Storefront.CategoryControlsTest do
  @moduledoc """
  Category controls take the shopper to the category, on every theme.

  These were broken in three different ways, and every one of them crashed the
  LiveView rather than doing nothing — `handle_event` has no catch-all clause, so
  an event with no matching function head raises `FunctionClauseError`, the
  process dies, and the page resets under the shopper:

    * **Fresh's home circles** fired `phx-click="filter_category"` at
      `StoreLive`, which has no such handler at all. Every category on the Fresh
      home page killed the page.
    * **Fresh and Bold's product-list buttons** sent `phx-value-id`, but
      `ProductListLive.handle_event/3` matches on `%{"category_id" => _}`. Ten
      other themes send `phx-value-category_id`. These two never matched.
    * **Bold and Starter's "All" / "Clear filters"** fired `clear_filters`,
      which is handled only in the platform's store directory
      (`EmakolaWeb.StoresLive`) — never in the storefront's product list.

  The tests drive the rendered element rather than calling the handler directly:
  `element/2` fails when the selector matches nothing, so a button that emits the
  wrong param name cannot pass, and a crashed LiveView cannot pass either.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Themes.ThemeResolver

  @themes ThemeResolver.theme_ids()

  defp seed(theme) do
    store = Emakola.Factory.create_store!(%{theme_config: %{"theme" => theme}})

    fruit = Emakola.Factory.create_category!(store, %{name: "Fruit"})
    veg = Emakola.Factory.create_category!(store, %{name: "Vegetables"})

    mango = Emakola.Factory.create_product!(store, %{title: "Mango", status: :active})
    Emakola.Factory.create_variant!(mango, store, %{price: 5000, stock_quantity: 10})
    set_category!(mango, fruit)

    okra = Emakola.Factory.create_product!(store, %{title: "Okra", status: :active})
    Emakola.Factory.create_variant!(okra, store, %{price: 3000, stock_quantity: 10})
    set_category!(okra, veg)

    %{store: store, fruit: fruit, veg: veg}
  end

  defp set_category!(product, category) do
    product
    |> Ash.Changeset.for_update(:update, %{category_id: category.id})
    |> Ash.update!(authorize?: false)
  end

  describe "the home page never fires an event the home page cannot handle" do
    for theme <- @themes do
      @theme theme

      test "#{theme} home", %{conn: conn} do
        %{store: store} = seed(@theme)

        {:ok, _view, html} = live(conn, "/s/#{store.slug}")

        # StoreLive handles add_to_cart, search_overlay and close_search — and
        # nothing else. Anything else on this page is a control that kills the
        # page when a shopper touches it.
        refute html =~ ~s(phx-click="filter_category"),
               "the #{@theme} home page fires filter_category, which StoreLive does not handle"

        refute html =~ ~s(phx-click="clear_filters"),
               "the #{@theme} home page fires clear_filters, which StoreLive does not handle"
      end
    end
  end

  describe "a home category control navigates to that category's page" do
    for theme <- @themes do
      @theme theme

      test "#{theme} home links to /category/:slug", %{conn: conn} do
        %{store: store, fruit: fruit} = seed(@theme)

        {:ok, view, html} = live(conn, "/s/#{store.slug}")

        # A theme is free to show no categories on its home page. If it shows
        # one, the control has to go somewhere real.
        if html =~ fruit.name do
          href = ~s(a[href="/s/#{store.slug}/category/#{fruit.slug}"])

          assert has_element?(view, href),
                 "the #{@theme} home page shows the #{fruit.name} category but does not link to it"
        end
      end
    end
  end

  describe "a product-list category control sends the param the handler matches on" do
    for theme <- @themes do
      @theme theme

      test "#{theme} product list", %{conn: conn} do
        %{store: store, fruit: fruit} = seed(@theme)

        {:ok, view, html} = live(conn, "/s/#{store.slug}/products")

        assert html =~ "Mango"
        assert html =~ "Okra"

        refute html =~ ~s(phx-click="clear_filters"),
               "the #{@theme} product list fires clear_filters, which ProductListLive does not " <>
                 "handle — it is handled only by the platform's store directory"

        # A theme is free to offer no category filter. One that DOES offer it
        # must send `category_id`: ProductListLive matches on
        # `%{"category_id" => _}` and has no catch-all, so `phx-value-id` raises
        # FunctionClauseError and takes the page down.
        #
        # has_element?/2 rather than element/2 here because several themes render
        # the same control twice (a desktop rail and a mobile pill row), which is
        # a real responsive layout, not a bug.
        if html =~ ~s(phx-click="filter_category") do
          assert has_element?(
                   view,
                   ~s([phx-click="filter_category"][phx-value-category_id="#{fruit.id}"])
                 ),
                 "the #{@theme} category button does not send category_id"

          assert has_element?(
                   view,
                   ~s([phx-click="filter_category"][phx-value-category_id="all"])
                 ),
                 "the #{@theme} product list has no working 'all' control"
        end
      end
    end
  end

  describe "filtering by a category actually narrows the list" do
    for theme <- @themes do
      @theme theme

      test "#{theme} product list", %{conn: conn} do
        %{store: store, fruit: fruit} = seed(@theme)

        {:ok, view, html} = live(conn, "/s/#{store.slug}/products")

        if html =~ ~s(phx-click="filter_category") do
          filtered = render_click(view, "filter_category", %{"category_id" => fruit.id})

          assert filtered =~ "Mango"
          refute filtered =~ "Okra", "the #{@theme} category filter did not narrow the list"

          # Several themes only render their "Clear filters" button once a filter
          # is active, so it is invisible to the check above until we set one.
          refute filtered =~ ~s(phx-click="clear_filters"),
                 "the #{@theme} product list offers a Clear filters button that " <>
                   "ProductListLive does not handle"

          restored = render_click(view, "filter_category", %{"category_id" => "all"})

          assert restored =~ "Mango"
          assert restored =~ "Okra", "the #{@theme} 'all' control did not clear the filter"
        end
      end
    end
  end
end
