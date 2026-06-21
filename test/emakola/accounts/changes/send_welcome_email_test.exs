defmodule Emakola.Accounts.Changes.SendWelcomeEmailTest do
  # async: false — swaps the global mailer adapter for the duration.
  use Emakola.DataCase, async: false

  import ExUnit.CaptureLog

  # A Swoosh adapter that always blows up, to simulate a transactional email
  # provider being down / rejecting the request at send time.
  defmodule RaisingAdapter do
    def deliver(_email, _config), do: raise("mailer boom")
    def deliver_many(_emails, _config), do: raise("mailer boom")
  end

  setup do
    original = Application.get_env(:emakola, Emakola.Mailer)
    on_exit(fn -> Application.put_env(:emakola, Emakola.Mailer, original) end)
    :ok
  end

  test "registration still succeeds when the welcome mailer raises" do
    Application.put_env(:emakola, Emakola.Mailer, adapter: RaisingAdapter)

    email = "merchant-#{System.unique_integer([:positive])}@example.com"

    log =
      capture_log(fn ->
        {:ok, merchant} =
          Emakola.Accounts.Merchant
          |> Ash.Changeset.for_create(:register_with_password, %{
            email: email,
            password: "Password123!",
            password_confirmation: "Password123!"
          })
          |> Ash.create(authorize?: false)

        assert to_string(merchant.email) == email
      end)

    assert log =~ "welcome email raised"
  end
end
