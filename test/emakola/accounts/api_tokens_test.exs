defmodule Emakola.Accounts.ApiTokensTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Accounts.{ApiTokens, Merchant}

  describe "issue_pair/1" do
    test "returns access + refresh tokens with expiry" do
      merchant = create_merchant!()

      assert {:ok, pair} = ApiTokens.issue_pair(merchant)
      assert is_binary(pair.access_token)
      assert is_binary(pair.refresh_token)
      assert pair.expires_in == 900

      assert {:ok, %{"purpose" => "user"}, Merchant} =
               AshAuthentication.Jwt.verify(pair.access_token, :emakola)

      assert {:ok, %{"purpose" => "emakola_api_refresh"}, Merchant} =
               AshAuthentication.Jwt.verify(pair.refresh_token, :emakola)
    end
  end

  describe "exchange_refresh/1" do
    test "issues a new pair and revokes the presented refresh token (rotation)" do
      merchant = create_merchant!()
      {:ok, pair} = ApiTokens.issue_pair(merchant)

      assert {:ok, new_pair} = ApiTokens.exchange_refresh(pair.refresh_token)
      assert new_pair.access_token != pair.access_token

      assert {:error, :invalid_refresh_token} = ApiTokens.exchange_refresh(pair.refresh_token)

      assert {:ok, _} = ApiTokens.exchange_refresh(new_pair.refresh_token)
    end

    test "rejects an access token used as refresh token" do
      merchant = create_merchant!()
      {:ok, pair} = ApiTokens.issue_pair(merchant)

      assert {:error, :invalid_refresh_token} = ApiTokens.exchange_refresh(pair.access_token)
    end

    test "rejects garbage" do
      assert {:error, :invalid_refresh_token} = ApiTokens.exchange_refresh("not-a-jwt")
    end
  end

  describe "revoke/1" do
    test "revoked refresh token can no longer be exchanged" do
      merchant = create_merchant!()
      {:ok, pair} = ApiTokens.issue_pair(merchant)

      assert :ok = ApiTokens.revoke(pair.refresh_token)
      assert {:error, :invalid_refresh_token} = ApiTokens.exchange_refresh(pair.refresh_token)
    end
  end
end
