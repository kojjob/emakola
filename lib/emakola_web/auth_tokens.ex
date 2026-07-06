defmodule EmakolaWeb.AuthTokens do
  @moduledoc """
  Signs and verifies AshAuthentication subject strings with Phoenix.Token.

  Session tokens must never be raw subjects (`user?id=<uuid>`) — anyone
  knowing a UUID could forge a session. Subjects are signed at issuance
  and verified before being trusted anywhere.
  """

  @salt "auth_subject_v1"
  @max_age 60 * 60 * 24 * 30

  @platform_session_salt "platform_session_v1"
  @platform_session_max_age 60 * 60 * 24 * 14

  @login_exchange_salt "platform_login_exchange_v1"
  @login_exchange_max_age 30

  @subject_exchange_salt "auth_subject_exchange_v1"
  @subject_exchange_max_age 60

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

  @doc "Signs a platform `UserSession` id for the session cookie (valid 14 days)."
  def sign_platform_session(session_id) when is_binary(session_id) do
    Phoenix.Token.sign(EmakolaWeb.Endpoint, @platform_session_salt, session_id)
  end

  @doc """
  Verifies a signed platform session id. Returns `{:ok, session_id}` or
  `{:error, reason}`. Safely rejects nil and non-binary input.
  """
  def verify_platform_session(signed) when is_binary(signed) do
    Phoenix.Token.verify(EmakolaWeb.Endpoint, @platform_session_salt, signed,
      max_age: @platform_session_max_age
    )
  end

  def verify_platform_session(_), do: {:error, :missing}

  @doc """
  Signs a user id as a short-lived (30s) login exchange token, bridging the
  login LiveView to `PlatformSessionController` (LiveView cannot write the
  session cookie).
  """
  def sign_login_exchange(user_id) when is_binary(user_id) do
    Phoenix.Token.sign(EmakolaWeb.Endpoint, @login_exchange_salt, user_id)
  end

  @doc """
  Verifies a login exchange token. Returns `{:ok, user_id}` or
  `{:error, reason}`. Safely rejects nil and non-binary input.
  """
  def verify_login_exchange(signed) when is_binary(signed) do
    Phoenix.Token.verify(EmakolaWeb.Endpoint, @login_exchange_salt, signed,
      max_age: @login_exchange_max_age
    )
  end

  def verify_login_exchange(_), do: {:error, :missing}

  @doc """
  Signs a subject string as a short-lived (60s) exchange token for the
  LiveView -> session-controller redirect bridge. The long-lived session token
  is then minted server-side and stored only in the (signed) session cookie, so
  the durable credential never travels in a URL where it could leak via access
  logs, the Referer header, or browser history.
  """
  def sign_subject_exchange(subject) when is_binary(subject) do
    Phoenix.Token.sign(EmakolaWeb.Endpoint, @subject_exchange_salt, subject)
  end

  @doc """
  Verifies a subject exchange token. Returns `{:ok, subject}` or
  `{:error, reason}`. Safely rejects nil and non-binary input. A long-lived
  session subject token (different salt) is NOT a valid exchange token.
  """
  def verify_subject_exchange(signed) when is_binary(signed) do
    Phoenix.Token.verify(EmakolaWeb.Endpoint, @subject_exchange_salt, signed,
      max_age: @subject_exchange_max_age
    )
  end

  def verify_subject_exchange(_), do: {:error, :missing}
end
