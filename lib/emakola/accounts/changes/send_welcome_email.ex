defmodule Emakola.Accounts.Changes.SendWelcomeEmail do
  @moduledoc """
  Ash after-action change that sends a welcome email to newly registered users.
  Attached to the `register_with_password` action.

  The send is **best-effort**: a transactional email provider being down,
  rejecting the request, or raising must never abort registration. Failures are
  logged and swallowed so the account is still created.
  """
  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, user ->
      send_welcome(user)
      {:ok, user}
    end)
  end

  defp send_welcome(user) do
    case Emakola.Notifications.AuthMailer.welcome(user) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("[accounts] welcome email not sent: #{inspect(reason)}")
    end
  rescue
    exception ->
      Logger.error("[accounts] welcome email raised: #{Exception.message(exception)}")
  end
end
