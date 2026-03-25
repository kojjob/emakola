defmodule Emakola.Analytics.AppEvent do
  use Ash.Resource,
    domain: Emakola.Analytics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("app_events")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :event_name, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute(:actor_id, :uuid, public?: true)
    attribute(:organisation_id, :uuid, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)

    attribute :occurred_at, :utc_datetime do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :create do
      accept([:event_name, :actor_id, :organisation_id, :metadata, :occurred_at])
    end

    read :by_organisation do
      argument(:organisation_id, :uuid, allow_nil?: false)
      filter(expr(organisation_id == ^arg(:organisation_id)))
    end

    read :by_event_name do
      argument(:event_name, :string, allow_nil?: false)
      filter(expr(event_name == ^arg(:event_name)))
    end
  end
end
