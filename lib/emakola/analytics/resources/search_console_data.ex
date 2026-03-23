defmodule Emakola.Analytics.SearchConsoleData do
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

  actions do
    defaults([:read])

    create :create do
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
