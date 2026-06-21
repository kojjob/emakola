defmodule EmakolaWeb.Plugs.RecentlyViewedStores do
  @moduledoc """
  Cookie-based "recently viewed stores" tracker.

  Reads `request_path` on every request; if it matches `/s/<slug>...`,
  prepends `<slug>` to the `recently_viewed_stores` cookie — a
  comma-separated list of store slugs, deduped (most-recent first) and
  capped at 8 entries. The cookie is `http_only`, `same_site=Lax`, and
  not signed; it carries no privileged information, only public store
  slugs already present in the URL.

  ## Behaviour

  * **Storefront paths only.** Non-storefront paths (`/`, `/admin/...`,
    `/products`, etc.) leave the cookie untouched.
  * **Slug allowlist.** The path segment must match
    `~r/\\A[a-z0-9][a-z0-9-]{0,62}\\z/` to be recorded — this rejects
    path traversal (`..`), querystring confusion, semicolons, percent
    encoding, and the empty string. Anything else is dropped silently.
  * **Dedupe + cap.** Re-visiting an already-tracked store moves it to
    the front of the list. The list is capped at 8 entries; older ones
    fall off.
  * **No DB calls.** This plug never queries the database. Validation
    of slug existence happens later (in the LiveView consumer).

  ## Reading the cookie

  LiveViews and controllers read the cookie via `list_from_cookie/1`,
  passing `conn.cookies` (controllers) or
  `get_connect_params(socket)["recently_viewed_stores_cookies"]`
  (LiveView mount). The integrating LiveView (`StoresLive`) is
  responsible for filtering the slug list against existing public
  stores before rendering.
  """

  import Plug.Conn

  @behaviour Plug

  @cookie_name "recently_viewed_stores"
  @max_slugs 8
  # 30 days
  @max_age 60 * 60 * 24 * 30

  # Lowercase letters / digits / hyphen, must start with alnum,
  # 1..63 chars total. Rejects "..", ";", "/", "%", "?", "#", and "".
  @slug_regex ~r/\A[a-z0-9][a-z0-9-]{0,62}\z/

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: path} = conn, _opts) do
    case extract_slug(path) do
      nil -> conn
      slug -> update_cookie(conn, slug)
    end
  end

  @doc """
  Parses the cookie string into a list of slugs, capped at 8.

  Accepts the `conn.cookies` map (or the LiveView `connect_params`
  cookie subset). Missing or empty cookies return `[]`.

  Note: this is a pure parser. Callers should still validate that the
  returned slugs correspond to existing, public stores before rendering.
  """
  @spec list_from_cookie(map()) :: [String.t()]
  def list_from_cookie(cookies) when is_map(cookies) do
    cookies
    |> Map.get(@cookie_name, "")
    |> case do
      val when is_binary(val) -> val
      _ -> ""
    end
    |> String.split(",", trim: true)
    |> Enum.take(@max_slugs)
  end

  def list_from_cookie(_), do: []

  @doc "Cookie name, exposed for tests and consumers."
  @spec cookie_name() :: String.t()
  def cookie_name, do: @cookie_name

  defp extract_slug("/@" <> rest) do
    rest
    |> String.split("/", parts: 2)
    |> List.first()
    |> sanitize_slug()
  end

  defp extract_slug(_), do: nil

  defp sanitize_slug(slug) when is_binary(slug) do
    if Regex.match?(@slug_regex, slug), do: slug, else: nil
  end

  defp sanitize_slug(_), do: nil

  defp update_cookie(conn, slug) do
    conn = fetch_cookies(conn)

    existing =
      conn.cookies
      |> Map.get(@cookie_name, "")
      |> case do
        val when is_binary(val) -> val
        _ -> ""
      end
      |> String.split(",", trim: true)

    new_list =
      [slug | Enum.reject(existing, &(&1 == slug))]
      |> Enum.take(@max_slugs)

    put_resp_cookie(conn, @cookie_name, Enum.join(new_list, ","),
      max_age: @max_age,
      http_only: true,
      same_site: "Lax",
      sign: false
    )
  end
end
