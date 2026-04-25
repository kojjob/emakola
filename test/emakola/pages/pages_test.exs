defmodule Emakola.PagesTest do
  @moduledoc """
  Pins the Pages domain contract:

    * Page resource enforces unique (store_id, slug)
    * `fetch_published_page/2` returns published pages for a store
    * Drafts (published: false) never reach the storefront
    * Missing pages return :not_found, not a raise
    * Nil store input is tolerated (defensive — early in the request lifecycle)
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Pages

  setup do
    {:ok, store: Factory.create_store!(%{name: "Test Shop", slug: "test-shop"})}
  end

  describe "create_page/2" do
    test "creates a page with default empty blocks", %{store: store} do
      {:ok, page} =
        Pages.create_page(
          %{
            store_id: store.id,
            slug: "home",
            title: "Home"
          },
          authorize?: false
        )

      assert page.slug == "home"
      assert page.title == "Home"
      assert page.published == false
      assert page.blocks == []
      assert page.meta == %{}
    end

    test "rejects duplicate slug for the same store", %{store: store} do
      {:ok, _} =
        Pages.create_page(
          %{store_id: store.id, slug: "home", title: "Home"},
          authorize?: false
        )

      assert {:error, _changeset} =
               Pages.create_page(
                 %{store_id: store.id, slug: "home", title: "Home v2"},
                 authorize?: false
               )
    end

    test "allows the same slug across different stores", %{store: store_a} do
      store_b = Factory.create_store!(%{name: "Other Shop", slug: "other-shop"})

      {:ok, _} =
        Pages.create_page(
          %{store_id: store_a.id, slug: "home", title: "A"},
          authorize?: false
        )

      assert {:ok, _} =
               Pages.create_page(
                 %{store_id: store_b.id, slug: "home", title: "B"},
                 authorize?: false
               )
    end
  end

  describe "fetch_published_page/2" do
    test "returns the page when one is published at the slug", %{store: store} do
      {:ok, _} =
        Pages.create_page(
          %{
            store_id: store.id,
            slug: "home",
            title: "Home",
            published: true,
            blocks: [%{"id" => "x", "type" => "spacer", "content" => %{}}]
          },
          authorize?: false
        )

      assert {:ok, page} = Pages.fetch_published_page(store, "home")
      assert page.slug == "home"
      assert length(page.blocks) == 1
    end

    test "returns :not_found when the page is a draft", %{store: store} do
      {:ok, _} =
        Pages.create_page(
          %{store_id: store.id, slug: "home", title: "Home", published: false},
          authorize?: false
        )

      assert :not_found = Pages.fetch_published_page(store, "home")
    end

    test "returns :not_found when no page exists at the slug", %{store: store} do
      assert :not_found = Pages.fetch_published_page(store, "home")
    end

    test "returns :not_found for a nil store" do
      assert :not_found = Pages.fetch_published_page(nil, "home")
    end

    test "returns :not_found for a non-string slug", %{store: store} do
      assert :not_found = Pages.fetch_published_page(store, nil)
    end
  end

  describe "list_pages_for_store/1" do
    test "returns pages scoped to the store, sorted by slug", %{store: store} do
      {:ok, _} =
        Pages.create_page(
          %{store_id: store.id, slug: "home", title: "Home"},
          authorize?: false
        )

      {:ok, _} =
        Pages.create_page(
          %{store_id: store.id, slug: "about", title: "About"},
          authorize?: false
        )

      {:ok, pages} = Pages.list_pages_for_store(store.id, authorize?: false)
      assert length(pages) == 2
      assert Enum.map(pages, & &1.slug) == ["about", "home"]
    end

    test "returns empty list when the store has no pages", %{store: store} do
      assert {:ok, []} = Pages.list_pages_for_store(store.id, authorize?: false)
    end
  end
end
