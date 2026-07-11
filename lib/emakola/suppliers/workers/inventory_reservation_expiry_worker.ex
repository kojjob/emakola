defmodule Emakola.Suppliers.Workers.InventoryReservationExpiryWorker do
  @moduledoc "Returns unused expired passport-tier inventory holds to supplier stock."
  use Oban.Worker, queue: :orders, max_attempts: 3, unique: [period: 300, fields: [:args]]

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Emakola.Suppliers.InventoryReservations.expire_due()
  end
end
