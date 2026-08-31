defmodule Mix.Tasks.Emakola.BackfillVerifiedMerchants do
  @shortdoc "Grandfathers trading merchants past the new verification gate"

  @moduledoc """
  Marks unverified merchants verified — but only the ones who have actually
  been trading.

      mix emakola.backfill_verified_merchants --dry-run
      mix emakola.backfill_verified_merchants

  Access is gated on a verified address now. Applied flatly, that locks out
  every merchant who signed up during the three weeks production ran on a
  dead mail key and has been selling ever since — people whose accounts are
  demonstrably real and whose shops are demonstrably theirs.

  So the split is by evidence rather than by date: a merchant who owns a store
  that has products or orders is grandfathered, because forcing them through
  verification buys no safety (the account already exists, and the money is
  governed at payout, where the payout account must be verified before
  anything settles). A merchant with no store and no trade is left unverified,
  because that is exactly the junk-signup bucket the gate is for, and there is
  nobody to inconvenience.

  Run with `--dry-run` first. It prints what it would do and changes nothing.
  """

  use Mix.Task

  require Ash.Query

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    dry_run? = "--dry-run" in args

    {trading, dormant} =
      unverified_merchants()
      |> Enum.split_with(&has_traded?/1)

    Mix.shell().info("Unverified merchants: #{length(trading) + length(dormant)}")
    Mix.shell().info("  trading (will be grandfathered): #{length(trading)}")
    Mix.shell().info("  dormant  (left unverified):      #{length(dormant)}")

    if dry_run? do
      Enum.each(trading, &Mix.shell().info("  would verify #{&1.email}"))
      Mix.shell().info("\nDry run — nothing changed.")
    else
      Enum.each(trading, fn merchant ->
        merchant
        |> Ash.Changeset.for_update(:update_profile, %{})
        |> Ash.Changeset.force_change_attribute(:confirmed_at, DateTime.utc_now())
        |> Ash.update!(authorize?: false)
      end)

      Mix.shell().info("\nVerified #{length(trading)} trading merchants.")
    end
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
