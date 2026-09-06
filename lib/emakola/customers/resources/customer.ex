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

    add_ons do
      # Arms prevent_hijacking? below. Deliberately minimal for customers:
      # confirm_on_create? false because there is no per-store-branded customer
      # email flow yet — so a password-registered customer simply stays
      # unconfirmed, which is the SAFE state (an OAuth login can never absorb
      # their account; they keep signing in with their password). Pure-OAuth
      # customers auto-confirm (the provider verified the address) and are
      # unaffected. When store-branded customer email lands, flip
      # confirm_on_create? and give the sender a real mailer.
      confirmation :confirm_new_customer do
        monitor_fields([:email])
        confirm_on_create?(false)
        confirm_on_update?(false)
        # No links are ever emailed (see above), but the library rightly
        # refuses GET-confirmable tokens outright, so this is set regardless.
        require_interaction?(true)
        auto_confirm_actions([:register_with_oauth2])
        sender(Emakola.Customers.Senders.LogOnlyConfirmationSender)
      end
    end

    strategies do
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
        register_action_name(:register_with_password)
        sign_in_action_name(:sign_in_with_password)
      end

      # Storefront social login. The identity resource is per-store: Ash scopes
      # an identity on a multitenant resource to the tenant by default
      # (all_tenants?: false), so the extension's (uid, strategy) becomes
      # (store_id, uid, strategy). The same Google account is therefore a
      # different customer at every shop, which is what a shopper needs and the
      # opposite of the merchant rule. See CustomerIdentity for why.
      #
      # prevent_hijacking? true — armed by the confirmation add-on above.
      google :google do
        client_id(fn _, _ -> Emakola.OAuthConfig.fetch(:google, :client_id) end)
        client_secret(fn _, _ -> Emakola.OAuthConfig.fetch(:google, :client_secret) end)
        redirect_uri(fn _, _ -> Emakola.OAuthConfig.redirect_uri() end)
        register_action_name(:register_with_oauth2)
        sign_in_action_name(:sign_in_with_oauth2)
        identity_resource(Emakola.Customers.CustomerIdentity)
        prevent_hijacking?(true)
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
        identity_resource(Emakola.Customers.CustomerIdentity)
        prevent_hijacking?(true)
      end

      apple :apple do
        client_id(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :client_id) end)
        team_id(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :team_id) end)
        private_key_id(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :private_key_id) end)
        private_key_path(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :private_key_path) end)
        redirect_uri(fn _, _ -> Emakola.OAuthConfig.redirect_uri() end)
        register_action_name(:register_with_oauth2)
        sign_in_action_name(:sign_in_with_oauth2)
        identity_resource(Emakola.Customers.CustomerIdentity)
        prevent_hijacking?(true)
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

    # Optional on purpose. Most buyers in this market do not use email, and
    # requiring it made phone-first signup impossible — the WhatsApp flow had
    # to ask for an address the buyer did not have. Reachability is enforced
    # instead by ContactDetailPresent on the create actions: a customer must
    # have a phone or an email, so the shop can always reach them.
    attribute :email, :ci_string do
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

    # Set when a customer asks to stop receiving marketing messages. A stamp
    # rather than a boolean so the date is auditable — every SMS costs the
    # merchant money, and "when did they opt out" is the question that
    # settles a dispute. nil means never opted out.
    attribute :marketing_opt_out_at, :utc_datetime_usec do
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
    has_many :returns, Emakola.Orders.Return
  end

  aggregates do
    count(:order_count, :orders)
    count(:total_orders, :orders)
    sum(:total_spent, :orders, :total)

    # Money that arrived. Pending is not yet money; cancelled never was.
    sum :paid_total, :orders, :total do
      filter(expr(status in [:confirmed, :processing, :shipped, :delivered]))
    end

    count :paid_order_count, :orders do
      filter(expr(status in [:confirmed, :processing, :shipped, :delivered]))
    end

    count :cancelled_order_count, :orders do
      filter(expr(status == :cancelled))
    end

    count(:returns_count, :returns)

    min :first_paid_order_at, :orders, :inserted_at do
      filter(expr(status in [:confirmed, :processing, :shipped, :delivered]))
    end

    # last_order_at (below) is touched by CheckoutService on EVERY checkout,
    # paid or not — so a customer who abandoned a checkout yesterday but last
    # PAID 90 days ago would not read as "gone quiet" against it. This is the
    # aggregate that segment actually needs.
    max :last_paid_order_at, :orders, :inserted_at do
      filter(expr(status in [:confirmed, :processing, :shipped, :delivered]))
    end
  end

  identities do
    identity(:unique_store_email, [:store_id, :email])
    # Required by AshAuthentication password strategy; real uniqueness is
    # enforced by the composite :unique_store_email identity above.
    identity(:unique_email, [:email])
    identity(:unique_store_phone, [:store_id, :phone])
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

    # Backfill only — no live actor may call this, not even the customer's
    # own record. The backfill itself runs with authorize?: false and never
    # has an actor.
    policy action(:backdate_last_order) do
      forbid_if(always())
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
      validate(Emakola.Customers.Validations.ContactDetailPresent)
    end

    # Opting out is its own intent, not a field edit — widening :update to
    # accept the stamp would let any customer edit clear it by omission.
    update :opt_out_of_marketing do
      change(set_attribute(:marketing_opt_out_at, &DateTime.utc_now/0))
    end

    update :opt_in_to_marketing do
      change(set_attribute(:marketing_opt_out_at, nil))
    end

    # Passwordless, store-scoped registration via verified phone. store_id comes
    # from the request tenant (multitenancy :attribute).
    create :register_with_phone do
      accept([:email, :name, :phone])
      validate(Emakola.Customers.Validations.ContactDetailPresent)
      validate(Emakola.Customers.Validations.NotPlaceholderEmail)
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
      validate(Emakola.Customers.Validations.NotPlaceholderEmail)
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

      # Records the provider's iss/sub against this store's customer. The tenant
      # rides along from the changeset, so the identity lands scoped to the shop
      # the shopper is signing in to.
      change(AshAuthentication.Strategy.OAuth2.IdentityChange)

      change(fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info) || %{}

        changeset
        |> Ash.Changeset.change_attribute(:email, user_info["email"])
        |> Ash.Changeset.change_attribute(:name, user_info["name"])
      end)

      validate(Emakola.Customers.Validations.NotPlaceholderEmail)
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

    # Backfill only: a historical order must not stamp "now".
    update :backdate_last_order do
      accept([:last_order_at])
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

      # An unverified caller (default) must never bind a stranger's guest
      # checkout to an existing account that holds credentials — see
      # FindOrCreateCustomer. Only the signed-in path (which uses
      # customer_id directly, never this action) knows the phone/email is
      # really that customer's, so callers pass true only there.
      argument(:verified?, :boolean, default: false)

      run(Emakola.Customers.Actions.FindOrCreateCustomer)
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([:order_count, :paid_total, :paid_order_count])
      end)
    end

    read :search do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:query, :string, allow_nil?: false)

      prepare(Emakola.Customers.Preparations.SearchCustomers)
      prepare(build(load: [:order_count, :paid_total, :paid_order_count]))
    end

    # How many customers bought more than once. Aggregates are filterable.
    read :bought_again_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id) and paid_order_count >= 2))
    end

    read :get_by_id do
      get?(true)
      argument(:id, :uuid, allow_nil?: false)

      filter(expr(id == ^arg(:id)))
    end

    # Store-scoped single-customer read. Customer is `global?(true)`, so the
    # id-only `get_by_id` above spans every store — admin pages MUST use this and
    # pass the merchant's current store, or a merchant could read/edit another
    # store's customer by id (IDOR).
    read :get_by_id_for_store do
      get?(true)
      argument(:id, :uuid, allow_nil?: false)
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(id == ^arg(:id) and store_id == ^arg(:store_id)))
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
