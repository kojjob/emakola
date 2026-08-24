defmodule Emakola.Infra.FlyCertsTest do
  use ExUnit.Case, async: true

  import Mox

  alias Emakola.Infra.FlyCerts

  setup :verify_on_exit!

  setup do
    Application.put_env(:emakola, Emakola.Infra.FlyCerts,
      api_token: "fly_test_token",
      app_name: "emakola",
      endpoint: "https://api.fly.io/graphql"
    )

    on_exit(fn -> Application.delete_env(:emakola, Emakola.Infra.FlyCerts) end)
    :ok
  end

  defp cert_body(overrides \\ %{}) do
    Map.merge(
      %{
        "hostname" => "kentekingdom.com",
        "clientStatus" => "Ready",
        "isConfigured" => true,
        "isApex" => true,
        "isAcmeAlpnConfigured" => true,
        "isAcmeDnsConfigured" => false,
        "isAcmeHttpConfigured" => false,
        "dnsValidationHostname" => "_acme-challenge.kentekingdom.com",
        "dnsValidationTarget" => "kentekingdom.com.56jyg89.flydns.net.",
        "rateLimitedUntil" => nil,
        "validationErrors" => []
      },
      overrides
    )
  end

  describe "add_certificate/1" do
    test "posts the addCertificate mutation with appId and hostname" do
      expect(Emakola.HTTPClientMock, :post, fn url, opts ->
        assert url == "https://api.fly.io/graphql"
        body = Keyword.fetch!(opts, :json)

        assert body.query =~ "addCertificate"
        assert body.variables == %{appId: "emakola", hostname: "kentekingdom.com"}

        headers = Keyword.fetch!(opts, :headers)
        assert {"authorization", "Bearer fly_test_token"} in headers

        {:ok, %{"data" => %{"addCertificate" => %{"certificate" => cert_body()}}}}
      end)

      assert {:ok, status} = FlyCerts.add_certificate("kentekingdom.com")
      assert status.hostname == "kentekingdom.com"
      assert status.client_status == "Ready"
      assert status.configured?
    end
  end

  describe "get_certificate/1" do
    test "parses a certificate that is still waiting on DNS" do
      expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
        cert = cert_body(%{"clientStatus" => "Awaiting configuration", "isConfigured" => false})
        {:ok, %{"data" => %{"app" => %{"certificate" => cert}}}}
      end)

      assert {:ok, status} = FlyCerts.get_certificate("kentekingdom.com")
      assert status.client_status == "Awaiting configuration"
      refute status.configured?
      refute status.ready?
    end

    test "reports ready? only for the Ready status" do
      expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, %{"data" => %{"app" => %{"certificate" => cert_body()}}}}
      end)

      assert {:ok, %{ready?: true}} = FlyCerts.get_certificate("kentekingdom.com")
    end

    test "surfaces the Let's Encrypt rate limit" do
      expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
        cert = cert_body(%{"rateLimitedUntil" => "2026-08-30T00:00:00Z"})
        {:ok, %{"data" => %{"app" => %{"certificate" => cert}}}}
      end)

      assert {:ok, status} = FlyCerts.get_certificate("kentekingdom.com")
      assert status.rate_limited_until == "2026-08-30T00:00:00Z"
    end

    test "surfaces validation errors as readable strings" do
      expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
        cert = cert_body(%{"validationErrors" => [%{"message" => "no AAAA record"}]})
        {:ok, %{"data" => %{"app" => %{"certificate" => cert}}}}
      end)

      assert {:ok, status} = FlyCerts.get_certificate("kentekingdom.com")
      assert status.validation_errors == ["no AAAA record"]
    end

    test "returns nil when the app has no certificate for that hostname" do
      expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, %{"data" => %{"app" => %{"certificate" => nil}}}}
      end)

      assert {:ok, nil} = FlyCerts.get_certificate("never-added.com")
    end
  end

  describe "delete_certificate/1" do
    test "posts the deleteCertificate mutation" do
      expect(Emakola.HTTPClientMock, :post, fn _url, opts ->
        body = Keyword.fetch!(opts, :json)
        assert body.query =~ "deleteCertificate"
        assert body.variables == %{appId: "emakola", hostname: "kentekingdom.com"}
        {:ok, %{"data" => %{"deleteCertificate" => %{"app" => %{"name" => "emakola"}}}}}
      end)

      assert :ok = FlyCerts.delete_certificate("kentekingdom.com")
    end
  end

  describe "error handling" do
    # GraphQL answers 200 on failure with an "errors" key, and HTTPClient.Req
    # maps every 2xx to {:ok, body}. Without an explicit check here, every Fly
    # failure would read as success.
    test "treats a 200 carrying GraphQL errors as an error" do
      expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
        {:ok, %{"errors" => [%{"message" => "You must be authenticated"}]}}
      end)

      assert {:error, {:fly_error, ["You must be authenticated"]}} =
               FlyCerts.add_certificate("kentekingdom.com")
    end

    test "passes a transport failure through" do
      expect(Emakola.HTTPClientMock, :post, fn _url, _opts -> {:error, :timeout} end)
      assert {:error, :timeout} = FlyCerts.add_certificate("kentekingdom.com")
    end

    test "passes an HTTP error status through" do
      expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
        {:error, %{status: 401, body: "unauthorized"}}
      end)

      assert {:error, %{status: 401}} = FlyCerts.add_certificate("kentekingdom.com")
    end
  end

  describe "ships dark" do
    test "makes no call at all without an API token" do
      Application.put_env(:emakola, Emakola.Infra.FlyCerts, api_token: nil, app_name: "emakola")

      # No Mox expectation: any HTTP call would fail verify_on_exit!.
      assert {:error, :not_configured} = FlyCerts.add_certificate("kentekingdom.com")
      assert {:error, :not_configured} = FlyCerts.get_certificate("kentekingdom.com")
      assert {:error, :not_configured} = FlyCerts.delete_certificate("kentekingdom.com")
    end

    test "configured?/0 reports whether certificates can be provisioned" do
      assert FlyCerts.configured?()
      Application.put_env(:emakola, Emakola.Infra.FlyCerts, api_token: nil)
      refute FlyCerts.configured?()
    end
  end
end
