defmodule Emakola.Accounts do
  @moduledoc "Accounts domain — users, merchants, organisations, and authentication."
  use Ash.Domain

  require Ash.Query

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

      # Same action, paginated: the platform queue passes a confirmation
      # filter and a page, the plain interface above stays 1-arity for the
      # callers that want a whole small set.
      define(:page_merchants_for_admin, action: :list_for_admin, args: [:search, :confirmation])
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

  Three independent mechanisms have to be closed:

    * **Ash-issued tokens** (mobile API refresh tokens, magic links) are rows
      in the token table — revoke them.
    * **Device pairings** are short-lived codes that mint a fresh session when
      redeemed — revoke the ones in flight, or a confirmed code outlives the
      revocation it was supposed to be caught by.
    * **Browser sessions** are signed `Phoenix.Token` subjects held in the
      cookie. Nothing server-side is consulted when one is presented, so they
      cannot be deleted; instead we move the merchant's `sessions_valid_from`
      cutoff past every token issued so far.

  Closing only the first leaves a stolen cookie working for its full 30-day
  lifetime, which would make password reset useless against account takeover.
  """
  def revoke_all_sessions_for(merchant) do
    # Device pairings are a third mechanism, and they outlive both of the above
    # for their ninety seconds: a confirmed code is a credential someone is
    # holding right now. Cutting sessions while leaving one live would leave a
    # way straight back in.
    Emakola.Accounts.DevicePairings.revoke_pending(merchant.id)

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
  Counts behind the platform merchant queue's stat tiles.

  Four counts rather than one full-table read. The queue reads a page at a
  time now, so the tiles must not be the thing that drags every merchant on the
  platform into memory.
  """
  def merchant_admin_stats do
    cutoff = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)

    %{
      total: count_merchants(Emakola.Accounts.Merchant),
      confirmed:
        count_merchants(Ash.Query.filter(Emakola.Accounts.Merchant, not is_nil(confirmed_at))),
      with_store:
        count_merchants(Ash.Query.filter(Emakola.Accounts.Merchant, exists(stores, true))),
      new_30d: count_merchants(Ash.Query.filter(Emakola.Accounts.Merchant, inserted_at > ^cutoff))
    }
  end

  defp count_merchants(query), do: Ash.count!(query, authorize?: false)

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

  @doc """
  Whether a merchant may use the app at all.

  Proving you own the address is the price of entry: an unverified account
  can register and can verify, and nothing else. The check lives here rather
  than in the login form because there are three doors — the form, an
  existing session cookie, and the mobile API — and a rule enforced at one of
  them is not a rule.
  """
  def access_allowed?(%{confirmed_at: nil}), do: false
  def access_allowed?(%{confirmed_at: _confirmed}), do: true
  def access_allowed?(_other), do: false

  @doc """
  Sends the confirmation email again.

  Always returns `:ok`, whether or not the address belongs to anybody: the
  verify page is reachable without a session, so a truthful answer here would
  turn it into a list of who banks with us. Already-verified accounts are a
  no-op for the same reason.
  """
  def resend_confirmation(email) when is_binary(email) do
    strategy = AshAuthentication.Info.strategy!(Emakola.Accounts.Merchant, :confirm_new_merchant)

    with {:ok, merchant} <- merchant_by_email(email),
         false <- access_allowed?(merchant),
         {:ok, token} <-
           AshAuthentication.AddOn.Confirmation.confirmation_token_for_link(
             strategy,
             merchant,
             %{}
           ) do
      Emakola.Accounts.Senders.ConfirmationSender.send(merchant, token, [])
    end

    :ok
  rescue
    _ -> :ok
  end

  defp merchant_by_email(email) do
    Emakola.Accounts.Merchant
    |> Ash.Query.filter(email == ^String.downcase(String.trim(email)))
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> :error
      {:ok, merchant} -> {:ok, merchant}
      other -> other
    end
  end
end
