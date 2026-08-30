defmodule EmakolaWeb.StoresLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "GET /stores (public directory)" do
    test "renders publicly without authentication", %{conn: conn} do
      assert {:ok, view, _html} = live(conn, "/stores")
      assert has_element?(view, "#stores-page")
      assert has_element?(view, "#stores-hero")
      assert has_element?(view, "#stores-search-form")
      assert has_element?(view, "#stores-discovery-controls")
      assert has_element?(view, ~s(#stores-grid[phx-update="stream"]))
      assert has_element?(view, "#stores-region-filter")
      assert has_element?(view, "#stores-sort-filter")
      assert has_element?(view, "#stores-map-button")
    end

    test "lists active stores with links to their storefronts", %{conn: conn} do
      Factory.create_store!(%{
        name: "Akosua's Boutique",
        slug: "akosua-boutique",
        description: "Handmade Ankara fashion from Accra",
        city: "Accra",
        region: "Greater Accra"
      })

      Factory.create_store!(%{name: "Kente Collective", slug: "kente-collective"})

      {:ok, view, _html} = live(conn, "/stores")

      # The directory hands out the short form. /s/:slug still routes, it is
      # just no longer the link we give people.
      assert has_element?(view, ~s(a[href="/akosua-boutique"]))
      assert has_element?(view, ~s(a[href="/kente-collective"]))
      assert has_element?(view, "#stores-grid")
    end

    test "grid cards serve the webp medium variant when one exists", %{conn: conn} do
      store = Factory.create_store!(%{name: "Variant Shop", slug: "variant-shop"})
      product = Factory.create_product!(store, %{title: "Photographed"})
      Factory.create_variant!(product, store)

      product
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

      Factory.create_image!(product, store)
      |> Ash.Changeset.for_update(:mark_processed, %{
        thumbnail_url: "https://s3.example.com/test/photo_thumb.webp",
        medium_url: "https://s3.example.com/test/photo_medium.webp"
      })
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, "/stores")

      assert html =~ "photo_medium.webp"
    end

    test "directory cards keep their favorite button", %{conn: conn} do
      Factory.create_store!(%{name: "Fave Guard Shop", slug: "fave-guard-shop"})

      {:ok, view, _html} = live(conn, "/stores")

      assert has_element?(
               view,
               ~s(#stores-grid [phx-click="toggle_favorite"][phx-value-slug="fave-guard-shop"])
             )
    end

    test "a store with no cover image shows its newest product photo", %{conn: conn} do
      store = Factory.create_store!(%{name: "Ama Provisions", slug: "ama-provisions"})
      product = Factory.create_product!(store, %{title: "Shito Jar"})
      Factory.create_variant!(product, store, %{price: 3_500, stock_quantity: 10})
      Factory.create_image!(product, store, %{url: "/uploads/ama/shito-front.jpg"})

      product
      |> Ash.Changeset.for_update(:activate, %{}, authorize?: false)
      |> Ash.update!()

      {:ok, _view, html} = live(conn, "/stores")

      assert html =~ "/uploads/ama/shito-front.jpg",
             "with no merchant cover set, the directory card must fall back to " <>
               "a real product photo instead of a gradient placeholder"
    end

    test "a merchant-set cover image wins over product photos", %{conn: conn} do
      store =
        Factory.create_store!(%{
          name: "Cover First",
          slug: "cover-first",
          cover_image_url: "/uploads/cover-first/storefront.jpg"
        })

      product = Factory.create_product!(store, %{title: "Basket"})
      Factory.create_variant!(product, store, %{price: 2_000, stock_quantity: 5})
      Factory.create_image!(product, store, %{url: "/uploads/cover-first/basket.jpg"})

      product
      |> Ash.Changeset.for_update(:activate, %{}, authorize?: false)
      |> Ash.update!()

      {:ok, _view, html} = live(conn, "/stores")

      assert html =~ "/uploads/cover-first/storefront.jpg"
      refute html =~ "/uploads/cover-first/basket.jpg"
    end

    test "draft products' photos never surface on the directory", %{conn: conn} do
      store = Factory.create_store!(%{name: "Drafts Only", slug: "drafts-only"})
      product = Factory.create_product!(store, %{title: "Unpublished"})
      Factory.create_image!(product, store, %{url: "/uploads/drafts-only/secret.jpg"})

      {:ok, _view, html} = live(conn, "/stores")

      refute html =~ "/uploads/drafts-only/secret.jpg"
    end

    test "excludes inactive stores", %{conn: conn} do
      Factory.create_store!(%{name: "Live Shop", slug: "live-shop"})
      Factory.create_store!(%{name: "Hidden Shop", slug: "hidden-shop", active: false})

      {:ok, view, _html} = live(conn, "/stores")

      assert has_element?(view, ~s(a[href="/live-shop"]))
      refute has_element?(view, ~s(a[href="/hidden-shop"]))
    end

    test "shows empty state when no active stores exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/stores")

      assert has_element?(view, "#stores-empty-state")
    end

    test "search narrows the visible stores", %{conn: conn} do
      Factory.create_store!(%{name: "Coffee World", slug: "coffee-world"})
      Factory.create_store!(%{name: "Ankara Threads", slug: "ankara-threads"})

      {:ok, view, _html} = live(conn, "/stores")

      view
      |> form("#stores-search-form", search: %{query: "coffee"})
      |> render_change()

      assert has_element?(view, ~s(a[href="/coffee-world"]))
      refute has_element?(view, ~s(a[href="/ankara-threads"]))
    end

    test "theme filter chip narrows by theme_config[\"theme\"]", %{conn: conn} do
      Factory.create_store!(%{
        name: "Beauty Spot",
        slug: "beauty-spot",
        theme_config: %{"theme" => "beauty"}
      })

      Factory.create_store!(%{
        name: "Tech Hub",
        slug: "tech-hub",
        theme_config: %{"theme" => "electronics"}
      })

      {:ok, view, _html} = live(conn, "/stores")

      # Click the Beauty chip — only Beauty Spot should remain
      view
      |> element(~s|button[phx-click="select_theme"][phx-value-theme="beauty"]|)
      |> render_click()

      assert has_element?(view, ~s(a[href="/beauty-spot"]))
      refute has_element?(view, ~s(a[href="/tech-hub"]))
    end

    test "region filter narrows by region", %{conn: conn} do
      # Canonical region names throughout — the same strings `Store.region`
      # holds. The filter used to offer snake_case slugs against a column
      # storing "Greater Accra", so picking a region matched nothing.
      Factory.create_store!(%{
        name: "Accra Goods",
        slug: "accra-goods",
        region: "Greater Accra"
      })

      Factory.create_store!(%{
        name: "Kumasi Crafts",
        slug: "kumasi-crafts",
        region: "Ashanti"
      })

      {:ok, view, _html} = live(conn, "/stores")

      view
      |> form("#stores-filter-form",
        filters: %{region: "Ashanti", sort: "featured"}
      )
      |> render_change()

      assert has_element?(view, ~s(a[href="/kumasi-crafts"]))
      refute has_element?(view, ~s(a[href="/accra-goods"]))
    end

    test "a page link sitting in a picture field never reaches an img tag", %{conn: conn} do
      # Two live merchants pasted their Instagram profile and their website
      # into cover_image_url through the "Or paste a picture link" field, and
      # /stores rendered a broken image for every shopper. The validation stops
      # new ones; this stops the rows that predate it.
      store =
        Factory.create_store!(%{name: "Pasted Link", slug: "pasted-link"})
        |> Ash.Seed.update!(%{
          cover_image_url: "https://www.instagram.com/someone?igsi=abc",
          logo_url: "https://www.makolaai.com/#download"
        })

      {:ok, view, _html} = live(conn, "/stores")

      html = render(view)
      assert has_element?(view, ~s(a[href="/pasted-link"])), "the shop should still be listed"
      refute html =~ "instagram.com"
      refute html =~ "makolaai.com"
      assert store.slug == "pasted-link"
    end

    test "a page link cannot take the featured hero", %{conn: conn} do
      Factory.create_store!(%{
        name: "Pasted Hero",
        slug: "pasted-hero",
        featured: true,
        featured_rank: 1
      })
      |> Ash.Seed.update!(%{cover_image_url: "https://www.instagram.com/someone"})

      {:ok, view, _html} = live(conn, "/stores")

      # No real picture anywhere, so the shop keeps its place in the grid but
      # does not hold the big slot.
      refute has_element?(view, ~s(#featured-hero[href="/pasted-hero"]))
    end

    test "picking a region on the map filters the directory", %{conn: conn} do
      Factory.create_store!(%{name: "Volta Wares", slug: "volta-wares", region: "Volta"})
      Factory.create_store!(%{name: "Accra Goods", slug: "accra-goods", region: "Greater Accra"})

      {:ok, view, _html} = live(conn, "/stores")

      view |> element("#stores-map-button") |> render_click()
      assert has_element?(view, ~s([data-region="Volta"]))

      view
      |> element(~s(button[phx-value-region="Volta"]))
      |> render_click()

      assert has_element?(view, ~s(a[href="/volta-wares"]))
      refute has_element?(view, ~s(a[href="/accra-goods"]))
    end

    test "the map counts every store in a region, not just the loaded page", %{conn: conn} do
      # Fifteen shops against a twelve-per-page grid: a count derived from
      # the page would say 12, and the old map said 0 for every region.
      for n <- 1..15 do
        Factory.create_store!(%{
          name: "Accra Shop #{n}",
          slug: "accra-shop-#{n}",
          region: "Greater Accra"
        })
      end

      {:ok, view, _html} = live(conn, "/stores")
      view |> element("#stores-map-button") |> render_click()

      html = render(view)
      assert html =~ "15 stores"
      refute html =~ "12 stores"
    end

    test "sort dropdown switches the order", %{conn: conn} do
      Factory.create_store!(%{name: "Aaa Shop", slug: "aaa-shop"})
      Factory.create_store!(%{name: "Zzz Shop", slug: "zzz-shop"})

      {:ok, view, _html} = live(conn, "/stores")

      view
      |> form("#stores-filter-form",
        filters: %{region: "", sort: "name"}
      )
      |> render_change()

      assert has_element?(view, ~s(a[href="/aaa-shop"]))
      assert has_element?(view, ~s(a[href="/zzz-shop"]))
    end

    test "the spotlight renders when at least one featured store exists", %{conn: conn} do
      Factory.create_store!(%{
        name: "Carousel Star",
        slug: "carousel-star",
        featured: true,
        featured_rank: 1,
        cover_image_url: "https://cdn.example/carousel-star.png",
        tagline: "Hand-picked excellence"
      })

      {:ok, view, _html} = live(conn, "/stores")

      assert has_element?(view, "#featured-spotlight")
      assert has_element?(view, ~s(#featured-hero[href="/carousel-star"]))
    end

    test "the hero is the top-ranked shop and the tiles carry the rest, nobody twice", %{
      conn: conn
    } do
      for {name, rank} <- [{"Rank One", 1}, {"Rank Two", 2}, {"Rank Three", 3}] do
        Factory.create_store!(%{
          name: name,
          slug: String.replace(String.downcase(name), " ", "-"),
          featured: true,
          featured_rank: rank,
          cover_image_url: "https://cdn.example/#{rank}.png"
        })
      end

      {:ok, view, html} = live(conn, "/stores")

      # Date-seeded rotation picks the day's head; whoever leads, the hero
      # holds exactly one shop and the tiles never repeat it.
      assert has_element?(view, "#featured-hero")
      [hero_name] = Regex.run(~r/Rank (?:One|Two|Three)/, hero_html(view)) |> List.wrap()

      refute tile_html(view) =~ hero_name
      assert html =~ "Market spotlight"
    end

    test "a featured shop without any photo never holds the hero", %{conn: conn} do
      Factory.create_store!(%{
        name: "No Photo Shop",
        slug: "no-photo-shop",
        featured: true,
        featured_rank: 1
      })

      Factory.create_store!(%{
        name: "Photo Shop",
        slug: "photo-shop",
        featured: true,
        featured_rank: 2,
        cover_image_url: "https://cdn.example/photo-shop.png"
      })

      {:ok, view, _html} = live(conn, "/stores")

      # Rank one has no image; a giant gradient placeholder is not a hero.
      # The slot passes to the best-ranked shop that can actually fill it.
      assert has_element?(view, ~s(#featured-hero[href="/photo-shop"]))
      refute has_element?(view, ~s(#featured-hero[href="/no-photo-shop"]))
    end

    test "a worker-assigned spotlight shop leads the hero without any featured flag", %{
      conn: conn
    } do
      Factory.create_store!(%{
        name: "Merit Shop",
        slug: "merit-shop",
        cover_image_url: "https://cdn.example/merit.png"
      })
      |> Ash.Changeset.for_update(:set_directory_standing, %{
        directory_eligible: true,
        directory_score: 800,
        directory_slot: :spotlight
      })
      |> Ash.update!(authorize?: false)

      {:ok, view, _html} = live(conn, "/stores")

      assert has_element?(view, ~s(#featured-hero[href="/merit-shop"]))
    end

    test "the companion panel hides when only one shop can fill the spotlight", %{conn: conn} do
      # A young directory often has exactly one shop with a real photo. An
      # "Also featured" box with nothing in it reads as a broken page, so the
      # hero takes the whole width instead.
      Factory.create_store!(%{
        name: "Only Shop",
        slug: "only-shop",
        featured: true,
        featured_rank: 1,
        cover_image_url: "https://cdn.example/only.png"
      })

      {:ok, view, _html} = live(conn, "/stores")

      assert has_element?(view, ~s(#featured-hero[href="/only-shop"]))
      refute has_element?(view, "#featured-tiles")
      refute render(view) =~ "Also featured"
    end

    test "the spotlight hides entirely when nothing is featured", %{conn: conn} do
      Factory.create_store!(%{name: "Plain Shop", slug: "plain-shop"})

      {:ok, view, _html} = live(conn, "/stores")

      refute has_element?(view, "#featured-spotlight")
    end

    defp hero_html(view), do: view |> element("#featured-hero") |> render()
    defp tile_html(view), do: view |> element("#featured-tiles") |> render()

    test "renders the merchant CTA and shared marketing chrome", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/stores")

      assert has_element?(view, "#main-nav")
      assert has_element?(view, "#stores-sell-cta")
      assert has_element?(view, ~s(#stores-sell-cta a[href="/auth/register"]))
    end

    test "curation strips hide when filters are active", %{conn: conn} do
      Factory.create_store!(%{
        name: "Featured Apparel",
        slug: "featured-apparel",
        featured: true,
        featured_rank: 1,
        cover_image_url: "https://cdn.example/apparel.png",
        theme_config: %{"theme" => "fashion"}
      })

      Factory.create_store!(%{
        name: "Beauty Standalone",
        slug: "beauty-standalone",
        theme_config: %{"theme" => "beauty"}
      })

      {:ok, view, _html} = live(conn, "/stores")
      assert has_element?(view, "#featured-spotlight")

      view
      |> element(~s|button[phx-click="select_theme"][phx-value-theme="beauty"]|)
      |> render_click()

      refute has_element?(view, "#featured-spotlight")
    end

    test "the hero carries the Featured pill and a working link", %{conn: conn} do
      Factory.create_store!(%{
        name: "Top Shop",
        slug: "top-shop",
        featured: true,
        featured_rank: 1,
        cover_image_url: "https://cdn.example/top-shop.png"
      })

      {:ok, view, _html} = live(conn, "/stores")

      assert has_element?(view, ~s(#featured-hero[href="/top-shop"]))
      assert has_element?(view, "#featured-hero .hero-star-solid")
    end
  end

  describe "browse rails" do
    test "an all-but-empty directory shows no rail headings at all", %{conn: conn} do
      Factory.create_store!(%{name: "Lonely Shop", slug: "lonely-shop"})

      {:ok, _view, html} = live(conn, "/stores")

      # One shop cannot fill a rail, and a heading over one card reads as broken.
      refute html =~ "Just opened"
      refute html =~ "Most visited"
    end

    test "rails appear once there are enough shops to fill one", %{conn: conn} do
      for i <- 1..6 do
        Factory.create_store!(%{name: "Rail Shop #{i}", slug: "rail-shop-#{i}"})
      end

      {:ok, _view, html} = live(conn, "/stores")

      assert html =~ "Just opened"
      assert html =~ "Most visited"
    end

    test "the rails survive a search and come back when it is cleared", %{conn: conn} do
      for i <- 1..6 do
        Factory.create_store!(%{name: "Rail Shop #{i}", slug: "rail-shop-#{i}"})
      end

      {:ok, view, html} = live(conn, "/stores")
      assert html =~ "Just opened"

      filtered =
        view
        |> element("#stores-search-form")
        |> render_change(%{"value" => "Rail Shop 1"})

      # Browsing rails step aside for results while a filter is active.
      refute filtered =~ "Just opened"

      cleared =
        view
        |> element("#stores-search-form")
        |> render_change(%{"value" => ""})

      assert cleared =~ "Just opened"
    end
  end
end
