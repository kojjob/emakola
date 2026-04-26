defmodule Emakola.Accounts do
  @moduledoc "Accounts domain — users, merchants, organisations, and authentication."
  use Ash.Domain

  resources do
    resource Emakola.Accounts.User do
      define(:register_with_password, args: [:email, :password, :password_confirmation])
      define(:sign_in_with_password, args: [:email, :password])
      define(:request_magic_link, args: [:email])
      define(:get_user_by_id, action: :read, get_by: [:id])
    end

    resource Emakola.Accounts.Organisation do
      define(:create_organisation, action: :create, args: [:name])
      define(:get_organisation, action: :read, get_by: [:id])
    end

    resource Emakola.Accounts.Membership do
      define(:create_membership, action: :create)
      define(:list_memberships, action: :read)
    end

    resource(Emakola.Accounts.Merchant)

    # Store resource moved to Emakola.Stores on 2026-04-26.
    # See docs/PLAN-domain-restructuring-2026-04-26.md Step 3.

    resource Emakola.Accounts.StoreMembership do
      define(:create_store_membership, action: :create)
    end

    resource(Emakola.Accounts.Token)
  end
end
