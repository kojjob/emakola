defmodule EmakolaWeb.Storefront.ReviewPhotoUploadTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  require Ash.Query

  setup %{conn: conn} do
    store = Factory.create_store!(%{name: "Review Shop"})
    product = Factory.create_product!(store, %{title: "Shea Butter", status: :active})
    variant = Factory.create_variant!(product, store, %{price: 5_000})

    customer =
      Emakola.Customers.Customer
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "efua@example.com",
        name: "Efua Owusu",
        store_id: store.id,
        password: "password123",
        password_confirmation: "password123"
      })
      |> Ash.create!(authorize?: false)

    # A delivered order containing the product makes the customer
    # review-eligible (PurchaseVerifier.has_delivered_order?/3).
    order =
      Factory.create_order!(store, %{
        customer_id: customer.id,
        status: :delivered,
        total: 5_000,
        subtotal: 5_000
      })

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!(authorize?: false)

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))
    conn = Phoenix.ConnTest.init_test_session(conn, %{"customer_token" => token})

    %{conn: conn, store: store, product: product}
  end

  test "review photos upload to platform storage, not local disk", %{
    conn: conn,
    store: store,
    product: product
  } do
    Mox.stub(Emakola.StorageMock, :upload, fn _binary, path, _opts ->
      {:ok, "https://cdn.example.com/#{path}"}
    end)

    {:ok, view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")
    Mox.allow(Emakola.StorageMock, self(), view.pid)

    render_click(view, "set_review_rating", %{"rating" => "5"})

    photo =
      file_input(view, "form[phx-submit=submit_review]", :review_photos, [
        %{name: "photo.png", content: <<137, 80, 78, 71>>, type: "image/png"}
      ])

    render_upload(photo, "photo.png")

    view
    |> element("form[phx-submit=submit_review]")
    |> render_submit(%{"body" => "Melts beautifully.", "title" => ""})

    [review] =
      Emakola.Catalog.Review
      |> Ash.Query.filter(product_id == ^product.id)
      |> Ash.read!(authorize?: false)

    assert [%{"url" => url}] = review.images
    assert url == "https://cdn.example.com/stores/#{store.id}/reviews/" <> Path.basename(url)
  end
end
