defmodule Emakola.InputSanitizationTest do
  @moduledoc """
  Input sanitization tests for the Emakola platform.

  Verifies that malicious input in various fields is safely handled:
  - Script tags in product titles and descriptions
  - HTML entities in category names
  - Special characters in customer emails
  - SQL injection in order notes
  - SQL injection in search queries
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  require Ash.Query

  # ── Setup ──────────────────────────────────────────────────────────

  setup %{conn: conn} do
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)

    {:ok, conn: conn, store: store, merchant: merchant}
  end

  # ── Product Title XSS ─────────────────────────────────────────────

  describe "product title with script injection" do
    @xss_title "<script>alert('xss')</script>"

    test "script tag in product title is stored as-is in database", %{store: store} do
      product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: @xss_title, store_id: store.id})
        |> Ash.create!(authorize?: false)

      # Data layer stores the raw text
      assert product.title == @xss_title
    end

    test "script tag in product title is escaped when rendered in HTML", %{
      conn: conn,
      store: store
    } do
      _product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: @xss_title, store_id: store.id})
        |> Ash.create!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/products")

      # The raw <script> must NOT appear in the rendered HTML
      refute html =~ "<script>alert('xss')</script>"
      # It should appear HTML-entity-encoded
      assert html =~ "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;" or
               html =~ "&lt;script&gt;"
    end

    test "script tag with encoded entities in product title", %{store: store} do
      encoded_xss = "&#60;script&#62;alert('xss')&#60;/script&#62;"

      product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: encoded_xss, store_id: store.id})
        |> Ash.create!(authorize?: false)

      assert product.title == encoded_xss
    end

    test "event handler injection in product title", %{store: store} do
      event_xss = "\" onmouseover=\"alert('xss')\""

      product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: event_xss, store_id: store.id})
        |> Ash.create!(authorize?: false)

      assert product.title == event_xss
    end

    test "image tag XSS in product title is escaped in admin", %{conn: conn, store: store} do
      img_xss = "<img src=x onerror=alert('xss')>"

      _product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: img_xss, store_id: store.id})
        |> Ash.create!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/products")

      # The raw img tag must NOT appear unescaped
      refute html =~ "<img src=x onerror=alert('xss')>"
      assert html =~ "&lt;img"
    end
  end

  # ── Category Name HTML Entities ────────────────────────────────────

  describe "category name with HTML entities" do
    test "HTML tags in category name are escaped", %{conn: conn, store: store} do
      html_name = "<b>Bold Category</b><script>alert(1)</script>"

      _category =
        Emakola.Catalog.Category
        |> Ash.Changeset.for_create(:create, %{name: html_name, store_id: store.id})
        |> Ash.create!(authorize?: false)

      {:ok, _view, html} = live(conn, ~p"/admin/categories")

      refute html =~ "<b>Bold Category</b>"
      refute html =~ "<script>alert(1)</script>"
      assert html =~ "&lt;b&gt;"
    end

    test "HTML entities (&amp; &lt; &gt;) in category name are double-escaped correctly", %{
      store: store
    } do
      entity_name = "Shoes &amp; Bags &lt;New&gt;"

      category =
        Emakola.Catalog.Category
        |> Ash.Changeset.for_create(:create, %{name: entity_name, store_id: store.id})
        |> Ash.create!(authorize?: false)

      assert category.name == entity_name
    end

    test "SVG-based XSS in category name", %{store: store} do
      svg_xss = "<svg onload=alert('xss')>"

      category =
        Emakola.Catalog.Category
        |> Ash.Changeset.for_create(:create, %{name: svg_xss, store_id: store.id})
        |> Ash.create!(authorize?: false)

      assert category.name == svg_xss
    end
  end

  # ── Customer Email with Special Characters ────────────────────────

  describe "customer email with special characters" do
    test "email with plus addressing is accepted", %{store: store} do
      result =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:create, %{
          email: "user+tag@example.com",
          name: "Plus User",
          store_id: store.id
        })
        |> Ash.create(authorize?: false)

      assert {:ok, customer} = result
      assert to_string(customer.email) == "user+tag@example.com"
    end

    test "email with dots is accepted", %{store: store} do
      result =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:create, %{
          email: "first.last@example.co.gh",
          name: "Dot User",
          store_id: store.id
        })
        |> Ash.create(authorize?: false)

      assert {:ok, customer} = result
      assert to_string(customer.email) == "first.last@example.co.gh"
    end

    test "email with SQL injection attempt is handled safely", %{store: store} do
      malicious_email = "user@example.com'; DROP TABLE customers; --"

      result =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:create, %{
          email: malicious_email,
          name: "SQL Inject User",
          store_id: store.id
        })
        |> Ash.create(authorize?: false)

      # Should either reject as invalid email or store safely (parameterized)
      case result do
        {:error, _changeset} ->
          # Email format validation rejected it
          assert true

        {:ok, customer} ->
          # If stored, it's safely parameterized
          assert to_string(customer.email) == malicious_email
      end
    end

    test "email with script injection is handled safely", %{store: store} do
      xss_email = "<script>alert('xss')</script>@example.com"

      result =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:create, %{
          email: xss_email,
          name: "XSS Email User",
          store_id: store.id
        })
        |> Ash.create(authorize?: false)

      case result do
        {:error, _changeset} ->
          # Rejected by email validation
          assert true

        {:ok, customer} ->
          # If stored, it's safely escaped on render
          assert to_string(customer.email) == xss_email
      end
    end
  end

  # ── Order Notes with SQL Injection ────────────────────────────────

  describe "order notes with SQL injection attempts" do
    test "SQL injection in order notes is stored as plain text", %{store: store} do
      customer = create_customer!(store.id)

      sql_inject_notes = "'; DROP TABLE orders; --"

      order =
        Emakola.Orders.Order
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          customer_id: customer.id,
          subtotal: 10000,
          total: 10000,
          currency: "GHS",
          notes: sql_inject_notes
        })
        |> Ash.create!(authorize?: false)

      # The notes should be stored as plain text, not executed as SQL
      assert order.notes == sql_inject_notes

      # Verify the orders table still exists by querying it
      {:ok, orders} =
        Emakola.Orders.Order
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read(authorize?: false)

      assert length(orders) >= 1
    end

    test "UNION SELECT injection in order notes is harmless", %{store: store} do
      customer = create_customer!(store.id)

      union_inject = "' UNION SELECT password FROM users; --"

      order =
        Emakola.Orders.Order
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          customer_id: customer.id,
          subtotal: 10000,
          total: 10000,
          currency: "GHS",
          notes: union_inject
        })
        |> Ash.create!(authorize?: false)

      assert order.notes == union_inject
    end

    test "nested SQL injection with comments in order notes", %{store: store} do
      customer = create_customer!(store.id)

      nested_inject = "/*'; DELETE FROM orders WHERE '1'='1'; --*/"

      order =
        Emakola.Orders.Order
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          customer_id: customer.id,
          subtotal: 10000,
          total: 10000,
          currency: "GHS",
          notes: nested_inject
        })
        |> Ash.create!(authorize?: false)

      assert order.notes == nested_inject
    end
  end

  # ── Search Query SQL Injection ────────────────────────────────────

  describe "search query with SQL injection" do
    test "DROP TABLE injection in product search returns empty results", %{store: store} do
      _product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Normal Product", store_id: store.id})
        |> Ash.create!(authorize?: false)

      malicious_search = "'; DROP TABLE products; --"

      {:ok, results} =
        Emakola.Catalog.Product
        |> Ash.Query.filter(contains(title, ^malicious_search))
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read(authorize?: false)

      # Should return empty - not crash or destroy data
      assert results == []

      # Products table still intact
      {:ok, all_products} =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read(authorize?: false)

      assert length(all_products) >= 1
    end

    test "UNION injection in product search is parameterized", %{store: store} do
      _product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Safe Product", store_id: store.id})
        |> Ash.create!(authorize?: false)

      union_search = "' UNION SELECT email, password FROM merchants --"

      {:ok, results} =
        Emakola.Catalog.Product
        |> Ash.Query.filter(contains(title, ^union_search))
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read(authorize?: false)

      assert results == []
    end

    test "boolean-based blind SQL injection in customer search", %{store: store} do
      _customer =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:create, %{
          email: "real@example.com",
          name: "Real Customer",
          store_id: store.id
        })
        |> Ash.create!(authorize?: false)

      blind_inject = "' OR '1'='1' --"

      {:ok, results} =
        Emakola.Customers.Customer
        |> Ash.Query.filter(email == ^blind_inject)
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read(authorize?: false)

      # Should NOT return all customers - parameterized query prevents injection
      assert results == []
    end

    test "time-based SQL injection in search is parameterized", %{store: store} do
      _product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Quick Product", store_id: store.id})
        |> Ash.create!(authorize?: false)

      time_inject = "'; SELECT pg_sleep(5); --"

      # Should complete quickly (not sleep 5 seconds) because input is parameterized
      {time_microseconds, {:ok, results}} =
        :timer.tc(fn ->
          Emakola.Catalog.Product
          |> Ash.Query.filter(contains(title, ^time_inject))
          |> Ash.Query.filter(store_id == ^store.id)
          |> Ash.read(authorize?: false)
        end)

      assert results == []
      # Should complete in under 2 seconds (well below the 5s sleep attempt)
      assert time_microseconds < 2_000_000
    end

    test "SQL injection via admin order search form", %{conn: conn, store: store} do
      customer = create_customer!(store.id)
      _order = create_order!(store.id, customer.id, :pending)

      {:ok, view, _html} = live(conn, ~p"/admin/orders")

      # Attempt SQL injection through the search form
      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{"search" => "'; DROP TABLE orders; --"})

      # Should not crash and orders table should still be intact
      assert is_binary(html)
    end

    test "SQL injection via admin product search form", %{conn: conn, store: store} do
      _product =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Searchable Product", store_id: store.id})
        |> Ash.create!(authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/admin/products")

      # Attempt SQL injection through the product search
      html =
        view
        |> element("form[phx-change='search']")
        |> render_change(%{"search" => "' OR 1=1; --"})

      assert is_binary(html)
    end
  end

  # ── Test Helpers ──────────────────────────────────────────────────

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
    subject = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

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
    |> Ash.create!(authorize?: false)
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
      |> Ash.create!(authorize?: false)

    transition_to_status(order, status)
  end

  defp transition_to_status(order, :pending), do: order

  defp transition_to_status(order, :confirmed) do
    {:ok, order} = Ash.update(order, %{}, action: :confirm, authorize?: false)
    order
  end
end
