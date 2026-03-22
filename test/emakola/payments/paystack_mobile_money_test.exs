defmodule Emakola.Payments.Gateways.PaystackMobileMoneyTest do
  @moduledoc "Tests for Paystack mobile money and channel-specific payment flows."

  use ExUnit.Case, async: true

  import Mox

  alias Emakola.Payments.Gateways.Paystack

  setup :verify_on_exit!

  describe "initiate_payment/1 with mobile_money channel" do
    test "includes channels: [\"mobile_money\"] in API payload" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        assert body.channels == ["mobile_money"]

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/momo",
             "access_code" => "momo123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        order_id: "order-uuid-456",
        callback_url: "https://example.com/callback",
        channel: "mobile_money",
        mobile_money_provider: "mtn",
        phone: "0241234567"
      }

      assert {:ok, result} = Paystack.initiate_payment(params)
      assert result.authorization_url == "https://checkout.paystack.com/momo"
    end

    test "includes mobile_money_provider 'mtn' in API payload" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        assert body.channels == ["mobile_money"]
        assert body.metadata.mobile_money_provider == "mtn"

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/mtn",
             "access_code" => "mtn123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 200_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "mobile_money",
        mobile_money_provider: "mtn",
        phone: "0241234567"
      }

      assert {:ok, _result} = Paystack.initiate_payment(params)
    end

    test "includes mobile_money_provider 'vod' for Vodafone Cash" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        assert body.channels == ["mobile_money"]
        assert body.metadata.mobile_money_provider == "vod"

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/vod",
             "access_code" => "vod123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 100_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "mobile_money",
        mobile_money_provider: "vod",
        phone: "0201234567"
      }

      assert {:ok, _result} = Paystack.initiate_payment(params)
    end

    test "includes mobile_money_provider 'tgo' for AirtelTigo" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        assert body.channels == ["mobile_money"]
        assert body.metadata.mobile_money_provider == "tgo"

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/tgo",
             "access_code" => "tgo123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 300_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "mobile_money",
        mobile_money_provider: "tgo",
        phone: "0271234567"
      }

      assert {:ok, _result} = Paystack.initiate_payment(params)
    end

    test "includes phone number in metadata for mobile money" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        assert body.metadata.phone == "0241234567"

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/momo",
             "access_code" => "momo123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "mobile_money",
        mobile_money_provider: "mtn",
        phone: "0241234567"
      }

      assert {:ok, _result} = Paystack.initiate_payment(params)
    end
  end

  describe "initiate_payment/1 with card channel" do
    test "includes channels: [\"card\"] in API payload" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        assert body.channels == ["card"]

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/card",
             "access_code" => "card123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 750_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "card"
      }

      assert {:ok, result} = Paystack.initiate_payment(params)
      assert result.authorization_url == "https://checkout.paystack.com/card"
    end
  end

  describe "initiate_payment/1 with bank channel" do
    test "includes channels: [\"bank\"] in API payload" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        assert body.channels == ["bank"]

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/bank",
             "access_code" => "bank123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 1_000_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "bank"
      }

      assert {:ok, _result} = Paystack.initiate_payment(params)
    end
  end

  describe "initiate_payment/1 without channel (default behavior)" do
    test "does not include channels key when no channel specified" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        refute Map.has_key?(body, :channels)

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/default",
             "access_code" => "def123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123"
      }

      assert {:ok, _result} = Paystack.initiate_payment(params)
    end
  end

  describe "phone number validation" do
    test "returns error when phone is missing for mobile_money channel" do
      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "mobile_money",
        mobile_money_provider: "mtn"
      }

      assert {:error, {:validation_error, message}} = Paystack.initiate_payment(params)
      assert message =~ "phone"
    end

    test "returns error for invalid Ghana phone number format" do
      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "mobile_money",
        mobile_money_provider: "mtn",
        phone: "12345"
      }

      assert {:error, {:validation_error, message}} = Paystack.initiate_payment(params)
      assert message =~ "phone"
    end

    test "accepts valid 10-digit Ghana phone number starting with 0" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        assert body.metadata.phone == "0241234567"

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/momo",
             "access_code" => "momo123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "mobile_money",
        mobile_money_provider: "mtn",
        phone: "0241234567"
      }

      assert {:ok, _result} = Paystack.initiate_payment(params)
    end

    test "normalizes +233 prefix to 0 format" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        # +233241234567 should become 0241234567
        assert body.metadata.phone == "0241234567"

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/momo",
             "access_code" => "momo123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "mobile_money",
        mobile_money_provider: "mtn",
        phone: "+233241234567"
      }

      assert {:ok, _result} = Paystack.initiate_payment(params)
    end

    test "normalizes 233 prefix (without +) to 0 format" do
      Emakola.HTTPClientMock
      |> expect(:post, fn _url, opts ->
        body = opts[:json]
        assert body.metadata.phone == "0241234567"

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "authorization_url" => "https://checkout.paystack.com/momo",
             "access_code" => "momo123",
             "reference" => body.reference
           }
         }}
      end)

      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "mobile_money",
        mobile_money_provider: "mtn",
        phone: "233241234567"
      }

      assert {:ok, _result} = Paystack.initiate_payment(params)
    end
  end

  describe "invalid provider" do
    test "returns error for unknown mobile_money_provider" do
      params = %{
        amount: 500_000,
        email: "customer@example.com",
        currency: "GHS",
        store_id: "store-uuid-123",
        channel: "mobile_money",
        mobile_money_provider: "unknown_provider",
        phone: "0241234567"
      }

      assert {:error, {:validation_error, message}} = Paystack.initiate_payment(params)
      assert message =~ "provider"
    end
  end
end
