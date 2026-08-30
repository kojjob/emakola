defmodule EmakolaWeb.Supplier.ActionLiveTest do
  @moduledoc """
  The public supplier page.

  The assertions that matter most here are the negative ones. This is a URL a
  merchant pastes into WhatsApp, so it will get forwarded, and what it does NOT
  render is the security boundary: no buyer identity before the supplier
  commits, and no money at any point.
  """
  use EmakolaWeb.ConnCase, async: false

  import Emakola.Factory
  import Mox
  import Phoenix.LiveViewTest

  alias Emakola.Suppliers.SupplierAction

  setup :verify_on_exit!

  @shipping_address %{
    "name" => "Ama Mensah",
    "line_1" => "14 Oxford Street",
    "city" => "Osu",
    "region" => "Greater Accra",
    "phone" => "+233244000111"
  }

  setup do
    store = create_store!()
    order = create_order!(store, %{shipping_address: @shipping_address})
    supplier = create_supplier!(store)
    product = create_product!(store, %{title: "Ankara Wax Print"})
    variant = create_variant!(product, store, %{price: 12_500})
    fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)

    # :create accepts only the ids and the quantity — DenormalizeVariant fills
    # product_title, unit_price and line_total from the variant.
    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 3,
      fulfillment_id: fulfillment.id
    })
    |> Ash.create!(authorize?: false)

    %{store: store, order: order, fulfillment: fulfillment, path: path_for(fulfillment)}
  end

  defp path_for(fulfillment) do
    "/supply/" <> (fulfillment |> SupplierAction.action_url() |> String.split("/") |> List.last())
  end

  defp reload(f), do: Ash.get!(Emakola.Orders.Fulfillment, f.id, authorize?: false)

  # Asserting `refute html =~ "375"` against a full LiveView render is a lottery
  # ticket: SVG path data is full of coordinates like "M3.375a1.125", and the
  # phx-session blob is random base64. Strip the markup and check what a person
  # would actually read.
  defp visible_text(html) do
    html
    |> String.replace(~r{<svg.*?</svg>}s, " ")
    |> String.replace(~r{<[^>]*>}s, " ")
  end

  describe "a dead link" do
    test "renders a plain screen at 200 rather than crashing", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/supply/garbage")

      assert html =~ "This link no longer works"
      refute html =~ "Ama Mensah"
    end

    test "a revoked token lands on the same screen", %{conn: conn, fulfillment: f, path: path} do
      {:ok, _} = Emakola.Orders.rotate_fulfillment_supplier_link(f, authorize?: false)

      {:ok, _view, html} = live(conn, path)

      assert html =~ "This link no longer works"
    end
  end

  describe "the offer screen — what a forwarded link must not leak" do
    test "shows the items, the quantity and the town", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, path)

      assert html =~ "Ankara Wax Print"
      assert html =~ "× 3"
      assert html =~ "Osu"
    end

    test "does NOT show the buyer's name, street or phone", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, path)

      refute html =~ "Ama Mensah"
      refute html =~ "14 Oxford Street"
      refute html =~ "+233244000111"
    end

    # cost_price is the merchant's margin and unit_price is the buyer's price.
    # Either one on a link that gets forwarded around WhatsApp hands a
    # competitor the merchant's economics.
    test "renders no money at all", %{conn: conn, path: path} do
      {:ok, _view, html} = live(conn, path)
      text = visible_text(html)

      refute text =~ "125"
      refute text =~ "375"
      refute text =~ "GH₵"
    end
  end

  describe "accepting" do
    test "reveals the full address only after the supplier commits", %{conn: conn, path: path} do
      {:ok, view, html} = live(conn, path)
      refute html =~ "14 Oxford Street"

      html = view |> element("button", "I have it") |> render_click()

      assert html =~ "Ama Mensah"
      assert html =~ "14 Oxford Street"
      assert html =~ "+233244000111"
    end

    test "still renders no money after accepting", %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)

      text = view |> element("button", "I have it") |> render_click() |> visible_text()

      refute text =~ "GH₵"
      refute text =~ "375"
      refute text =~ "125"
    end

    test "stamps accepted_at without moving status", %{conn: conn, path: path, fulfillment: f} do
      {:ok, view, _html} = live(conn, path)
      view |> element("button", "I have it") |> render_click()

      reloaded = reload(f)
      assert %DateTime{} = reloaded.accepted_at
      assert reloaded.status == :pending
    end
  end

  describe "declining" do
    test "moves to the declined screen with no buttons left", %{
      conn: conn,
      path: path,
      fulfillment: f
    } do
      {:ok, view, _html} = live(conn, path)

      html = view |> element("button", "Yes, no stock") |> render_click()

      assert html =~ "You said no stock"
      assert reload(f).status == :declined
      refute html =~ "I have it"
    end
  end

  describe "marking sent" do
    setup %{conn: conn, path: path} do
      {:ok, view, _html} = live(conn, path)
      view |> element("button", "I have it") |> render_click()
      %{view: view}
    end

    test "records the tracking number and moves on to the handover", %{
      view: view,
      fulfillment: f
    } do
      html = render_submit(view, "mark_sent", %{"shipment" => %{"tracking_number" => "GH-77"}})

      assert html =~ "GH-77"
      assert html =~ "At the customer"
      assert reload(f).status == :shipped
    end

    test "a blank tracking number is refused without moving the fulfillment", %{
      view: view,
      fulfillment: f
    } do
      html = render_submit(view, "mark_sent", %{"shipment" => %{"tracking_number" => "  "}})

      assert html =~ "Please add the tracking number"
      assert reload(f).status == :pending
    end

    # There is no catch-all handle_event/3 in this codebase, so a form arriving
    # without its key would take the page down. This is the realistic crash,
    # not a forged event name.
    test "a submit with no params at all does not crash the page", %{view: view} do
      html = render_submit(view, "mark_sent", %{})

      assert html =~ "Please add the tracking number"
      assert render(view) =~ "Tracking number"
    end
  end

  describe "acting on a fulfillment that moved underneath" do
    test "a merchant cancelling between load and tap gives a sentence, not a crash", %{
      conn: conn,
      path: path,
      fulfillment: f
    } do
      {:ok, view, _html} = live(conn, path)

      {:ok, _} = Emakola.Orders.cancel_fulfillment(f, authorize?: false)

      html = view |> element("button", "I have it") |> render_click()

      assert html =~ "This order is finished"
      assert html =~ "This order has changed"
    end
  end

  # SupplierAction builds this path as a plain string rather than a ~p sigil, to
  # keep the domain layer from depending on the router for compilation. This is
  # the compensating check: rename the route and links already sitting in
  # people's WhatsApp break, so the rename must fail here first.
  test "the router still serves the exact path SupplierAction mints", %{fulfillment: f} do
    minted = SupplierAction.action_url(f)

    assert minted =~ "/supply/"

    # A `live` route's :plug is Phoenix.LiveView.Plug — the LiveView module
    # itself lives in :metadata. Matching on the path is what this test is for.
    assert Enum.any?(EmakolaWeb.Router.__routes__(), &(&1.path == "/supply/:token")),
           "SupplierAction mints #{minted} but the router no longer serves /supply/:token"
  end

  test "the reserved-slug list now covers the new path", _ctx do
    assert EmakolaWeb.ReservedStoreSlugs.reserved?("supply"),
           "a new store could be slugged 'supply' and lose its short URL"
  end

  test "the page is noindex — the URL carries a credential", %{conn: conn, path: path} do
    conn = get(conn, path)

    assert html_response(conn, 200) =~ "noindex"
  end

  describe "the handover — proving delivery at the door" do
    setup %{conn: conn, path: path} do
      stub(Emakola.SMSProviderMock, :send_sms, fn _phone, _message, _opts -> {:ok, %{}} end)

      {:ok, view, _html} = live(conn, path)
      view |> element("button", "I have it") |> render_click()
      render_submit(view, "mark_sent", %{"shipment" => %{"tracking_number" => "GH-88"}})

      %{view: view}
    end

    test "offers to send a code to the customer, not to show one", %{view: view} do
      html = render(view)

      assert html =~ "Send code to customer"
      # The supplier types the code in; they are never shown it.
      refute html =~ "Your code is"
    end

    test "asks for the customer's numbers once the code is sent", %{view: view} do
      html = view |> element("button", "Send code to customer") |> render_click()

      assert html =~ "Ask the customer for their 6 numbers"
      assert html =~ "delivery[code]"
    end

    test "a wrong code says so and leaves the fulfillment shipped", %{
      view: view,
      fulfillment: f
    } do
      view |> element("button", "Send code to customer") |> render_click()

      html = render_submit(view, "verify_delivery", %{"delivery" => %{"code" => "000000"}})

      assert html =~ "not right"
      assert reload(f).status == :shipped
    end

    test "the correct code closes the order", %{view: view, fulfillment: f} do
      view |> element("button", "Send code to customer") |> render_click()

      # return_code: true exists only for tests — it is the buyer's phone that
      # receives the real one, and reissuing here is what the supplier tapping
      # "Send again" would do anyway.
      {:ok, code} =
        Emakola.Orders.CustomerDelivery.request_delivery_code(f.store_id, f.id, return_code: true)

      html = render_submit(view, "verify_delivery", %{"delivery" => %{"code" => code}})

      assert html =~ "Thank you"
      assert reload(f).status == :delivered
    end

    # There is no catch-all handle_event/3, so a form with its key stripped
    # would take the page down.
    test "a submit with no params does not crash the page", %{view: view} do
      view |> element("button", "Send code to customer") |> render_click()

      html = render_submit(view, "verify_delivery", %{})

      assert html =~ "not right"
      assert render(view) =~ "Ask the customer"
    end
  end
end
