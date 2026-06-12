defmodule Emakola.Accounts.Validations.InviteEmailAvailable do
  @moduledoc """
  Rejects a platform invite when the email already belongs to a user
  (active or deactivated) or already has a pending invite — pending
  meaning not accepted, not revoked, and not expired.
  """

  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    email = Ash.Changeset.get_attribute(changeset, :email)

    cond do
      is_nil(email) -> :ok
      user_exists?(email) -> error("already has an account")
      pending_invite_exists?(email) -> error("already has a pending invite")
      true -> :ok
    end
  end

  defp user_exists?(email) do
    Emakola.Accounts.User
    |> Ash.Query.filter(email == ^email)
    |> Ash.exists?(authorize?: false)
  end

  defp pending_invite_exists?(email) do
    now = DateTime.utc_now()

    Emakola.Accounts.PlatformInvite
    |> Ash.Query.filter(
      email == ^email and is_nil(accepted_at) and is_nil(revoked_at) and expires_at > ^now
    )
    |> Ash.exists?(authorize?: false)
  end

  defp error(message) do
    {:error, Ash.Error.Changes.InvalidAttribute.exception(field: :email, message: message)}
  end
end
