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

  This is the development face. Production runs a release, which ships no Mix,
  so there it is `bin/emakola rpc 'Emakola.Release.backfill_verified_merchants()'`.
  Both call `Emakola.Accounts.VerificationBackfill`.
  """

  use Mix.Task

  alias Emakola.Accounts.VerificationBackfill

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    dry_run? = "--dry-run" in args

    result = VerificationBackfill.run(dry_run?: dry_run?)

    Mix.shell().info("Unverified merchants: #{result.trading + result.dormant}")
    Mix.shell().info("  trading (will be grandfathered): #{result.trading}")
    Mix.shell().info("  dormant  (left unverified):      #{result.dormant}")

    if dry_run? do
      Enum.each(VerificationBackfill.trading_emails(), &Mix.shell().info("  would verify #{&1}"))
      Mix.shell().info("\nDry run — nothing changed.")
    else
      Mix.shell().info("\nVerified #{result.verified} trading merchants.")
    end
  end
end
