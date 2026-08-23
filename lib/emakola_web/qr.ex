defmodule EmakolaWeb.QR do
  @moduledoc """
  QR payloads and QR SVG markup — the one place either is produced.

  Most Makola merchants read poorly, so every URL we ask them or their buyer to
  type is a literacy tax. A QR removes the typing entirely: the merchant shows a
  square, the buyer's own camera does the rest. No app, no keyboard.

  ## Why this module takes resources instead of URLs

  A QR is an instruction a phone obeys without anyone reading it first. A module
  that encoded a caller-supplied string would therefore let any path that reaches
  a merchant-controlled value turn Makola into a phishing redirector — the buyer
  scans a code shown on a Makola page and lands anywhere.

  So there is deliberately **no** public arity that accepts a bare URL. Every
  entry point takes a resource and composes the URL itself from internal
  identifiers. The guard is structural rather than a rule reviewers must
  remember at each call site: a binary matches no clause.

  Note that `Emakola.Accounts.TOTP`'s `# Safe to mark raw: EQRCode emits pure
  geometry` comment is a claim about the *markup* — it says nothing about whether
  the payload can be trusted, which is what this module exists to settle.

  ## Hosts

  URLs come from `EmakolaWeb.SEO.Canonical`, which composes them from config and
  never from the request host. That matters more here than it does for SEO: a
  printed poster outlives the session that rendered it, so a payload inheriting
  whichever host happened to serve the LiveView would be wrong the moment the
  sticker leaves the building.

  Store-scoped payloads therefore follow Canonical onto store subdomains if and
  when `:store_subdomain_base` is configured. Pay-link and susu payloads do not —
  those routes are `host: @apex_hosts` scoped in the router, so a subdomain
  cannot serve them.

  ## Rendering

  Markup is viewBox-scaled and carries no pixel dimensions, so one call renders
  correctly on a low-end phone and on a printed poster; size it with `:class` at
  the call site. Output is safe for `Phoenix.HTML.raw/1` — EQRCode emits pure
  geometry, and the payload never reaches the markup.
  """

  alias EmakolaWeb.SEO.Canonical

  @svg_defaults [viewbox: true]

  # -- payloads ---------------------------------------------------------------
  #
  # Public because the admin's copy-link and WhatsApp-share affordances need the
  # same string the QR encodes — one definition, so the printed code and the
  # pasted link can never drift apart.

  @doc "Buyer-facing checkout URL for a pay link. Apex-only route."
  @spec pay_link_url(%{code: String.t()}) :: String.t()
  def pay_link_url(%{code: code}) when is_binary(code), do: Canonical.url("/pay/" <> code)

  @doc "Buyer-facing URL for a susu (lay-away) plan. Apex-only route."
  @spec susu_url(%{code: String.t()}) :: String.t()
  def susu_url(%{code: code}) when is_binary(code), do: Canonical.url("/susu/" <> code)

  @doc "A store's canonical home — the permanent \"my shop\" code."
  @spec store_url(%{slug: String.t()}) :: String.t()
  def store_url(%{slug: slug} = store) when is_binary(slug), do: Canonical.store_url(store)

  @doc "Order tracking URL, scoped to the store that owns the order."
  @spec order_tracking_url(%{slug: String.t()}, %{order_number: String.t()}) :: String.t()
  def order_tracking_url(%{slug: slug} = store, %{order_number: number})
      when is_binary(slug) and is_binary(number) do
    Canonical.path(store, "/track/" <> number)
  end

  # -- rendering --------------------------------------------------------------

  @doc "QR of a pay link's checkout URL."
  @spec pay_link_svg(%{code: String.t()}, keyword()) :: String.t()
  def pay_link_svg(%{code: _} = link, opts \\ []), do: render(pay_link_url(link), opts)

  @doc "QR of a susu plan's buyer URL."
  @spec susu_svg(%{code: String.t()}, keyword()) :: String.t()
  def susu_svg(%{code: _} = plan, opts \\ []), do: render(susu_url(plan), opts)

  @doc "QR of a store's home — the code a merchant prints for their stall."
  @spec store_svg(%{slug: String.t()}, keyword()) :: String.t()
  def store_svg(%{slug: _} = store, opts \\ []), do: render(store_url(store), opts)

  @doc "QR of an order's tracking page — for the packing slip."
  @spec order_tracking_svg(%{slug: String.t()}, %{order_number: String.t()}, keyword()) ::
          String.t()
  def order_tracking_svg(%{slug: _} = store, %{order_number: _} = order, opts \\ []) do
    render(order_tracking_url(store, order), opts)
  end

  # Reached only via the builders above, so `url` is always one of ours.
  defp render(url, opts) when is_binary(url) and is_list(opts) do
    url
    |> EQRCode.encode()
    |> EQRCode.svg(Keyword.merge(@svg_defaults, opts))
  end
end
