defmodule EmakolaWeb.Storefront.PoliciesLiveTest do
  @moduledoc """
  The storefront Policies page is a single page with three anchored sections
  (shipping/returns, privacy, terms). Blank sections show sensible, store-name
  driven templated defaults that the merchant can override.
  """
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "GET /:slug/policies" do
    test "renders three anchored sections with templated defaults when blank", %{conn: conn} do
      store = Factory.create_store!(%{name: "Policy Store", slug: "policy-store"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/policies")

      assert html =~ ~s(id="shipping")
      assert html =~ ~s(id="privacy")
      assert html =~ ~s(id="terms")
      assert html =~ "Policy Store"
      assert html =~ "only collects the information"

      assert html
             |> LazyHTML.from_fragment()
             |> LazyHTML.query(
               ~s(link[rel="canonical"][href="http://localhost:4000/#{store.slug}/policies"])
             )
             |> Enum.any?()
    end

    test "renders the store's custom policy text", %{conn: conn} do
      store = Factory.create_store!(%{name: "Custom Policy", slug: "custom-policy"})

      Factory.create_page_content!(store, %{
        shipping_returns: "We deliver within Accra in 1 day.",
        privacy_policy: "We use Paystack for payments.",
        terms_of_service: "All sales final."
      })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/policies")

      assert html =~ "We deliver within Accra in 1 day."
      assert html =~ "We use Paystack for payments."
      assert html =~ "All sales final."
    end
  end
end
