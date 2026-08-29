defmodule Emakola.Accounts.Senders.PasswordResetSender do
  @moduledoc "Sends password reset emails via Swoosh."
  use AshAuthentication.Sender
  alias Emakola.Privacy
  require Logger

  @impl true
  def send(user, token, _opts) do
    email =
      case user do
        %{email: email} -> to_string(email)
        email -> to_string(email)
      end

    Logger.info("Sending password reset to #{Privacy.mask_email(email)}")

    if is_map(user) and Map.has_key?(user, :email) do
      # Ensure email is a plain string for Swoosh compatibility (Ash uses CiString)
      normalized_user = Map.update!(user, :email, &to_string/1)

      # Deliver off the request path. A synchronous provider round-trip makes
      # "known email" measurably slower than "unknown email", so the identical
      # confirmation copy would still leak account existence via response
      # latency. Fire-and-forget keeps both branches indistinguishable.
      Task.Supervisor.start_child(Emakola.TaskSupervisor, fn ->
        Emakola.Notifications.AuthMailer.password_reset(normalized_user, token)
      end)
    end

    :ok
  end
end
