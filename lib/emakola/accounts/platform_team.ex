defmodule Emakola.Accounts.PlatformTeam do
  @moduledoc """
  Coordination layer for platform staff team management: staff listing,
  permission editing, deactivation, force logout, TOTP reset, and the
  invite lifecycle.

  Every mutating function requires an actor with the `:manage_team`
  permission and returns `{:error, :unauthorized}` otherwise. Ownership
  changes and (de/re)activation additionally require an owner actor
  (`{:error, :owner_required}`). Last-owner protection is enforced by
  `Emakola.Accounts.Validations.EnsureOwnerRemains` on the user actions.
  Audit rows are written by `after_action` hooks on the resource actions.

  The raw invite token only ever exists in memory and in the invite
  email — the database stores its SHA-256 digest. Acceptance runs in a
  single transaction so a half-created account can never consume an
  invite.
  """

  require Ash.Query
  require Logger

  alias Emakola.Accounts.PlatformInvite
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Accounts.Sessions
  alias Emakola.Accounts.User
  alias Emakola.Notifications.Mailers.PlatformInviteMailer

  @doc "Lists platform staff (owners first, then by name/email)."
  def list_staff do
    User
    |> Ash.Query.for_read(:platform_staff)
    |> Ash.Query.sort(is_owner: :desc, name: :asc, email: :asc)
    |> Ash.read(authorize?: false)
  end

  @doc "Lists open (not accepted, not revoked) invites, newest first."
  def list_open_invites do
    PlatformInvite
    |> Ash.Query.for_read(:list_open)
    |> Ash.read(authorize?: false)
  end

  @doc """
  Update a staff member's permissions (and, for owner actors, the
  `is_owner` flag) via `:set_platform_permissions`.

  Changing `is_owner` requires an owner actor. The action's
  `EnsureOwnerRemains` validation rejects demoting the last active owner.
  """
  def update_permissions(%User{} = user, attrs, actor) do
    is_owner = Map.get(attrs, :is_owner, user.is_owner)

    with :ok <- require_manage_team(actor),
         :ok <- require_owner_for_ownership_change(user, is_owner, actor) do
      user
      |> Ash.Changeset.for_update(
        :set_platform_permissions,
        %{is_owner: is_owner, platform_permissions: Map.fetch!(attrs, :platform_permissions)},
        actor: actor
      )
      |> Ash.update(authorize?: false)
    end
  end

  @doc """
  Deactivate a staff member (owner-only) and revoke all their sessions.

  The action runs first — its `EnsureOwnerRemains` validation may reject
  deactivating the last active owner — then sessions are revoked.
  """
  def deactivate(%User{} = user, actor) do
    with :ok <- require_manage_team(actor),
         :ok <- require_owner(actor),
         {:ok, deactivated} <- run_update(user, :deactivate_staff, actor),
         {:ok, _count} <- Sessions.revoke_all_for_user(user.id, actor) do
      {:ok, deactivated}
    end
  end

  @doc "Reactivate a deactivated staff member (owner-only)."
  def reactivate(%User{} = user, actor) do
    with :ok <- require_manage_team(actor),
         :ok <- require_owner(actor) do
      run_update(user, :reactivate_staff, actor)
    end
  end

  @doc "Revoke all of a staff member's active sessions; returns `{:ok, count}`."
  def force_logout(%User{} = user, actor) do
    with :ok <- require_manage_team(actor) do
      Sessions.revoke_all_for_user(user.id, actor)
    end
  end

  @doc "Clear a staff member's TOTP secret so they re-enrol on next login."
  def reset_totp(%User{} = user, actor) do
    with :ok <- require_manage_team(actor) do
      run_update(user, :clear_totp, actor)
    end
  end

  @doc "Revoke an open invite."
  def revoke_invite(%PlatformInvite{} = invite, actor) do
    with :ok <- require_manage_team(actor) do
      invite
      |> Ash.Changeset.for_update(:revoke, %{}, actor: actor)
      |> Ash.update(authorize?: false)
    end
  end

  @doc """
  Resend an invite: revoke the old one, then create a fresh invite with
  the same email and permissions (a new token email is sent).
  """
  def resend_invite(%PlatformInvite{} = invite, actor, opts \\ []) do
    with :ok <- require_manage_team(actor),
         {:ok, _revoked} <- revoke_invite(invite, actor) do
      create_invite(to_string(invite.email), invite.permissions, actor, opts)
    end
  end

  @doc """
  Create an invite as `actor` and email the raw token to `email`.

  Requires an actor with the `:manage_team` permission.
  """
  def create_invite(_email, _permissions, nil), do: {:error, :actor_required}

  def create_invite(email, permissions, %User{} = actor, opts \\ []) do
    mailer = Keyword.get(opts, :mailer, PlatformInviteMailer)

    changeset =
      Ash.Changeset.for_create(PlatformInvite, :create, %{
        email: email,
        permissions: permissions,
        invited_by_id: actor.id
      })

    with :ok <- require_manage_team(actor),
         {:ok, invite} <- Ash.create(changeset) do
      case mailer.invite(
             to_string(invite.email),
             invite.__metadata__.raw_token,
             actor.name || to_string(actor.email)
           ) do
        {:ok, _} ->
          {:ok, invite}

        {:error, reason} ->
          # The flash can only say "Could not send the invite email." — the
          # provider's reason lives here or nowhere.
          Logger.error(
            "platform invite email failed to=#{to_string(invite.email)} " <>
              "id=#{invite.id} reason=#{inspect(reason)}"
          )

          invite
          |> Ash.Changeset.for_update(:revoke, %{})
          |> Ash.update(authorize?: false, actor: actor)
          |> case do
            {:error, revoke_error} ->
              Logger.warning(
                "invite revoke failed after mailer failure id=#{invite.id} " <>
                  "reason=#{inspect(revoke_error)}"
              )

            _ ->
              :ok
          end

          {:error, :email_delivery_failed}
      end
    end
  end

  @doc """
  Classify a raw invite token.

  Returns `{:ok, invite}` for a pending invite, otherwise
  `{:error, :invalid | :expired | :already_accepted | :revoked}`.
  """
  def invite_status(raw_token) do
    hash = hash_token(raw_token)

    case pending_by_token_hash(hash) do
      %PlatformInvite{} = invite -> {:ok, invite}
      nil -> classify_non_pending(hash)
    end
  end

  @doc """
  Accept a pending invite: create a confirmed staff user (with the
  invite's permissions, never owner) and mark the invite accepted, in
  one transaction. The new user is NOT signed in — they must sign in at
  /platform/login, which forces TOTP enrolment.
  """
  def accept_invite(raw_token, attrs) do
    with {:ok, invite} <- invite_status(raw_token) do
      do_accept(invite, attrs)
    end
  end

  @doc "SHA-256 hex digest of a raw invite token."
  def hash_token(raw_token) do
    :sha256 |> :crypto.hash(raw_token) |> Base.encode16(case: :lower)
  end

  # Mark accepted first: if user creation then fails (validation error,
  # or the email was registered after the invite went out) the whole
  # transaction rolls back and the invite stays pending.
  defp do_accept(invite, attrs) do
    Emakola.Repo.transaction(fn ->
      with {:ok, _invite} <- mark_accepted(invite),
           {:ok, user} <- create_user(invite, attrs) do
        user
      else
        {:error, error} -> Emakola.Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, user} -> {:ok, user}
      {:error, error} -> {:error, classify_accept_error(error)}
    end
  end

  defp mark_accepted(invite) do
    invite
    |> Ash.Changeset.for_update(:accept, %{})
    |> Ash.update()
  end

  defp create_user(invite, attrs) do
    User
    |> Ash.Changeset.for_create(:accept_platform_invite, %{
      email: to_string(invite.email),
      name: attrs[:name],
      password: attrs[:password],
      password_confirmation: attrs[:password_confirmation],
      platform_permissions: invite.permissions
    })
    |> Ash.create(authorize?: false)
  end

  defp classify_accept_error(error) do
    if email_taken?(error), do: :email_taken, else: error
  end

  defp email_taken?(%{errors: errors}) when is_list(errors),
    do: Enum.any?(errors, &email_taken?/1)

  defp email_taken?(%{field: :email, message: message}) when is_binary(message),
    do: message =~ "already been taken"

  defp email_taken?(_), do: false

  defp pending_by_token_hash(hash) do
    PlatformInvite
    |> Ash.Query.for_read(:pending_by_token_hash, %{token_hash: hash})
    |> Ash.read_one!()
  end

  defp require_manage_team(actor) do
    if PlatformPermissions.allowed?(actor, :manage_team),
      do: :ok,
      else: {:error, :unauthorized}
  end

  defp require_owner(%User{is_owner: true, deactivated_at: nil}), do: :ok
  defp require_owner(_actor), do: {:error, :owner_required}

  defp require_owner_for_ownership_change(%User{is_owner: current}, new, _actor)
       when new == current,
       do: :ok

  defp require_owner_for_ownership_change(_user, _new, actor), do: require_owner(actor)

  defp run_update(user, action, actor) do
    user
    |> Ash.Changeset.for_update(action, %{}, actor: actor)
    |> Ash.update(authorize?: false)
  end

  defp classify_non_pending(hash) do
    PlatformInvite
    |> Ash.Query.filter(token_hash == ^hash)
    |> Ash.read_one!()
    |> case do
      nil -> {:error, :invalid}
      %PlatformInvite{accepted_at: %DateTime{}} -> {:error, :already_accepted}
      %PlatformInvite{revoked_at: %DateTime{}} -> {:error, :revoked}
      _expired -> {:error, :expired}
    end
  end
end
