defmodule Emakola.Accounts.Sessions do
  @moduledoc """
  Lifecycle service for DB-backed platform-staff sessions.

  Verification rejects revoked sessions, sessions idle longer than 24
  hours (revoking them as a side effect), and sessions belonging to
  deactivated users. `touch/1` rate-limits last-seen writes to one per
  5 minutes. Revocations are recorded in the platform audit log.
  """

  require Ash.Query

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.UserSession

  @idle_timeout_hours 24
  @touch_granularity_minutes 5

  @doc "Creates an active session row for the given user."
  def create(user, ip, user_agent) do
    UserSession
    |> Ash.Changeset.for_create(:create, %{user_id: user.id, ip: ip, user_agent: user_agent})
    |> Ash.create(authorize?: false)
  end

  @doc """
  Verifies a session id, returning `{:ok, user, session}` or
  `{:error, :not_found | :revoked | :idle_expired | :deactivated}`.

  Never raises on garbage input. An idle-expired session is revoked.
  """
  def verify_session_id(session_id) when is_binary(session_id) do
    case get_session(session_id, load: [:user]) do
      {:ok, session} -> check_session(session)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def verify_session_id(_), do: {:error, :not_found}

  @doc "Updates last_seen_at, but only if it is staler than the touch granularity."
  def touch(%UserSession{} = session) do
    threshold = DateTime.add(DateTime.utc_now(), -@touch_granularity_minutes, :minute)

    if DateTime.before?(session.last_seen_at, threshold) do
      session
      |> Ash.Changeset.for_update(:touch, %{})
      |> Ash.update(authorize?: false)
    else
      {:ok, session}
    end
  end

  @doc "Revokes a session (by struct or id) and audits it."
  def revoke(%UserSession{} = session) do
    with {:ok, revoked} <-
           session
           |> Ash.Changeset.for_update(:revoke, %{})
           |> Ash.update(authorize?: false) do
      PlatformAudit.log(:session_revoked, revoked.user_id, %{session_id: revoked.id})
      {:ok, revoked}
    end
  end

  def revoke(session_id) when is_binary(session_id) do
    with {:ok, session} <- get_session(session_id) do
      revoke(session)
    end
  end

  @doc "Revokes all active sessions for a user; returns `{:ok, count}` and audits."
  def revoke_all_for_user(user_id) do
    result =
      UserSession
      |> Ash.Query.filter(user_id == ^user_id and is_nil(revoked_at))
      |> Ash.bulk_update(:revoke, %{},
        strategy: :stream,
        return_records?: true,
        return_errors?: true,
        authorize?: false
      )

    case result do
      %Ash.BulkResult{status: :success, records: records} ->
        count = length(records)

        PlatformAudit.log(:sessions_force_revoked, user_id, %{
          user_id: user_id,
          count: count
        })

        {:ok, count}

      %Ash.BulkResult{errors: errors} ->
        {:error, errors}
    end
  end

  @doc "Lists active sessions for a user, most recently seen first."
  def list_active_for_user(user_id) do
    UserSession
    |> Ash.Query.for_read(:list_active_for_user, %{user_id: user_id})
    |> Ash.read(authorize?: false)
  end

  defp get_session(session_id, opts \\ []) do
    case Ash.get(UserSession, session_id, Keyword.put(opts, :authorize?, false)) do
      {:ok, session} -> {:ok, session}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp check_session(session) do
    idle_threshold = DateTime.add(DateTime.utc_now(), -@idle_timeout_hours, :hour)

    cond do
      not is_nil(session.revoked_at) ->
        {:error, :revoked}

      DateTime.before?(session.last_seen_at, idle_threshold) ->
        _ = revoke(session)
        {:error, :idle_expired}

      not is_nil(session.user.deactivated_at) ->
        {:error, :deactivated}

      true ->
        {:ok, session.user, session}
    end
  end
end
