defmodule Emakola.Accounts.UserSession do
  @moduledoc """
  DB-backed session row for platform staff.

  The browser cookie holds a Phoenix.Token-signed session id (see
  `EmakolaWeb.AuthTokens.sign_platform_session/1`); the row makes the
  session unforgeable and revocable. Lifecycle rules (idle timeout, touch
  granularity, revocation auditing) live in `Emakola.Accounts.Sessions`.
  """

  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("user_sessions")
    repo(Emakola.Repo)

    references do
      reference(:user, index?: true)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :ip, :string do
      public?(true)
      constraints(max_length: 45)
    end

    attribute :user_agent, :string do
      public?(true)
      constraints(max_length: 500)
    end

    attribute :last_seen_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
    end

    attribute(:revoked_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :user, Emakola.Accounts.User do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:user_id, :ip, :user_agent])

      change(set_attribute(:last_seen_at, &DateTime.utc_now/0))
    end

    update :touch do
      require_atomic?(false)
      accept([])

      change(set_attribute(:last_seen_at, &DateTime.utc_now/0))
    end

    update :revoke do
      require_atomic?(false)
      accept([])

      change(set_attribute(:revoked_at, &DateTime.utc_now/0))
    end

    read :list_active_for_user do
      argument(:user_id, :uuid, allow_nil?: false)

      filter(expr(user_id == ^arg(:user_id) and is_nil(revoked_at)))
      prepare(build(sort: [last_seen_at: :desc]))
    end
  end
end
