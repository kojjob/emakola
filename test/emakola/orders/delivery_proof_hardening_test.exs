defmodule Emakola.Orders.DeliveryProofHardeningTest do
  @moduledoc """
  The delivery OTP is the only mechanism in the system that requires a second
  party to assent before a merchant is paid. Two properties of the proof record
  itself were weaker than they read.

  **The attempt cap was per-code, not per-proof.** `:reissue` reset `attempts`
  to zero with no lifetime budget, so the cap did not bound total guessing — it
  bounded guessing between two sends. At three sends per ten minutes that is
  fifteen guesses per ten minutes, forever.

  **A verified proof could be un-verified.** `:reissue` cleared `verified_at`,
  so the record offered no replay protection of its own; the only thing standing
  in the way was a status check in the caller.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  defp issue!(fulfillment) do
    %{
      fulfillment_id: fulfillment.id,
      code_hash: Bcrypt.hash_pwd_salt("123456"),
      expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
      sent_to: "•••••1234"
    }
    |> Emakola.Orders.issue_fulfillment_delivery_proof(authorize?: false)
  end

  defp reissue(proof) do
    proof
    |> Ash.Changeset.for_update(:reissue, %{
      code_hash: Bcrypt.hash_pwd_salt("654321"),
      expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
      sent_to: "•••••1234"
    })
    |> Ash.update(authorize?: false)
  end

  defp record_attempts!(proof, count) do
    Enum.reduce(1..count, proof, fn _i, acc ->
      acc
      |> Ash.Changeset.for_update(:record_attempt, %{})
      |> Ash.update!(authorize?: false)
    end)
  end

  setup do
    store = create_store!()
    order = create_order!(store)
    fulfillment = create_fulfillment!(order, store)
    {:ok, proof} = issue!(fulfillment)

    %{store: store, fulfillment: fulfillment, proof: proof}
  end

  describe "the lifetime guess budget (F2)" do
    test "a fresh proof starts with a spent count of zero", %{proof: proof} do
      assert proof.total_attempts == 0
    end

    test "reissuing clears the per-code attempts but NOT the lifetime count", %{proof: proof} do
      proof = record_attempts!(proof, 4)
      assert proof.attempts == 4
      assert proof.total_attempts == 4

      {:ok, reissued} = reissue(proof)

      assert reissued.attempts == 0, "the per-code cap resets, as it should"
      assert reissued.total_attempts == 4, "the lifetime budget must not reset"
    end

    test "the lifetime budget accumulates across many reissues", %{proof: proof} do
      proof =
        Enum.reduce(1..4, proof, fn _i, acc ->
          acc = record_attempts!(acc, 5)
          {:ok, reissued} = reissue(acc)
          reissued
        end)

      assert proof.total_attempts == 20
    end

    test "reissue is refused once the lifetime budget is spent", %{proof: proof} do
      proof = record_attempts!(proof, 25)

      assert {:error, _} = reissue(proof),
             "an attacker must not be able to buy a fresh attempt window forever"
    end
  end

  describe "a verified proof is final (F3)" do
    test "reissue is refused once the proof has been verified", %{proof: proof} do
      verified =
        proof
        |> Ash.Changeset.for_update(:verify, %{})
        |> Ash.update!(authorize?: false)

      assert %DateTime{} = verified.verified_at

      assert {:error, _} = reissue(verified),
             "a verified delivery must not be resettable to unverified"
    end

    test "the reissue path still works on an unverified proof", %{proof: proof} do
      assert {:ok, reissued} = reissue(proof)
      assert is_nil(reissued.verified_at)
    end
  end
end
