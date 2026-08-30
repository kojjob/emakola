defmodule Emakola.Accounts.DevicePairingsTest do
  @moduledoc """
  The lifecycle of a scan-to-sign-in request.

  These tests are the security contract, not a feature description. The flow
  hands out a bearer credential in visible form, so what matters is what it
  refuses: an expired code, a replayed code, a code confirmed by nobody, and a
  code redeemed twice at once.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Accounts.DevicePairings

  setup do
    merchant = Emakola.Factory.create_merchant!()
    {:ok, merchant: merchant}
  end

  describe "issuing" do
    test "returns the plaintext token once and never stores it", %{merchant: merchant} do
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)

      assert is_binary(token)
      # 32 random bytes, base64url — well past guessing range.
      assert byte_size(token) >= 40
      assert pairing.status == :pending

      # The row keeps only a digest. A database read must not yield anything a
      # phone could redeem.
      refute pairing.token_digest == token
      assert byte_size(pairing.token_digest) == 64
    end

    test "expires 90 seconds out", %{merchant: merchant} do
      {:ok, _token, pairing} = DevicePairings.issue(merchant.id)

      seconds = DateTime.diff(pairing.expires_at, DateTime.utc_now())
      assert seconds > 80 and seconds <= 90
    end

    test "two issues never collide", %{merchant: merchant} do
      {:ok, a, _} = DevicePairings.issue(merchant.id)
      {:ok, b, _} = DevicePairings.issue(merchant.id)

      refute a == b
    end
  end

  describe "scanning" do
    test "a valid token records the phone and moves to :scanned", %{merchant: merchant} do
      {:ok, token, _} = DevicePairings.issue(merchant.id)

      assert {:ok, pairing} = DevicePairings.scan(token, "iPhone Safari")
      assert pairing.status == :scanned
      assert pairing.scanned_by == "iPhone Safari"
    end

    test "an unknown token is refused", %{merchant: _merchant} do
      assert {:error, :not_found} = DevicePairings.scan("not-a-real-token", "iPhone")
    end

    test "an expired token is refused", %{merchant: merchant} do
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      expire!(pairing)

      assert {:error, :expired} = DevicePairings.scan(token, "iPhone")
    end
  end

  describe "confirming — the step that defeats the inverted attack" do
    test "the desktop that minted it can confirm", %{merchant: merchant} do
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "iPhone")

      assert {:ok, confirmed} = DevicePairings.confirm(pairing.id, merchant.id)
      assert confirmed.status == :confirmed
    end

    test "another merchant cannot confirm someone else's pairing", %{merchant: merchant} do
      other = Emakola.Factory.create_merchant!()
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "iPhone")

      assert {:error, :not_found} = DevicePairings.confirm(pairing.id, other.id)
    end

    test "a pairing nobody scanned cannot be confirmed", %{merchant: merchant} do
      {:ok, _token, pairing} = DevicePairings.issue(merchant.id)

      assert {:error, :not_scanned} = DevicePairings.confirm(pairing.id, merchant.id)
    end
  end

  describe "redeeming" do
    test "a confirmed token yields its merchant exactly once", %{merchant: merchant} do
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "iPhone")
      {:ok, _} = DevicePairings.confirm(pairing.id, merchant.id)

      assert {:ok, redeemed} = DevicePairings.redeem(token)
      assert redeemed.id == merchant.id

      # Replay. The image outlives the redemption, so this is the case that
      # matters most.
      assert {:error, :not_found} = DevicePairings.redeem(token)
    end

    test "an unconfirmed token cannot be redeemed", %{merchant: merchant} do
      {:ok, token, _} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "iPhone")

      # Scanned but never confirmed on the desktop — this is exactly the
      # inverted-phishing case, and it must not produce a session.
      assert {:error, :not_confirmed} = DevicePairings.redeem(token)
    end

    test "an expired token cannot be redeemed even after confirmation", %{merchant: merchant} do
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "iPhone")
      {:ok, _} = DevicePairings.confirm(pairing.id, merchant.id)
      expire!(pairing)

      assert {:error, :expired} = DevicePairings.redeem(token)
    end

    test "a rejected pairing cannot be redeemed", %{merchant: merchant} do
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "iPhone")
      {:ok, _} = DevicePairings.reject(pairing.id, merchant.id)

      assert {:error, :not_confirmed} = DevicePairings.redeem(token)
    end

    test "concurrent redemptions cannot both win", %{merchant: merchant} do
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "iPhone")
      {:ok, _} = DevicePairings.confirm(pairing.id, merchant.id)

      # Two phones with the same photographed code, racing. The row lock is the
      # only thing standing between that and two live sessions.
      results =
        [1, 2]
        |> Enum.map(fn _ -> Task.async(fn -> DevicePairings.redeem(token) end) end)
        |> Task.await_many(5_000)

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    end
  end

  describe "leaving a trace" do
    test "a redemption is written to the audit log", %{merchant: merchant} do
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "An iPhone")
      {:ok, _} = DevicePairings.confirm(pairing.id, merchant.id)
      {:ok, _} = DevicePairings.redeem(token)

      # A pairing IS a sign-in. Without a record, an account taken over this
      # way leaves nothing behind to investigate.
      entries = Ash.read!(Emakola.Audit.AuditLog, authorize?: false)

      assert Enum.any?(entries, fn e ->
               e.action == :device_paired and e.actor_id == merchant.id
             end)
    end

    test "a refused redemption is recorded too", %{merchant: merchant} do
      {:ok, token, _pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "An iPhone")

      # Never confirmed — the inverted-phishing shape. Someone trying it is
      # exactly what a reviewer would want to find in the log.
      {:error, :not_confirmed} = DevicePairings.redeem(token)

      entries = Ash.read!(Emakola.Audit.AuditLog, authorize?: false)
      assert Enum.any?(entries, &(&1.action == :device_pairing_refused))
    end
  end

  describe "rate limiting" do
    test "a burst of pairing requests is cut off", %{merchant: merchant} do
      results = for _ <- 1..12, do: DevicePairings.issue(merchant.id)

      assert Enum.any?(results, &match?({:error, :rate_limited}, &1)),
             "expected issuing to be rate limited"
    end

    test "one merchant's burst does not lock out another", %{merchant: merchant} do
      other = Emakola.Factory.create_merchant!()
      for _ <- 1..12, do: DevicePairings.issue(merchant.id)

      assert {:ok, _token, _pairing} = DevicePairings.issue(other.id)
    end
  end

  describe "revocation" do
    test "signing out kills a code still waiting on screen", %{merchant: merchant} do
      {:ok, token, _pairing} = DevicePairings.issue(merchant.id)

      DevicePairings.revoke_pending(merchant.id)

      # The merchant walked away from the desktop. A code still live on that
      # screen must not sign anyone in afterwards.
      assert {:error, _} = DevicePairings.scan(token, "An iPhone")
    end

    test "a code already confirmed is killed too", %{merchant: merchant} do
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "An iPhone")
      {:ok, _} = DevicePairings.confirm(pairing.id, merchant.id)

      DevicePairings.revoke_pending(merchant.id)

      # This is the one that matters: confirmed but not yet redeemed is a
      # credential someone is holding right now.
      assert {:error, :not_confirmed} = DevicePairings.redeem(token)
    end

    test "revoking one merchant leaves another's codes alone", %{merchant: merchant} do
      other = Emakola.Factory.create_merchant!()
      {:ok, their_token, their_pairing} = DevicePairings.issue(other.id)
      {:ok, _} = DevicePairings.scan(their_token, "An iPhone")
      {:ok, _} = DevicePairings.confirm(their_pairing.id, other.id)

      DevicePairings.revoke_pending(merchant.id)

      assert {:ok, redeemed} = DevicePairings.redeem(their_token)
      assert redeemed.id == other.id
    end

    test "cutting a merchant's sessions cuts their pairings with them", %{merchant: merchant} do
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "An iPhone")
      {:ok, _} = DevicePairings.confirm(pairing.id, merchant.id)

      # revoke_all_sessions_for/1 is what runs on a password reset or a
      # suspected takeover. A pairing that survived it would be a way back in.
      Emakola.Accounts.revoke_all_sessions_for(merchant)

      assert {:error, :not_confirmed} = DevicePairings.redeem(token)
    end
  end

  defp expire!(pairing) do
    pairing
    |> Ash.Changeset.for_update(:confirm, %{})
    |> Ash.Changeset.force_change_attribute(
      :expires_at,
      DateTime.add(DateTime.utc_now(), -1, :second)
    )
    |> Ash.Changeset.force_change_attribute(:status, pairing.status)
    |> Ash.update!(authorize?: false)
  end
end
