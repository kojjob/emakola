defmodule Emakola.AI.Usage do
  @moduledoc """
  One row per AI generation attempt — the accounting record for the AI suite.

  Captures the model, token counts, computed cost (integer micro-USD), status,
  and latency for every `Emakola.AI.generate/3` call, scoped to the calling store
  (or `nil` for platform-scoped calls like the admin copilot). Powers per-store
  usage/cost dashboards and is the basis for any future quota or billing.

  `store_id` is a plain nullable column, **not** an Ash tenant: platform-scoped
  rows have no store, so attribute multitenancy doesn't apply — reads filter by
  `store_id` explicitly (`usage_for_store`). All access is server-side via
  `authorize?: false`; a future merchant-facing read must add policies.
  """

  use Ash.Resource,
    domain: Emakola.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ai_usage")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(true)
    end

    attribute :feature, :string do
      allow_nil?(false)
      constraints(max_length: 100)
    end

    attribute :provider, :string do
      allow_nil?(false)
      constraints(max_length: 50)
    end

    attribute :model, :string do
      constraints(max_length: 100)
    end

    attribute :input_tokens, :integer do
      default(0)
      allow_nil?(false)
    end

    attribute :output_tokens, :integer do
      default(0)
      allow_nil?(false)
    end

    attribute :cost_microusd, :integer do
      default(0)
      allow_nil?(false)
    end

    attribute :status, :atom do
      allow_nil?(false)
      constraints(one_of: [:success, :error, :not_configured, :rate_limited])
    end

    attribute :latency_ms, :integer do
      default(0)
      allow_nil?(false)
    end

    attribute :actor_id, :uuid do
      allow_nil?(true)
    end

    attribute :error, :string do
      constraints(max_length: 1000)
    end

    timestamps()
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id,
        :feature,
        :provider,
        :model,
        :input_tokens,
        :output_tokens,
        :cost_microusd,
        :status,
        :latency_ms,
        :actor_id,
        :error
      ])
    end

    read :usage_for_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
