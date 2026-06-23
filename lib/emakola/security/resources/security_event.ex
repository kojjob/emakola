defmodule Emakola.Security.SecurityEvent do
  @moduledoc """
  A persisted security/abuse event — rate-limit exceedances and failed sign-ins.

  Platform-owned (not tenant-scoped); fed by `Emakola.Security.record/1` from the
  rate-limiter plug and the auth flows, and surfaced by the abuse monitor. Writes
  are internal (`authorize?: false`); reads bypass authorization for the gated
  platform admin.
  """
  use Ash.Resource,
    domain: Emakola.Security,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("security_events")
    repo(Emakola.Repo)

    custom_indexes do
      index([:inserted_at])
      index([:ip])
      index([:event_type])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :event_type, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:rate_limit_exceeded, :auth_failed])
    end

    attribute :subject_type, :atom do
      allow_nil?(false)
      default(:anonymous)
      public?(true)
      constraints(one_of: [:merchant, :customer, :platform, :anonymous])
    end

    attribute(:identifier, :string, public?: true)
    attribute(:ip, :string, public?: true)
    attribute(:path, :string, public?: true)

    attribute :metadata, :map do
      default(%{})
      public?(true)
    end

    create_timestamp(:inserted_at)
  end

  policies do
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    policy action_type([:create]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :record do
      accept([:event_type, :subject_type, :identifier, :ip, :path, :metadata])
    end

    read :recent do
      prepare(build(sort: [inserted_at: :desc], limit: 50))
    end
  end
end
