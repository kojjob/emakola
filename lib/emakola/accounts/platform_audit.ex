defmodule Emakola.Accounts.PlatformAudit do
  @moduledoc """
  Records platform-staff security events to the append-only
  `Emakola.Accounts.PlatformAuditLog`.

  Never raises: an audit failure must not take down a login flow. Failures
  are logged as warnings and returned as `{:error, reason}` for callers
  that want to inspect them.
  """

  require Logger

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.User

  @topic "platform:audit_log"

  @doc "PubSub topic every successful log is broadcast on, as `{:platform_audit_logged, entry}`."
  def topic, do: @topic

  @doc """
  Log a platform audit event.

  `actor` may be a `%User{}`, a user id binary, or `nil` (e.g. failed
  sign-ins with no known actor).
  """
  def log(action, actor, metadata \\ %{}, ip \\ nil) do
    result =
      PlatformAuditLog
      |> Ash.Changeset.for_create(:create, %{
        actor_id: actor_id(actor),
        action: action,
        metadata: metadata,
        ip: ip
      })
      |> Ash.create(authorize?: false)

    case result do
      {:ok, log} ->
        Phoenix.PubSub.broadcast(Emakola.PubSub, @topic, {:platform_audit_logged, log})
        result

      {:error, reason} ->
        Logger.warning(
          "platform audit log failed action=#{inspect(action)} reason=#{inspect(reason)}"
        )

        result
    end
  end

  defp actor_id(%User{id: id}), do: id
  defp actor_id(id) when is_binary(id), do: id
  defp actor_id(nil), do: nil

  defp actor_id(other) do
    Logger.warning("platform_audit: unexpected actor #{inspect(other)}, treating as nil")
    nil
  end
end
