defmodule EmakolaWeb.Storefront.DownloadControllerTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory
  import Mox

  setup :verify_on_exit!

  alias Emakola.Catalog.DigitalFile
  alias Emakola.Fulfillment.DownloadGrant

  defp digital_store! do
    create_store!()
    |> Ash.Changeset.for_update(:update_settings, %{
      enabled_product_types: [:physical, :digital_download]
    })
    |> Ash.update!(authorize?: false)
  end

  defp register_customer!(store, email \\ nil) do
    Emakola.Customers.Customer
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email || "buyer-#{System.unique_integer([:positive])}@example.com",
      name: "Buyer",
      phone: "+233240000000",
      store_id: store.id,
      password: "password123",
      password_confirmation: "password123"
    })
    |> Ash.create!(authorize?: false)
  end

  defp issue_grant!(store, customer, overrides \\ %{}) do
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
        file_name: "asset.zip",
        storage_key: "stores/#{store.id}/files/asset-#{System.unique_integer([:positive])}.zip",
        content_type: "application/zip",
        byte_size: 1_000_000
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
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))
    Phoenix.ConnTest.init_test_session(conn, %{"customer_token" => token})
  end

  setup %{conn: conn} do
    store = digital_store!()
    customer = register_customer!(store)
    grant = issue_grant!(store, customer)
    {:ok, conn: conn, store: store, customer: customer, grant: grant}
  end

  describe "GET /@:store_slug/downloads/:id" do
    test "redirects to presigned URL for a valid owner", %{
      conn: conn,
      store: s,
      customer: c,
      grant: g
    } do
      expect(Emakola.StorageMock, :presigned_url, fn _path, _opts ->
        {:ok, "https://cdn.example/sig?token=abc"}
      end)

      conn = conn |> log_in(c) |> get("/@#{s.slug}/downloads/#{g.id}")

      assert redirected_to(conn, 302) == "https://cdn.example/sig?token=abc"
    end

    test "returns 401 when no customer session is present", %{conn: conn, store: s, grant: g} do
      conn = get(conn, "/@#{s.slug}/downloads/#{g.id}")

      assert conn.status == 401
    end

    test "returns 404 when another customer tries to download", %{conn: conn, store: s, grant: g} do
      other = register_customer!(s, "other-#{System.unique_integer([:positive])}@example.com")

      conn = conn |> log_in(other) |> get("/@#{s.slug}/downloads/#{g.id}")

      assert conn.status == 404
    end

    test "returns 404 for an unknown grant id", %{conn: conn, store: s, customer: c} do
      fake_id = Ecto.UUID.generate()
      conn = conn |> log_in(c) |> get("/@#{s.slug}/downloads/#{fake_id}")

      assert conn.status == 404
    end

    test "returns 410 Gone for an expired grant", %{conn: conn, store: s, customer: c} do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      grant = issue_grant!(s, c, %{expires_at: past})

      conn = conn |> log_in(c) |> get("/@#{s.slug}/downloads/#{grant.id}")

      assert conn.status == 410
      assert conn.resp_body =~ "expired"
    end

    test "returns 410 Gone for a grant at its download limit",
         %{conn: conn, store: s, customer: c} do
      grant = issue_grant!(s, c, %{download_limit: 1})

      # First download succeeds (consumes the limit)
      expect(Emakola.StorageMock, :presigned_url, fn _, _ -> {:ok, "https://cdn/sig"} end)
      conn1 = conn |> log_in(c) |> get("/@#{s.slug}/downloads/#{grant.id}")
      assert redirected_to(conn1, 302) == "https://cdn/sig"

      # Second download is refused; storage must NOT be called again.
      conn2 =
        Phoenix.ConnTest.build_conn() |> log_in(c) |> get("/@#{s.slug}/downloads/#{grant.id}")

      assert conn2.status == 410
      assert conn2.resp_body =~ "limit"
    end

    test "returns 503 when the storage adapter fails", %{
      conn: conn,
      store: s,
      customer: c,
      grant: g
    } do
      expect(Emakola.StorageMock, :presigned_url, fn _, _ -> {:error, :s3_unavailable} end)

      conn = conn |> log_in(c) |> get("/@#{s.slug}/downloads/#{g.id}")

      assert conn.status == 503
    end

    test "returns 404 for a grant with nil customer_id (guest grants need token flow)",
         %{conn: conn, store: s, customer: c} do
      grant = issue_grant!(s, c, %{customer_id: nil})

      conn = conn |> log_in(c) |> get("/@#{s.slug}/downloads/#{grant.id}")

      assert conn.status == 404
    end
  end
end
