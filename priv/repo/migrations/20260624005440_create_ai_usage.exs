defmodule Emakola.Repo.Migrations.CreateAiUsage do
  @moduledoc """
  AI suite accounting log — one row per `Emakola.AI.generate/3` call, with model,
  token counts, computed cost (micro-USD), status and latency. `store_id` is a
  plain nullable column (platform-scoped calls have no store); indexed because
  `usage_for_store` filters on it.
  """

  use Ecto.Migration

  def up do
    create table(:ai_usage, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :store_id, :uuid
      add :feature, :text, null: false
      add :provider, :text, null: false
      add :model, :text
      add :input_tokens, :bigint, null: false, default: 0
      add :output_tokens, :bigint, null: false, default: 0
      add :cost_microusd, :bigint, null: false, default: 0
      add :status, :text, null: false
      add :latency_ms, :bigint, null: false, default: 0
      add :actor_id, :uuid
      add :error, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:ai_usage, [:store_id])
  end

  def down do
    drop table(:ai_usage)
  end
end
