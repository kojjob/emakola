defmodule Emakola.Accounts.MerchantTokenStorageTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias AshAuthentication.{Info, Strategy}
  alias Emakola.Accounts.Merchant

  test "password sign-in stores the issued token (presence check prerequisite)" do
    merchant = create_merchant!(%{password: "Password123!"})

    strategy = Info.strategy!(Merchant, :password)

    {:ok, signed_in} =
      Strategy.action(strategy, :sign_in, %{
        email: to_string(merchant.email),
        password: "Password123!"
      })

    token = signed_in.__metadata__.token
    assert is_binary(token)

    {:ok, %{"jti" => jti}, Merchant} = AshAuthentication.Jwt.verify(token, :emakola)

    {:ok, records} =
      AshAuthentication.TokenResource.Actions.get_token(
        Emakola.Accounts.Token,
        %{"jti" => jti, "purpose" => "user"}
      )

    assert [_record] = records
  end
end
