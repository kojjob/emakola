defmodule Emakola.Accounts.RevokeAllTokensTest do
  use Emakola.DataCase, async: true

  require Ash.Query

  alias AshAuthentication.{Info, Strategy}
  alias Emakola.Accounts.{Merchant, Token}

  test "revoke_all_sessions_for/1 revokes stored tokens and sets the session cutoff" do
    email = "revoke-#{System.unique_integer([:positive])}@example.com"

    merchant =
      Merchant
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{email: email, password: "Password123!", password_confirmation: "Password123!"},
        authorize?: false
      )
      |> Ash.create!()

    # Minting a session stores a token row (store_all_tokens? is on)
    strategy = Info.strategy!(Merchant, :password)

    {:ok, _} =
      Strategy.action(strategy, :sign_in, %{"email" => email, "password" => "Password123!"})

    subject = AshAuthentication.user_to_subject(merchant)

    live_tokens =
      Token
      |> Ash.Query.filter(subject == ^subject and purpose != "revocation")
      |> Ash.read!(authorize?: false)

    assert live_tokens != [], "expected sign-in to store at least one live token"

    assert :ok = Emakola.Accounts.revoke_all_sessions_for(merchant)

    remaining =
      Token
      |> Ash.Query.filter(subject == ^subject and purpose != "revocation")
      |> Ash.read!(authorize?: false)

    assert remaining == []

    # Browser sessions are not rows — the cutoff is what invalidates them.
    reloaded = Ash.get!(Merchant, merchant.id, authorize?: false)
    assert reloaded.sessions_valid_from, "expected the session cutoff to be set"
  end
end
