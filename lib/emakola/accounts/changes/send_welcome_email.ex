defmodule Emakola.Accounts.Changes.SendWelcomeEmail do
  @moduledoc """
  Ash after-action change that sends a welcome email to newly registered users.
  Attached to the `register_with_password` action on the User resource.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, user ->
      Emakola.Notifications.AuthMailer.welcome(user)
      {:ok, user}
    end)
  end
end
