defmodule Emakola.Payments.Workers.SusuCompletionWorker do
  @moduledoc """
  Shell for TC-3 Task 5's susu-plan completion worker.

  `Emakola.Orders.SusuChunks.confirm_chunk/1` (Task 3) enqueues this job,
  unique on its args, the instant a plan's final chunk lands
  (`contributed_amount == total_amount` -> `:complete`). Task 5 does the
  real work here: creating the plan's order, attaching every contributing
  payment via `Payment.:attach_order`, and notifying the buyer.

  Until Task 5 lands, `perform/1` snoozes rather than either silently
  no-opping (`:ok` would hide that nothing happened) or erroring the queue
  into retries and eventual `:discarded` (a plan that legitimately
  completed shouldn't dead-letter). The job stays visibly queued in Oban —
  an honest "not implemented yet", not a placeholder pretending to work.
  """

  use Oban.Worker,
    queue: :orders,
    unique: [fields: [:args], period: 86_400]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"susu_plan_id" => _plan_id}}) do
    {:snooze, 60}
  end
end
