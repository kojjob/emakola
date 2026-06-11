defmodule EmakolaWeb.AuthTokens do
  @moduledoc """
  Signs and verifies AshAuthentication subject strings with Phoenix.Token.

  Session tokens must never be raw subjects (`user?id=<uuid>`) — anyone
  knowing a UUID could forge a session. Subjects are signed at issuance
  and verified before being trusted anywhere.
  """

  @salt "auth_subject_v1"
  @max_age 60 * 60 * 24 * 30

  @doc "Signs a subject string for storage in the session or a redirect URL."
  def sign_subject(subject) when is_binary(subject) do
    Phoenix.Token.sign(EmakolaWeb.Endpoint, @salt, subject)
  end

  @doc """
  Verifies a signed subject. Returns `{:ok, subject}` or `{:error, reason}`.
  Safely rejects nil and non-binary input.
  """
  def verify_subject(signed) when is_binary(signed) do
    Phoenix.Token.verify(EmakolaWeb.Endpoint, @salt, signed, max_age: @max_age)
  end

  def verify_subject(_), do: {:error, :missing}
end
