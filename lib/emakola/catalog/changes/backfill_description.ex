defmodule Emakola.Catalog.Changes.BackfillDescription do
  @moduledoc """
  Queues the AI description backfill for a product created without one.

  The worker is idempotent, skips products that gained a description in the
  meantime, cancels cleanly when AI is not configured, and is capped by the
  per-store daily `RateLimiter`. Enqueuing on create means a merchant who
  never opens the SEO dashboard still ends up with a product page Google has
  something to read on.
  """
  use Ash.Resource.Change

  alias Emakola.Content.Workers.ProductSEOWorker

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, product ->
      if blank?(product.description) do
        %{"product_id" => product.id}
        |> ProductSEOWorker.new()
        |> Oban.insert()
      end

      {:ok, product}
    end)
  end

  defp blank?(value), do: not is_binary(value) or String.trim(value) == ""
end
