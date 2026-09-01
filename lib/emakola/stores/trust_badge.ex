defmodule Emakola.Stores.TrustBadge do
  @moduledoc """
  What a storefront trust badge is allowed to claim, and for how long.

  Pure: signals in, verdict out. No database, no structs — the badge renders
  from plain maps in `StoresComponents`, and keeping the rule here means the
  three render sites cannot drift apart.

  Two rules keep the badge honest:

  **A badge needs a recorded basis.** `Store.verified` alone says only that a
  boolean is true; `verified_basis` says what was actually checked. A store
  carrying the flag with no basis claims nothing and shows nothing.

  **A basis that can no longer be earned does not last forever.** Approvals
  under the retired Ghana Card flow rest on a check L.I. 2523 has made an
  offence to repeat, so they lapse #{90} days after the basis was stamped.
  A merchant who proves their payout wallet in that window keeps a badge with
  no expiry; one who never returns quietly stops carrying a claim nobody can
  refresh.

  The reasons are deliberately coarser than the bases. A shopper sees one
  symbol everywhere — the same tick at 7px in a directory grid as on the shop
  page — because three near-identical marks are three things a merchant's
  low-literacy customers have to learn. The *reason* is spelled out once, in
  words and a picture, on the shop page where there is room for it.
  """

  @legacy_grace_days 90

  @doc """
  Whether the store may show a trust badge at all.
  """
  @spec visible?(map()) :: boolean()
  def visible?(store), do: reason(store) != nil

  @doc """
  What the badge rests on, as the shopper-facing reason:

    * `:wallet`   — the merchant proved control of their payout wallet
    * `:papers`   — staff checked a licence or tax receipt
    * `:identity` — verified against the national register (not yet built)
    * `:legacy`   — approved under the retired document flow, still in grace
    * `nil`       — no badge

  """
  @spec reason(map()) :: :wallet | :papers | :identity | :legacy | nil
  def reason(store) do
    if Map.get(store, :verified) do
      basis_reason(Map.get(store, :verified_basis), Map.get(store, :verified_basis_at))
    end
  end

  defp basis_reason(:wallet_proof, _at), do: :wallet
  defp basis_reason(:business_review, _at), do: :papers
  defp basis_reason(:nia_biometric, _at), do: :identity

  defp basis_reason(:retired_document_flow, %DateTime{} = at) do
    if DateTime.diff(DateTime.utc_now(), at, :second) <= @legacy_grace_days * 24 * 3600,
      do: :legacy
  end

  # No stamp means nothing dates the claim, so it cannot be shown to have
  # survived the grace window. Fails closed on purpose: an unlabelled badge is
  # the thing this module exists to stop.
  defp basis_reason(_unlabelled, _at), do: nil

  @doc """
  The one short line shown beside the badge on the shop page. Kept under eight
  words: these shops sell to customers who do not read well.
  """
  @spec line(map()) :: String.t() | nil
  def line(store), do: reason_line(reason(store))

  defp reason_line(:wallet), do: "Money goes to a checked wallet"
  defp reason_line(:papers), do: "Shop papers checked"
  defp reason_line(:identity), do: "Identity checked with NIA"
  defp reason_line(:legacy), do: "Checked by Makola staff"
  defp reason_line(nil), do: nil

  @doc "Grace window, in days, for the retired document basis."
  def legacy_grace_days, do: @legacy_grace_days
end
