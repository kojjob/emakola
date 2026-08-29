defmodule EmakolaWeb.Admin.OrderSupplierLinkTest do
  @moduledoc """
  The merchant's half of the supplier action link.

  The link is worthless unless the merchant can get it to the supplier, so
  these cover sending it, seeing the answer, and revoking it. The
  "Resend disappears once accepted" case is the one that pays for the
  accept-is-a-timestamp design: status is still `:notified` after an accept, so
  anything keying on status alone would keep nagging a supplier who already
  said yes.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Emakola.Suppliers.SupplierAction

  setup %{conn: conn} do
    {merchant, store} = create_authenticated_merchant!()
    conn = authenticate_conn(conn, merchant)

    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        subtotal: 10_000,
        total: 10_000,
        currency: "GHS"
      })
      |> Ash.create!(authorize?: false)

    supplier =
      Emakola.Suppliers.Supplier
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        name: "Kwame Wholesale",
        whatsapp_number: "+233244555666"
      })
      |> Ash.create!(authorize?: false)

    fulfillment =
      Emakola.Orders.Fulfillment
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        order_id: order.id,
        supplier_id: supplier.id
      })
      |> Ash.create!(authorize?: false)

    %{conn: conn, store: store, order: order, supplier: supplier, fulfillment: fulfillment}
  end

  defp show_path(order), do: ~p"/admin/orders/#{order.id}"
  defp reload(f), do: Ash.get!(Emakola.Orders.Fulfillment, f.id, authorize?: false)

  describe "getting the link to the supplier" do
    test "renders the supplier action link for a supplier group", %{conn: conn, order: order} do
      {:ok, _view, html} = live(conn, show_path(order))

      assert html =~ "/supply/"
      assert html =~ "Copy supplier link"
    end

    test "offers a WhatsApp deep link to that supplier's own number", %{
      conn: conn,
      order: order
    } do
      {:ok, _view, html} = live(conn, show_path(order))

      assert html =~ "wa.me/233244555666"
    end

    test "renders no supplier link for the merchant's own-stock group", %{
      conn: conn,
      store: store,
      order: order
    } do
      Emakola.Orders.Fulfillment
      |> Ash.Changeset.for_create(:create, %{store_id: store.id, order_id: order.id})
      |> Ash.create!(authorize?: false)

      {:ok, view, _html} = live(conn, show_path(order))

      # One supplier group, one own-stock group — exactly one link. The
      # own-stock group must never get one: a nil supplier_id is the merchant's
      # own inventory, and SupplierAction refuses tokens for it.
      assert view |> element("[data-role='supplier-link']") |> has_element?()

      assert 1 ==
               view
               |> render()
               |> then(&Regex.scan(~r/data-role="supplier-link"/, &1))
               |> length()
    end
  end

  describe "seeing the supplier's answer" do
    test "shows an accepted line once the supplier accepts", %{
      conn: conn,
      order: order,
      fulfillment: f
    } do
      {:ok, _} = Emakola.Orders.supplier_accept_fulfillment(f, authorize?: false)

      {:ok, _view, html} = live(conn, show_path(order))

      assert html =~ "Supplier accepted"
    end

    test "shows a declined line and tells the merchant what to do", %{
      conn: conn,
      order: order,
      fulfillment: f
    } do
      {:ok, _} =
        Emakola.Orders.supplier_decline_fulfillment(
          f,
          %{decline_reason: :out_of_stock},
          authorize?: false
        )

      {:ok, _view, html} = live(conn, show_path(order))

      assert html =~ "Out of stock"
      assert html =~ "find another supplier"
    end

    # The whole point of accept-as-a-timestamp: status is still :notified here,
    # so anything keying on status alone would keep nagging a supplier who has
    # already agreed.
    test "stops offering Resend once the supplier has accepted", %{
      conn: conn,
      order: order,
      fulfillment: f
    } do
      {:ok, notified} =
        Emakola.Orders.mark_fulfillment_notified(f, %{notified_via: :sms}, authorize?: false)

      {:ok, _view, html} = live(conn, show_path(order))
      assert html =~ "Resend"

      {:ok, accepted} = Emakola.Orders.supplier_accept_fulfillment(notified, authorize?: false)
      assert accepted.status == :notified, "precondition: accept must not move status"

      {:ok, _view, html} = live(conn, show_path(order))
      refute html =~ "Resend"
    end
  end

  describe "the merchant's recovery from a decline" do
    setup %{fulfillment: f} do
      {:ok, declined} =
        Emakola.Orders.supplier_decline_fulfillment(
          f,
          %{decline_reason: :out_of_stock},
          authorize?: false
        )

      %{declined: declined}
    end

    test "still offers Mark shipped — they can source it elsewhere", %{
      conn: conn,
      order: order
    } do
      {:ok, _view, html} = live(conn, show_path(order))

      assert html =~ "Mark shipped"
    end
  end

  describe "a send that never reached the supplier" do
    test "surfaces the failure and relabels the button Try again", %{
      conn: conn,
      order: order,
      fulfillment: f
    } do
      {:ok, _} =
        Emakola.Orders.record_fulfillment_send_failure(
          f,
          %{last_send_error: "whatsapp:http_401"},
          authorize?: false
        )

      {:ok, _view, html} = live(conn, show_path(order))

      assert html =~ "Message not delivered"
      assert html =~ "Try again"
      # The label is for the logs, not the merchant.
      refute html =~ "http_401"
    end

    test "tells the merchant to add a number when there is no contact at all", %{
      conn: conn,
      order: order,
      fulfillment: f
    } do
      {:ok, _} =
        Emakola.Orders.record_fulfillment_send_failure(
          f,
          %{last_send_error: "no_contact"},
          authorize?: false
        )

      {:ok, _view, html} = live(conn, show_path(order))

      assert html =~ "Add a phone number for this supplier"
    end
  end

  describe "revoking a link" do
    test "New link rotates the version and kills the token already in the wild", %{
      conn: conn,
      order: order,
      fulfillment: f
    } do
      old_token =
        f |> SupplierAction.action_url() |> String.split("/") |> List.last()

      assert {:ok, _} = SupplierAction.authorize(old_token)

      {:ok, view, _html} = live(conn, show_path(order))

      view
      |> element("[phx-click='rotate_supplier_link'][phx-value-id='#{f.id}']")
      |> render_click()

      assert reload(f).supplier_link_version == 2
      assert {:error, :revoked_token} = SupplierAction.authorize(old_token)
    end
  end

  # ── Helpers (mirrors order_live_test.exs) ──

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

    init_test_session(conn, %{"user_token" => subject})
  end
end
