defmodule Emakola.Accounts do
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

    resource Emakola.Accounts.Store do
      define(:create_store, action: :create)
      define(:get_store, action: :read, get_by: [:id])
      define(:update_store_settings, action: :update_settings)
    end

    resource Emakola.Accounts.StoreMembership do
      define(:create_store_membership, action: :create)
    end

    resource(Emakola.Accounts.Token)
  end
end
