defmodule Emakola.Accounts.TOTPTest do
  use ExUnit.Case, async: true

  alias Emakola.Accounts.TOTP

  describe "generate_secret/0" do
    test "returns a 20-byte binary, unique across calls" do
      secret = TOTP.generate_secret()

      assert is_binary(secret)
      assert byte_size(secret) == 20
      refute TOTP.generate_secret() == secret
    end
  end

  describe "otpauth_uri/2" do
    test "contains the issuer and the email" do
      uri = TOTP.otpauth_uri("admin@example.com", TOTP.generate_secret())

      assert uri =~ "otpauth://totp/"
      assert uri =~ "issuer=Makola%20Platform"
      assert uri =~ "Makola%20Platform:admin@example.com"
    end
  end

  describe "qr_svg/1" do
    test "returns an SVG string" do
      svg =
        "admin@example.com"
        |> TOTP.otpauth_uri(TOTP.generate_secret())
        |> TOTP.qr_svg()

      assert is_binary(svg)
      assert svg =~ "<svg"
    end
  end

  describe "valid_code?/3" do
    setup do
      %{secret: TOTP.generate_secret()}
    end

    test "accepts the current window's code", %{secret: secret} do
      code = NimbleTOTP.verification_code(secret)

      assert TOTP.valid_code?(secret, code)
    end

    test "accepts the previous window's code (clock drift)", %{secret: secret} do
      code = NimbleTOTP.verification_code(secret, time: System.os_time(:second) - 30)

      assert TOTP.valid_code?(secret, code)
    end

    test "rejects a future window's code", %{secret: secret} do
      code = NimbleTOTP.verification_code(secret, time: System.os_time(:second) + 90)

      refute TOTP.valid_code?(secret, code)
    end

    test "rejects a code minted from another secret", %{secret: secret} do
      code = NimbleTOTP.verification_code(TOTP.generate_secret())

      refute TOTP.valid_code?(secret, code)
    end

    test "rejects garbage codes without raising", %{secret: secret} do
      refute TOTP.valid_code?(secret, "")
      refute TOTP.valid_code?(secret, nil)
      refute TOTP.valid_code?(secret, "abc")
      refute TOTP.valid_code?(secret, "12345678")
    end

    test "returns false (no raise) when secret is nil" do
      refute TOTP.valid_code?(nil, "123456")
    end

    test "blocks reuse via since:", %{secret: secret} do
      code = NimbleTOTP.verification_code(secret)

      assert TOTP.valid_code?(secret, code, since: nil)
      refute TOTP.valid_code?(secret, code, since: DateTime.utc_now())
    end
  end
end
