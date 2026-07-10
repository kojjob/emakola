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
  @share_clicks_session_key "earn_share_clicks"

  @utm_keys ~w(utm_source utm_medium utm_campaign utm_content utm_term)

  def init(opts), do: opts

  def call(conn, _opts) do
    captured = capture(conn.params)
    conn = maybe_record_share_click(conn, conn.params)

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
    base =
      Enum.reduce(@utm_keys, %{}, fn key, acc ->
        case Map.get(params, key) do
          val when is_binary(val) and val != "" -> Map.put(acc, key, val)
          _ -> acc
        end
      end)

    base =
      case Map.get(params, "share") do
        token when is_binary(token) and byte_size(token) <= 100 and token != "" ->
          Map.put(base, "share_token", token)

        _ ->
          base
      end

    case Map.get(params, "ref") do
      "whatsapp" -> Map.put(base, "click_to_whatsapp", true)
      _ -> base
    end
  end

  defp capture(_params), do: %{}

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
end
