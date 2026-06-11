defmodule EmakolaWeb.AuthTokensTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.AuthTokens

  describe "sign_subject/1 and verify_subject/1" do
    test "round-trips a subject string" do
      subject = "user?id=#{Ash.UUID.generate()}"
      signed = AuthTokens.sign_subject(subject)

      assert signed != subject
      assert {:ok, ^subject} = AuthTokens.verify_subject(signed)
    end

    test "rejects a tampered value" do
      signed = AuthTokens.sign_subject("user?id=#{Ash.UUID.generate()}")

      assert {:error, :invalid} = AuthTokens.verify_subject(signed <> "x")
    end

    test "rejects a raw (unsigned) subject string" do
      assert {:error, :invalid} =
               AuthTokens.verify_subject("user?id=#{Ash.UUID.generate()}")
    end

    test "rejects nil" do
      assert {:error, :missing} = AuthTokens.verify_subject(nil)
    end

    test "rejects non-binary garbage" do
      assert {:error, :missing} = AuthTokens.verify_subject(123)
      assert {:error, :missing} = AuthTokens.verify_subject(%{})
    end

    test "rejects binary garbage" do
      assert {:error, :invalid} = AuthTokens.verify_subject("garbage")
    end

    test "rejects a value signed with a different salt" do
      other = Phoenix.Token.sign(EmakolaWeb.Endpoint, "some_other_salt", "user?id=abc")

      assert {:error, :invalid} = AuthTokens.verify_subject(other)
    end
  end
end
