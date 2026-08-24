defmodule Emakola.Accounts.PhoneRecovery do
  @moduledoc """
  Account recovery for merchants who have no email.

  Recovery was email-only, so a merchant without an email address could not
  get back into their own shop — in a market where most merchants do not use
  email. This is that lockout fix: prove control of the registered phone with
  a one-time code, then set a new password.

  Two properties are deliberate:

    * **An unknown phone still returns `:ok`.** Confirming whether a number
      has an account would turn this form into a way to enumerate every
      merchant's phone number. The caller cannot tell the difference; only
      someone holding the phone can.
    * **A reset ends every existing session.** A recovered account may have
      been recovered *from* someone, so old browser tokens must die with the
      old password — the same treatment the email reset gets.

  Code delivery, rate limiting and E.164 normalisation are
  `Emakola.Accounts.PhoneAuth`'s job; this module is the recovery policy on
  top of it.
  """

  require Ash.Query
  require Logger

  alias Emakola.Accounts
  alias Emakola.Accounts.Merchant
  alias Emakola.Accounts.PhoneAuth

  @doc """
  Sends a recovery code to `phone` if a merchant is registered with it.

  Always returns `:ok` — see the note above on not revealing whether a number
  is known.
  """
  @spec request_code(String.t()) :: :ok
  def request_code(phone) when is_binary(phone) do
    case find_merchant(phone) do
      nil ->
        # Deliberately silent to the caller; logged so a flood of unknown
        # numbers is still visible to us.
        Logger.info("[PhoneRecovery] recovery requested for an unregistered phone")
        :ok

      _merchant ->
        case PhoneAuth.request_code(phone, :merchant) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning("[PhoneRecovery] code delivery failed reason=#{inspect(reason)}")
            :ok
        end
    end
  end

  @doc """
  Verifies `code` against `phone` and sets `new_password`.

  Consumes the code, so it cannot be replayed, and invalidates every session
  the account already had.
  """
  @spec verify_and_reset(String.t(), String.t(), String.t()) ::
          {:ok, Merchant.t()} | {:error, term()}
  def verify_and_reset(phone, code, new_password)
      when is_binary(phone) and is_binary(code) and is_binary(new_password) do
    with %Merchant{} = merchant <- find_merchant(phone),
         :ok <- PhoneAuth.verify_code(phone, code, :merchant),
         {:ok, merchant} <- set_password(merchant, new_password) do
      # Recovery may be recovery *from* someone. Old tokens die with the old
      # password, exactly as they do on the email reset path. The session
      # cutoff itself is moved by set_password/2 in the same write.
      Accounts.revoke_all_sessions_for(merchant)

      {:ok, merchant}
    else
      nil -> {:error, :invalid_code}
      {:error, reason} -> {:error, reason}
    end
  end

  defp set_password(merchant, new_password) do
    hashed = Bcrypt.hash_pwd_salt(new_password)

    merchant
    |> Ash.Changeset.for_update(:invalidate_sessions, %{})
    |> Ash.Changeset.force_change_attribute(:hashed_password, hashed)
    |> Ash.update(authorize?: false)
  end

  defp find_merchant(phone) do
    normalised = PhoneAuth.normalize(phone)

    Merchant
    |> Ash.Query.filter(phone == ^normalised)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, merchant} -> merchant
      _ -> nil
    end
  end
end
