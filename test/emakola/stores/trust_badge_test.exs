defmodule Emakola.Stores.TrustBadgeTest do
  @moduledoc """
  What a storefront badge is allowed to claim.

  A badge that attests to nothing is the pattern this codebase reverses, so
  these tests pin the two rules that keep it honest: a badge needs a recorded
  basis, and a basis that can no longer be earned lawfully does not last
  forever.
  """
  use ExUnit.Case, async: true

  alias Emakola.Stores.TrustBadge

  defp store(overrides) do
    Map.merge(
      %{verified: true, verified_basis: :wallet_proof, verified_basis_at: DateTime.utc_now()},
      Map.new(overrides)
    )
  end

  defp days_ago(n), do: DateTime.add(DateTime.utc_now(), -n * 24 * 3600, :second)

  describe "visible?" do
    test "an unverified store has no badge" do
      refute TrustBadge.visible?(store(%{verified: false}))
      assert TrustBadge.reason(store(%{verified: false})) == nil
    end

    test "a wallet-proven store has a badge that never lapses" do
      assert TrustBadge.visible?(store(%{verified_basis_at: days_ago(2000)}))
      assert TrustBadge.reason(store(%{})) == :wallet
    end

    test "a papers-checked store has a badge" do
      s = store(%{verified_basis: :business_review})
      assert TrustBadge.visible?(s)
      assert TrustBadge.reason(s) == :papers
    end

    test "an NIA-verified store reads as identity" do
      s = store(%{verified_basis: :nia_biometric})
      assert TrustBadge.visible?(s)
      assert TrustBadge.reason(s) == :identity
    end
  end

  describe "the retired Ghana Card basis lapses" do
    test "still shows inside the grace window" do
      s = store(%{verified_basis: :retired_document_flow, verified_basis_at: days_ago(30)})
      assert TrustBadge.visible?(s)
      assert TrustBadge.reason(s) == :legacy
    end

    test "stops showing past it — the check can no longer be lawfully repeated" do
      s = store(%{verified_basis: :retired_document_flow, verified_basis_at: days_ago(91)})
      refute TrustBadge.visible?(s)
      assert TrustBadge.reason(s) == nil
    end

    test "re-proving by wallet clears the lapse" do
      lapsed = store(%{verified_basis: :retired_document_flow, verified_basis_at: days_ago(200)})
      refute TrustBadge.visible?(lapsed)

      reproven = %{lapsed | verified_basis: :wallet_proof, verified_basis_at: DateTime.utc_now()}
      assert TrustBadge.visible?(reproven)
    end
  end

  describe "a badge with no recorded basis claims nothing" do
    test "verified but unlabelled does not show" do
      refute TrustBadge.visible?(store(%{verified_basis: nil, verified_basis_at: nil}))
    end

    test "a legacy basis with no timestamp does not show" do
      s = store(%{verified_basis: :retired_document_flow, verified_basis_at: nil})
      refute TrustBadge.visible?(s)
    end
  end

  describe "works on a plain map, not just a Store struct" do
    test "tolerates a map missing the badge keys entirely" do
      refute TrustBadge.visible?(%{name: "Ama Trades"})
      assert TrustBadge.reason(%{name: "Ama Trades"}) == nil
    end
  end
end
