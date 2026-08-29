defmodule EmakolaWeb.Plugs.UtmCapture do
  @moduledoc """
  Captures UTM and click-source parameters from the request query string into
  the session. Persists across page navigation so the values are available at
  checkout to be written to `Order.attribution`.

  ## Captured keys

      utm_source   — "instagram", "tiktok", "whatsapp", "google", ...
      utm_medium   — "bio_link", "story", "dm", "post", ...
      utm_campaign — campaign tag, e.g. "spring-2026"
      utm_content  — creative variant
      utm_term     — paid keyword

  Plus the platform-specific shortcut:

      ?ref=whatsapp        → click_to_whatsapp = true (Phase 2 attribution)

  ## Behaviour

  * **First-touch wins.** Once a session has any captured UTM, subsequent
    requests that lack UTM params do **not** clear the existing session data.
    A new request that DOES have UTMs overwrites — last source attribution.
  * **No UI side-effects.** This plug only mutates the session; it does not
    redirect or render. Storefront pages render unchanged whether the plug
    runs or not.
  * **Empty params are no-ops.** Hitting any URL without `utm_*` keys leaves
    the session untouched.
  """

  import Plug.Conn

  @session_key "utm_attribution"
  @affiliate_clicks_session_key "affiliate_link_clicks"
  @share_clicks_session_key "earn_share_clicks"

  @utm_keys ~w(utm_source utm_medium utm_campaign utm_content utm_term)

  def init(opts), do: opts

  def call(conn, _opts) do
    captured = capture(conn.params)
    conn = maybe_record_share_click(conn, conn.params)
    conn = maybe_record_affiliate_click(conn, conn.params)

    case captured do
      empty when map_size(empty) == 0 ->
        conn

      attribution ->
        existing = get_session(conn, @session_key) || %{}

        merged =
          existing
          |> Map.merge(attribution)
          |> Map.put_new("first_seen_at", DateTime.utc_now() |> DateTime.to_iso8601())

        put_session(conn, @session_key, merged)
    end
  end

  @doc """
  Returns the captured attribution map for the current session, or `%{}` if
  none was captured. Used by checkout/order creation to populate
  `Order.attribution`.
  """
  @spec from_session(Plug.Conn.t()) :: map()
  def from_session(conn) do
    get_session(conn, @session_key) || %{}
  end

  defp capture(%{} = params) do
    params
    |> utm_keys()
    |> put_token(params, "share", "share_token")
    |> put_token(params, "aff", "affiliate_token")
    |> put_sales_team(params)
    |> put_click_to_whatsapp(params)
  end

  defp capture(_params), do: %{}

  defp utm_keys(params) do
    Enum.reduce(@utm_keys, %{}, fn key, acc ->
      case Map.get(params, key) do
        val when is_binary(val) and val != "" -> Map.put(acc, key, val)
        _ -> acc
      end
    end)
  end

  # Share and affiliate tokens are captured identically — opaque strings,
  # length-capped so a crafted URL cannot stuff the session. They are stored
  # under different keys because they pay different people.
  defp put_token(base, params, param, key) do
    case Map.get(params, param) do
      token when is_binary(token) and byte_size(token) <= 100 and token != "" ->
        Map.put(base, key, token)

      _ ->
        base
    end
  end

  defp put_sales_team(base, params) do
    case Ecto.UUID.cast(Map.get(params, "sales_team")) do
      {:ok, team_id} -> Map.put(base, "sales_team_id", team_id)
      :error -> base
    end
  end

  defp put_click_to_whatsapp(base, params) do
    case Map.get(params, "ref") do
      "whatsapp" -> Map.put(base, "click_to_whatsapp", true)
      _ -> base
    end
  end

  defp maybe_record_share_click(conn, %{"share" => token})
       when is_binary(token) and token != "" and byte_size(token) <= 100 do
    recorded = get_session(conn, @share_clicks_session_key) || []

    if token in recorded do
      conn
    else
      Emakola.Suppliers.SalesSharing.record_click(token)
      put_session(conn, @share_clicks_session_key, Enum.take([token | recorded], 20))
    end
  end

  defp maybe_record_share_click(conn, _params), do: conn

  # Same once-per-session dedupe as share clicks: a buyer browsing three pages
  # with the token in their session is one click, not three. The counter is
  # for the affiliate's own page and never a basis for money — commission
  # comes from PaymentSplit rows.
  defp maybe_record_affiliate_click(conn, %{"aff" => token})
       when is_binary(token) and token != "" and byte_size(token) <= 100 do
    recorded = get_session(conn, @affiliate_clicks_session_key) || []

    if token in recorded do
      conn
    else
      Emakola.Affiliates.Programme.record_click(token)
      put_session(conn, @affiliate_clicks_session_key, Enum.take([token | recorded], 20))
    end
  end

  defp maybe_record_affiliate_click(conn, _params), do: conn
end
