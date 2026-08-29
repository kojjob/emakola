defmodule Emakola.Suppliers.SupplierActionTest do
  @moduledoc """
  The unauthenticated capability boundary a supplier acts through.

  This is the only place in the app where a stranger holding a URL can move an
  order, so most of what follows is the security surface rather than the happy
  path. Two properties do most of the work:

    * every function takes a **token**, never a fulfilment id, so there is no
      identifier for a caller to swap; and
    * `authorize/1` refuses a `supplier_id: nil` group, which is the merchant's
      own stock and must never be reachable from a public link.
  """
  use Emakola.DataCase, async: false

  setup :verify_on_exit!
  import Emakola.Factory
  import Mox

  alias Emakola.Suppliers.SupplierAction
  alias EmakolaWeb.SupplierLinkTokens

  setup do
    store = create_store!()

    # A phone on the shipping address: the delivery OTP goes to the BUYER, so
    # without one there is nobody to send the code to.
    order =
      create_order!(store, %{
        shipping_address: %{
          "name" => "Ama Mensah",
          "line_1" => "14 Oxford Street",
          "city" => "Osu",
          "phone" => "+233244000111"
        }
      })

    supplier = create_supplier!(store)
    fulfillment = create_fulfillment!(order, store, supplier_id: supplier.id)

    %{
      store: store,
      order: order,
      supplier: supplier,
      fulfillment: fulfillment,
      token: SupplierAction.action_url(fulfillment) |> token_from_url()
    }
  end

  defp token_from_url(url), do: url |> String.split("/") |> List.last()

  defp reload(f), do: Ash.get!(Emakola.Orders.Fulfillment, f.id, authorize?: false)

  describe "the happy path" do
    test "authorize → accept → mark_sent walks a fulfillment to :shipped", ctx do
      assert {:ok, loaded} = SupplierAction.authorize(ctx.token)
      assert loaded.id == ctx.fulfillment.id

      assert {:ok, accepted} = SupplierAction.accept(ctx.token)
      assert %DateTime{} = accepted.accepted_at
      assert accepted.status == :pending, "accept must not move status"

      assert {:ok, sent} = SupplierAction.mark_sent(ctx.token, "GH-TRACK-44")
      assert sent.status == :shipped
      assert sent.tracking_number == "GH-TRACK-44"
    end

    # The whole reason this module exists alongside InboundFulfillment, which
    # filters on supplier.linked_store_id and therefore locks out every
    # off-platform supplier.
    test "works for an off-platform supplier with no linked store", ctx do
      assert is_nil(ctx.supplier.linked_store_id)
      assert {:ok, _} = SupplierAction.accept(ctx.token)
    end

    test "decline moves to :declined and records the reason", ctx do
      assert {:ok, declined} = SupplierAction.decline(ctx.token, :out_of_stock)
      assert declined.status == :declined
      assert declined.decline_reason == :out_of_stock
    end

    test "decline defaults to :out_of_stock", ctx do
      assert {:ok, declined} = SupplierAction.decline(ctx.token)
      assert declined.decline_reason == :out_of_stock
    end
  end

  describe "token rejection" do
    test "a garbage token is not found", _ctx do
      assert {:error, :invalid_token} = SupplierAction.authorize("garbage")
    end

    test "nil is rejected without raising", _ctx do
      assert {:error, :invalid_token} = SupplierAction.authorize(nil)
    end

    test "an expired token is rejected", ctx do
      thirty_one_days_ago =
        DateTime.utc_now()
        |> DateTime.add(-31 * 24 * 60 * 60, :second)
        |> DateTime.to_unix(:second)

      stale =
        Phoenix.Token.sign(
          EmakolaWeb.Endpoint,
          "supplier_action_v1",
          [ctx.fulfillment.id, 1],
          signed_at: thirty_one_days_ago
        )

      assert {:error, :expired_token} = SupplierAction.authorize(stale)
    end

    test "a token for a fulfillment that no longer exists is not found", _ctx do
      orphan = SupplierLinkTokens.sign(Ash.UUID.generate(), 1)
      assert {:error, :not_found} = SupplierAction.authorize(orphan)
    end
  end

  describe "revocation" do
    test "rotating the link kills the old token and mints a working one", ctx do
      assert {:ok, _} = SupplierAction.authorize(ctx.token)

      {:ok, rotated} =
        Emakola.Orders.rotate_fulfillment_supplier_link(ctx.fulfillment, authorize?: false)

      assert {:error, :revoked_token} = SupplierAction.authorize(ctx.token)

      fresh = rotated |> SupplierAction.action_url() |> token_from_url()
      assert {:ok, _} = SupplierAction.authorize(fresh)
    end

    test "a revoked token cannot write either", ctx do
      {:ok, _} =
        Emakola.Orders.rotate_fulfillment_supplier_link(ctx.fulfillment, authorize?: false)

      assert {:error, :revoked_token} = SupplierAction.accept(ctx.token)
      assert is_nil(reload(ctx.fulfillment).accepted_at)
    end
  end

  describe "scoping" do
    # A nil supplier_id is the merchant's own-stock group. Nothing mints tokens
    # for those today, but verification is where this belongs: a future caller
    # or a minting bug would otherwise hand a stranger the merchant's own order
    # and the buyer's address with it.
    test "a hand-forged token for the merchant's own-stock group is refused", ctx do
      own_stock = create_fulfillment!(ctx.order, ctx.store)
      assert is_nil(own_stock.supplier_id)

      forged = SupplierLinkTokens.sign(own_stock.id, own_stock.supplier_link_version)

      assert {:error, :not_found} = SupplierAction.authorize(forged)
      assert {:error, :not_found} = SupplierAction.accept(forged)
    end

    test "a token for one fulfillment cannot move another", ctx do
      other = create_fulfillment!(ctx.order, ctx.store, supplier_id: ctx.supplier.id)

      assert {:ok, resolved} = SupplierAction.authorize(ctx.token)
      assert resolved.id == ctx.fulfillment.id
      refute resolved.id == other.id

      {:ok, _} = SupplierAction.accept(ctx.token)

      assert is_nil(reload(other).accepted_at), "the wrong fulfillment moved"
    end
  end

  describe "terminal states" do
    # Written out rather than looped: `for status <- [...]` inlines the status
    # as a literal into each generated test, so a `case` over it has an
    # unreachable clause and the compiler says so — and CI compiles tests with
    # --warnings-as-errors.
    defp assert_all_actions_refused(token) do
      assert {:error, :not_actionable} = SupplierAction.accept(token)
      assert {:error, :not_actionable} = SupplierAction.decline(token, :out_of_stock)
      assert {:error, :not_actionable} = SupplierAction.mark_sent(token, "GH-9")
    end

    test "every action is refused once the fulfillment is cancelled", ctx do
      {:ok, cancelled} = Emakola.Orders.cancel_fulfillment(ctx.fulfillment, authorize?: false)

      assert_all_actions_refused(ctx.token)

      assert reload(cancelled).status == :cancelled
    end

    test "every action is refused once the fulfillment is delivered", ctx do
      {:ok, shipped} =
        Emakola.Orders.mark_fulfillment_shipped(
          ctx.fulfillment,
          %{tracking_number: "GH-1"},
          authorize?: false
        )

      {:ok, delivered} = Emakola.Orders.mark_fulfillment_delivered(shipped, authorize?: false)

      assert_all_actions_refused(ctx.token)

      assert reload(delivered).status == :delivered
    end
  end

  describe "replay — the link is a capability, so replay is the design" do
    test "accepting twice both succeed and the timestamp does not slide", ctx do
      assert {:ok, first} = SupplierAction.accept(ctx.token)
      assert {:ok, second} = SupplierAction.accept(ctx.token)

      assert second.accepted_at == first.accepted_at
    end

    test "marking sent twice fails the second time and keeps the first tracking", ctx do
      assert {:ok, _} = SupplierAction.mark_sent(ctx.token, "GH-FIRST")
      assert {:error, :not_actionable} = SupplierAction.mark_sent(ctx.token, "GH-SECOND")

      assert reload(ctx.fulfillment).tracking_number == "GH-FIRST"
    end
  end

  describe "tracking number validation" do
    test "blank and whitespace-only are refused", ctx do
      assert {:error, :tracking_required} = SupplierAction.mark_sent(ctx.token, "")
      assert {:error, :tracking_required} = SupplierAction.mark_sent(ctx.token, "   ")
      assert {:error, :tracking_required} = SupplierAction.mark_sent(ctx.token, nil)

      assert reload(ctx.fulfillment).status == :pending
    end

    test "over 100 characters is refused with a friendly atom", ctx do
      assert {:error, :tracking_too_long} =
               SupplierAction.mark_sent(ctx.token, String.duplicate("x", 101))
    end

    test "is trimmed before storing", ctx do
      assert {:ok, sent} = SupplierAction.mark_sent(ctx.token, "  GH-TRIM-7  ")
      assert sent.tracking_number == "GH-TRIM-7"
    end
  end

  describe "rate limiting" do
    test "refuses writes past the per-fulfillment window", ctx do
      # The limit is keyed per fulfilment, not per IP: peer_data is nil in a
      # disconnected LiveView mount, so IP keying inside the LiveView would be
      # a trap. IP protection lives on the route instead.
      for _ <- 1..10, do: SupplierAction.accept(ctx.token)

      assert {:error, :rate_limited} = SupplierAction.accept(ctx.token)
    end

    test "reads are not rate limited", ctx do
      for _ <- 1..10, do: SupplierAction.accept(ctx.token)

      assert {:ok, _} = SupplierAction.authorize(ctx.token)
    end
  end

  describe "declining tells the merchant" do
    test "writes a merchant notification pointing at the order", ctx do
      merchant = create_merchant!()

      Emakola.Accounts.StoreMembership
      |> Ash.Changeset.for_create(:create, %{
        merchant_id: merchant.id,
        store_id: ctx.store.id,
        role: :owner
      })
      |> Ash.create!(authorize?: false)

      {:ok, _} = SupplierAction.decline(ctx.token, :out_of_stock)

      notifications =
        Emakola.Notifications.Notification
        |> Ash.read!(authorize?: false)
        |> Enum.filter(&(&1.recipient_id == merchant.id))

      assert [notification] = notifications
      assert notification.recipient_kind == :merchant
      assert notification.action_url =~ ctx.order.id
    end

    test "still succeeds when the store has no members to notify", ctx do
      assert {:ok, declined} = SupplierAction.decline(ctx.token, :out_of_stock)
      assert declined.status == :declined
    end
  end

  # ── Delivery proof (the leg that decides whether the merchant is paid) ──

  describe "closing the delivery loop" do
    setup ctx do
      stub(Emakola.SMSProviderMock, :send_sms, fn _phone, _message, _opts -> {:ok, %{}} end)

      {:ok, _} = SupplierAction.accept(ctx.token)
      {:ok, shipped} = SupplierAction.mark_sent(ctx.token, "GH-DELIVERY-1")

      Map.put(ctx, :shipped, shipped)
    end

    test "a supplier can request a code and verify what the buyer reads out", ctx do
      assert {:ok, code} = SupplierAction.request_delivery_code(ctx.token, return_code: true)

      assert {:ok, delivered} = SupplierAction.verify_delivery(ctx.token, code)
      assert delivered.status == :delivered
    end

    # The whole point of the OTP: the party who wants the delivery recorded must
    # not be able to record it alone.
    test "the supplier never learns the code", ctx do
      assert {:ok, proof} = SupplierAction.request_delivery_code(ctx.token)

      refute Map.has_key?(proof, :code)
      assert proof.sent_to =~ "•"
    end

    test "a wrong code is refused and the fulfillment does not move", ctx do
      {:ok, _} = SupplierAction.request_delivery_code(ctx.token)

      assert {:error, :invalid_code} = SupplierAction.verify_delivery(ctx.token, "000000")
      assert reload(ctx.shipped).status == :shipped
    end

    test "five wrong codes lock it", ctx do
      {:ok, _} = SupplierAction.request_delivery_code(ctx.token)

      for _ <- 1..5, do: SupplierAction.verify_delivery(ctx.token, "000000")

      assert {:error, :too_many_attempts} = SupplierAction.verify_delivery(ctx.token, "000000")
    end

    test "a code cannot be requested before the goods are sent", ctx do
      other = create_fulfillment!(ctx.order, ctx.store, supplier_id: ctx.supplier.id)
      token = other |> SupplierAction.action_url() |> token_from_url()

      assert {:error, :fulfillment_not_shipped} = SupplierAction.request_delivery_code(token)
    end

    test "a revoked token cannot request or verify", ctx do
      {:ok, _} = SupplierAction.request_delivery_code(ctx.token)
      {:ok, _} = Emakola.Orders.rotate_fulfillment_supplier_link(ctx.shipped, authorize?: false)

      assert {:error, :revoked_token} = SupplierAction.request_delivery_code(ctx.token)
      assert {:error, :revoked_token} = SupplierAction.verify_delivery(ctx.token, "123456")
    end

    # The send budget belongs to the RECIPIENT, not the requester. A merchant and
    # a supplier acting on the same fulfilment must not be able to fire six codes
    # at one buyer's phone in ten minutes between them.
    test "shares its send budget with the merchant's own delivery-code path", ctx do
      {:ok, _} = SupplierAction.request_delivery_code(ctx.token)
      {:ok, _} = SupplierAction.request_delivery_code(ctx.token)

      {:ok, _} =
        Emakola.Orders.CustomerDelivery.request_delivery_code(ctx.store.id, ctx.shipped.id)

      assert {:error, :rate_limited} = SupplierAction.request_delivery_code(ctx.token),
             "the merchant's send must count against the supplier's budget"
    end

    test "a verified delivery cannot be replayed", ctx do
      {:ok, code} = SupplierAction.request_delivery_code(ctx.token, return_code: true)
      {:ok, _} = SupplierAction.verify_delivery(ctx.token, code)

      assert {:error, reason} = SupplierAction.verify_delivery(ctx.token, code)
      assert reason in [:already_verified, :fulfillment_not_shipped, :not_actionable]
    end
  end
end
