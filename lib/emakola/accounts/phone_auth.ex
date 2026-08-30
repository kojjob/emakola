defmodule Emakola.Accounts.PhoneAuth do
  @moduledoc """
  Issues and verifies phone one-time codes for WhatsApp/SMS authentication.
  Codes are 6 digits, stored hashed (Bcrypt), ~10-min TTL, ≤5 attempts, and
  rate-limited per phone. Delivery prefers WhatsApp, falls back to SMS.

  Three purposes:

    * `:merchant` / `:customer` — signing in.
    * `:payout` — proving control of the wallet money will be sent to. This is
      how Makola establishes a merchant's identity now that L.I. 2523 has
      retired the Ghana Card flow: the telco already KYC'd the wallet against
      a Ghana Card, so answering a code sent to it inherits that check.

  The SMS body differs per purpose on purpose. "Your verification code" tells
  the holder nothing about what they are approving, which is exactly what a
  caller talking someone through handing over a code relies on. A payout code
  says money is involved.
  """
  alias Emakola.Accounts.PhoneOtp

  @ttl_seconds 600
  @max_attempts 5
  @send_limit 3
  @send_window_ms 600_000
  @verify_limit 10
  @verify_window_ms 600_000

  @doc "Ship-dark switch — show the WhatsApp button only when enabled."
  def enabled?, do: Application.get_env(:emakola, :phone_auth_enabled, false)

  @doc "Generate, store (hashed), and deliver a code. opts: :store_id."
  def request_code(phone, purpose, opts \\ []) when purpose in [:merchant, :customer, :payout] do
    phone = normalize(phone)

    with :ok <- rate_limit("phone_otp:send:#{phone}", @send_limit, @send_window_ms),
         code <- generate_code(),
         {:ok, _otp} <- store(phone, code, purpose, opts),
         :ok <- deliver(phone, code, purpose, opts) do
      :ok
    end
  end

  @doc "Verify a code; consumes the OTP on success."
  def verify_code(phone, code, purpose, opts \\ [])
      when purpose in [:merchant, :customer, :payout] do
    phone = normalize(phone)

    with :ok <- rate_limit("phone_otp:verify:#{phone}", @verify_limit, @verify_window_ms),
         {:ok, otp} <- latest_live_otp(phone, purpose, opts),
         :ok <- check_not_expired(otp),
         :ok <- check_attempts(otp),
         :ok <- check_code(otp, code) do
      consume(otp)
      :ok
    end
  end

  @doc "Normalize a Ghana/Nigeria local or international number to E.164."
  def normalize(phone) do
    digits = String.replace(phone, ~r/[^\d+]/, "")

    cond do
      String.starts_with?(digits, "+") -> digits
      String.starts_with?(digits, "0") -> "+233" <> String.slice(digits, 1..-1//1)
      String.starts_with?(digits, "233") or String.starts_with?(digits, "234") -> "+" <> digits
      true -> "+233" <> digits
    end
  end

  @doc """
  Combine a country code with a national number into E.164.

  Strips non-digit separators from `number` and drops a single leading trunk-0
  (e.g. Ghana `0501234567`), so the national number entered with or without the
  trunk-0 yields the same result. The combined value is run through the same
  E.164 cleanup as `normalize/1`.
  """
  def to_e164(cc, number) do
    national =
      number
      |> String.replace(~r/\D/, "")
      |> String.replace_prefix("0", "")

    normalize(cc <> national)
  end

  defp generate_code, do: 100_000..999_999 |> Enum.random() |> Integer.to_string()

  defp store(phone, code, purpose, opts) do
    PhoneOtp
    |> Ash.Changeset.for_create(:issue, %{
      phone: phone,
      code_hash: Bcrypt.hash_pwd_salt(code),
      purpose: purpose,
      store_id: Keyword.get(opts, :store_id),
      expires_at: DateTime.add(DateTime.utc_now(), @ttl_seconds, :second)
    })
    |> Ash.create(authorize?: false)
  end

  defp deliver(phone, code, purpose, opts) do
    case send_whatsapp(phone, code, opts) do
      :ok -> :ok
      :error -> send_sms(phone, code, purpose)
    end
  end

  defp send_whatsapp(phone, code, opts) do
    case whatsapp_provider().send_message(
           phone,
           "auth_code",
           %{code: code},
           Keyword.take(opts, [:store_id]) ++ [bypass_rate_limit: true]
         ) do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  defp send_sms(phone, code, purpose) do
    case sms_provider().send_sms(phone, sms_body(code, purpose), []) do
      {:ok, _} -> :ok
      _ -> {:error, :delivery_failed}
    end
  end

  # A payout code approves money movement, so it says so. Never share this
  # code is the line that stops a merchant reading it out to a caller.
  defp sms_body(code, :payout) do
    "Makola code #{code}. Someone is linking this number to receive your money. " <>
      "If this is not you, ignore it. Never share this code."
  end

  defp sms_body(code, _sign_in) do
    "Your Makola verification code is #{code}. It expires in 10 minutes."
  end

  defp latest_live_otp(phone, purpose, _opts) do
    PhoneOtp
    |> Ash.Query.for_read(:live_for_phone, %{phone: phone, purpose: purpose})
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [otp]} -> {:ok, otp}
      _ -> {:error, :invalid}
    end
  end

  defp check_not_expired(otp) do
    if DateTime.compare(otp.expires_at, DateTime.utc_now()) == :gt,
      do: :ok,
      else: {:error, :expired}
  end

  defp check_attempts(otp) do
    if otp.attempts < @max_attempts, do: :ok, else: {:error, :too_many_attempts}
  end

  defp check_code(otp, code) do
    if Bcrypt.verify_pass(code, otp.code_hash) do
      :ok
    else
      otp |> Ash.Changeset.for_update(:record_attempt, %{}) |> Ash.update(authorize?: false)
      {:error, :invalid}
    end
  end

  defp consume(otp),
    do: otp |> Ash.Changeset.for_update(:consume, %{}) |> Ash.update(authorize?: false)

  defp rate_limit(key, limit, window_ms) do
    case Emakola.RateLimit.check_rate(key, limit, window_ms) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limited}
    end
  end

  defp whatsapp_provider,
    do:
      Application.get_env(
        :emakola,
        :whatsapp_provider,
        Emakola.Notifications.Providers.LogWhatsApp
      )

  defp sms_provider,
    do: Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)
end
