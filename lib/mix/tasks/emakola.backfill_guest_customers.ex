defmodule Mix.Tasks.Emakola.BackfillGuestCustomers do
  @shortdoc "Links guest orders to customers by the phone they typed"

  @moduledoc """
  Storefront guest orders were created with no customer. This links each one
  to the customer for its shipping phone, creating the customer when needed.
  Safe to re-run.

      mix emakola.backfill_guest_customers [--dry-run]
  """

  use Mix.Task

  alias Emakola.Customers.GuestBackfill

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    dry_run? = "--dry-run" in args

    result = GuestBackfill.run(dry_run?: dry_run?)

    Mix.shell().info("Guest orders with a phone: #{result.linked}")
    Mix.shell().info("Guest orders without a phone, left alone: #{result.skipped}")
    Mix.shell().info("Guest orders that failed to link (see logs): #{result.failed}")

    if dry_run?,
      do: Mix.shell().info("Dry run. Nothing changed."),
      else: Mix.shell().info("Linked #{result.linked} orders.")
  end
end
