defmodule Emakola.Accounts.Merchant do
  @moduledoc "Merchant actor resource used as the principal for Ash authorization policy checks."
  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("merchants")
    repo(Emakola.Repo)
  end

  authentication do
    tokens do
      enabled?(true)
      token_resource(Emakola.Accounts.Token)
      store_all_tokens?(true)
      require_token_presence_for_authentication?(true)

      signing_secret(fn _, _ ->
        Application.fetch_env(:emakola, :token_signing_secret)
      end)
    end

    add_ons do
      # Arms prevent_hijacking? on every OAuth strategy below: registration via
      # a provider is an UPSERT on :unique_email (that is how "link my Google"
      # works), and without confirmed-ness to check, that upsert doubles as an
      # account takeover of any unconfirmed password account. Sign-in is NOT
      # gated on confirmation — an unconfirmed account is already safe (it
      # cannot be OAuth-linked), and prod email delivery may be down.
      confirmation :confirm_new_merchant do
        monitor_fields([:email])
        confirm_on_create?(true)
        confirm_on_update?(true)
        # A bare GET must not confirm (mail scanners prefetch links); the
        # /confirm/merchant page renders a button that POSTs the token.
        require_interaction?(true)
        # Proof of mailbox ownership is proof enough: magic-link sign-in and
        # provider-verified OAuth emails confirm without a second round trip.
        auto_confirm_actions([:sign_in_with_magic_link, :register_with_oauth2])
        sender(Emakola.Accounts.Senders.ConfirmationSender)
      end
    end

    strategies do
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)

        resettable do
          sender(Emakola.Accounts.Senders.PasswordResetSender)
          # 24h: short enough to bound the risk window, long enough for flaky
          # mobile email delivery. AuthMailer.password_reset copy must match.
          token_lifetime({24, :hours})
        end
      end

      magic_link do
        identity_field(:email)
        require_interaction?(true)

        sender(Emakola.Accounts.Senders.MagicLinkSender)
      end

      # Social login. Secrets resolve at runtime from Emakola.OAuthConfig, so a
      # provider stays inert (ship-dark) until its credentials are set — the
      # matching button is hidden by EmakolaWeb.OAuth in the meantime.
      google :google do
        client_id(fn _, _ -> Emakola.OAuthConfig.fetch(:google, :client_id) end)
        client_secret(fn _, _ -> Emakola.OAuthConfig.fetch(:google, :client_secret) end)
        redirect_uri(fn _, _ -> Emakola.OAuthConfig.redirect_uri() end)
        identity_resource(Emakola.Accounts.MerchantIdentity)
        register_action_name(:register_with_oauth2)
        sign_in_action_name(:sign_in_with_oauth2)
        # See the prevent_hijacking? note on :facebook — armed the same way.
        prevent_hijacking?(true)
      end

      # Facebook has no built-in strategy — generic oauth2 against the Graph API.
      # The exact endpoints/scopes should be confirmed against the Meta app
      # during setup; this stays dark until FACEBOOK_* is configured.
      oauth2 :facebook do
        client_id(fn _, _ -> Emakola.OAuthConfig.fetch(:facebook, :client_id) end)
        client_secret(fn _, _ -> Emakola.OAuthConfig.fetch(:facebook, :client_secret) end)
        redirect_uri(fn _, _ -> Emakola.OAuthConfig.redirect_uri() end)
        base_url("https://graph.facebook.com/v18.0")
        authorize_url("https://www.facebook.com/v18.0/dialog/oauth")
        token_url("https://graph.facebook.com/v18.0/oauth/access_token")
        user_url("https://graph.facebook.com/me?fields=id,name,email")
        authorization_params(scope: "email public_profile")
        identity_resource(Emakola.Accounts.MerchantIdentity)
        # Armed by the confirmation add-on above: an OAuth login can only link
        # to an email whose account is CONFIRMED — an unconfirmed password
        # account (which anyone could have registered with someone else's
        # email) can never be absorbed or taken over via a provider login.
        prevent_hijacking?(true)
        register_action_name(:register_with_oauth2)
        sign_in_action_name(:sign_in_with_oauth2)
      end

      # Apple needs a paid Apple Developer account + a .p8 signing key on disk
      # (APPLE_PRIVATE_KEY_PATH); stays dark until those exist.
      apple :apple do
        client_id(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :client_id) end)
        team_id(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :team_id) end)
        private_key_id(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :private_key_id) end)
        private_key_path(fn _, _ -> Emakola.OAuthConfig.fetch(:apple, :private_key_path) end)
        redirect_uri(fn _, _ -> Emakola.OAuthConfig.redirect_uri() end)
        identity_resource(Emakola.Accounts.MerchantIdentity)
        register_action_name(:register_with_oauth2)
        sign_in_action_name(:sign_in_with_oauth2)
        # See the prevent_hijacking? note on :facebook — armed the same way.
        prevent_hijacking?(true)
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

    # Browser sessions are signed Phoenix.Token subjects, not rows we can
    # delete — verifying one only proves the signature. Bumping this cutoff
    # invalidates every session token issued before it, which is what makes
    # "password reset signs you out everywhere" true for the web path.
    attribute :sessions_valid_from, :utc_datetime do
      allow_nil?(true)
      sensitive?(true)
    end

    attribute(:name, :string, public?: true, constraints: [max_length: 255])

    attribute(:phone, :string, public?: true, constraints: [max_length: 20])

    # When this phone was last proven by a one-time code. `PhoneAuth` proved
    # phones already, but nothing durable recorded it — "verified" lived only
    # as a socket assign that vanished with the connection. Cleared whenever
    # the phone changes, so it can never vouch for a number nobody answered.
    attribute(:phone_verified_at, :utc_datetime_usec, public?: true)

    attribute(:business_name, :string, public?: true, constraints: [max_length: 255])

    attribute(:avatar_url, :string, public?: true, constraints: [max_length: 2_048])

    attribute(:preferences, :map, default: %{}, public?: true)

    attribute(:confirmed_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  relationships do
    has_many :store_memberships, Emakola.Accounts.StoreMembership

    many_to_many :stores, Emakola.Stores.Store do
      through(Emakola.Accounts.StoreMembership)
    end
  end

  aggregates do
    # Sorting the platform queue by "most stores" has to happen in the database
    # now that the page reads a screen at a time rather than the whole table.
    count(:stores_count, :stores)
  end

  identities do
    identity(:unique_email, [:email])
    # Phone is a login method (WhatsApp/SMS OTP); nullable, so Postgres allows
    # many email-only rows (multiple NULLs) — only set phones must be unique.
    identity(:unique_phone, [:phone])
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

    # Reads are open (needed for internal lookups, auth flows)
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Merchants can update/destroy only their own records
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

    # Passwordless registration via verified phone (WhatsApp/SMS OTP). The phone
    # is already OTP-verified by PhoneAuth; email is collected once in the UI.
    create :register_with_phone do
      accept([:email, :name, :phone])
      change(set_attribute(:confirmed_at, &DateTime.utc_now/0))
      change(set_attribute(:phone_verified_at, &DateTime.utc_now/0))
    end

    # Shared by all OAuth strategies (google/facebook/apple). ash_authentication
    # passes the provider in the action context, so OAuth2.IdentityChange records
    # the right strategy. Links to an existing merchant by verified email.
    create :register_with_oauth2 do
      description("Register or link a merchant from a social-login provider.")
      upsert?(true)
      upsert_identity(:unique_email)
      upsert_fields([])
      accept([])

      argument(:user_info, :map, allow_nil?: false)
      argument(:oauth_tokens, :map, allow_nil?: false)

      change(AshAuthentication.GenerateTokenChange)
      change(AshAuthentication.Strategy.OAuth2.IdentityChange)

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

    read :list_for_admin do
      argument(:search, :string, default: "")

      argument(:confirmation, :atom,
        default: :all,
        constraints: [one_of: [:all, :confirmed, :unconfirmed]]
      )

      # The platform queue reads one screen at a time. `required?: false` keeps
      # the unpaginated callers — which ask for a whole small set on purpose —
      # returning a plain list.
      pagination(offset?: true, countable: true, default_limit: 25, required?: false)

      filter(
        expr(
          (is_nil(^arg(:search)) or ^arg(:search) == "" or
             ilike(name, ^arg(:search)) or ilike(email, ^arg(:search)) or
             ilike(business_name, ^arg(:search)) or ilike(phone, ^arg(:search))) and
            (^arg(:confirmation) == :all or
               (^arg(:confirmation) == :confirmed and not is_nil(confirmed_at)) or
               (^arg(:confirmation) == :unconfirmed and is_nil(confirmed_at)))
        )
      )

      # No default sort: the caller picks one, and a default here would win
      # ahead of it.
      prepare(build(load: [:stores, :stores_count]))
    end

    # Changing the phone drops its proof. Without this a merchant could
    # register with a number they proved, then quietly swap in one they never
    # answered and keep the verified stamp.
    update :update_profile do
      require_atomic?(false)
      accept([:name, :avatar_url, :preferences, :phone, :business_name])

      change(fn changeset, _context ->
        if Ash.Changeset.changing_attribute?(changeset, :phone) do
          Ash.Changeset.force_change_attribute(changeset, :phone_verified_at, nil)
        else
          changeset
        end
      end)
    end

    # Moves the session cutoff to now, killing every browser session token
    # issued before this instant. Paired with token revocation after a
    # password reset — see `Emakola.Accounts.revoke_all_sessions_for/1`.
    update :invalidate_sessions do
      accept([])

      change(set_attribute(:sessions_valid_from, &DateTime.utc_now/0))
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
