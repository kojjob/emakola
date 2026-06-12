defmodule Emakola.Cart.CartCleanupWorker do
  @moduledoc """
  Oban cron worker that cleans up expired cart sessions from the cart_items table in Postgres.
  Runs every 6 hours. Carts older than 72 hours are removed.
  """
  use Oban.Worker, queue: :default, max_attempts: 1

  @max_age_seconds 72 * 3600

  @impl Oban.Worker
  def perform(_job) do
    Emakola.Cart.CartStore.cleanup_expired(@max_age_seconds)
    :ok
  end
end
