defmodule Emakola.Accounts.PlatformTeam do
  @moduledoc """
  Coordination layer for platform staff team management. Phase 8 extends
  this with listing and permission management; for now it owns the
  invite lifecycle.

  The raw invite token only ever exists in memory and in the invite
  email — the database stores its SHA-256 digest. Acceptance runs in a
  single transaction so a half-created account can never consume an
  invite.
  """

  require Ash.Query

  alias Emakola.Accounts.PlatformInvite
  alias Emakola.Accounts.User
  alias Emakola.Notifications.Mailers.PlatformInviteMailer

  @doc """
  Create an invite as `actor` and email the raw token to `email`.

  Permission gating happens in the UI layer (Phase 8); the service only
  requires that an actor is present.
  """
  def create_invite(_email, _permissions, nil), do: {:error, :actor_required}

  def create_invite(email, permissions, %User{} = actor) do
    changeset =
      Ash.Changeset.for_create(PlatformInvite, :create, %{
        email: email,
        permissions: permissions,
        invited_by_id: actor.id
      })

    with {:ok, invite} <- Ash.create(changeset) do
      PlatformInviteMailer.invite(
        to_string(invite.email),
        invite.__metadata__.raw_token,
        actor.name || to_string(actor.email)
      )

      {:ok, invite}
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
