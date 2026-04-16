defmodule Emakola.Accounts.User do
  @moduledoc "User resource with AshAuthentication supporting email/password and magic-link sign-in."
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

      magic_link do
        identity_field(:email)
        require_interaction?(true)

        sender(Emakola.Accounts.Senders.MagicLinkSender)
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

    attribute :is_platform_admin, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
    end

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

    bypass always() do
      authorize_unless(actor_present())
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

    update :update_profile do
      accept([:name, :avatar_url, :preferences])
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
