defmodule Emakola.Accounts.PlatformAuditLog do
  @moduledoc """
  Append-only audit log for platform-staff security events.

  Records sign-ins, TOTP events, invites, permission changes, and session
  revocations for platform administrators. No update or destroy actions are
  defined, ensuring tamper-proof records. Deliberately separate from the
  merchant-side `Emakola.Audit` domain.

  `actor_id` is a plain UUID rather than a foreign key so log entries
  survive user deletion (and failed sign-ins have no actor at all).
  """

  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("platform_audit_logs")
    repo(Emakola.Repo)

    custom_indexes do
      index([:inserted_at, :id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :actor_id, :uuid do
      allow_nil?(true)
      public?(true)
    end

    attribute :action, :atom do
      constraints(
        one_of: [
          :sign_in_succeeded,
          :sign_in_failed,
          :totp_failed,
          :totp_enabled,
          :invite_created,
          :invite_accepted,
          :invite_revoked,
          :permissions_changed,
          :owner_changed,
          :session_revoked,
          :sessions_force_revoked,
          :staff_deactivated,
          :staff_reactivated,
          :sign_out
        ]
      )

      allow_nil?(false)
      public?(true)
    end

    attribute :metadata, :map do
      default(%{})
      public?(true)
    end

    attribute :ip, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 45)
    end

    create_timestamp(:inserted_at)
  end

  actions do
    create :create do
      accept([:actor_id, :action, :metadata, :ip])
    end

    read :list do
      pagination(keyset?: true, default_limit: 50, max_page_size: 200)
      prepare(build(sort: [inserted_at: :desc, id: :desc]))
    end
  end
end
