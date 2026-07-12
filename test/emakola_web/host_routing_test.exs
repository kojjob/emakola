defmodule EmakolaWeb.HostRoutingTest do
  @moduledoc """
  Regression for the storefront reload-loop flicker: the storefront must be
  routed BY HOST so the browser address-bar URL matches the mounted LiveView.

  `<slug>.makola.io/` mounts StoreLive at root (address bar stays "/", and the
  router maps "/" → StoreLive on that host); `makola.io/` keeps mounting the
  apex LandingLive. Before this change the storefront was served-in-place via
  path rewriting, so LiveView's client saw "/" map to LandingLive (not its
  StoreLive) and force-reloaded forever.

  async: false because it mutates the global :store_subdomain_base app env.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox

  alias Emakola.Catalog.DigitalFile
  alias Emakola.Factory
  alias Emakola.Fulfillment.DownloadGrant

  setup :verify_on_exit!

  setup do
    previous = Application.get_env(:emakola, :store_subdomain_base)
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")

    on_exit(fn ->
      if previous do
        Application.put_env(:emakola, :store_subdomain_base, previous)
      else
        Application.delete_env(:emakola, :store_subdomain_base)
      end
    end)

    {_merchant, store} = Factory.create_merchant_with_store!(%{name: "Kente Kingdom"})
    %{store: store}
  end

  describe "GET / by host" do
    test "a store subdomain renders the storefront (not the landing page)", %{
      conn: conn,
      store: store
    } do
      conn = %{conn | host: "#{store.slug}.makola.io"}

      html = conn |> get("/") |> html_response(200)

      assert html =~ store.name
      refute html =~ "Start selling — free"
    end

    test "the apex host renders the landing page", %{conn: conn} do
      conn = %{conn | host: "makola.io"}

      html = conn |> get("/") |> html_response(200)

      assert html =~ "Start selling — free"
    end
  end

  describe "storefront LiveView mounted by host" do
    test "a store subdomain connects and renders the cart without redirecting", %{
      conn: conn,
      store: store
    } do
      conn = %{conn | host: "#{store.slug}.makola.io"}

      {:ok, view, html} = live(conn, "/cart")

      # Store resolved from host (no redirect-loop back to "/")
      refute_redirected(view, "/")
      assert html =~ "empty" or html =~ "Shopping Bag"
    end

    test "the newsletter form subscribes on the host-routed storefront (:storefront_root)", %{
      conn: conn,
      store: store
    } do
      require Ash.Query

      conn = %{conn | host: "#{store.slug}.makola.io"}
      {:ok, view, _html} = live(conn, "/")

      html = render_submit(view, "subscribe_newsletter", %{"email" => "host@example.com"})

      assert html =~ "Thanks for subscribing"

      assert [subscriber] =
               Emakola.Customers.NewsletterSubscriber
               |> Ash.Query.filter(store_id == ^store.id)
               |> Ash.read!(authorize?: false)

      assert Ash.CiString.value(subscriber.email) == "host@example.com"
    end
  end

  describe "a host with no store" do
    test "GET /cart redirects to the ABSOLUTE apex root (not relative / — that would loop)",
         %{conn: conn} do
      conn = %{conn | host: "makola.io"}

      assert {:error, {:redirect, %{to: to}}} = live(conn, "/cart")
      assert to == EmakolaWeb.Endpoint.url() <> "/"
    end
  end

  # Legacy apex aliases (emakola.com) must be in @apex_hosts. ResolveStoreHost
  # redirects no-store hosts to Endpoint.url() <> "/"; if the deployed apex host
  # is not host-locked to the apex scope it falls into the storefront catch-all
  # and loops. Guards against re-introducing that loop on a config flip.
  describe "GET / on a legacy apex alias host" do
    test "renders the landing page (apex), not a storefront/redirect", %{conn: conn} do
      conn = %{conn | host: "emakola.com"}

      html = conn |> get("/") |> html_response(200)

      assert html =~ "Start selling — free"
    end
  end

  # Storefront CONTROLLER routes (logout + downloads) must also exist at ROOT,
  # host-resolved — otherwise logged-in subdomain customers 404 on sign-out and
  # download links (which now render root-relative via store_path/2).
  describe "storefront controller routes by host" do
    setup %{store: store} do
      customer = register_customer!(store)
      %{customer: customer}
    end

    test "GET /auth/customer-logout clears the customer session and redirects (not 404)", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      conn =
        %{conn | host: "#{store.slug}.makola.io"}
        |> log_in_customer(customer)
        |> get("/auth/customer-logout")

      assert redirected_to(conn, 302)
      assert get_session(conn, :customer_token) == nil
    end

    test "GET /downloads/:id redirects to the presigned URL for a valid owner (not 404)", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      grant = issue_grant!(store, customer)

      expect(Emakola.StorageMock, :presigned_url, fn _path, _opts ->
        {:ok, "https://cdn.example/sig?token=abc"}
      end)

      conn =
        %{conn | host: "#{store.slug}.makola.io"}
        |> log_in_customer(customer)
        |> get("/downloads/#{grant.id}")

      assert redirected_to(conn, 302) == "https://cdn.example/sig?token=abc"
    end

    test "GET /downloads/:id returns 404 for an unknown grant (store resolved, not a routing 404)",
         %{conn: conn, store: store, customer: customer} do
      conn =
        %{conn | host: "#{store.slug}.makola.io"}
        |> log_in_customer(customer)
        |> get("/downloads/#{Ecto.UUID.generate()}")

      assert conn.status == 404
    end
  end

  # Regression for the #189 host-routing latent crash: storefront detail
  # LiveViews pattern-matched "store_slug" in mount/3, but the subdomain routes
  # (/products/:slug, /category/:slug, ...) carry the store in the HOST, not the
  # path — so params have no store_slug and mount/3 raised FunctionClauseError.
  # The store is already in socket.assigns.store via the on_mount hook.
  describe "storefront detail LiveViews mounted by host" do
    test "a product detail page mounts on the subdomain (params carry no store_slug)", %{
      conn: conn,
      store: store
    } do
      product = Factory.create_product!(store, status: :active)
      Factory.create_variant!(product, store)

      conn = %{conn | host: "#{store.slug}.makola.io"}

      assert {:ok, _view, _html} = live(conn, "/products/#{product.slug}")
    end

    test "a category page mounts on the subdomain (params carry no store_slug)", %{
      conn: conn,
      store: store
    } do
      category =
        Emakola.Catalog.Category
        |> Ash.Changeset.for_create(:create, %{name: "Textiles", store_id: store.id})
        |> Ash.create!(authorize?: false)

      conn = %{conn | host: "#{store.slug}.makola.io"}

      assert {:ok, _view, _html} = live(conn, "/category/#{category.slug}")
    end
  end

  defp log_in_customer(conn, customer) do
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))
    Phoenix.ConnTest.init_test_session(conn, %{"customer_token" => token})
  end

  defp register_customer!(store) do
    Emakola.Customers.Customer
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "buyer-#{System.unique_integer([:positive])}@example.com",
      name: "Buyer",
      phone: "+23324#{System.unique_integer([:positive])}",
      store_id: store.id,
      password: "password123",
      password_confirmation: "password123"
    })
    |> Ash.create!(authorize?: false)
  end

  defp issue_grant!(store, customer) do
    store =
      store
      |> Ash.Changeset.for_update(:update_settings, %{
        enabled_product_types: [:physical, :digital_download]
      })
      |> Ash.update!(authorize?: false)

    product = Factory.create_product!(store, product_type: :digital_download)
    variant = Factory.create_variant!(product, store)
    order = Factory.create_order!(store, customer_id: customer.id)

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
    |> Ash.Changeset.for_create(:issue, %{
      store_id: store.id,
      order_id: order.id,
      line_item_id: line_item.id,
      customer_id: customer.id,
      digital_file_id: file.id
    })
    |> Ash.create!(authorize?: false)
  end
end
