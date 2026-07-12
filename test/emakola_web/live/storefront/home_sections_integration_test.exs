defmodule EmakolaWeb.Storefront.HomeSectionsIntegrationTest do
  @moduledoc """
  End-to-end seal for the theme-native home-section pipeline (spec:
  docs/superpowers/specs/2026-07-11-section-editor-design.md). These tests
  are NOT RED-first TDD — Tasks 1-6 already built `HomeSections`,
  `SectionRenderer`, and the Starter/Atelier decompositions; this file
  verifies the full round trip (put_layout -> saved_layout ->
  effective_layout -> SectionRenderer -> live storefront HTML) behaves as
  designed. Any failure here is a Task 1-6 bug, not a test to weaken.

  Landmark literals (Starter theme, Task 5):
    - Hero: "Your New Favorite Store" (theme default `hero.title`)
    - Category Pills: "Shop by Category"
    - Featured Products: "Featured Products"
    - Trust: "Secure Payment"
    - Newsletter: "Stay in the Know" (theme default `newsletter.title`)

  The factory's default store theme is "market" (see
  `Emakola.Themes.ThemeResolver`'s `@default_theme`), not "starter", so every
  test here sets `theme_config["theme"]` explicitly via the store `:update`
  action before asserting on Starter-specific markup.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Themes.HomeSections
  alias Emakola.Themes.Starter

  defp set_starter_theme!(store) do
    store
    |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => "starter"}})
    |> Ash.update!(authorize?: false)
  end

  test "a saved starter layout reorders and hides sections on the live storefront", %{
    conn: conn
  } do
    {merchant, store} = create_merchant_with_store!()
    store = set_starter_theme!(store)

    defaults = HomeSections.default_layout(Starter)

    reordered =
      defaults
      |> Enum.reject(&(&1["type"] == "starter/newsletter"))
      |> Enum.reverse()

    {:ok, _store} = HomeSections.put_layout(merchant, store, "starter", reordered)

    {:ok, _view, html} = live(conn, "/s/#{store.slug}")

    # Newsletter section was dropped from the saved layout entirely.
    refute html =~ "Stay in the Know"
    # Reversed order: Trust now renders before Hero.
    assert String.match?(html, ~r/Secure Payment.*Your New Favorite Store/s)
  end

  test "a store with no saved layout renders the unchanged default home", %{conn: conn} do
    {_merchant, store} = create_merchant_with_store!()
    store = set_starter_theme!(store)

    {:ok, _view, html} = live(conn, "/s/#{store.slug}")

    assert html =~ "Your New Favorite Store"
    assert html =~ "Stay in the Know"
  end

  test "the page-builder home override still wins over section layouts", %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    store = set_starter_theme!(store)

    {:ok, _page} =
      Emakola.Pages.create_page(
        %{
          store_id: store.id,
          slug: "home",
          title: "Home",
          published: true,
          blocks: [
            %{
              "id" => "override-block",
              "type" => "text_section",
              "content" => %{"title" => "PAGE BUILDER OVERRIDE BLOCK"}
            }
          ]
        },
        authorize?: false
      )

    # A section layout is also saved for the active theme — the page-builder
    # override must win regardless.
    {:ok, _store} =
      HomeSections.put_layout(merchant, store, "starter", HomeSections.default_layout(Starter))

    {:ok, _view, html} = live(conn, "/s/#{store.slug}")

    assert html =~ "PAGE BUILDER OVERRIDE BLOCK"
    refute html =~ "Your New Favorite Store"
  end

  # Controller-added (closes a deferred review finding): the schema-scoped
  # URL rule was previously only exercised directly against the sanitizer
  # via a `FakeSection` module (see home_sections_test.exs), because the
  # registry resolved only "block/..." types until the theme fan-out
  # registered real sectionized themes. Now that Starter is registered,
  # verify the round trip end-to-end through `put_layout` and the live
  # storefront render for both halves of the rule:
  #
  #   - positive: a colon-containing string setting on a REAL starter
  #     section (Hero) survives untouched (colons are inert in plain
  #     strings, not URLs).
  #   - negative: none of Starter's five section schemas declare an
  #     `:image_url`/`:link`-typed setting, so the URL-blocking half of the
  #     rule can't be exercised end-to-end via a real starter type (that
  #     remains covered at the unit level in home_sections_test.exs against
  #     the public `FakeSection` seam). Instead, this asserts the
  #     complementary, already-documented behaviour: a `block/<type>` entry
  #     declares no settings schema (`BlockSection.settings_schema/0` is
  #     `[]`), so it is exempt from URL scoping by design — parity with the
  #     page builder's own unsanitized verbatim content model, NOT a claim
  #     that the value is harmless. Verified directly: `block/hero_banner`
  #     with `settings["cta_url"] => "javascript:alert(1)"` survives
  #     `put_layout` and renders as a LIVE `<a href="javascript:alert(1)">`.
  #     URL-position fields on blocks like hero_banner/split/image_banner/
  #     audio are a real stored-XSS vector once `put_layout` gets a web
  #     caller. The security follow-up (sanitize href/src at the
  #     block-render boundary, closing both this path and the pre-existing
  #     page-builder one) is tracked in TODO.md and gates the section-editor
  #     UI PR.
  test "put_layout URL-scoping survives end-to-end for a real starter section and a block-bridge entry",
       %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    store = set_starter_theme!(store)

    heading_entries =
      Enum.map(HomeSections.default_layout(Starter), fn entry ->
        if entry["type"] == "starter/hero" do
          Map.put(entry, "settings", %{"heading" => "Sale: Ends Friday"})
        else
          entry
        end
      end)

    {:ok, store} = HomeSections.put_layout(merchant, store, "starter", heading_entries)

    {:ok, _view, html} = live(conn, "/s/#{store.slug}")
    assert html =~ "Sale: Ends Friday"

    block_entries = [
      %{
        "id" => "js-block",
        "type" => "block/text_section",
        "enabled" => true,
        "settings" => %{"title" => "Notice", "body" => "javascript:alert(1)"}
      }
    ]

    {:ok, store} = HomeSections.put_layout(merchant, store, "starter", block_entries)

    {:ok, _view, html} = live(conn, "/s/#{store.slug}")
    assert html =~ "javascript:alert(1)"
  end

  # The seal for the section-editor UI (Task 6): every prior test in this
  # file drives persistence directly through `HomeSections.put_layout/4` —
  # proving the STORAGE/RENDER half of the pipeline, which Tasks 1-5 (core)
  # already own. This test is NOT RED-first — `DesignSectionsLive` was
  # already built and covered unit-by-unit in
  # `design_sections_live_test.exs` — it seals the remaining, previously
  # unverified half: that a merchant driving the ADMIN EDITOR (mount,
  # drag-reorder, Publish) produces the exact same effect on the LIVE
  # STOREFRONT as a direct `put_layout` call. A `put_layout`-only test would
  # re-test the core PR; this one proves the editor's write path and the
  # storefront's read path agree.
  test "a reorder published through the section editor renders on the live storefront", %{
    conn: conn
  } do
    {merchant, store} = create_merchant_with_store!()
    store = set_starter_theme!(store)

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {:ok, view, _html} = live(conn, "/admin/design/sections")

    # Full id order: Trust moves ahead of Hero (default order is Hero ->
    # Category Pills -> Featured Products -> Trust -> Newsletter).
    order = [
      "starter/trust",
      "starter/hero",
      "starter/category_pills",
      "starter/featured_products",
      "starter/newsletter"
    ]

    render_hook(view, "reorder", %{"order" => order})
    render_click(view, "publish")

    saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
    assert ["starter/trust", "starter/hero" | _] = Enum.map(saved, & &1["id"])

    {:ok, _view, html} = live(conn, "/s/#{store.slug}")

    # Trust ("Secure Payment") now renders before Hero ("Your New Favorite
    # Store") on the public storefront — the editor's write path and the
    # storefront's read path agree.
    assert String.match?(html, ~r/Secure Payment.*Your New Favorite Store/s)
  end
end
