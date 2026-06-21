defmodule Emakola.Content.Workers.BlogGeneratorWorker do
  @moduledoc """
  Generates an AI blog/guide post for a store from a topic (SEO Phase 3b).

  Creates an `:ai_draft` post — never published — that a human reviews and
  publishes. Gated by the per-store `RateLimiter`; Oban uniqueness dedupes by
  `{store_id, topic}`. Cancels rather than retries when the generator is
  ship-dark or the daily cap is hit.
  """

  use Oban.Worker,
    queue: :ai_content,
    max_attempts: 3,
    unique: [period: 30, keys: [:store_id, :topic]]

  alias Emakola.Content.{Generator, RateLimiter}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"store_id" => store_id, "topic" => topic} = args}) do
    type = type_for(Map.get(args, "type"))

    with :ok <- RateLimiter.check_and_increment(store_id),
         {:ok, store} <- Ash.get(Emakola.Stores.Store, store_id, authorize?: false),
         {:ok, draft} <- Generator.generate_blog_post(topic, store, type),
         {:ok, _post} <- create_draft(store_id, type, draft) do
      :ok
    else
      {:error, :rate_limit_exceeded} -> {:cancel, "store hit its daily AI limit"}
      {:error, :not_configured} -> {:cancel, "AI generator not configured"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_draft(store_id, type, draft) do
    Emakola.Content.create_ai_draft_post(
      %{
        store_id: store_id,
        type: type,
        title: draft.title,
        body: draft.body,
        excerpt: draft.excerpt,
        tags: draft.tags
      },
      authorize?: false
    )
  end

  # Explicit allowlist — never String.to_atom on job args.
  defp type_for("guide"), do: :guide
  defp type_for(_), do: :blog_post
end
