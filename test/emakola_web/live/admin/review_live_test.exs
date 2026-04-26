defmodule EmakolaWeb.Admin.ReviewLiveTest do
  @moduledoc """
  LiveView tests for the admin review management page.
  Tests review table rendering, status filtering, and hide/unhide actions.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)

    {:ok, conn: conn, store: store, merchant: merchant}
  end

  describe "ReviewLive" do
    test "renders page with empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reviews")

      assert html =~ "Reviews"
      assert html =~ "No reviews found"
    end

    test "displays reviews in table", %{conn: conn, store: store} do
      product = Factory.create_product!(store, status: :active)
      _variant = Factory.create_variant!(product, store)
      customer = Factory.create_customer!(store, name: "Ama Mensah")

      order =
        Factory.create_order!(store,
          customer_id: customer.id,
          status: :delivered
        )

      create_review!(store, product, customer, order, %{
        rating: 4,
        title: "Great quality",
        body: "Really enjoyed this product."
      })

      {:ok, _view, html} = live(conn, ~p"/admin/reviews")

      assert html =~ product.title
      assert html =~ "Ama Mensah"
      assert html =~ "Great quality"
      assert html =~ "Published"
      assert html =~ "Hide"
    end

    test "filters reviews by status", %{conn: conn, store: store} do
      {product, customer, order} = setup_reviewable_product(store)

      review =
        create_review!(store, product, customer, order, %{
          rating: 5,
          body: "Amazing product!"
        })

      # Hide the review
      review
      |> Ash.Changeset.for_update(:hide, %{})
      |> Ash.update!(authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/admin/reviews")

      # Filter to published only -- should not show hidden review
      html = view |> element(~s(button[phx-value-status="published"])) |> render_click()
      refute html =~ "Amazing product!"

      # Filter to hidden -- should show the review
      html = view |> element(~s(button[phx-value-status="hidden"])) |> render_click()
      assert html =~ "Amazing product!"
      assert html =~ "Show"

      # Filter to all -- should show the review
      html = view |> element(~s(button[phx-value-status="all"])) |> render_click()
      assert html =~ "Amazing product!"
    end

    test "hides a review", %{conn: conn, store: store} do
      {product, customer, order} = setup_reviewable_product(store)

      _review =
        create_review!(store, product, customer, order, %{
          rating: 3,
          body: "It was okay."
        })

      {:ok, view, html} = live(conn, ~p"/admin/reviews")

      assert html =~ "Published"
      assert html =~ "Hide"

      html = view |> element(~s(button[phx-click="hide_review"])) |> render_click()

      assert html =~ "Review hidden"
      assert html =~ "Hidden"
      assert html =~ "Show"
    end

    test "unhides a review", %{conn: conn, store: store} do
      {product, customer, order} = setup_reviewable_product(store)

      review =
        create_review!(store, product, customer, order, %{
          rating: 2,
          body: "Not great."
        })

      # Hide it first
      review
      |> Ash.Changeset.for_update(:hide, %{})
      |> Ash.update!(authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/admin/reviews")

      html = view |> element(~s(button[phx-click="unhide_review"])) |> render_click()

      assert html =~ "Review restored"
      assert html =~ "Published"
    end

    test "shows status filter buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reviews")

      assert html =~ "All"
      assert html =~ "Published"
      assert html =~ "Hidden"
    end
  end

  # ── Test Helpers ──

  defp setup_reviewable_product(store) do
    product = Factory.create_product!(store, status: :active)
    _variant = Factory.create_variant!(product, store)
    customer = Factory.create_customer!(store)

    order =
      Factory.create_order!(store,
        customer_id: customer.id,
        status: :delivered
      )

    {product, customer, order}
  end

  defp create_review!(store, product, customer, order, attrs) do
    default = %{
      store_id: store.id,
      product_id: product.id,
      customer_id: customer.id,
      order_id: order.id,
      rating: 5,
      body: "Test review body"
    }

    Emakola.Catalog.Review
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!(authorize?: false)
  end

  defp create_authenticated_merchant! do
    store =
      Emakola.Stores.Store
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Store #{System.unique_integer([:positive])}",
        slug: "test-store-#{System.unique_integer([:positive])}"
      })
      |> Ash.create!(authorize?: false)

    merchant =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "merchant-#{System.unique_integer([:positive])}@test.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!(authorize?: false)

    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      merchant_id: merchant.id,
      store_id: store.id,
      role: :owner
    })
    |> Ash.create!(authorize?: false)

    {merchant, store}
  end

  defp authenticate_conn(conn, merchant) do
    subject = AshAuthentication.user_to_subject(merchant)

    conn
    |> init_test_session(%{"user_token" => subject})
  end
end
