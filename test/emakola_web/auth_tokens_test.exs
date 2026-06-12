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

  describe "sign_platform_session/1 and verify_platform_session/1" do
    test "round-trips a session id" do
      session_id = Ash.UUID.generate()
      signed = AuthTokens.sign_platform_session(session_id)

      assert signed != session_id
      assert {:ok, ^session_id} = AuthTokens.verify_platform_session(signed)
    end

    test "rejects a tampered value" do
      signed = AuthTokens.sign_platform_session(Ash.UUID.generate())

      assert {:error, :invalid} = AuthTokens.verify_platform_session(signed <> "x")
    end

    test "rejects nil and non-binary garbage" do
      assert {:error, :missing} = AuthTokens.verify_platform_session(nil)
      assert {:error, :missing} = AuthTokens.verify_platform_session(123)
    end

    test "rejects a raw (unsigned) uuid" do
      assert {:error, :invalid} = AuthTokens.verify_platform_session(Ash.UUID.generate())
    end

    test "rejects tokens signed for other purposes" do
      id = Ash.UUID.generate()

      assert {:error, :invalid} =
               AuthTokens.verify_platform_session(AuthTokens.sign_login_exchange(id))

      assert {:error, :invalid} =
               AuthTokens.verify_platform_session(AuthTokens.sign_subject(id))
    end
  end

  describe "sign_login_exchange/1 and verify_login_exchange/1" do
    test "round-trips a user id" do
      user_id = Ash.UUID.generate()
      signed = AuthTokens.sign_login_exchange(user_id)

      assert signed != user_id
      assert {:ok, ^user_id} = AuthTokens.verify_login_exchange(signed)
    end

    test "rejects a tampered value" do
      signed = AuthTokens.sign_login_exchange(Ash.UUID.generate())

      assert {:error, :invalid} = AuthTokens.verify_login_exchange(signed <> "x")
    end

    test "rejects nil and non-binary garbage" do
      assert {:error, :missing} = AuthTokens.verify_login_exchange(nil)
      assert {:error, :missing} = AuthTokens.verify_login_exchange(%{})
    end

    test "rejects tokens signed for other purposes" do
      id = Ash.UUID.generate()

      assert {:error, :invalid} =
               AuthTokens.verify_login_exchange(AuthTokens.sign_platform_session(id))

      assert {:error, :invalid} =
               AuthTokens.verify_login_exchange(AuthTokens.sign_subject(id))
    end
  end
end
