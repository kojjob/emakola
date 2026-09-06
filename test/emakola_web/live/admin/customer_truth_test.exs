defmodule EmakolaWeb.Admin.CustomerTruthTest do
  @moduledoc """
  The customers list showed GH₵ 0.00 next to every buyer and "N/A" in a tile.
  Real buyers with real money deserve real numbers, and the two buttons that
  did nothing now do something.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  defp order!(store, customer, total, status) do
    Factory.create_order!(store, %{
      subtotal: total,
      total: total,
      status: status,
      customer_id: customer.id
    })
  end

  describe "the list" do
    test "shows paid money, last bought, and who bought again", ctx do
      ama = Factory.create_customer!(ctx.store, %{name: "Ama Serwaa", phone: "+233241111111"})
      kofi = Factory.create_customer!(ctx.store, %{name: "Kofi Mensah", phone: "+233242222222"})

      order!(ctx.store, ama, 10_000, :confirmed)
      order!(ctx.store, ama, 2_500, :delivered)
      order!(ctx.store, ama, 9_000, :pending)
      order!(ctx.store, kofi, 4_000, :confirmed)

      ama
      |> Ash.Changeset.for_update(:backdate_last_order, %{
        last_order_at: DateTime.add(DateTime.utc_now(), -3 * 86_400, :second)
      })
      |> Ash.update!(authorize?: false)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      assert has_element?(view, "#customer-#{ama.id}", "GH₵ 125")
      assert has_element?(view, "#customer-#{ama.id}", "3 days ago")
      assert has_element?(view, "#customer-#{kofi.id}", "GH₵ 40")
      assert has_element?(view, "#customers-bought-again", "1")
      refute render(view) =~ "N/A"
    end

    test "a search result still shows real money, not the loaded window's zero", ctx do
      ama = Factory.create_customer!(ctx.store, %{name: "Ama Serwaa", phone: "+233241111111"})
      Factory.create_customer!(ctx.store, %{name: "Kofi Mensah", phone: "+233242222222"})

      order!(ctx.store, ama, 10_000, :confirmed)
      order!(ctx.store, ama, 2_500, :delivered)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      view
      |> element("#customer-search-form")
      |> render_change(%{"search" => "Ama"})

      assert has_element?(view, "#customer-#{ama.id}", "GH₵ 125")
    end

    test "add customer creates one from a name and phone", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      view |> element("#add-customer-toggle") |> render_click()

      view
      |> form("#add-customer-form", customer: %{name: "Yaa Asantewaa", phone: "0201234567"})
      |> render_submit()

      assert has_element?(view, "#customers-table", "Yaa Asantewaa")

      [customer] =
        Emakola.Customers.list_customers_by_store!(ctx.store.id, authorize?: false)

      assert customer.phone == "+233201234567"
    end

    test "add customer rejects a bad phone number", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      view |> element("#add-customer-toggle") |> render_click()

      html =
        view
        |> form("#add-customer-form", customer: %{name: "Bad Phone", phone: "123"})
        |> render_submit()

      assert html =~ "Enter a valid phone number"
      assert Emakola.Customers.list_customers_by_store!(ctx.store.id, authorize?: false) == []
    end

    test "add customer rejects a phone that already belongs to a customer", ctx do
      Factory.create_customer!(ctx.store, %{name: "Ama", phone: "+233241111111"})

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      view |> element("#add-customer-toggle") |> render_click()

      html =
        view
        |> form("#add-customer-form", customer: %{name: "Second Ama", phone: "0241111111"})
        |> render_submit()

      assert html =~ "That phone is already a customer"

      assert length(Emakola.Customers.list_customers_by_store!(ctx.store.id, authorize?: false)) ==
               1
    end

    test "add customer rejects an email that already belongs to a customer", ctx do
      Factory.create_customer!(ctx.store, %{name: "Ama", email: "ama@example.com"})

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      view |> element("#add-customer-toggle") |> render_click()

      html =
        view
        |> form("#add-customer-form", customer: %{name: "Second Ama", email: "ama@example.com"})
        |> render_submit()

      assert html =~ "That email is already a customer"

      assert length(Emakola.Customers.list_customers_by_store!(ctx.store.id, authorize?: false)) ==
               1
    end

    test "add customer survives a crafted non-string param instead of crashing", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      view |> element("#add-customer-toggle") |> render_click()

      html =
        view
        |> element("#add-customer-form")
        |> render_submit(%{"customer" => %{"name" => "Odd", "phone" => ["1"], "email" => ""}})

      assert html =~ "Enter a valid phone number"
      assert Emakola.Customers.list_customers_by_store!(ctx.store.id, authorize?: false) == []
    end

    # The placeholder address belongs to a specific phone-first guest lookup,
    # not to a person. A row holding it here would be found by
    # FindOrCreateCustomer's credential-less fallback and bound to a stranger's
    # guest checkout. The public registration paths already refuse it; this is
    # the surface where a merchant can type one by hand.
    test "add customer refuses a phone-placeholder email address", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      view |> element("#add-customer-toggle") |> render_click()

      html =
        view
        |> form("#add-customer-form",
          customer: %{
            name: "Squatter",
            phone: "0249999999",
            email: "p233241111111@phone.customers.makola.io"
          }
        )
        |> render_submit()

      assert html =~ "Use your own email address"
      assert Emakola.Customers.list_customers_by_store!(ctx.store.id, authorize?: false) == []
    end

    test "export is a real link", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      assert has_element?(view, ~s{a[href="/admin/export/customers.csv"]}, "Export")
    end

    test "another store's customer never appears in this store's list, or its bought-again count",
         ctx do
      other_store = Factory.create_store!()
      other_customer = Factory.create_customer!(other_store, %{name: "Not Yours"})
      # Two paid orders — this customer WOULD count as "bought again" if the
      # tile ever leaked across stores.
      order!(other_store, other_customer, 5_000, :confirmed)
      order!(other_store, other_customer, 5_000, :confirmed)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      refute has_element?(view, "#customer-#{other_customer.id}")
      refute render(view) =~ "Not Yours"
      assert has_element?(view, "#customers-bought-again", "0")
    end

    test "a segment chip narrows the list", ctx do
      twice = Factory.create_customer!(ctx.store, %{name: "Twice Buyer"})
      once = Factory.create_customer!(ctx.store, %{name: "Once Buyer"})
      for _ <- 1..2, do: order!(ctx.store, twice, 100, :confirmed)
      order!(ctx.store, once, 100, :confirmed)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      view
      |> element(~s{#customer-segments button[phx-value-segment="bought_again"]})
      |> render_click()

      assert has_element?(view, "#customer-#{twice.id}")
      refute has_element?(view, "#customer-#{once.id}")
    end

    test "a search clears the chosen segment, so the chip stops lying about the list", ctx do
      twice = Factory.create_customer!(ctx.store, %{name: "Twice Buyer"})
      once = Factory.create_customer!(ctx.store, %{name: "Once Buyer"})
      for _ <- 1..2, do: order!(ctx.store, twice, 100, :confirmed)
      order!(ctx.store, once, 100, :confirmed)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      view
      |> element(~s{#customer-segments button[phx-value-segment="bought_again"]})
      |> render_click()

      view
      |> element("#customer-search-form")
      |> render_change(%{"search" => "Once"})

      refute has_element?(
               view,
               ~s{#customer-segments button[phx-value-segment="bought_again"][data-on]}
             )

      assert has_element?(view, "#customer-#{once.id}")
      refute has_element?(view, "#customer-#{twice.id}")
    end

    test "segment chip counts are real on the first render, not just after a click", ctx do
      twice = Factory.create_customer!(ctx.store, %{name: "Twice Buyer"})
      once = Factory.create_customer!(ctx.store, %{name: "Once Buyer"})
      for _ <- 1..2, do: order!(ctx.store, twice, 100, :confirmed)
      order!(ctx.store, once, 100, :confirmed)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers")

      assert has_element?(
               view,
               ~s{#customer-segments button[phx-value-segment="bought_again"]},
               "1"
             )
    end
  end

  describe "the detail page" do
    test "notes can be written and removed", ctx do
      customer = Factory.create_customer!(ctx.store, %{name: "Ama"})

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers/#{customer.id}")

      view
      |> form("#note-form", note: %{content: "Prefers delivery after 5pm"})
      |> render_submit()

      assert has_element?(view, "#notes", "Prefers delivery after 5pm")
      refute render(view) =~ "coming soon"

      [note] =
        Emakola.Customers.list_notes_by_customer_and_store!(customer.id, ctx.store.id,
          authorize?: false
        )

      view |> element("#note-#{note.id} button", "Remove") |> render_click()

      refute has_element?(view, "#notes", "Prefers delivery after 5pm")
    end

    test "shows last bought, address, opt-out, tags, and the problem counts", ctx do
      customer =
        Factory.create_customer!(ctx.store, %{
          name: "Ama",
          phone: "+233241111111",
          tags: ["wholesale"]
        })

      Factory.create_address!(customer, ctx.store, %{line_1: "12 Oxford St", city: "Accra"})
      order!(ctx.store, customer, 5_000, :cancelled)
      paid = order!(ctx.store, customer, 5_000, :delivered)

      Emakola.Orders.Return
      |> Ash.Changeset.for_create(:request_return, %{
        store_id: ctx.store.id,
        order_id: paid.id,
        customer_id: customer.id,
        reason: :changed_mind
      })
      |> Ash.create!(authorize?: false)

      Emakola.Marketing.Campaigns.opt_out(customer)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers/#{customer.id}")

      assert has_element?(view, "#customer-address", "12 Oxford St")
      assert has_element?(view, "#customer-opt-out", "No marketing messages")
      assert has_element?(view, "#customer-tags", "wholesale")
      assert has_element?(view, "#customer-problems", "1 return")
      assert has_element?(view, "#customer-problems", "1 cancelled")
      assert has_element?(view, ~s{a[href="https://wa.me/233241111111"]})
      assert has_element?(view, "#customer-message")

      # The forward-looking aggregates (tasks 5-9 read these by name) depend on
      # the brand-new `has_many :returns` between two `global?(true)`
      # multitenant resources — a misconfiguration there compiles fine and
      # only breaks at query time, so load it for real here.
      require Ash.Query

      loaded =
        Emakola.Customers.Customer
        |> Ash.Query.filter(id == ^customer.id)
        |> Ash.Query.load([
          :paid_total,
          :paid_order_count,
          :cancelled_order_count,
          :returns_count
        ])
        |> Ash.read_one!(authorize?: false)

      assert loaded.paid_total == 5_000
      assert loaded.paid_order_count == 1
      assert loaded.cancelled_order_count == 1
      assert loaded.returns_count == 1
    end

    test "order history windows to 20 with a Show all button", ctx do
      customer = Factory.create_customer!(ctx.store, %{name: "Ama"})
      # Sorted newest first, so the OLDEST of 21 orders is the one pushed
      # past the 20-row window.
      orders = for _ <- 1..21, do: order!(ctx.store, customer, 1_000, :confirmed)
      oldest_order = List.first(orders)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers/#{customer.id}")

      refute render(view) =~ oldest_order.order_number
      assert has_element?(view, "#show-all-orders", "Show all")

      view |> element("#show-all-orders") |> render_click()

      assert render(view) =~ oldest_order.order_number
      refute has_element?(view, "#show-all-orders")
    end

    test "the three money tiles reconcile: total spent, paid orders, and their average", ctx do
      customer = Factory.create_customer!(ctx.store, %{name: "Ama"})
      order!(ctx.store, customer, 10_000, :confirmed)
      order!(ctx.store, customer, 5_000, :delivered)
      order!(ctx.store, customer, 9_000, :pending)
      order!(ctx.store, customer, 1_000, :cancelled)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers/#{customer.id}")

      html = render(view)
      # Paid money only (pending/cancelled excluded): 10_000 + 5_000.
      assert html =~ "GH₵ 150"
      assert html =~ "Paid Orders"
      refute html =~ "Total Orders"
      # Average of the two paid orders behind that GH₵ 150: 150 / 2 = 75.
      assert html =~ "GH₵ 75"
    end

    test "a failed payment counts even when the stored email case differs", ctx do
      customer = Factory.create_customer!(ctx.store, %{name: "Ama", email: "ama@example.com"})

      payment = Factory.create_payment!(ctx.store, %{customer_email: "AMA@Example.com"})
      payment |> Ash.Changeset.for_update(:mark_failed, %{}) |> Ash.update!(authorize?: false)

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers/#{customer.id}")

      assert has_element?(view, "#customer-problems", "1 failed payment")
    end

    test "a note over 2,000 characters is refused, not silently truncated", ctx do
      customer = Factory.create_customer!(ctx.store, %{name: "Ama"})
      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers/#{customer.id}")

      too_long = String.duplicate("a", 2_001)

      html =
        view
        |> form("#note-form", note: %{content: too_long})
        |> render_submit()

      assert html =~ "Write something first"

      assert Emakola.Customers.list_notes_by_customer_and_store!(customer.id, ctx.store.id,
               authorize?: false
             ) == []
    end

    test "message opens the chat thread with this buyer", ctx do
      customer = Factory.create_customer!(ctx.store, %{name: "Ama"})

      {:ok, view, _html} = live(ctx.conn, ~p"/admin/customers/#{customer.id}")

      view |> element("#customer-message") |> render_click()

      {:ok, thread} = Emakola.Conversations.open_shop_thread(ctx.store.id, customer.id)
      assert_redirect(view, "/admin/messages/#{thread.id}")
    end
  end
end
