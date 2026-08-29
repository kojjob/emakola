defmodule EmakolaWeb.SupplierLinkTokensTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.SupplierLinkTokens

  defp id, do: Ash.UUID.generate()

  describe "sign/2 and verify/1" do
    test "round-trips a fulfillment id and its link version" do
      fulfillment_id = id()
      signed = SupplierLinkTokens.sign(fulfillment_id, 1)

      assert signed != fulfillment_id
      assert {:ok, {^fulfillment_id, 1}} = SupplierLinkTokens.verify(signed)
    end

    test "carries the version through, so a rotated link is distinguishable" do
      fulfillment_id = id()

      assert {:ok, {^fulfillment_id, 7}} =
               fulfillment_id |> SupplierLinkTokens.sign(7) |> SupplierLinkTokens.verify()
    end

    test "rejects a tampered token" do
      signed = SupplierLinkTokens.sign(id(), 1)

      assert {:error, :invalid} = SupplierLinkTokens.verify(signed <> "x")
    end

    test "rejects a token signed with a different salt" do
      # The salt is what stops a token minted for one purpose being replayed at
      # another. An order-tracking token must not open a supplier action page.
      other = EmakolaWeb.TrackingTokens.sign_order_tracking(id())

      assert {:error, :invalid} = SupplierLinkTokens.verify(other)
    end

    test "rejects nil and non-binary garbage without raising" do
      assert {:error, :missing} = SupplierLinkTokens.verify(nil)
      assert {:error, :missing} = SupplierLinkTokens.verify(123)
      assert {:error, :missing} = SupplierLinkTokens.verify(%{})
    end

    test "rejects binary garbage" do
      assert {:error, :invalid} = SupplierLinkTokens.verify("garbage")
    end

    test "rejects a token older than the max age" do
      # Phoenix.Token's :signed_at is in SECONDS. Passing milliseconds dates the
      # token ~55,000 years in the future, and verify/1 then answers :invalid
      # rather than :expired — a confusing way to fail this test.
      thirty_one_days_ago =
        DateTime.utc_now()
        |> DateTime.add(-31 * 24 * 60 * 60, :second)
        |> DateTime.to_unix(:second)

      stale =
        Phoenix.Token.sign(EmakolaWeb.Endpoint, "supplier_action_v1", [id(), 1],
          signed_at: thirty_one_days_ago
        )

      assert {:error, :expired} = SupplierLinkTokens.verify(stale)
    end

    test "accepts a token just inside the max age" do
      fulfillment_id = id()

      twenty_nine_days_ago =
        DateTime.utc_now()
        |> DateTime.add(-29 * 24 * 60 * 60, :second)
        |> DateTime.to_unix(:second)

      fresh_enough =
        Phoenix.Token.sign(EmakolaWeb.Endpoint, "supplier_action_v1", [fulfillment_id, 1],
          signed_at: twenty_nine_days_ago
        )

      assert {:ok, {^fulfillment_id, 1}} = SupplierLinkTokens.verify(fresh_enough)
    end

    # A validly-signed token whose payload is not the shape we mint is not
    # authority for anything. Accepting it would mean trusting our own salt more
    # than our own contract — and the salt is shared across every future use of
    # this module.
    test "rejects a validly-signed token whose payload is the wrong shape" do
      for payload <- [%{"id" => id()}, [id()], [id(), 1, :extra], id(), [1, id()]] do
        signed = Phoenix.Token.sign(EmakolaWeb.Endpoint, "supplier_action_v1", payload)

        assert {:error, :invalid} = SupplierLinkTokens.verify(signed),
               "accepted a wrong-shaped payload: #{inspect(payload)}"
      end
    end
  end
end
