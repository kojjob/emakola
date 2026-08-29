defmodule EmakolaWeb.Storefront.SEOIndexabilityTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  describe "private and transactional pages" do
    setup do
      %{store: create_store!(%{name: "Private Route Shop", slug: "private-route-shop"})}
    end

    test "cart and checkout emit noindex", %{conn: conn, store: store} do
      for path <- ["/s/#{store.slug}/cart", "/s/#{store.slug}/checkout"] do
        document = conn |> get(path) |> html_response(200) |> LazyHTML.from_fragment()

        assert document
               |> LazyHTML.query(~s(meta[name="robots"][content="noindex, nofollow"]))
               |> Enum.any?()
      end
    end

    test "customer and merchant auth pages emit noindex", %{conn: conn, store: store} do
      for path <- ["/s/#{store.slug}/login", "/auth/login"] do
        document = conn |> get(path) |> html_response(200) |> LazyHTML.from_fragment()

        assert document
               |> LazyHTML.query(~s(meta[name="robots"][content="noindex, nofollow"]))
               |> Enum.any?()
      end
    end
  end

  describe "published custom pages" do
    test "emits the merchant SEO title and canonical URL", %{conn: conn} do
      store = create_store!(%{name: "Page Shop", slug: "page-shop"})

      {:ok, page} =
        Emakola.Pages.create_page(
          %{
            store_id: store.id,
            slug: "size-guide",
            title: "Size Guide",
            published: true,
            blocks: [%{"id" => "intro", "type" => "text_section", "content" => %{}}],
            meta: %{
              "seo_title" => "Ghanaian Clothing Size Guide",
              "description" => "Find the right clothing size before you order."
            }
          },
          authorize?: false
        )

      html = conn |> get("/s/#{store.slug}/p/#{page.slug}") |> html_response(200)
      canonical = EmakolaWeb.SEO.Canonical.page_url(store, page)
      document = LazyHTML.from_fragment(html)

      assert document |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim() ==
               "Ghanaian Clothing Size Guide"

      assert document
             |> LazyHTML.query(~s(link[rel="canonical"][href="#{canonical}"]))
             |> Enum.any?()

      assert document
             |> LazyHTML.query(~s(meta[name="robots"][content="index, follow"]))
             |> Enum.any?()
    end
  end
end
