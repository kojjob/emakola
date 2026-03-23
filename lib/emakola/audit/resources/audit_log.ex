defmodule Emakola.Audit.AuditLog do
  @moduledoc """
  Immutable audit log resource for GDPR/SOC2 compliance.

  Records all significant actions in the system. Audit logs are append-only:
  no update or destroy actions are defined, ensuring tamper-proof records.
  """

  use Ash.Resource,
    domain: Emakola.Audit,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("audit_logs")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :action, :atom do
      constraints(
        one_of: [
          :create,
          :update,
          :delete,
          :login,
          :logout,
          :invite,
          :role_change,
          :subscription_change,
          :api_key_created,
          :api_key_revoked,
          :settings_changed,
          :export_requested
        ]
      )

      allow_nil?(false)
      public?(true)
    end

    attribute :resource_type, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :resource_id, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :actor_id, :uuid do
      allow_nil?(true)
      public?(true)
    end

    attribute :organisation_id, :uuid do
      allow_nil?(true)
      public?(true)
    end

    attribute :changes, :map do
      default(%{})
      public?(true)
    end

    attribute :metadata, :map do
      default(%{})
      public?(true)
    end

    attribute :ip_address, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 45)
    end

    attribute :user_agent, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 1_000)
    end

    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :action,
        :resource_type,
        :resource_id,
        :actor_id,
        :organisation_id,
        :changes,
        :metadata,
        :ip_address,
        :user_agent
      ])
    end

    read :by_resource do
      argument(:resource_type, :string, allow_nil?: false)
      argument(:resource_id, :string, allow_nil?: false)

      filter(expr(resource_type == ^arg(:resource_type) and resource_id == ^arg(:resource_id)))
    end

    read :by_actor do
      argument(:actor_id, :uuid, allow_nil?: false)

      filter(expr(actor_id == ^arg(:actor_id)))
    end

    read :by_organisation do
      argument(:organisation_id, :uuid, allow_nil?: false)

      filter(expr(organisation_id == ^arg(:organisation_id)))
    end
  end
end
