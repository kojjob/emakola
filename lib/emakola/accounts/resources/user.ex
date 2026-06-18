defmodule Emakola.Accounts.User do
  @moduledoc "Platform staff user resource with AshAuthentication password sign-in (TOTP enforced at the web layer)."
  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("users")
    repo(Emakola.Repo)
  end

  authentication do
    tokens do
      enabled?(true)
      token_resource(Emakola.Accounts.Token)
      require_token_presence_for_authentication?(true)

      signing_secret(fn _, _ ->
        Application.fetch_env(:emakola, :token_signing_secret)
      end)
    end

    strategies do
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :email, :ci_string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 320)
    end

    attribute :hashed_password, :string do
      allow_nil?(true)
      sensitive?(true)
    end

    attribute(:name, :string, public?: true, constraints: [max_length: 255])

    attribute(:avatar_url, :string, public?: true, constraints: [max_length: 2_048])

    attribute(:preferences, :map, default: %{}, public?: true)

    attribute(:confirmed_at, :utc_datetime_usec, public?: true)

    attribute :is_owner, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
    end

    attribute :platform_permissions, {:array, :atom} do
      default([])
      allow_nil?(false)
      public?(true)
      constraints(items: [one_of: Emakola.Accounts.PlatformPermissions.all()])
    end

    attribute :totp_secret, :binary do
      allow_nil?(true)
      sensitive?(true)
    end

    attribute(:totp_last_used_at, :utc_datetime_usec)

    attribute(:deactivated_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  relationships do
    has_many :memberships, Emakola.Accounts.Membership

    many_to_many :organisations, Emakola.Accounts.Organisation do
      through(Emakola.Accounts.Membership)
    end
  end

  identities do
    identity(:unique_email, [:email])
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if(always())
    end

    bypass action(:register_with_password) do
      authorize_if(always())
    end

    bypass action_type(:read) do
      authorize_if(always())
    end

    policy action_type([:update, :destroy]) do
      authorize_if(expr(id == ^actor(:id)))
    end
  end

  changes do
    change(Emakola.Accounts.Changes.SendWelcomeEmail,
      on: [:create],
      where: [action_is(:register_with_password)]
    )
  end

  actions do
    defaults([:read])

    read :platform_staff do
      filter(expr(is_owner == true or platform_permissions != []))
    end

    create :accept_platform_invite do
      # Internal-only: invoked by Emakola.Accounts.PlatformTeam.accept_invite/2
      # after verifying a pending invite token. Never grants ownership —
      # is_owner keeps its false default.
      accept([:email, :name])

      argument :password, :string do
        allow_nil?(false)
        sensitive?(true)
        constraints(min_length: 8, max_length: 72)
      end

      argument :password_confirmation, :string do
        allow_nil?(false)
        sensitive?(true)
      end

      argument :platform_permissions, {:array, :atom} do
        default([])
        constraints(items: [one_of: Emakola.Accounts.PlatformPermissions.all()])
      end

      validate(confirm(:password, :password_confirmation))

      change(set_attribute(:confirmed_at, &DateTime.utc_now/0))
      change(set_attribute(:platform_permissions, arg(:platform_permissions)))

      change(fn changeset, _ctx ->
        case Ash.Changeset.fetch_argument(changeset, :password) do
          {:ok, password} when is_binary(password) ->
            Ash.Changeset.force_change_attribute(
              changeset,
              :hashed_password,
              Bcrypt.hash_pwd_salt(password)
            )

          _ ->
            changeset
        end
      end)
    end

    create :bootstrap_owner do
      # First platform owner, created out-of-band by
      # `mix emakola.bootstrap_platform_owner`. The generated
      # `register_with_password` action neither confirms the account nor
      # produces a sign-in-ready password for platform staff, so we hash the
      # password, confirm immediately, and grant ownership here.
      accept([:email])

      argument :password, :string do
        allow_nil?(false)
        sensitive?(true)
        constraints(min_length: 8, max_length: 72)
      end

      change(set_attribute(:is_owner, true))
      change(set_attribute(:confirmed_at, &DateTime.utc_now/0))

      change(fn changeset, _ctx ->
        case Ash.Changeset.fetch_argument(changeset, :password) do
          {:ok, password} when is_binary(password) ->
            Ash.Changeset.force_change_attribute(
              changeset,
              :hashed_password,
              Bcrypt.hash_pwd_salt(password)
            )

          _ ->
            changeset
        end
      end)
    end

    update :update_profile do
      accept([:name, :avatar_url, :preferences])
    end

    update :set_platform_permissions do
      require_atomic?(false)
      accept([:is_owner, :platform_permissions])

      validate(Emakola.Accounts.Validations.EnsureOwnerRemains)

      change(
        after_action(fn changeset, user, ctx ->
          Emakola.Accounts.PlatformAudit.log(:permissions_changed, ctx.actor, %{
            user_id: user.id,
            email: to_string(user.email),
            permissions: user.platform_permissions
          })

          if changeset.data.is_owner != user.is_owner do
            Emakola.Accounts.PlatformAudit.log(:owner_changed, ctx.actor, %{
              user_id: user.id,
              email: to_string(user.email),
              is_owner: user.is_owner
            })
          end

          {:ok, user}
        end)
      )
    end

    update :deactivate_staff do
      require_atomic?(false)
      accept([])

      change(set_attribute(:deactivated_at, &DateTime.utc_now/0))
      validate(Emakola.Accounts.Validations.EnsureOwnerRemains)

      change(
        after_action(fn _changeset, user, ctx ->
          Emakola.Accounts.PlatformAudit.log(:staff_deactivated, ctx.actor, %{
            user_id: user.id,
            email: to_string(user.email)
          })

          {:ok, user}
        end)
      )
    end

    update :reactivate_staff do
      require_atomic?(false)
      accept([])

      change(set_attribute(:deactivated_at, nil))

      change(
        after_action(fn _changeset, user, ctx ->
          Emakola.Accounts.PlatformAudit.log(:staff_reactivated, ctx.actor, %{
            user_id: user.id,
            email: to_string(user.email)
          })

          {:ok, user}
        end)
      )
    end

    update :setup_totp do
      require_atomic?(false)
      accept([])

      argument(:secret, :binary, allow_nil?: false, sensitive?: true)
      argument(:code, :string, allow_nil?: false, sensitive?: true)

      validate(Emakola.Accounts.Validations.ValidateTotpCode)

      change(set_attribute(:totp_secret, arg(:secret)))
      change(set_attribute(:totp_last_used_at, &DateTime.utc_now/0))

      change(
        after_action(fn _changeset, user, _ctx ->
          Emakola.Accounts.PlatformAudit.log(:totp_enabled, user)
          {:ok, user}
        end)
      )
    end

    update :record_totp_use do
      # Call with authorize?: false during login — no actor is established
      # until after TOTP succeeds. The update policy requires id == actor.id.
      accept([])

      change(set_attribute(:totp_last_used_at, &DateTime.utc_now/0))
    end

    update :clear_totp do
      require_atomic?(false)
      accept([])

      change(set_attribute(:totp_secret, nil))
      change(set_attribute(:totp_last_used_at, nil))

      change(
        after_action(fn _changeset, user, ctx ->
          # Actor is the acting admin when set (team-page reset); fall back
          # to the target for self-service / mix-task paths with no actor.
          Emakola.Accounts.PlatformAudit.log(:totp_disabled, ctx.actor || user, %{
            target_user_id: user.id,
            target_email: to_string(user.email)
          })

          {:ok, user}
        end)
      )
    end

    update :change_password do
      require_atomic?(false)
      accept([])

      argument(:current_password, :string, allow_nil?: false, sensitive?: true)
      argument(:password, :string, allow_nil?: false, sensitive?: true)
      argument(:password_confirmation, :string, allow_nil?: false, sensitive?: true)

      validate(confirm(:password, :password_confirmation))

      change(fn changeset, _ctx ->
        current = Ash.Changeset.get_argument(changeset, :current_password)
        user = changeset.data

        if Bcrypt.verify_pass(current, user.hashed_password) do
          hashed = Bcrypt.hash_pwd_salt(Ash.Changeset.get_argument(changeset, :password))
          Ash.Changeset.force_change_attribute(changeset, :hashed_password, hashed)
        else
          Ash.Changeset.add_error(changeset, field: :current_password, message: "is incorrect")
        end
      end)
    end

    destroy :destroy do
      primary?(true)
    end
  end
end
