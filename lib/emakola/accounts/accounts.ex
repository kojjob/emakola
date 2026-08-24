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
      define(:list_merchants_for_admin, action: :list_for_admin, args: [:search])
      define(:get_merchant, action: :read, get_by: [:id])
      define(:register_merchant_with_phone, action: :register_with_phone)
    end

    # OAuth identity links for merchant social login (managed by
    # AshAuthentication.UserIdentity).
    resource(Emakola.Accounts.MerchantIdentity)

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

    resource(Emakola.Accounts.PhoneOtp)
    resource(Emakola.Accounts.DevicePairing)
  end

  @doc """
  End every authenticated session for a merchant. Used after a password reset
  so the new password actually locks out anyone holding old credentials.

  Two independent mechanisms have to be closed:

    * **Ash-issued tokens** (mobile API refresh tokens, magic links) are rows
      in the token table — revoke them.
    * **Browser sessions** are signed `Phoenix.Token` subjects held in the
      cookie. Nothing server-side is consulted when one is presented, so they
      cannot be deleted; instead we move the merchant's `sessions_valid_from`
      cutoff past every token issued so far.

  Closing only the first leaves a stolen cookie working for its full 30-day
  lifetime, which would make password reset useless against account takeover.
  """
  def revoke_all_sessions_for(merchant) do
    subject = AshAuthentication.user_to_subject(merchant)

    Emakola.Accounts.Token
    |> Ash.bulk_update!(:revoke_all_stored_for_subject, %{subject: subject},
      authorize?: false,
      strategy: [:atomic, :atomic_batches, :stream]
    )

    merchant
    |> Ash.Changeset.for_update(:invalidate_sessions, %{}, authorize?: false)
    |> Ash.update!()

    :ok
  end

  @doc """
  Whether a browser session token minted at `issued_at` (unix seconds) is
  still live for this merchant. Tokens predating `sessions_valid_from` — and
  legacy tokens, which report `issued_at: 0` — are dead.
  """
  def session_live?(%{sessions_valid_from: nil}, _issued_at), do: true

  def session_live?(%{sessions_valid_from: cutoff}, issued_at) when is_integer(issued_at) do
    # Strictly after: Phoenix.Token stamps issued-at in whole seconds, so a
    # token minted in the same second as the reset would otherwise survive it.
    issued_at > DateTime.to_unix(cutoff)
  end

  def session_live?(_merchant, _issued_at), do: false
end
