defmodule Emakola.Orders.Workers.AbandonedCheckoutPruneWorker do
  @moduledoc """
  Deletes checkouts left behind more than 30 days ago, recovered or not. The
  merchant page shows seven days; nothing reads older rows, and a phone that
  never bought should not sit in the database for good. Idempotent.
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
