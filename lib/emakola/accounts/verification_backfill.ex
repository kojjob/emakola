defmodule Emakola.Accounts.VerificationBackfill do
  @moduledoc """
  Grandfathers trading merchants past the verification gate.

  Access is gated on a verified address. Applied flatly, that locks out every
  merchant who signed up during the three weeks production ran on a dead mail
  key and has been selling ever since — people whose accounts are demonstrably
  real and whose shops are demonstrably theirs.

  So the split is by evidence rather than by date: a merchant who owns a store
  holding a product or an order is grandfathered, because forcing them through
  verification buys no safety (the account already exists, and the money is
  governed at payout, where the payout account must be verified before anything
  settles). A merchant with no store and no trade is left unverified, because
  that is exactly the junk-signup bucket the gate is for, and there is nobody
  to inconvenience.

  The logic lives here, rather than in the Mix task, because production runs a
  release and a release ships no Mix. `Emakola.Release.backfill_verified_merchants/1`
  is how it is invoked there; the Mix task is the same call with printing.
  """

  require Ash.Query

  @type result :: %{
          trading: non_neg_integer(),
          dormant: non_neg_integer(),
          verified: non_neg_integer()
        }

  @doc """
  Verifies every unverified merchant with evidence of trading.

  Pass `dry_run?: true` to count without writing. Returns counts only — never
  addresses, tokens or anything else that should not sit in a deploy log.
  """
  @spec run(keyword()) :: result()
  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run?, false)

    {trading, dormant} = Enum.split_with(unverified_merchants(), &has_traded?/1)

    verified = if dry_run?, do: 0, else: Enum.count(trading, &verify!/1)

    %{trading: length(trading), dormant: length(dormant), verified: verified}
  end

  @doc "Emails that would be grandfathered. For the dev-time dry run only."
  @spec trading_emails() :: [String.t()]
  def trading_emails do
    unverified_merchants()
    |> Enum.filter(&has_traded?/1)
    |> Enum.map(&to_string(&1.email))
  end

  defp verify!(merchant) do
    merchant
    |> Ash.Changeset.for_update(:update_profile, %{})
    |> Ash.Changeset.force_change_attribute(:confirmed_at, DateTime.utc_now())
    |> Ash.update!(authorize?: false)

    true
  end

  defp unverified_merchants do
    Emakola.Accounts.Merchant
    |> Ash.Query.filter(is_nil(confirmed_at))
    |> Ash.read!(authorize?: false)
  end

  # Evidence of a real shop: a store this merchant belongs to that holds a
  # product or has taken an order.
  defp has_traded?(merchant) do
    store_ids =
      Emakola.Accounts.StoreMembership
      |> Ash.Query.filter(merchant_id == ^merchant.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.store_id)

    store_ids != [] and (any_products?(store_ids) or any_orders?(store_ids))
  end

  defp any_products?(store_ids) do
    Emakola.Catalog.Product
    |> Ash.Query.filter(store_id in ^store_ids)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end

  defp any_orders?(store_ids) do
    Emakola.Orders.Order
    |> Ash.Query.filter(store_id in ^store_ids)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end
end
