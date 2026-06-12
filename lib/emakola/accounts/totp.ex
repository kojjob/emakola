defmodule Emakola.Accounts.TOTP do
  @moduledoc """
  TOTP two-factor helpers for platform staff.

  Wraps NimbleTOTP and EQRCode so the rest of the app never touches the
  libraries directly.
  """

  @issuer "Emakola Platform"
  @period 30
  @qr_width 220

  @doc "Generates a random 20-byte TOTP secret."
  def generate_secret, do: NimbleTOTP.secret()

  @doc "Builds the otpauth:// URI an authenticator app enrols from."
  def otpauth_uri(email, secret) do
    NimbleTOTP.otpauth_uri("#{@issuer}:#{email}", secret, issuer: @issuer)
  end

  @doc """
  Renders an otpauth URI as an inline SVG QR code (#{@qr_width}px viewBox).

  Safe to render with Phoenix.HTML.raw/1 — EQRCode generates pure geometry;
  no user text is interpolated into the SVG markup.
  """
  def qr_svg(uri) do
    uri |> EQRCode.encode() |> EQRCode.svg(width: @qr_width, viewbox: true)
  end

  @doc """
  Checks a 6-digit code against the secret.

  Accepts the current or the previous #{@period}s window to tolerate client
  clock drift. Pass `since:` (the last time a code was accepted) to block
  reuse of a code within its window, per the TOTP RFC. Garbage codes
  (`nil`, wrong length) return `false` without raising.
  """
  def valid_code?(secret, code, opts \\ [])

  def valid_code?(secret, code, opts) when is_binary(secret) and is_binary(code) do
    since = Keyword.get(opts, :since)
    now = System.os_time(:second)

    NimbleTOTP.valid?(secret, code, time: now, since: since) or
      NimbleTOTP.valid?(secret, code, time: now - @period, since: since)
  end

  def valid_code?(_secret, _code, _opts), do: false
end
