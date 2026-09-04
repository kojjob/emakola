defmodule Emakola.Accounts.ResendConfirmationTest do
  use Emakola.DataCase, async: false

  alias Emakola.Accounts
  alias Emakola.Accounts.Merchant

  @confirm_subject "Confirm your Makola email"

  defp register!(email) do
    Merchant
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "Password123!",
      password_confirmation: "Password123!"
    })
    |> Ash.create!(authorize?: false)
  end

  defp token_from_next_confirmation_email do
    assert_receive {:email, %Swoosh.Email{subject: @confirm_subject} = mail}
    [_, token] = Regex.run(~r/confirm=([^\s&"]+)/, mail.text_body)
    token
  end

  defp confirm_with(token) do
    strategy = AshAuthentication.Info.strategy!(Merchant, :confirm_new_merchant)
    AshAuthentication.Strategy.action(strategy, :confirm, %{"confirm" => token})
  end

  test "a resent link confirms the account, exactly like the original one" do
    email = "ama-#{System.unique_integer([:positive])}@example.com"
    merchant = register!(email)
    _original_token = token_from_next_confirmation_email()

    assert :ok = Accounts.resend_confirmation(email)
    resent_token = token_from_next_confirmation_email()

    assert {:ok, confirmed} = confirm_with(resent_token)
    assert confirmed.id == merchant.id
    assert confirmed.confirmed_at
    assert to_string(confirmed.email) == email
  end

  test "resending for an already confirmed or unknown address sends nothing and stays quiet" do
    email = "kofi-#{System.unique_integer([:positive])}@example.com"
    register!(email)
    token = token_from_next_confirmation_email()
    {:ok, _} = confirm_with(token)

    assert :ok = Accounts.resend_confirmation(email)

    assert :ok =
             Accounts.resend_confirmation(
               "nobody-#{System.unique_integer([:positive])}@example.com"
             )

    refute_receive {:email, %Swoosh.Email{subject: @confirm_subject}}
  end
end
