defmodule Emakola.Accounts do
  @moduledoc "Accounts domain — users, merchants, organisations, and authentication."
  use Ash.Domain

  resources do
    resource Emakola.Accounts.User do
      define(:register_with_password, args: [:email, :password, :password_confirmation])
      define(:get_user_by_id, action: :read, get_by: [:id])
    end

    resource Emakola.Accounts.Organisation do
      define(:create_organisation, action: :create, args: [:name])
      define(:get_organisation, action: :read, get_by: [:id])
    end

    resource Emakola.Accounts.Membership do
      define(:create_membership, action: :create)
      define(:list_memberships, action: :read)
      define(:list_memberships_by_user, action: :by_user, args: [:user_id])
    end

    resource Emakola.Accounts.Merchant do
      define(:update_merchant_profile, action: :update_profile)
    end

    # Store resource moved to Emakola.Stores on 2026-04-26.
    # See docs/PLAN-domain-restructuring-2026-04-26.md Step 3.

    resource Emakola.Accounts.StoreMembership do
      define(:create_store_membership, action: :create)
      define(:get_merchant_store_membership, action: :by_merchant, args: [:merchant_id])
    end

    resource(Emakola.Accounts.UserSession)

    resource(Emakola.Accounts.PlatformInvite)

    resource Emakola.Accounts.PlatformAuditLog do
      define(:create_platform_audit_log, action: :create)
      define(:list_platform_audit_logs, action: :list)
    end

    resource(Emakola.Accounts.Token)
  end
end
