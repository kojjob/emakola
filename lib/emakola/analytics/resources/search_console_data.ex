defmodule Emakola.Analytics.SearchConsoleData do
  @moduledoc "Google Search Console metrics synced periodically via the GSC worker for SEO reporting."
  use Ash.Resource,
    domain: Emakola.Analytics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("search_console_data")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :keyword, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 500)
    end

    attribute(:page, :string, public?: true, constraints: [max_length: 2_048])
    attribute(:clicks, :integer, default: 0, public?: true)
    attribute(:impressions, :integer, default: 0, public?: true)

    attribute(:position, :float, public?: true)

    attribute(:ctr, :float, public?: true)

    attribute(:organisation_id, :uuid, public?: true)

    attribute :fetched_at, :utc_datetime do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
  end

  identities do
    # Search Console is queried for a ROLLING 28-day window aggregated by
    # (query, page) — there is no date dimension in the response. Each nightly
    # run therefore returns the same rows with a fresh `fetched_at`, and
    # creating them blindly stacks one copy per night.
    #
    # `nils_distinct?: false` matters: `page` and `organisation_id` are both
    # nullable, and Postgres treats every NULL as distinct by default, so a
    # plain unique index would let NULL-page rows duplicate forever.
    identity(:unique_keyword_page, [:keyword, :page, :organisation_id], nils_distinct?: false)
  end

  actions do
    defaults([:read])

    create :create do
      # One row per keyword+page, always carrying the latest window. This is a
      # current-state table, not a time series: consecutive 28-day windows
      # overlap by 27 days, so differencing snapshots would not yield a trend
      # anyway.
      upsert?(true)
      upsert_identity(:unique_keyword_page)

      upsert_fields([:clicks, :impressions, :position, :ctr, :fetched_at])

      accept([
        :keyword,
        :page,
        :clicks,
        :impressions,
        :position,
        :ctr,
        :organisation_id,
        :fetched_at
      ])
    end

    read :by_organisation do
      argument(:organisation_id, :uuid, allow_nil?: false)
      filter(expr(organisation_id == ^arg(:organisation_id)))
    end
  end
end
