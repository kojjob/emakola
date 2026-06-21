defmodule Emakola.Customers.Customer do
  @moduledoc """
  Customer resource — store-scoped customer accounts.

  Each store maintains its own customer list. The same email can exist across
  different stores but must be unique within a single store.

  Used for order attribution, repeat-purchase tracking, and customer communications.
  Supports find-or-create for automatic customer resolution at checkout.
  """

  use Ash.Resource,
    domain: Emakola.Customers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    tokens do
      enabled?(true)
      token_resource(Emakola.Customers.CustomerToken)
      require_token_presence_for_authentication?(true)

      signing_secret(fn _, _ ->
        Application.fetch_env(:emakola, :token_signing_secret)
      end)
    end

    strategies do
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
        register_action_name(:register_with_password)
        sign_in_action_name(:sign_in_with_password)
      end

      # Storefront social login. No identity_resource on purpose: the per-store
      # Customer is found/created by the upsert action keyed on
      # :unique_store_email (store_id from the request tenant).
      # AshAuthentication.UserIdentity has no multitenancy support, so an
      # identity table would make the same social account ambiguous across
      # stores. prevent_hijacking? false — same debt as the merchant strategies
      # (no email-confirmation flow yet).
      google :google do
        client_id(fn _, _ -> Emakola.OAuthConfig.fetch(:google, :client_id) end)
        client_secret(fn _, _ -> Emakola.OAuthConfig.fetch(:google, :client_secret) end)
        redirect_uri(fn _, _ -> Emakola.OAuthConfig.redirect_uri() end)
        register_action_name(:register_with_oauth2)
        sign_in_action_name(:sign_in_with_oauth2)
        prevent_hijacking?(false)
      end

      oauth2 :facebook do
        client_id(fn _, _ -> Emakola.OAuthConfig.fetch(:facebook, :client_id) end)
        client_secret(fn _, _ -> Emakola.OAuthConfig.fetch(:facebook, :client_secret) end)
        redirect_uri(fn _, _ -> Emakola.OAuthConfig.redirect_uri() end)
        base_url("https://graph.facebook.com/v18.0")
        authorize_url("https://www.facebook.com/v18.0/dialog/oauth")
        token_url("https://graph.facebook.com/v18.0/oauth/access_token")
        user_url("https://graph.facebook.com/me?fields=id,name,email")
        authorization_params(scope: "email public_profile")
        register_action_name(:register_with_oauth2)
        sign_in_action_name(:sign_in_with_oauth2)
        prevent_hijacking?(false)
      end

      apple :apple do
        client_id(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :client_id) end)
        team_id(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :team_id) end)
        private_key_id(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :private_key_id) end)
        private_key_path(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :private_key_path) end)
        redirect_uri(fn _, _ -> Emakola.OAuthConfig.redirect_uri() end)
        register_action_name(:register_with_oauth2)
        sign_in_action_name(:sign_in_with_oauth2)
        prevent_hijacking?(false)
      end
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("customers")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :email, :ci_string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 320)
    end

    attribute :name, :string do
      public?(true)
      constraints(max_length: 255)
    end

    attribute :phone, :string do
      public?(true)
      constraints(max_length: 20)
    end

    attribute :tags, {:array, :string} do
      default([])
      public?(true)
    end

    attribute :hashed_password, :string do
      allow_nil?(true)
      sensitive?(true)
    end

    attribute :last_order_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    has_many :addresses, Emakola.Customers.Address
    has_many :notes, Emakola.Customers.CustomerNote
    has_many :orders, Emakola.Orders.Order
  end

  aggregates do
    count(:order_count, :orders)
    count(:total_orders, :orders)
    sum(:total_spent, :orders, :total)
  end

  identities do
    identity(:unique_store_email, [:store_id, :email])
    # Required by AshAuthentication password strategy; real uniqueness is
    # enforced by the composite :unique_store_email identity above.
    identity(:unique_email, [:email])
  end

  policies do
    # Authentication interactions (login, register, etc.) always allowed
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if(always())
    end

    # Registration allowed without actor (factory/internal calls)
    bypass action(:register_with_password) do
      authorize_if(always())
    end

    # Generic actions (action :name) — internal helpers like find_or_create
    # invoked from unauthenticated checkout. The action's run/3 calls
    # `Ash.create(authorize?: false)` internally for the actual write.
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Creates require Merchant with store access. CheckoutService customer
    # creation and webhook handlers opt in via `authorize?: false`.
    policy action_type(:create) do
      forbid_unless(actor_present())
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Merchant actors: verify store membership (for reads + writes)
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Customer actors: self-read only — a customer can only read their own record
    # within their store. Direct list/search queries use authorize?: false.
    policy actor_attribute_equals(:__struct__, Emakola.Customers.Customer) do
      authorize_if(expr(id == ^actor(:id) and store_id == ^actor(:store_id)))
    end

    # nil actor on writes falls through to default-deny. System code must
    # opt in with `authorize?: false`.
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:email, :name, :phone, :store_id, :tags])
    end

    create :register_with_password do
      accept([:email, :store_id, :name, :phone])

      argument(:password, :string,
        allow_nil?: false,
        sensitive?: true,
        constraints: [min_length: 8]
      )

      argument(:password_confirmation, :string,
        allow_nil?: false,
        sensitive?: true
      )

      validate(AshAuthentication.Strategy.Password.PasswordConfirmationValidation)
      change(AshAuthentication.Strategy.Password.HashPasswordChange)
      change(AshAuthentication.GenerateTokenChange)
    end

    # Shared by all storefront OAuth strategies. store_id is set from the request
    # tenant (multitenancy :attribute), so the upsert on :unique_store_email
    # finds-or-creates the customer within the right store. The provider comes
    # from the auth context. registration_enabled? defaults true, so this upsert
    # handles both new and returning customers (sign_in_with_oauth2 is required
    # to exist but unused).
    create :register_with_oauth2 do
      upsert?(true)
      upsert_identity(:unique_store_email)
      upsert_fields([])
      accept([])

      argument(:user_info, :map, allow_nil?: false)
      argument(:oauth_tokens, :map, allow_nil?: false)

      change(AshAuthentication.GenerateTokenChange)

      change(fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info) || %{}

        changeset
        |> Ash.Changeset.change_attribute(:email, user_info["email"])
        |> Ash.Changeset.change_attribute(:name, user_info["name"])
      end)
    end

    read :sign_in_with_oauth2 do
      argument(:user_info, :map, allow_nil?: false)
      argument(:oauth_tokens, :map, allow_nil?: false)

      prepare(AshAuthentication.Strategy.OAuth2.SignInPreparation)
    end

    update :update do
      require_atomic?(false)
      accept([:name, :phone, :tags])
    end

    update :touch_last_order do
      require_atomic?(false)
      accept([])

      change(set_attribute(:last_order_at, &DateTime.utc_now/0))
    end

    action :find_or_create, :struct do
      constraints(instance_of: __MODULE__)

      argument :email, :ci_string do
        allow_nil?(false)
      end

      argument :store_id, :uuid do
        allow_nil?(false)
      end

      argument(:name, :string)
      argument(:phone, :string)

      run(Emakola.Customers.Actions.FindOrCreateCustomer)
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([:order_count])
      end)
    end

    read :search do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:query, :string, allow_nil?: false)

      prepare(Emakola.Customers.Preparations.SearchCustomers)
      prepare(build(load: [:order_count]))
    end

    read :get_by_id do
      get?(true)
      argument(:id, :uuid, allow_nil?: false)

      filter(expr(id == ^arg(:id)))
    end

    read :by_store_in_period do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:from, :utc_datetime, allow_nil?: false)
      argument(:to, :utc_datetime, allow_nil?: false)

      filter(
        expr(
          store_id == ^arg(:store_id) and
            inserted_at >= ^arg(:from) and
            inserted_at < ^arg(:to)
        )
      )
    end
  end
end
