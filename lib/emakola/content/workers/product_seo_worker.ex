defmodule Emakola.Content.Workers.ProductSEOWorker do
  @moduledoc """
  Backfills a missing product description with AI (SEO Phase 3b).

  Idempotent on two levels: Oban uniqueness (one job per product per minute) and
  a data check (skips products that already have a description). Gated by the
  per-store daily `RateLimiter`: past the cap the job snoozes until the cap
  resets, so a large import is described over a few days rather than stopping
  at fifty. The description is saved through `:backfill_description`, which
  marks it as AI-written so the product form can ask the merchant to read it.
  Ships dark — if the generator has no API key it cancels the job rather than
  retrying forever.
  """

  use Oban.Worker, queue: :ai_content, max_attempts: 3, unique: [period: 60, keys: [:product_id]]

  alias Emakola.Content.{Generator, RateLimiter}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"product_id" => product_id}}) do
    case Ash.get(Emakola.Catalog.Product, product_id, authorize?: false) do
      {:ok, product} -> backfill(product)
      _ -> :ok
    end
  end

  defp backfill(product) do
    if present?(product.description) do
      :ok
    else
      with :ok <- RateLimiter.check_and_increment(product.store_id),
           {:ok, store} <- Ash.get(Emakola.Stores.Store, product.store_id, authorize?: false),
           {:ok, description} <- Generator.generate_product_description(product, store) do
        product
        |> Ash.Changeset.for_update(:backfill_description, %{description: description})
        |> Ash.update(authorize?: false)

        :ok
      else
        {:error, :rate_limit_exceeded} -> {:snooze, RateLimiter.seconds_until_reset()}
        {:error, :not_configured} -> {:cancel, "AI generator not configured"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
