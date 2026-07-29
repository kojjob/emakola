defmodule EmakolaWeb.Storefront.FaqLiveTest do
  @moduledoc """
  The storefront FAQ page renders the store's own question/answer pairs, with a
  neutral empty state when none have been added.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "GET /s/:slug/faq" do
    test "shows a neutral empty state when the store has no FAQs", %{conn: conn} do
      store = Factory.create_store!(%{name: "Empty FAQ", slug: "empty-faq"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/faq")

      assert html =~ "Frequently Asked Questions"
      assert html =~ "No FAQs have been added yet"

      assert html
             |> LazyHTML.from_fragment()
             |> LazyHTML.query(~s(meta[name="robots"][content="noindex, follow"]))
             |> Enum.any?()
    end

    test "renders the store's questions and answers", %{conn: conn} do
      store = Factory.create_store!(%{name: "FAQ Shop", slug: "faq-shop"})

      Factory.create_page_content!(store, %{
        faq_items: [
          %{"question" => "Do you ship nationwide?", "answer" => "Yes, across Ghana."},
          %{"question" => "What payment methods?", "answer" => "MoMo and cards."}
        ]
      })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/faq")

      assert html =~ "Do you ship nationwide?"
      assert html =~ "Yes, across Ghana."
      assert html =~ "What payment methods?"

      document = LazyHTML.from_fragment(html)

      assert document
             |> LazyHTML.query(~s(meta[name="robots"][content="index, follow"]))
             |> Enum.any?()

      assert document
             |> LazyHTML.query(~s(script[type="application/ld+json"]))
             |> LazyHTML.text() =~ ~s("FAQPage")
    end

    test "drops blank FAQ rows from a half-filled form", %{conn: conn} do
      store = Factory.create_store!(%{name: "Blank FAQ", slug: "blank-faq"})

      Factory.create_page_content!(store, %{
        faq_items: [
          %{"question" => "", "answer" => ""},
          %{"question" => "Real question?", "answer" => "Real answer."}
        ]
      })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/faq")

      assert html =~ "Real question?"
    end
  end
end
