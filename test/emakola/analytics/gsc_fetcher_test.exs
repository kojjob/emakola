defmodule Emakola.Analytics.GscFetcherTest do
  # async: false — mutates the :gsc_credentials / :http_client application env.
  use ExUnit.Case, async: false

  import Mox

  alias Emakola.Analytics.GscFetcher

  setup :verify_on_exit!

  setup do
    Application.put_env(:emakola, :http_client, Emakola.HTTPClientMock)
    prev = Application.get_env(:emakola, :gsc_credentials)

    on_exit(fn ->
      Application.put_env(:emakola, :http_client, Emakola.HTTPClientMock)

      if prev,
        do: Application.put_env(:emakola, :gsc_credentials, prev),
        else: Application.delete_env(:emakola, :gsc_credentials)
    end)

    :ok
  end

  test "ships dark: returns {:ok, []} with no credentials" do
    Application.delete_env(:emakola, :gsc_credentials)
    assert {:ok, []} = GscFetcher.fetch("org-1")
  end

  test "queries the Search Console API and maps rows to SearchConsoleData shape" do
    Application.put_env(:emakola, :gsc_credentials, "test-token")

    expect(Emakola.HTTPClientMock, :post, fn url, opts ->
      assert url =~ "searchAnalytics/query"
      assert {"authorization", "Bearer test-token"} in opts[:headers]
      assert opts[:json].dimensions == ["query", "page"]

      {:ok,
       %{
         "rows" => [
           %{
             "keys" => ["kente cloth", "https://makola.io/shops/greater-accra"],
             "clicks" => 5,
             "impressions" => 120,
             "position" => 8.4,
             "ctr" => 0.041
           }
         ]
       }}
    end)

    assert {:ok, [row]} = GscFetcher.fetch("org-1")
    assert row.keyword == "kente cloth"
    assert row.page == "https://makola.io/shops/greater-accra"
    assert row.clicks == 5
    assert row.position == 8.4
    assert %DateTime{} = row.fetched_at
  end

  test "rejects malformed credentials without calling the API" do
    Application.put_env(:emakola, :gsc_credentials, %{wrong: true})
    assert {:error, :invalid_gsc_credentials} = GscFetcher.fetch("org-1")
  end

  test "handles an empty API response" do
    Application.put_env(:emakola, :gsc_credentials, "test-token")
    expect(Emakola.HTTPClientMock, :post, fn _url, _opts -> {:ok, %{}} end)
    assert {:ok, []} = GscFetcher.fetch("org-1")
  end

  describe "Goth-issued service-account tokens" do
    setup do
      Application.put_env(:emakola, :goth_module, __MODULE__.GothStub)
      on_exit(fn -> Application.delete_env(:emakola, :goth_module) end)
    end

    test "a {:goth, name} credential is exchanged for a live bearer token" do
      Application.put_env(:emakola, :gsc_credentials, {:goth, :working_server})

      expect(Emakola.HTTPClientMock, :post, fn _url, opts ->
        assert {"authorization", "Bearer goth-issued-token"} in opts[:headers]
        {:ok, %{}}
      end)

      assert {:ok, []} = GscFetcher.fetch("org-1")
    end

    test "a Goth failure is reported and the API is never called" do
      Application.put_env(:emakola, :gsc_credentials, {:goth, :broken_server})

      # No HTTPClientMock expectation: calling the API without a token would
      # fail verify_on_exit! as an unexpected call.
      assert {:error, {:goth_error, :account_not_authorized}} = GscFetcher.fetch("org-1")
    end
  end

  # Regression guard, not a TDD-red test: `site_url/0` already honours
  # :gsc_site_url. It exists because a Search Console *Domain* property is
  # addressed as `sc-domain:makola.io` — the endpoint URL default is the
  # URL-prefix form and 403s against a Domain property. This pins the encoding
  # so a future "simplification" of site_url/0 can't silently reintroduce that.
  test "a Domain property's sc-domain: identifier reaches the API percent-encoded" do
    Application.put_env(:emakola, :gsc_credentials, "test-token")
    Application.put_env(:emakola, :gsc_site_url, "sc-domain:makola.io")
    on_exit(fn -> Application.delete_env(:emakola, :gsc_site_url) end)

    expect(Emakola.HTTPClientMock, :post, fn url, _opts ->
      assert url =~ "/sites/sc-domain%3Amakola.io/searchAnalytics/query"
      {:ok, %{}}
    end)

    assert {:ok, []} = GscFetcher.fetch("org-1")
  end

  defmodule GothStub do
    def fetch(:working_server), do: {:ok, %{token: "goth-issued-token"}}
    def fetch(:broken_server), do: {:error, :account_not_authorized}
  end
end
