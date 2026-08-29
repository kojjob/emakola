defmodule EmakolaWeb.Storefront.CheckoutSteppedFlowTest do
  @moduledoc """
  The checkout shows one section at a time.

  The LiveView has carried `:step` since it was written, but nothing rendered
  it: the stepper was hardcoded markup and all four sections were on screen at
  once. These tests pin the stepped behaviour, and — more importantly — pin the
  two things that gating sections can silently break: values entered in a
  section that is no longer rendered, and `place_order` itself.

  Assertions are scoped to elements rather than matched against the whole
  render: a full LiveView render carries a random base64 `phx-session` blob, so
  `refute html =~ "..."` on it is a lottery ticket.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Cart.CartStore

  setup do
    store = create_store!(%{name: "Stepped Shop", slug: "stepped-shop", currency: "GHS"})
    product = create_product!(store, %{title: "Test Shirt"})
    variant = create_variant!(product, store, %{price: 5000, stock_quantity: 20, sku: "TS-001"})

    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)

    %{store: store, variant: variant}
  end

  defp cart_conn(conn, variant) do
    session_id = Ecto.UUID.generate()

    CartStore.add_item(session_id, variant.store_id, %{
      variant_id: variant.id,
      product_title: "Test Shirt",
      variant_info: "TS-001",
      unit_price: 5000,
      quantity: 2,
      sku: "TS-001"
    })

    init_test_session(conn, %{"cart_session_id" => session_id})
  end

  defp checkout(conn, store, variant) do
    conn = cart_conn(conn, variant)
    {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")
    view
  end

  defp valid_contact,
    do: %{"phone" => "0244123456", "fullname" => "Ama Mensah", "email" => "ama@example.com"}

  describe "one section at a time" do
    test "opens on contact only", %{conn: conn, store: store, variant: variant} do
      view = checkout(conn, store, variant)

      assert has_element?(view, "#phone")
      assert has_element?(view, "#fullname")
      assert has_element?(view, "#email")

      refute has_element?(view, "#address")
      refute has_element?(view, "#region")
      refute has_element?(view, "[phx-click='select_payment']")
    end

    test "valid contact advances to delivery", %{conn: conn, store: store, variant: variant} do
      view = checkout(conn, store, variant)
      render_submit(view, "submit_details", valid_contact())

      assert has_element?(view, "#address")
      assert has_element?(view, "#region")
      assert has_element?(view, "#digital_address")
      assert has_element?(view, "#landmark")
      assert has_element?(view, "#notes")

      refute has_element?(view, "#phone")
    end

    test "incomplete contact does not advance", %{conn: conn, store: store, variant: variant} do
      view = checkout(conn, store, variant)
      render_submit(view, "submit_details", %{"phone" => "", "fullname" => ""})

      assert has_element?(view, "#phone")
      refute has_element?(view, "#address")
    end

    test "delivery advances to payment", %{conn: conn, store: store, variant: variant} do
      view = checkout(conn, store, variant)
      render_submit(view, "submit_details", valid_contact())
      render_submit(view, "submit_delivery", %{"address" => "House 14, Osu Badu Street"})

      assert has_element?(view, "[phx-click='select_payment']")
      refute has_element?(view, "#address")
    end
  end

  describe "finished steps fold, and can be reopened" do
    test "a finished step shows its answer and a way back", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      view = checkout(conn, store, variant)
      render_submit(view, "submit_details", valid_contact())

      assert has_element?(view, "#step-summary-contact", "0244123456")
      assert has_element?(view, "#step-summary-contact [phx-click='go_to_step']")
    end

    test "going back keeps what was already typed", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      view = checkout(conn, store, variant)
      render_submit(view, "submit_details", valid_contact())
      render_submit(view, "go_to_step", %{"step" => "1"})

      assert has_element?(view, "#phone[value='0244123456']")
      assert has_element?(view, "#fullname[value='Ama Mensah']")
    end
  end

  describe "gating a section must not blank what it held" do
    # submit_details defaulted every field to "" rather than to the existing
    # assign. Harmless while every input was on screen; once the address lives
    # on a step that is not rendered when contact is submitted, it wipes it.
    test "advancing from contact does not blank the address", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      view = checkout(conn, store, variant)

      render_change(view, "update_details", %{
        "address" => "House 14, Osu Badu Street",
        "notes" => "Blue gate",
        "region" => "ashanti"
      })

      render_submit(view, "submit_details", valid_contact())

      assert has_element?(view, "#address[value='House 14, Osu Badu Street']")
      assert has_element?(view, "#notes[value='Blue gate']")
      assert has_element?(view, "#region option[value='ashanti'][selected]")
    end
  end

  describe "what the stepper says" do
    test "marks the live step and the finished ones", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      view = checkout(conn, store, variant)
      assert has_element?(view, "#checkout-step-1[data-state='current']")
      assert has_element?(view, "#checkout-step-2[data-state='upcoming']")

      render_submit(view, "submit_details", valid_contact())

      assert has_element?(view, "#checkout-step-1[data-state='done']")
      assert has_element?(view, "#checkout-step-2[data-state='current']")
    end
  end

  describe "kept, not dropped" do
    test "email, notes and promo all survive the restructure", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      view = checkout(conn, store, variant)
      assert has_element?(view, "#email")

      render_submit(view, "submit_details", valid_contact())
      assert has_element?(view, "#notes")

      render_submit(view, "submit_delivery", %{"address" => "House 14"})
      assert has_element?(view, "[name='coupon_code']")
      assert has_element?(view, "[phx-click='apply_coupon']")
    end

    test "every Ghana region is still offered", %{conn: conn, store: store, variant: variant} do
      view = checkout(conn, store, variant)
      render_submit(view, "submit_details", valid_contact())

      html = render(view)

      for region <- Emakola.Suppliers.GhanaRegions.all() do
        assert html =~ region
      end
    end
  end

  describe "the USSD code matches the wallet" do
    # *170# is MTN's. It was hardcoded into the waiting screen, so a Telecel or
    # AirtelTigo buyer was told to dial a code that is not theirs.
    defp order_with(view, method) do
      render_click(view, "select_payment", %{"method" => method})

      render_submit(view, "place_order", %{
        "phone" => "0244123456",
        "fullname" => "Ama Mensah",
        "address" => "House 14, Osu Badu Street",
        "region" => "greater_accra"
      })
    end

    test "MTN is told to dial *170#", %{conn: conn, store: store, variant: variant} do
      view = checkout(conn, store, variant)
      order_with(view, "momo")
      assert has_element?(view, "#momo-ussd-hint", "*170#")
    end

    test "Telecel is not told to dial MTN's code", %{conn: conn, store: store, variant: variant} do
      view = checkout(conn, store, variant)
      order_with(view, "vodafone")
      assert has_element?(view, "#momo-ussd-hint", "*110#")
      refute has_element?(view, "#momo-ussd-hint", "*170#")
    end

    test "AirtelTigo is not told to dial MTN's code", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      view = checkout(conn, store, variant)
      order_with(view, "airteltigo")
      assert has_element?(view, "#momo-ussd-hint", "*110#")
      refute has_element?(view, "#momo-ussd-hint", "*170#")
    end
  end

  describe "placing the order is not gated on the step" do
    # The twelve existing render_submit(view, "place_order", ...) tests mount at
    # step 1 and push the event straight in. place_order must keep meaning
    # "place the order" from any step, or all of them start advancing instead.
    test "place_order works without walking the steps", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      view = checkout(conn, store, variant)

      render_submit(view, "place_order", %{
        "phone" => "0244123456",
        "fullname" => "Ama Mensah",
        "address" => "House 14, Osu Badu Street",
        "region" => "greater_accra"
      })

      refute has_element?(view, "#phone")
    end
  end
end
