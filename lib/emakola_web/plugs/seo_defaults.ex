defmodule EmakolaWeb.Plugs.SEODefaults do
  @moduledoc """
  Plug that sets default SEO assigns for storefront pages.

  Applied in the router for the storefront scope. Sets sensible
  defaults that LiveViews can override in their mount/3.

  Default assigns:
    - `:page_title` — nil (falls back to root layout default)
    - `:meta_description` — nil (falls back to root layout default)
    - `:og_image` — nil
    - `:canonical_url` — nil
    - `:robots` — "index, follow"
    - `:json_ld` — nil
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn
    |> assign_default(:page_title, nil)
    |> assign_default(:meta_description, nil)
    |> assign_default(:og_image, nil)
    |> assign_default(:canonical_url, nil)
    |> assign_default(:robots, "index, follow")
    |> assign_default(:json_ld, nil)
  end

  defp assign_default(conn, key, default) do
    if Map.has_key?(conn.assigns, key) do
      conn
    else
      assign(conn, key, default)
    end
  end
end
