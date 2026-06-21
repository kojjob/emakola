defmodule EmakolaWeb.Admin.Content.PageContentLiveTest do
  @moduledoc """
  The merchant admin editor for storefront page content (About / Contact / FAQ /
  Policies). Lazily materialises the store's content row on mount and saves each
  tab to the store-scoped `StorePageContent`.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.LiveViewHelpers

  describe "PageContentLive (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/content/pages")
    end
  end

  describe "PageContentLive (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders the tabbed editor and lazily creates a content row", %{conn: conn, store: store} do
      refute content_row(store)

      {:ok, _view, html} = live(conn, ~p"/admin/content/pages")

      assert html =~ "Store Pages"
      assert html =~ "About"
      assert html =~ "FAQ"
      assert html =~ "Policies"

      assert content_row(store)
    end

    test "saves the About headline and story", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/content/pages")

      render_hook(view, "update_scalar", %{"field" => "about_headline", "value" => "Our Bakery"})
      render_hook(view, "update_scalar", %{"field" => "about_story", "value" => "Founded 2021."})
      html = render_hook(view, "save_about", %{})

      assert html =~ "Saved"

      content = content_row(store)
      assert content.about_headline == "Our Bakery"
      assert content.about_story == "Founded 2021."
    end

    test "adds, fills and removes a FAQ row", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/content/pages")

      render_hook(view, "add_item", %{"collection" => "faq_items"})

      render_hook(view, "update_item", %{
        "collection" => "faq_items",
        "index" => "0",
        "field" => "question",
        "value" => "Open hours?"
      })

      render_hook(view, "update_item", %{
        "collection" => "faq_items",
        "index" => "0",
        "field" => "answer",
        "value" => "9 to 5."
      })

      render_hook(view, "save_faq", %{})

      assert content_row(store).faq_items == [
               %{"question" => "Open hours?", "answer" => "9 to 5."}
             ]

      render_hook(view, "remove_item", %{"collection" => "faq_items", "index" => "0"})
      render_hook(view, "save_faq", %{})

      assert content_row(store).faq_items == []
    end

    test "saves the policy bodies", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/content/pages")

      render_hook(view, "update_scalar", %{
        "field" => "shipping_returns",
        "value" => "2-day delivery."
      })

      render_hook(view, "update_scalar", %{
        "field" => "privacy_policy",
        "value" => "We keep data safe."
      })

      render_hook(view, "save_policies", %{})

      content = content_row(store)
      assert content.shipping_returns == "2-day delivery."
      assert content.privacy_policy == "We keep data safe."
    end
  end

  defp content_row(store) do
    case Emakola.Stores.get_page_content(store.id, authorize?: false, not_found_error?: false) do
      {:ok, content} -> content
      _ -> nil
    end
  end
end
