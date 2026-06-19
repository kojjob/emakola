defmodule Emakola.Payments.SettlementBanksTest do
  @moduledoc """
  Resolves a mobile-money provider to its Paystack settlement_bank code via a
  live List Banks lookup, falling back to last-known-good static codes when the
  API is unavailable (no keys / network / provider absent). The function is
  total — it always returns a code so payout onboarding never breaks.
  """
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  alias Emakola.Payments.SettlementBanks

  defp ok(data), do: {:ok, %{"status" => true, "data" => data}}

  describe "settlement_code/1 — live lookup wins" do
    test "matches MTN by slug and returns the live code" do
      Emakola.Payments.PaystackClientMock
      |> expect(:list_banks, fn _params ->
        ok([
          %{
            "slug" => "mtn-mobile-money",
            "name" => "MTN",
            "code" => "MTN_LIVE",
            "type" => "mobile_money"
          }
        ])
      end)

      assert SettlementBanks.settlement_code("mtn") == "MTN_LIVE"
    end

    test "matches vodafone via a telecel slug after the rebrand" do
      Emakola.Payments.PaystackClientMock
      |> expect(:list_banks, fn _params ->
        ok([
          %{
            "slug" => "telecel-cash",
            "name" => "Telecel Cash",
            "code" => "TCL",
            "type" => "mobile_money"
          }
        ])
      end)

      assert SettlementBanks.settlement_code("vodafone") == "TCL"
    end

    test "matches by name substring when the slug is unfamiliar" do
      Emakola.Payments.PaystackClientMock
      |> expect(:list_banks, fn _params ->
        ok([
          %{
            "slug" => "x-9921",
            "name" => "AirtelTigo Money",
            "code" => "ATL9",
            "type" => "mobile_money"
          }
        ])
      end)

      assert SettlementBanks.settlement_code("airteltigo") == "ATL9"
    end

    test "ignores non-mobile-money entries when matching" do
      Emakola.Payments.PaystackClientMock
      |> expect(:list_banks, fn _params ->
        ok([
          %{"slug" => "mtn-bank", "name" => "MTN Bank", "code" => "WRONG", "type" => "ghipss"},
          %{
            "slug" => "mtn-mobile-money",
            "name" => "MTN",
            "code" => "MTN_RIGHT",
            "type" => "mobile_money"
          }
        ])
      end)

      assert SettlementBanks.settlement_code("mtn") == "MTN_RIGHT"
    end
  end

  describe "settlement_code/1 — static fallback" do
    test "falls back to the static code when the client errors (no keys / network)" do
      Emakola.Payments.PaystackClientMock
      |> expect(:list_banks, fn _params -> {:error, :timeout} end)

      assert SettlementBanks.settlement_code("mtn") == "MTN"
    end

    test "falls back when Paystack returns status false" do
      Emakola.Payments.PaystackClientMock
      |> expect(:list_banks, fn _params ->
        {:ok, %{"status" => false, "message" => "Invalid key"}}
      end)

      assert SettlementBanks.settlement_code("vodafone") == "VOD"
    end

    test "falls back when the provider is absent from the live list" do
      Emakola.Payments.PaystackClientMock
      |> expect(:list_banks, fn _params ->
        ok([
          %{
            "slug" => "vod-mobile-money",
            "name" => "Vodafone",
            "code" => "VOD",
            "type" => "mobile_money"
          }
        ])
      end)

      assert SettlementBanks.settlement_code("mtn") == "MTN"
    end
  end

  describe "settlement_code/1 — unknown provider" do
    test "returns the input unchanged without calling the API" do
      # No Mox expectation set: an unknown provider must not hit list_banks.
      assert SettlementBanks.settlement_code("glo") == "glo"
    end
  end
end
