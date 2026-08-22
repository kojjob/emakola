defmodule EmakolaWeb.Admin.PayLinkLiveTest do
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  setup %{conn: conn} do
    {conn, user, store} = setup_authenticated_merchant(conn)
    %{conn: conn, user: user, store: store}
  end

  test "a merchant with no pay links is told what one is for, in a few words", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/pay-links")

    assert has_element?(view, "#pay-links-empty", "Make a pay link")
    assert has_element?(view, "#pay-links-empty", "Sell in one message")
    assert has_element?(view, "#pay-links-empty button", "Make a pay link")
  end

  test "lists links with funnel columns and empty state", %{conn: conn, store: store} do
    {:ok, _view, html} = live(conn, "/admin/pay-links")
    assert html =~ "Pay Links"

    Emakola.Orders.PayLink
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      type: :custom,
      title: "Deal",
      amount: 25_000
    })
    |> Ash.create!(authorize?: false)

    {:ok, _view, html} = live(conn, "/admin/pay-links")
    assert html =~ "Deal"
    assert html =~ "250"
  end

  test "creates a custom link from the modal and shows the share URL", %{conn: conn} do
    {:ok, view, _} = live(conn, "/admin/pay-links")

    view |> element("button", "New pay link") |> render_click()

    html =
      view
      |> form("#pay-link-create-form", %{
        "pay_link" => %{"type" => "custom", "title" => "Kente", "amount_ghs" => "250"}
      })
      |> render_submit()

    assert html =~ "/pay/"
    assert html =~ "wa.me"
  end

  test "the buyer protection override checkbox is hidden when the store setting is off",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/admin/pay-links")

    html = view |> element("button", "New pay link") |> render_click()

    refute html =~ "Buyer Protection — hold payment until delivery is confirmed"
  end

  test "the buyer protection override checkbox appears when the store setting is on, and an explicit override wins",
       %{conn: conn, store: store} do
    store
    |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
    |> Ash.update!(authorize?: false)

    {:ok, view, _} = live(conn, "/admin/pay-links")

    html = view |> element("button", "New pay link") |> render_click()
    assert html =~ "Buyer Protection — hold payment until delivery is confirmed"

    view
    |> form("#pay-link-create-form", %{
      "pay_link" => %{
        "type" => "custom",
        "title" => "Kente",
        "amount_ghs" => "250",
        "protected" => "false"
      }
    })
    |> render_submit()

    link =
      Emakola.Orders.PayLink
      |> Ash.read!(authorize?: false)
      |> Enum.find(&(&1.title == "Kente"))

    assert link.protected == false
  end

  test "creates a custom link with an optional expiry and note", %{conn: conn} do
    {:ok, view, _} = live(conn, "/admin/pay-links")

    view |> element("button", "New pay link") |> render_click()

    view
    |> form("#pay-link-create-form", %{
      "pay_link" => %{
        "type" => "custom",
        "title" => "Kente",
        "amount_ghs" => "250",
        "expires_at" => "2026-08-15",
        "note" => "VIP customer deal"
      }
    })
    |> render_submit()

    link =
      Emakola.Orders.PayLink
      |> Ash.read!(authorize?: false)
      |> Enum.find(&(&1.title == "Kente"))

    assert link.note == "VIP customer deal"
    assert DateTime.to_date(link.expires_at) == ~D[2026-08-15]
  end

  test "creates a catalog link from the product picker", %{conn: conn, store: store} do
    product = Factory.create_product!(store, %{status: :active})
    variant = Factory.create_variant!(product, store, %{price: 12_000})

    {:ok, view, _} = live(conn, "/admin/pay-links")

    view |> element("button", "New pay link") |> render_click()
    view |> element("button", "From catalog") |> render_click()

    html =
      view
      |> form("#pay-link-create-form", %{
        "pay_link" => %{"type" => "catalog", "variant_id" => variant.id, "quantity" => "2"}
      })
      |> render_submit()

    assert html =~ "/pay/"
    assert html =~ "wa.me"

    link =
      Emakola.Orders.PayLink
      |> Ash.read!(authorize?: false)
      |> Enum.find(&(&1.variant_id == variant.id))

    assert link.type == :catalog
    assert link.quantity == 2
  end

  test "the product picker only lists this store's own variants, and a foreign variant_id is rejected",
       %{conn: conn, store: store} do
    other_store = Factory.create_store!()

    other_product =
      Factory.create_product!(other_store, %{status: :active, title: "Foreign Product"})

    other_variant = Factory.create_variant!(other_product, other_store, %{price: 5_000})

    _own_product = Factory.create_product!(store, %{status: :active, title: "Own Product"})

    {:ok, view, _} = live(conn, "/admin/pay-links")

    html = view |> element("button", "New pay link") |> render_click()
    refute html =~ "Foreign Product"

    view |> element("button", "From catalog") |> render_click()

    # The <select> legitimately has no option for a foreign store's variant —
    # `form/3` would refuse to build this submission (proving the picker is
    # scoped). Push the event directly to simulate a crafted request that
    # bypasses the rendered UI entirely, and confirm the handler itself
    # rejects it too (defense in depth, not just an absent option).
    html2 =
      render_submit(view, "create", %{
        "pay_link" => %{"type" => "catalog", "variant_id" => other_variant.id, "quantity" => "1"}
      })

    refute html2 =~ "wa.me"

    refute Emakola.Orders.PayLink
           |> Ash.read!(authorize?: false)
           |> Enum.any?(&(&1.variant_id == other_variant.id))
  end

  test "cancels an active link", %{conn: conn, store: store} do
    link =
      Emakola.Orders.PayLink
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        type: :custom,
        title: "Deal",
        amount: 25_000
      })
      |> Ash.create!(authorize?: false)

    {:ok, view, _} = live(conn, "/admin/pay-links")
    view |> element("#cancel-link-#{link.id}") |> render_click()

    assert Ash.get!(Emakola.Orders.PayLink, link.id, authorize?: false, tenant: store.id).status ==
             :cancelled
  end

  test "another store's merchant cannot see the link", %{conn: _conn, store: store} do
    Emakola.Orders.PayLink
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      type: :custom,
      title: "Secret",
      amount: 25_000
    })
    |> Ash.create!(authorize?: false)

    other_conn = build_conn()
    {other_conn, _user, _other_store} = setup_authenticated_merchant(other_conn)

    {:ok, _view, html} = live(other_conn, "/admin/pay-links")
    refute html =~ "Secret"
  end

  # ── TC-3 Task 9: susu plans ──────────────────────────────────────

  describe "susu plans" do
    test "lists susu plans with progress and status", %{conn: conn, store: store} do
      plan = create_susu_plan!(store, %{type: :custom, title: "Fridge", total_amount: 20_000})

      plan
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 5_000})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, "/admin/pay-links")

      assert html =~ "Fridge"
      assert html =~ "Active"
      assert html =~ "GH₵ 50 / GH₵ 200"
    end

    test "creates a custom susu plan from the modal with the default min chunk", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/pay-links")

      render_click(view, "open_create", %{})
      render_click(view, "set_create_type", %{"type" => "susu"})

      html =
        view
        |> form("#susu-plan-create-form", %{
          "susu_plan" => %{
            "title" => "Fridge",
            "total_amount_ghs" => "600",
            "deadline" => "2026-09-15"
          }
        })
        |> render_submit()

      assert html =~ "/susu/"
      assert html =~ "wa.me"

      plan =
        Emakola.Orders.SusuPlan
        |> Ash.read!(authorize?: false)
        |> Enum.find(&(&1.title == "Fridge"))

      assert plan.type == :custom
      assert plan.total_amount == 60_000
      assert plan.min_chunk == 1_000
      assert DateTime.to_date(plan.deadline) == ~D[2026-09-15]
    end

    test "creates a custom susu plan with an explicit min chunk", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/pay-links")

      render_click(view, "open_create", %{})
      render_click(view, "set_create_type", %{"type" => "susu"})

      view
      |> form("#susu-plan-create-form", %{
        "susu_plan" => %{
          "title" => "TV",
          "total_amount_ghs" => "900",
          "deadline" => "2026-09-15",
          "min_chunk_ghs" => "25"
        }
      })
      |> render_submit()

      plan =
        Emakola.Orders.SusuPlan
        |> Ash.read!(authorize?: false)
        |> Enum.find(&(&1.title == "TV"))

      assert plan.min_chunk == 2_500
    end

    test "creates a catalog susu plan with an independently-negotiated total", %{
      conn: conn,
      store: store
    } do
      product = Factory.create_product!(store, %{status: :active})
      variant = Factory.create_variant!(product, store, %{price: 12_000})

      {:ok, view, _} = live(conn, "/admin/pay-links")

      render_click(view, "open_create", %{})
      render_click(view, "set_create_type", %{"type" => "susu"})
      render_click(view, "set_susu_item_type", %{"type" => "catalog"})

      view
      |> form("#susu-plan-create-form", %{
        "susu_plan" => %{
          "variant_id" => variant.id,
          "quantity" => "2",
          "total_amount_ghs" => "200",
          "deadline" => "2026-09-15"
        }
      })
      |> render_submit()

      plan =
        Emakola.Orders.SusuPlan
        |> Ash.read!(authorize?: false)
        |> Enum.find(&(&1.variant_id == variant.id))

      assert plan.type == :catalog
      assert plan.quantity == 2
      # Explicit total, not derived from variant.price * quantity (24_000) —
      # a susu plan's total is always negotiated, unlike PayLink's catalog type.
      assert plan.total_amount == 20_000
    end

    test "cancelling a susu plan routes through SusuLifecycle: refunds, releases stock, and notifies",
         %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{status: :active})
      variant = Factory.create_variant!(product, store, %{stock_quantity: 10})

      plan =
        create_susu_plan!(store, %{
          type: :catalog,
          variant_id: variant.id,
          quantity: 3,
          total_amount: 15_000
        })
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!(authorize?: false)

      :ok = Emakola.Orders.SusuStock.reserve(plan)
      assert Ash.reload!(variant, authorize?: false).stock_quantity == 7

      {:ok, view, _} = live(conn, "/admin/pay-links")
      view |> element("#cancel-susu-plan-#{plan.id}") |> render_click()

      assert Ash.get!(Emakola.Orders.SusuPlan, plan.id, authorize?: false, tenant: store.id).status ==
               :cancelled

      # Stock was given back — proves `SusuLifecycle.cancel/2` ran (release +
      # refund + notify), not the bare `SusuPlan.:cancel` action, which does
      # none of that.
      assert Ash.reload!(variant, authorize?: false).stock_quantity == 10
    end

    test "a crafted cancel event against an already-cancelled plan is a no-op", %{
      conn: conn,
      store: store
    } do
      plan = create_susu_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

      plan
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)

      {:ok, view, _} = live(conn, "/admin/pay-links")

      html = render_click(view, "cancel_susu_plan", %{"id" => plan.id})
      assert html =~ "Couldn&#39;t cancel"
    end

    test "extends an active plan's deadline forward", %{conn: conn, store: store} do
      plan =
        create_susu_plan!(store, %{
          type: :custom,
          title: "Fridge",
          total_amount: 15_000,
          deadline: future_deadline(10)
        })
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!(authorize?: false)

      {:ok, view, _} = live(conn, "/admin/pay-links")

      render_click(view, "open_extend_deadline", %{"id" => plan.id})

      html =
        view
        |> form("#extend-deadline-form-#{plan.id}", %{"deadline" => "2026-12-25"})
        |> render_submit()

      assert html =~ "Deadline extended"

      reloaded = Ash.get!(Emakola.Orders.SusuPlan, plan.id, authorize?: false, tenant: store.id)
      assert DateTime.to_date(reloaded.deadline) == ~D[2026-12-25]
    end

    test "rejects a backwards deadline extension with a friendly message", %{
      conn: conn,
      store: store
    } do
      original_deadline = future_deadline(30)

      plan =
        create_susu_plan!(store, %{
          type: :custom,
          title: "Fridge",
          total_amount: 15_000,
          deadline: original_deadline
        })
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!(authorize?: false)

      {:ok, view, _} = live(conn, "/admin/pay-links")

      render_click(view, "open_extend_deadline", %{"id" => plan.id})

      html =
        view
        |> form("#extend-deadline-form-#{plan.id}", %{"deadline" => "2020-01-01"})
        |> render_submit()

      assert html =~ "Choose a date later than the plan&#39;s current deadline."

      reloaded = Ash.get!(Emakola.Orders.SusuPlan, plan.id, authorize?: false, tenant: store.id)
      assert DateTime.to_date(reloaded.deadline) == DateTime.to_date(original_deadline)
    end

    test "another store's merchant cannot see, cancel, or extend the plan", %{store: store} do
      plan =
        create_susu_plan!(store, %{type: :custom, title: "Secret Plan", total_amount: 15_000})

      other_conn = build_conn()
      {other_conn, _user, _other_store} = setup_authenticated_merchant(other_conn)

      {:ok, other_view, html} = live(other_conn, "/admin/pay-links")
      refute html =~ "Secret Plan"

      # Crafted events pushed directly (bypassing the absent UI affordance)
      # must not reach across tenants either.
      render_click(other_view, "cancel_susu_plan", %{"id" => plan.id})

      render_click(other_view, "extend_deadline", %{
        "plan_id" => plan.id,
        "deadline" => "2026-12-25"
      })

      assert Ash.get!(Emakola.Orders.SusuPlan, plan.id, authorize?: false, tenant: store.id).status ==
               :pending
    end
  end

  # ── Test helpers ──────────────────────────────────────────────────

  defp future_deadline(days), do: DateTime.add(DateTime.utc_now(), days, :day)

  defp create_susu_plan!(store, attrs) do
    attrs = Map.new(attrs) |> Map.put_new(:deadline, future_deadline(30))

    Emakola.Orders.SusuPlan
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end
end
