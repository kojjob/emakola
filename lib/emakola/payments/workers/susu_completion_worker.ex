defmodule Emakola.Payments.Workers.SusuCompletionWorker do
  @moduledoc """
  Completes a susu plan (TC-3 Task 5): creates its order, attaches every
  contributing payment, apportions the platform fee, composes buyer
  protection, and confirms the order.

  `Emakola.Orders.SusuChunks.confirm_chunk/1` (Task 3) enqueues this job,
  unique on its args, the instant a plan's final chunk lands
  (`contributed_amount == total_amount` -> `:complete`).

  All the real work lives in `Emakola.Orders.SusuCompletion.complete/1`,
  which is idempotent (a second run for the same plan finds its order
  already created and no-ops). This `perform/1` does NOT rescue: a raise
  from `complete/1` means a genuine invariant violation (e.g. broken fee
  apportionment), which should fail the job loudly and let Oban retry —
  never recorded as a silent success.
  """

  use Oban.Worker,
    queue: :orders,
    unique: [fields: [:args], period: 86_400]

  alias Emakola.Orders.SusuCompletion

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"susu_plan_id" => plan_id}}) do
    {:ok, _order} = SusuCompletion.complete(plan_id)
    :ok
  end
end
