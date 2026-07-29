defmodule Emakola.Accounts.PasswordResetTest do
  use Emakola.DataCase, async: true

  import Swoosh.TestAssertions

  alias AshAuthentication.{Info, Strategy}
  alias Emakola.Accounts.Merchant

  defp unique_email, do: "reset-#{System.unique_integer([:positive])}@example.com"

  defp register!(email) do
    Merchant
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        email: email,
        password: "Password123!",
        password_confirmation: "Password123!"
      },
      authorize?: false
    )
    |> Ash.create!()
    |> tap(fn _ -> flush_emails() end)
  end

  # Registration sends its own mail (welcome + confirmation). Drain it so the
  # next assert_email_sent sees the reset email, not registration leftovers.
  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  defp strategy, do: Info.strategy!(Merchant, :password)

  defp extract_token_from_email do
    assert_email_sent(fn sent ->
      assert sent.subject == "Reset your Makola password"

      assert [token] =
               Regex.run(~r{/auth/reset-password\?token=([^"\s]+)}, sent.text_body,
                 capture: :all_but_first
               )

      token
    end)
  end

  describe "reset_request" do
    test "sends a reset email with a /auth/reset-password?token= link" do
      email = unique_email()
      register!(email)

      assert :ok = Strategy.action(strategy(), :reset_request, %{"email" => email})

      assert_email_sent(fn sent ->
        assert {_, ^email} = hd(sent.to)
        assert sent.subject == "Reset your Makola password"
        assert sent.text_body =~ "/auth/reset-password?token="
        # Copy must match the configured 24h lifetime
        assert sent.html_body =~ "24 hours"
      end)
    end

    test "an unknown email sends nothing and returns the same shape" do
      assert :ok = Strategy.action(strategy(), :reset_request, %{"email" => unique_email()})
      refute_email_sent()
    end
  end

  describe "reset" do
    test "a valid token sets the new password; the old one stops working" do
      email = unique_email()
      register!(email)
      :ok = Strategy.action(strategy(), :reset_request, %{"email" => email})
      token = extract_token_from_email()

      assert {:ok, _user} =
               Strategy.action(strategy(), :reset, %{
                 "reset_token" => token,
                 "password" => "NewPassword456!",
                 "password_confirmation" => "NewPassword456!"
               })

      assert {:ok, _} =
               Strategy.action(strategy(), :sign_in, %{
                 "email" => email,
                 "password" => "NewPassword456!"
               })

      assert {:error, _} =
               Strategy.action(strategy(), :sign_in, %{
                 "email" => email,
                 "password" => "Password123!"
               })
    end

    test "a garbage token is rejected" do
      assert {:error, _} =
               Strategy.action(strategy(), :reset, %{
                 "reset_token" => "not-a-real-token",
                 "password" => "NewPassword456!",
                 "password_confirmation" => "NewPassword456!"
               })
    end

    test "a too-short password is rejected with the field error" do
      email = unique_email()
      register!(email)
      :ok = Strategy.action(strategy(), :reset_request, %{"email" => email})
      token = extract_token_from_email()

      assert {:error, %Ash.Error.Invalid{}} =
               Strategy.action(strategy(), :reset, %{
                 "reset_token" => token,
                 "password" => "short",
                 "password_confirmation" => "short"
               })
    end
  end
end
