defmodule Emakola.Accounts.PlatformInvite do
  @moduledoc """
  Invitation for a new platform staff member.

  The invite email carries a raw token; only its SHA-256 hex digest is
  stored (`token_hash`), so a database leak cannot be replayed into an
  account. Invites expire after 7 days and are single-use. Invites never
  grant ownership — `is_owner` stays false on the accepted account.

  `invited_by_id` is a plain UUID (no FK) so invites survive staff
  deletion, consistent with the platform audit log. No destroy action —
  invites are revoked, never deleted.
  """

  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer

  alias Emakola.Accounts.PlatformAudit

  postgres do
    table("platform_invites")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :email, :ci_string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 320)
    end

    attribute :permissions, {:array, :atom} do
      default([])
      allow_nil?(false)
      public?(true)
      constraints(items: [one_of: Emakola.Accounts.PlatformPermissions.all()])
    end

    attribute :token_hash, :string do
      allow_nil?(false)
      sensitive?(true)
    end

    attribute :invited_by_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil?(false)
    end

    attribute(:accepted_at, :utc_datetime_usec, public?: true)
    attribute(:revoked_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  identities do
    identity(:unique_token_hash, [:token_hash])
  end

  actions do
    defaults([:read])

    create :create do
      accept([:email, :permissions, :invited_by_id])

      validate(Emakola.Accounts.Validations.InviteEmailAvailable)

      change(Emakola.Accounts.Changes.GeneratePlatformInviteToken)

      change(
        after_action(fn _changeset, invite, _ctx ->
          PlatformAudit.log(:invite_created, invite.invited_by_id, %{
            email: to_string(invite.email),
            permissions: invite.permissions
          })

          {:ok, invite}
        end)
      )
    end

    read :pending_by_token_hash do
      get?(true)
      argument(:token_hash, :string, allow_nil?: false)

      filter(
        expr(
          token_hash == ^arg(:token_hash) and is_nil(accepted_at) and is_nil(revoked_at) and
            expires_at > now()
        )
      )
    end

    read :list_open do
      filter(expr(is_nil(accepted_at) and is_nil(revoked_at)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    update :accept do
      require_atomic?(false)
      accept([])

      change(set_attribute(:accepted_at, &DateTime.utc_now/0))

      change(
        after_action(fn _changeset, invite, _ctx ->
          PlatformAudit.log(:invite_accepted, nil, %{email: to_string(invite.email)})
          {:ok, invite}
        end)
      )
    end

    update :revoke do
      require_atomic?(false)
      accept([])

      change(set_attribute(:revoked_at, &DateTime.utc_now/0))

      change(
        after_action(fn _changeset, invite, ctx ->
          PlatformAudit.log(:invite_revoked, ctx.actor, %{email: to_string(invite.email)})
          {:ok, invite}
        end)
      )
    end
  end
end
