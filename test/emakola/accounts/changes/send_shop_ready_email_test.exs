defmodule Emakola.Accounts.Changes.SendShopReadyEmailTest do
  # async: false — one test swaps the global mailer adapter.
  use Emakola.DataCase, async: false

  import ExUnit.CaptureLog

  alias Emakola.Accounts.Merchant

  defmodule RaisingAdapter do
    def deliver(_email, _config), do: raise("mailer boom")
    def deliver_many(_emails, _config), do: raise("mailer boom")
  end

  setup do
    original = Application.get_env(:emakola, Emakola.Mailer)
    on_exit(fn -> Application.put_env(:emakola, Emakola.Mailer, original) end)
    :ok
  end

  defp register!(email) do
    Merchant
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "Password123!",
      password_confirmation: "Password123!"
    })
    |> Ash.create!(authorize?: false)
  end

  # The real flow: registration mails a confirmation link; the merchant POSTs
  # its token on the confirm page. Take the token from that email.
  defp confirm!(_merchant) do
    strategy = AshAuthentication.Info.strategy!(Merchant, :confirm_new_merchant)
    assert_receive {:email, %Swoosh.Email{subject: "Confirm your Makola email"} = mail}
    [_, token] = Regex.run(~r/confirm=([^\s&"]+)/, mail.text_body)

    {:ok, confirmed} =
      AshAuthentication.Strategy.action(strategy, :confirm, %{"confirm" => token})

    confirmed
  end

  test "confirming the email sends the picture-first shop-ready email, once, to that address" do
    email = "ama-#{System.unique_integer([:positive])}@example.com"
    merchant = register!(email)
    refute_receive {:email, %Swoosh.Email{subject: "Your shop is ready to set up"}}

    confirmed = confirm!(merchant)
    assert confirmed.confirmed_at

    assert_receive {:email, %Swoosh.Email{subject: "Your shop is ready to set up"} = sent}
    assert {_, ^email} = hd(sent.to)
    assert sent.html_body =~ "Your shop. One link. Free."
    assert sent.html_body =~ "cowrie-coin.png"
    assert sent.html_body =~ "href=\"#{EmakolaWeb.Endpoint.url()}/admin\""
    assert sent.text_body =~ "#{EmakolaWeb.Endpoint.url()}/admin"
    refute_receive {:email, %Swoosh.Email{subject: "Your shop is ready to set up"}}
  end

  test "confirmation still succeeds when the mailer raises" do
    merchant = register!("kofi-#{System.unique_integer([:positive])}@example.com")
    Application.put_env(:emakola, Emakola.Mailer, adapter: RaisingAdapter)

    log =
      capture_log(fn ->
        confirmed = confirm!(merchant)
        assert confirmed.confirmed_at
      end)

    assert log =~ "shop-ready email raised"
  end
end
