defmodule Emakola.Accounts.Organisation do
  @moduledoc "Organisation (company or team) that owns one or more stores within the platform."
  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("organisations")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute(:logo_url, :string, public?: true, constraints: [max_length: 2_048])

    attribute(:billing_email, :string, public?: true, constraints: [max_length: 320])

    timestamps()
  end

  relationships do
    has_many :memberships, Emakola.Accounts.Membership

    many_to_many :users, Emakola.Accounts.User do
      through(Emakola.Accounts.Membership)
    end
  end

  identities do
    identity(:unique_slug, [:slug])
  end

  policies do
    # Reads are open (needed for internal lookups)
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Creates are open (onboarding creates organisations)
    bypass action_type(:create) do
      authorize_if(always())
    end

    # Users can only modify organisations they belong to
    policy action_type([:update, :destroy]) do
      authorize_if(expr(exists(memberships, user_id == ^actor(:id))))
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:name, :billing_email, :logo_url])

      change(fn changeset, _ctx ->
        case Ash.Changeset.get_attribute(changeset, :name) do
          nil ->
            changeset

          name ->
            slug =
              name
              |> String.downcase()
              |> String.replace(~r/[^a-z0-9]+/, "-")
              |> String.trim("-")

            Ash.Changeset.change_attribute(changeset, :slug, slug)
        end
      end)
    end

    update :update do
      accept([:name, :billing_email, :logo_url])
    end

    destroy :destroy do
      primary?(true)
    end
  end
end
