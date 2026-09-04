defmodule Emakola.Content.Workers.ImageAltTextWorker do
  @moduledoc """
  Backfills missing image alt text with AI vision (SEO Phase 3b).

  Idempotent (skips images that already have alt text; Oban uniqueness per
  image/minute), gated by the per-store `RateLimiter`, and cancels rather than
  retries when the generator is ship-dark or the daily cap is hit. Good alt text
  opens image search and improves accessibility.
  """

  use Oban.Worker, queue: :ai_content, max_attempts: 3, unique: [period: 60, keys: [:image_id]]

  alias Emakola.Content.{Generator, RateLimiter}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"image_id" => image_id}}) do
    case Ash.get(Emakola.Catalog.Image, image_id, authorize?: false) do
      {:ok, image} -> backfill(image)
      _ -> :ok
    end
  end

  defp backfill(image) do
    if present?(image.alt_text) do
      :ok
    else
      with :ok <- RateLimiter.check_and_increment(image.store_id),
           {:ok, alt_text} <- Generator.generate_image_alt_text(image.url) do
        image
        |> Ash.Changeset.for_update(:update, %{alt_text: alt_text})
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
