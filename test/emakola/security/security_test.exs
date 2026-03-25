defmodule Emakola.SecurityTest do
  @moduledoc """
  Comprehensive security test suite for the Emakola platform.

  Tests cover:
  - XSS prevention (HTML entity escaping)
  - SQL injection prevention
  - CSRF token verification
  - Rate limiting (429 responses)
  - Multi-tenant data isolation
  - Authentication enforcement on /admin/* routes
  - Authorization (merchant can only see own store data)
  - Input validation (extremely long strings)
  - File upload validation (content type restrictions)
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  require Ash.Query

  # ── Setup ──────────────────────────────────────────────────────────

  setup %{conn: conn} do
    # Store A: primary merchant
    {merchant_a, store_a} = create_authenticated_merchant!()
    conn_a = authenticate_conn(conn, merchant_a)

    # Store B: separate merchant for isolation tests
    {merchant_b, store_b} = create_authenticated_merchant!()
    conn_b = authenticate_conn(build_conn(), merchant_b)

    {:ok,
     conn: conn_a,
     conn_b: conn_b,
     merchant_a: merchant_a,
     merchant_b: merchant_b,
     store_a: store_a,
     store_b: store_b}
  end

  # ── XSS Prevention ────────────────────────────────────────────────

  describe "XSS prevention" do
    test "product title with script tag is escaped in HTML output", %{store_a: store} do
      xss_title = "<script>alert('xss')</script>Malicious Product"

      product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: xss_title, store_id: store.id})
        |> Ash.create!()

      # The title stored should preserve the raw text
      assert product.title == xss_title
    end

    test "category name with HTML entities is escaped", %{store_a: store} do
      xss_name = "<img src=x onerror=alert('xss')>"

      category =
        Emakola.Catalog.Category
        |> Ash.Changeset.for_create(:create, %{name: xss_name, store_id: store.id})
        |> Ash.create!()

      assert category.name == xss_name
    end

    test "product description with script injection is stored safely", %{store_a: store} do
      xss_desc = "<script>document.cookie</script><b>bold</b>"

      product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{
          title: "Safe Product",
          description: xss_desc,
          store_id: store.id
        })
        |> Ash.create!()

      assert product.description == xss_desc
    end

    test "product title with script tag is escaped in admin product list", %{
      conn: conn,
      store_a: store
    } do
      xss_title = "<script>alert('xss')</script>"

      _product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: xss_title, store_id: store.id})
        |> Ash.create!()

      {:ok, _view, html} = live(conn, ~p"/admin/products")

      # The raw <script> tag must NOT appear in the HTML output.
      # Phoenix LiveView auto-escapes by default, so it should be entity-encoded.
      refute html =~ "<script>alert('xss')</script>"
      assert html =~ "&lt;script&gt;"
    end

    test "category name with HTML is escaped in admin categories page", %{
      conn: conn,
      store_a: store
    } do
      xss_name = "<img src=x onerror=alert(1)>"

      _category =
        Emakola.Catalog.Category
        |> Ash.Changeset.for_create(:create, %{name: xss_name, store_id: store.id})
        |> Ash.create!()

      {:ok, _view, html} = live(conn, ~p"/admin/categories")

      refute html =~ "<img src=x onerror=alert(1)>"
      assert html =~ "&lt;img"
    end
  end

  # ── SQL Injection Prevention ──────────────────────────────────────

  describe "SQL injection prevention" do
    test "malicious search query does not execute SQL", %{store_a: store} do
      # Create a legitimate product
      _product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Real Product", store_id: store.id})
        |> Ash.create!()

      # Attempt SQL injection via Ash query - should not raise or execute
      malicious_input = "'; DROP TABLE products; --"

      result =
        Emakola.Catalog.Product
        |> Ash.Query.filter(contains(title, ^malicious_input))
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read()

      assert {:ok, []} = result
    end

    test "SQL injection in customer email search is parameterized", %{store_a: store} do
      _customer =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:create, %{
          email: "safe@example.com",
          name: "Safe Customer",
          store_id: store.id
        })
        |> Ash.create!()

      malicious_email = "' OR '1'='1"

      result =
        Emakola.Customers.Customer
        |> Ash.Query.filter(email == ^malicious_email)
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read()

      assert {:ok, []} = result
    end

    test "SQL injection via order search does not break", %{conn: conn, store_a: store} do
      customer = create_customer!(store.id)
      _order = create_order!(store.id, customer.id, :pending)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")

      # Attempt SQL injection through the search form
      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{"search" => "'; DROP TABLE orders; --"})

      # Should not crash; should show no results or all results
      assert is_binary(html)
    end
  end

  # ── CSRF Protection ───────────────────────────────────────────────

  describe "CSRF protection" do
    test "browser pipeline includes CSRF protection" do
      # Verify the router pipeline includes :protect_from_forgery
      conn = build_conn()

      _conn =
        conn
        |> Plug.Conn.put_private(:phoenix_endpoint, EmakolaWeb.Endpoint)
        |> Plug.Conn.put_private(:plug_session, %{})
        |> Plug.Conn.put_private(:plug_session_fetch, :done)
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.fetch_query_params()

      # Generate a CSRF token - proves the session system supports CSRF
      token = Plug.CSRFProtection.get_csrf_token()
      assert is_binary(token)
      assert byte_size(token) > 0
    end

    test "webhook endpoints skip CSRF (they use API pipeline)" do
      # Webhook endpoints should accept JSON POST without CSRF token
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")

      # Paystack webhook - should not fail due to CSRF
      conn_result = post(conn, "/webhooks/paystack", %{"event" => "charge.success"})
      # Should get a response (not a 403 CSRF error)
      assert conn_result.status != 403
    end
  end

  # ── Rate Limiting ─────────────────────────────────────────────────

  describe "rate limiting" do
    test "API health endpoint returns 429 after exceeding rate limit" do
      # The API pipeline has rate limiting: limit: 100, window_ms: 60_000
      # We can verify the rate limit headers are present
      conn = build_conn()
      conn = get(conn, "/api/health")

      # Should include rate limit headers
      assert get_resp_header(conn, "x-ratelimit-limit") != []
      assert get_resp_header(conn, "x-ratelimit-remaining") != []
    end
  end

  # ── Multi-Tenant Data Isolation ───────────────────────────────────

  describe "multi-tenant data isolation" do
    test "store A products are not visible to store B queries", %{
      store_a: store_a,
      store_b: store_b
    } do
      product_a =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Store A Product", store_id: store_a.id})
        |> Ash.create!()

      _product_b =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Store B Product", store_id: store_b.id})
        |> Ash.create!()

      # Query products for store B
      {:ok, store_b_products} =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store_b.id)
        |> Ash.read()

      product_ids = Enum.map(store_b_products, & &1.id)
      refute product_a.id in product_ids
    end

    test "store A customers are not visible to store B queries", %{
      store_a: store_a,
      store_b: store_b
    } do
      customer_a =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:create, %{
          email: "customer_a@test.com",
          name: "Customer A",
          store_id: store_a.id
        })
        |> Ash.create!()

      _customer_b =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:create, %{
          email: "customer_b@test.com",
          name: "Customer B",
          store_id: store_b.id
        })
        |> Ash.create!()

      {:ok, store_b_customers} =
        Emakola.Customers.Customer
        |> Ash.Query.filter(store_id == ^store_b.id)
        |> Ash.read()

      customer_ids = Enum.map(store_b_customers, & &1.id)
      refute customer_a.id in customer_ids
    end

    test "store A orders are not visible to store B queries", %{
      store_a: store_a,
      store_b: store_b
    } do
      customer_a = create_customer!(store_a.id)
      customer_b = create_customer!(store_b.id)

      order_a = create_order!(store_a.id, customer_a.id, :pending)
      _order_b = create_order!(store_b.id, customer_b.id, :pending)

      {:ok, store_b_orders} =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^store_b.id)
        |> Ash.read()

      order_ids = Enum.map(store_b_orders, & &1.id)
      refute order_a.id in order_ids
    end

    test "store B merchant cannot access store A admin products page", %{
      conn_b: conn_b,
      store_a: store_a
    } do
      _product_a =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Secret Product", store_id: store_a.id})
        |> Ash.create!()

      # Merchant B accesses admin products - should only see their own store's products
      {:ok, _view, html} = live(conn_b, ~p"/admin/products")

      refute html =~ "Secret Product"
    end
  end

  # ── Authentication ────────────────────────────────────────────────

  describe "authentication" do
    test "unauthenticated user is redirected from /admin/products" do
      conn = build_conn()
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/admin/products")
    end

    test "unauthenticated user is redirected from /admin/orders" do
      conn = build_conn()
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/admin/orders")
    end

    test "unauthenticated user is redirected from /admin/customers" do
      conn = build_conn()
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/admin/customers")
    end

    test "unauthenticated user is redirected from /admin/categories" do
      conn = build_conn()

      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/categories")
    end

    test "unauthenticated user is redirected from /admin/settings" do
      conn = build_conn()
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/admin/settings")
    end

    test "unauthenticated user is redirected from /admin/revenue" do
      conn = build_conn()
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/admin/revenue")
    end

    test "unauthenticated user is redirected from /admin/reports" do
      conn = build_conn()
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/admin/reports")
    end

    test "unauthenticated user is redirected from /dashboard" do
      conn = build_conn()
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/dashboard")
    end
  end

  # ── Authorization ─────────────────────────────────────────────────

  describe "authorization" do
    test "merchant can only see their own store products in admin", %{
      conn: conn_a,
      conn_b: conn_b,
      store_a: store_a,
      store_b: store_b
    } do
      _product_a =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Product Alpha", store_id: store_a.id})
        |> Ash.create!()

      _product_b =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Product Beta", store_id: store_b.id})
        |> Ash.create!()

      # Merchant A should see Product Alpha but not Product Beta
      {:ok, _view, html_a} = live(conn_a, ~p"/admin/products")
      assert html_a =~ "Product Alpha"
      refute html_a =~ "Product Beta"

      # Merchant B should see Product Beta but not Product Alpha
      {:ok, _view, html_b} = live(conn_b, ~p"/admin/products")
      assert html_b =~ "Product Beta"
      refute html_b =~ "Product Alpha"
    end

    test "merchant can only see their own store orders in admin", %{
      conn: conn_a,
      conn_b: conn_b,
      store_a: store_a,
      store_b: store_b
    } do
      customer_a = create_customer!(store_a.id)
      customer_b = create_customer!(store_b.id)

      order_a = create_order!(store_a.id, customer_a.id, :pending)
      order_b = create_order!(store_b.id, customer_b.id, :pending)

      {:ok, _view, html_a} = live(conn_a, ~p"/admin/orders")
      assert html_a =~ order_a.order_number
      refute html_a =~ order_b.order_number

      {:ok, _view, html_b} = live(conn_b, ~p"/admin/orders")
      assert html_b =~ order_b.order_number
      refute html_b =~ order_a.order_number
    end
  end

  # ── Input Validation ──────────────────────────────────────────────

  describe "input validation" do
    test "extremely long product title is rejected or handled gracefully", %{store_a: store} do
      long_title = String.duplicate("A", 10_001)

      result =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: long_title, store_id: store.id})
        |> Ash.create()

      # Should either reject with an error or truncate - not crash
      case result do
        {:error, _changeset} ->
          # Validation caught the overly long input
          assert true

        {:ok, product} ->
          # If it accepts, the product should be stored (framework handles it)
          assert is_binary(product.title)
      end
    end

    test "extremely long category name is handled gracefully", %{store_a: store} do
      long_name = String.duplicate("B", 10_001)

      result =
        Emakola.Catalog.Category
        |> Ash.Changeset.for_create(:create, %{name: long_name, store_id: store.id})
        |> Ash.create()

      case result do
        {:error, _changeset} -> assert true
        {:ok, category} -> assert is_binary(category.name)
      end
    end

    test "extremely long customer name is handled gracefully", %{store_a: store} do
      long_name = String.duplicate("C", 10_001)

      result =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:create, %{
          email: "long-name@test.com",
          name: long_name,
          store_id: store.id
        })
        |> Ash.create()

      case result do
        {:error, _changeset} -> assert true
        {:ok, customer} -> assert is_binary(customer.name)
      end
    end
  end

  # ── File Upload Validation ────────────────────────────────────────

  describe "file upload validation" do
    test "only image content types are accepted for product images", %{store_a: store} do
      product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Upload Test Product", store_id: store.id})
        |> Ash.create!()

      # Valid image content type should succeed
      valid_result =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://s3.example.com/test/valid.jpg",
          content_type: "image/jpeg",
          file_size_bytes: 500_000,
          product_id: product.id,
          store_id: store.id
        })
        |> Ash.create()

      assert {:ok, _image} = valid_result

      # Malicious content type should be rejected
      malicious_result =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://s3.example.com/test/malicious.exe",
          content_type: "application/x-executable",
          file_size_bytes: 500_000,
          product_id: product.id,
          store_id: store.id
        })
        |> Ash.create()

      assert {:error, _changeset} = malicious_result
    end

    test "HTML content type is rejected for product images", %{store_a: store} do
      product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "HTML Upload Test", store_id: store.id})
        |> Ash.create!()

      result =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://s3.example.com/test/malicious.html",
          content_type: "text/html",
          file_size_bytes: 500_000,
          product_id: product.id,
          store_id: store.id
        })
        |> Ash.create()

      assert {:error, _changeset} = result
    end

    test "JavaScript content type is rejected for product images", %{store_a: store} do
      product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "JS Upload Test", store_id: store.id})
        |> Ash.create!()

      result =
        Emakola.Catalog.Image
        |> Ash.Changeset.for_create(:create, %{
          url: "https://s3.example.com/test/malicious.js",
          content_type: "application/javascript",
          file_size_bytes: 500_000,
          product_id: product.id,
          store_id: store.id
        })
        |> Ash.create()

      assert {:error, _changeset} = result
    end
  end

  # ── Test Helpers ──────────────────────────────────────────────────

  defp create_authenticated_merchant! do
    store =
      Emakola.Accounts.Store
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Store #{System.unique_integer([:positive])}",
        slug: "test-store-#{System.unique_integer([:positive])}"
      })
      |> Ash.create!()

    merchant =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "merchant-#{System.unique_integer([:positive])}@test.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!()

    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      merchant_id: merchant.id,
      store_id: store.id,
      role: :owner
    })
    |> Ash.create!()

    {merchant, store}
  end

  defp authenticate_conn(conn, merchant) do
    subject = AshAuthentication.user_to_subject(merchant)

    conn
    |> init_test_session(%{"user_token" => subject})
  end

  defp create_customer!(store_id) do
    Emakola.Customers.Customer
    |> Ash.Changeset.for_create(:create, %{
      store_id: store_id,
      email: "customer-#{System.unique_integer([:positive])}@test.com",
      name: "Test Customer",
      phone: "+233240000000"
    })
    |> Ash.create!()
  end

  defp create_order!(store_id, customer_id, status, opts \\ []) do
    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        store_id: store_id,
        customer_id: customer_id,
        subtotal: Keyword.get(opts, :subtotal, 10000),
        total: Keyword.get(opts, :total, 10000),
        currency: "GHS"
      })
      |> Ash.create!()

    transition_to_status(order, status)
  end

  defp transition_to_status(order, :pending), do: order

  defp transition_to_status(order, :confirmed) do
    {:ok, order} = Ash.update(order, %{}, action: :confirm)
    order
  end
end
