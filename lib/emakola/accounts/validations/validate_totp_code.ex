defmodule Emakola.Accounts.Validations.ValidateTotpCode do
  @moduledoc """
  Validates the `:code` argument against the submitted `:secret` argument
  during TOTP enrolment (`update :setup_totp`).

  No `since:` is passed: this is the first confirmation of a fresh secret,
  so there is no prior use to guard against.
  """

  use Ash.Resource.Validation

  alias Emakola.Accounts.TOTP

  @impl true
  def validate(changeset, _opts, _context) do
    secret = Ash.Changeset.get_argument(changeset, :secret)
    code = Ash.Changeset.get_argument(changeset, :code)

    if TOTP.valid_code?(secret, code) do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidArgument.exception(
         field: :code,
         message: "is not a valid authenticator code"
       )}
    end
  end
end
