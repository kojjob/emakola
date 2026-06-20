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
end
