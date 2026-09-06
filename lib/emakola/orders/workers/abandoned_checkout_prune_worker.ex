defmodule Emakola.Orders.Workers.AbandonedCheckoutPruneWorker do
  @moduledoc """
  Deletes checkouts left behind more than 30 days ago, recovered or not. The
  merchant page shows seven days; nothing reads older rows, and a phone that
  never bought should not sit in the database for good. Idempotent.

  **Known ceiling: one unbounded `delete_all`.** After a quiet period, or on
  the first run following a backlog, this is a single large transaction
  holding locks on a table the storefront writes to at every checkout step 1,
  and `max_attempts: 1` means a timeout is skipped until the next night
  rather than retried. Left as one statement while the table is small and
  the nightly delta is a day's worth of rows. When that stops being true the
  fix is a bounded loop — `DELETE ... WHERE id IN (SELECT ... LIMIT 5000)`
  until it deletes nothing — which makes the runtime predictable without
  changing what gets deleted.
  """
  use Oban.Worker, queue: :default, max_attempts: 1

  import Ecto.Query

  @keep_days 30

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.add(DateTime.utc_now(), -@keep_days * 86_400, :second)

    from(c in "abandoned_checkouts", where: c.last_seen_at < ^cutoff)
    |> Emakola.Repo.delete_all()

    :ok
  end
end
