defmodule Emakola.Analytics.GscFetcher do
  @moduledoc """
  Real Google Search Console fetcher (SEO Phase 5) — replaces the stub seam in
  `GscSyncWorker`, surfacing "queries you almost rank for" to feed content
  decisions.

  Ships dark: with no `:gsc_credentials` it returns `{:ok, []}` (nothing fetched,
  nothing logged). When configured, it queries the Search Console
  `searchAnalytics.query` API through the injectable `:http_client` and maps rows
  to the `SearchConsoleData` shape.

  Auth is deliberately injected, not baked in: `:gsc_credentials` carries a usable
  access token (a string, or `%{access_token: ...}`). Production wires that to a
  Goth-issued service-account token — a config concern, so this module stays
  testable without the Google auth stack.
  """

  @api_base "https://searchconsole.googleapis.com/webmasters/v3/sites"
  @lookback_days 28
  @row_limit 100

  @spec fetch(any()) :: {:ok, [map()]} | {:error, term()}
  def fetch(_org_id) do
    case Application.get_env(:emakola, :gsc_credentials) do
      nil ->
        {:ok, []}

      credentials ->
        with {:ok, token} <- access_token(credentials),
             {:ok, body} <- query(token) do
          {:ok, parse_rows(body)}
        end
    end
  end

  defp query(token) do
    url = "#{@api_base}/#{URI.encode_www_form(site_url())}/searchAnalytics/query"
    {start_date, end_date} = date_range()

    body = %{
      startDate: start_date,
      endDate: end_date,
      dimensions: ["query", "page"],
      rowLimit: @row_limit
    }

    headers = [{"authorization", "Bearer #{token}"}, {"content-type", "application/json"}]

    http_client().post(url, json: body, headers: headers)
  end

  defp parse_rows(%{"rows" => rows}) when is_list(rows) do
    fetched_at = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.map(rows, fn row ->
      [keyword, page] = keys(row)

      %{
        keyword: keyword,
        page: page,
        clicks: row["clicks"],
        impressions: row["impressions"],
        position: row["position"],
        ctr: row["ctr"],
        fetched_at: fetched_at
      }
    end)
  end

  defp parse_rows(_), do: []

  defp keys(%{"keys" => [keyword, page | _]}), do: [keyword, page]
  defp keys(%{"keys" => [keyword]}), do: [keyword, nil]
  defp keys(_), do: [nil, nil]

  defp access_token(%{access_token: token}) when is_binary(token), do: {:ok, token}
  defp access_token(token) when is_binary(token), do: {:ok, token}

  # Service-account auth: the token is fetched per call, never frozen in
  # config — Goth's tokens expire hourly.
  defp access_token({:goth, name}) do
    case goth_module().fetch(name) do
      {:ok, %{token: token}} -> {:ok, token}
      {:error, reason} -> {:error, {:goth_error, reason}}
    end
  end

  defp access_token(_), do: {:error, :invalid_gsc_credentials}

  defp site_url, do: Application.get_env(:emakola, :gsc_site_url) || EmakolaWeb.Endpoint.url()

  defp date_range do
    today = Date.utc_today()
    {today |> Date.add(-@lookback_days) |> Date.to_iso8601(), Date.to_iso8601(today)}
  end

  defp http_client, do: Application.get_env(:emakola, :http_client, Emakola.HTTPClient.Req)

  defp goth_module, do: Application.get_env(:emakola, :goth_module, Goth)
end
