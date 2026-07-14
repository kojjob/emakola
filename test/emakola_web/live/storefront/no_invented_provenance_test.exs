defmodule EmakolaWeb.Storefront.NoInventedProvenanceTest do
  @moduledoc """
  No theme may state a fact about how a merchant's goods were made, sourced, or
  by whom.

  The platform knows nothing about any of this. A theme is a design a merchant
  installs in one click, so every claim shipped as a theme default is made on
  behalf of a merchant who never made it and cannot withdraw it:

    * Beauty told every shopper "All our shea, cocoa, and baobab is sourced
      directly from West African women's cooperatives. Fair trade, every batch."
    * Fashion credited two organisations that do not exist — "the Mensah
      collective", "the Kwame house" — and said every piece was "sewn in small
      batches by tailors and artisans across Accra".
    * Pharmacy asserted the store was a **licensed, verified pharmacy** selling
      **genuine medicines**, which is a regulatory claim, not a marketing one.

  The line: a theme may carry mood, a name, and a layout. It may not carry a
  checkable fact about the goods. Where a merchant has such a fact, they write
  it themselves (theme config / the section editor) and it is theirs.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Themes.ThemeResolver

  # Every registered theme, not a hand-maintained list. Eight themes were missing
  # from the list this replaces, and a hand-list cannot cover a theme added
  # tomorrow.
  @all_themes ThemeResolver.theme_ids()

  # Claims about provenance, materials, ethics, licensing and efficacy. These
  # are facts about goods and about the merchant's business — not adjectives.
  @invented_claim ~r/
      (?:ethically|responsibly|sustainably)\s+sourced
    | sourced\s+(?:from|directly)
    | fair[\s-]?trade
    | (?:women'?s\s+)?cooperatives?
    | licensed\s+pharmacy
    | verified\s+pharmacy
    | genuine\s+medicines?
    | hand[\s-]?(?:made|picked|sewn|woven|crafted)
    | (?:made|sewn|woven|picked)\s+by\s+hand
    | handcrafted
    | handpicked
    | designed\s+in\s+\w+
    | small\s+batch(?:es)?
    | our\s+artisans
    | recyclable
    | biodegradable
    | cruelty[\s-]?free
    | eco[\s-]?friendly
    | (?:made|built|sewn)\s+in\s+ghana
    | crafted\s+(?:from|with\s+care)
    | solid\s+wood
    | dermatologist[\s-]?tested
  /ix

  # Claims about OTHER PEOPLE — that a crowd trusts this shop, that these goods
  # sell well, that someone curated them. A brand-new store with no orders and no
  # reviews must not tell shoppers thousands of others got there first.
  #
  # Real social proof is fine and is not matched here: actual review counts and
  # star ratings come from published reviews (Emakola.Themes.Testimonial), and
  # sale badges come from a real compare_at_price. Only fabrications are banned.
  #
  # `apos` matches a literal apostrophe OR the HTML entities HEEx escapes it to.
  # Vibrant's "Editor's Pick" badge walked straight through an earlier version of
  # this regex, because by the time the claim reaches the page it reads
  # "Editor&#39;s Pick" and a plain ' no longer matches.
  # The `#` must be escaped: these regexes use /x, where a bare # starts a
  # comment and would swallow the rest of the pattern.
  @apos "(?:'|’|&\\#39;|&\\#x27;)"
  @invented_social_proof ~r/
      thousands\s+(?:trust|of\s+(?:happy\s+)?customers)
    | trusted\s+by
    | join\s+\d[\d,+]*\s+(?:shoppers|customers)
    | best[\s-]?sell(?:er|ers|ing)
    | trending\s+(?:now|products?)
    | most\s+popular
    | popular\s+products?
    | editor#{@apos}?s?\s+pick
    | customer#{@apos}?s?\s+favourite
  /ix

  defp seed(theme) do
    store = Factory.create_store!(%{theme_config: %{"theme" => theme}})
    product = Factory.create_product!(store, %{status: :active, title: "Blue Notebook"})
    Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})
    {store, product}
  end

  describe "a theme states no fact about goods it knows nothing about" do
    for theme <- @all_themes do
      @theme theme

      test "#{theme} home page", %{conn: conn} do
        {store, _product} = seed(@theme)

        {:ok, _view, html} = live(conn, "/s/#{store.slug}")

        refute html =~ @invented_claim,
               "the #{@theme} home page claims something about how this store's goods were made or sourced"
      end

      test "#{theme} PDP", %{conn: conn} do
        {store, product} = seed(@theme)

        {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

        refute html =~ @invented_claim,
               "the #{@theme} PDP claims something about how this product was made or sourced"
      end

      test "#{theme} product list", %{conn: conn} do
        {store, _product} = seed(@theme)

        {:ok, _view, html} = live(conn, "/s/#{store.slug}/products")

        refute html =~ @invented_claim,
               "the #{@theme} product list claims something about how these goods were made"
      end
    end
  end

  describe "a store with no customers claims no customers" do
    for theme <- @all_themes do
      @theme theme

      # Seeded with several products and NO orders and NO reviews — a shop on its
      # first day. Anything the storefront says about popularity here, it invented.
      test "#{theme} home page", %{conn: conn} do
        {store, _product} = seed(@theme)

        for title <- ["Red Notebook", "Green Notebook", "Black Notebook", "White Notebook"] do
          extra = Factory.create_product!(store, %{status: :active, title: title})
          Factory.create_variant!(extra, store, %{price: 5000, stock_quantity: 10})
        end

        {:ok, _view, html} = live(conn, "/s/#{store.slug}")

        refute html =~ @invented_social_proof,
               "the #{@theme} home page tells shoppers this store is popular — it has no orders and no reviews"
      end
    end
  end

  describe "a merchant's own words are still their own" do
    test "a merchant who writes a sourcing story keeps it", %{conn: conn} do
      store =
        Factory.create_store!(%{
          theme_config: %{
            "theme" => "fashion",
            "editorial_intro" => %{
              "title" => "Made in Osu",
              "body" => "Every piece is hand-sewn by the four tailors in our Osu workshop."
            }
          }
        })

      product = Factory.create_product!(store, %{status: :active})
      Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      # This claim is TRUE for this merchant, because this merchant made it.
      # Removing the fabricated defaults must not gag a shop that can back it up.
      assert html =~ "Made in Osu"
      assert html =~ "hand-sewn by the four tailors in our Osu workshop"
    end
  end

  describe "product facts the merchant did record are still shown" do
    test "a material the merchant set on the product is not invented", %{conn: conn} do
      {store, product} = seed("atelier")

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      # Atelier printed "Handcrafted" as the material of every product that had
      # no material recorded. A product with no material stated has no material
      # stated.
      refute html =~ ~r/handcrafted/i
    end
  end
end
