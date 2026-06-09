defmodule EmakolaWeb.Storefront.AccountDownloadsLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Catalog.DigitalFile
  alias Emakola.Fulfillment.DownloadGrant

  defp digital_store! do
    create_store!()
    |> Ash.Changeset.for_update(:update_settings, %{
      enabled_product_types: [:physical, :digital_download]
    })
    |> Ash.update!(authorize?: false)
  end

  defp register_customer!(store) do
    Emakola.Customers.Customer
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "buyer-#{System.unique_integer([:positive])}@example.com",
      name: "Ama Buyer",
      phone: "+233240000000",
      store_id: store.id,
      password: "password123",
      password_confirmation: "password123"
    })
    |> Ash.create!(authorize?: false)
  end

  defp issue_grant!(store, customer, file_name, overrides \\ %{}) do
    product = create_product!(store, product_type: :digital_download)
    variant = create_variant!(product, store)
    order = create_order!(store, customer_id: customer.id)

    line_item =
      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant.id,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

    file =
      DigitalFile
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        product_id: product.id,
        file_name: file_name,
        storage_key:
          "stores/#{store.id}/files/#{file_name}-#{System.unique_integer([:positive])}",
        content_type: "application/zip",
        byte_size: 5_242_880
      })
      |> Ash.create!(authorize?: false)

    DownloadGrant
    |> Ash.Changeset.for_create(
      :issue,
      Map.merge(
        %{
          store_id: store.id,
          order_id: order.id,
          line_item_id: line_item.id,
          customer_id: customer.id,
          digital_file_id: file.id
        },
        Map.new(overrides)
      )
    )
    |> Ash.create!(authorize?: false)
  end

  defp log_in(conn, customer) do
    token = AshAuthentication.user_to_subject(customer)
    Phoenix.ConnTest.init_test_session(conn, %{"customer_token" => token})
  end

  setup %{conn: conn} do
    store = digital_store!()
    customer = register_customer!(store)
    {:ok, conn: conn, store: store, customer: customer}
  end

  describe "mount — auth gate" do
    test "redirects unauthenticated visitor to login", %{conn: conn, store: s} do
      assert {:error, {:redirect, %{to: redirect_to}}} =
               live(conn, ~p"/s/#{s.slug}/account/downloads")

      assert redirect_to =~ "/login"
    end
  end

  describe "mount — empty state" do
    test "shows empty-state message when customer has no grants",
         %{conn: conn, store: s, customer: c} do
      {:ok, _view, html} = conn |> log_in(c) |> live(~p"/s/#{s.slug}/account/downloads")

      assert html =~ "no downloads" or html =~ "No downloads"
    end
  end

  describe "mount — listing grants" do
    test "lists active grants with file names and download links",
         %{conn: conn, store: s, customer: c} do
      _g1 = issue_grant!(s, c, "ebook.pdf")
      _g2 = issue_grant!(s, c, "soundtrack.mp3")

      {:ok, _view, html} = conn |> log_in(c) |> live(~p"/s/#{s.slug}/account/downloads")

      assert html =~ "ebook.pdf"
      assert html =~ "soundtrack.mp3"
      # Both rows render a download link to the controller endpoint
      assert html =~ "/s/#{s.slug}/downloads/"
    end

    test "shows :expired badge for grants whose expires_at is in the past",
         %{conn: conn, store: s, customer: c} do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      _g = issue_grant!(s, c, "old.zip", %{expires_at: past})

      {:ok, _view, html} = conn |> log_in(c) |> live(~p"/s/#{s.slug}/account/downloads")

      assert html =~ "Expired" or html =~ "expired"
    end

    test "shows :limit_reached badge for grants at their download limit",
         %{conn: conn, store: s, customer: c} do
      grant = issue_grant!(s, c, "single-use.zip", %{download_limit: 1})

      # Simulate the buyer having downloaded once
      grant
      |> Ash.Changeset.for_update(:increment_download_count, %{})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = conn |> log_in(c) |> live(~p"/s/#{s.slug}/account/downloads")

      assert html =~ "Limit reached" or html =~ "limit reached"
    end

    test "does not show grants belonging to another customer",
         %{conn: conn, store: s, customer: c} do
      _mine = issue_grant!(s, c, "my-file.zip")

      other = register_customer!(s)
      _theirs = issue_grant!(s, other, "their-file.zip")

      {:ok, _view, html} = conn |> log_in(c) |> live(~p"/s/#{s.slug}/account/downloads")

      assert html =~ "my-file.zip"
      refute html =~ "their-file.zip"
    end
  end
end
