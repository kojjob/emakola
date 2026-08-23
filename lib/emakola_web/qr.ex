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

  Markup is viewBox-scaled and carries no pixel dimensions, so the same call
  renders correctly on a low-end phone and on a printed poster — the containing
  box decides the size. In practice that box is
  `EmakolaWeb.QRComponents.qr_code/1`, which is where sizing lives; `:class` here
  is for a caller rendering a code outside that component.

  Renderers return **already-safe HTML** (`t:Phoenix.HTML.safe/0`), so templates
  interpolate them directly and no call site ever reaches for `raw/1`. That is
  deliberate: marking markup safe is a claim that needs justifying, and this is
  the only module positioned to justify it. It built the payload from an internal
  identifier, EQRCode emits pure geometry, the payload never reaches the markup,
  and `:id`/`:class` — the one place a caller's string *would* land in an
  attribute — are validated below. Scattering `raw/1` across templates would
  spread that claim to places that cannot make it.
  """

  alias EmakolaWeb.SEO.Canonical

  @typedoc """
  Anything carrying a short public code — `Emakola.Orders.PayLink`,
  `Emakola.Orders.SusuPlan`.

  Open map types (`optional(any()) => any()`) rather than the closed
  `%{code: String.t()}`, which means a map with *exactly* that key and so
  matches no Ash struct at all.
  """
  @type coded :: %{:code => String.t(), optional(any()) => any()}

  @typedoc "A store, or anything carrying its slug."
  @type store :: %{:slug => String.t(), optional(any()) => any()}

  @typedoc "An order, or anything carrying its number."
  @type order :: %{:order_number => String.t(), optional(any()) => any()}

  @svg_defaults [viewbox: true]

  # -- payloads ---------------------------------------------------------------
  #
  # Public because the admin's copy-link and WhatsApp-share affordances need the
  # same string the QR encodes — one definition, so the printed code and the
  # pasted link can never drift apart.

  @doc "Buyer-facing checkout URL for a pay link. Apex-only route."
  @spec pay_link_url(coded()) :: String.t()
  def pay_link_url(%{code: code}) when is_binary(code), do: Canonical.url("/pay/" <> code)

  @doc "Buyer-facing URL for a susu (lay-away) plan. Apex-only route."
  @spec susu_url(coded()) :: String.t()
  def susu_url(%{code: code}) when is_binary(code), do: Canonical.url("/susu/" <> code)

  @doc "A store's canonical home — the permanent \"my shop\" code."
  @spec store_url(store()) :: String.t()
  def store_url(%{slug: slug} = store) when is_binary(slug), do: Canonical.store_url(store)

  @doc "Order tracking URL, scoped to the store that owns the order."
  @spec order_tracking_url(store(), order()) :: String.t()
  def order_tracking_url(%{slug: slug} = store, %{order_number: number})
      when is_binary(slug) and is_binary(number) do
    Canonical.path(store, "/track/" <> number)
  end

  # -- rendering --------------------------------------------------------------

  @doc "QR of a pay link's checkout URL."
  @spec pay_link_svg(coded(), keyword()) :: Phoenix.HTML.safe()
  def pay_link_svg(%{code: _} = link, opts \\ []), do: render(pay_link_url(link), opts)

  @doc "QR of a susu plan's buyer URL."
  @spec susu_svg(coded(), keyword()) :: Phoenix.HTML.safe()
  def susu_svg(%{code: _} = plan, opts \\ []), do: render(susu_url(plan), opts)

  @doc "QR of a store's home — the code a merchant prints for their stall."
  @spec store_svg(store(), keyword()) :: Phoenix.HTML.safe()
  def store_svg(%{slug: _} = store, opts \\ []), do: render(store_url(store), opts)

  @doc "QR of an order's tracking page — for the packing slip."
  @spec order_tracking_svg(store(), order(), keyword()) :: Phoenix.HTML.safe()
  def order_tracking_svg(%{slug: _} = store, %{order_number: _} = order, opts \\ []) do
    render(order_tracking_url(store, order), opts)
  end

  # Reached only via the builders above, so `url` is always one of ours. See the
  # moduledoc for why the safe-marking happens here and nowhere else.
  defp render(url, opts) when is_binary(url) and is_list(opts) do
    url
    |> EQRCode.encode()
    |> EQRCode.svg(Keyword.merge(@svg_defaults, validate_markup_opts(opts)))
    |> Phoenix.HTML.raw()
  end

  # EQRCode writes :id and :class into the markup by hand (`key="val"`, no
  # escaping), and callers render the result with raw/1 — so a value carrying a
  # quote would break out of the attribute. Every legitimate value here is a CSS
  # class list or a DOM id, so refusing anything else is both sufficient and
  # louder than sanitising: a caller passing dynamic text gets an error rather
  # than silently-mangled markup.
  defp validate_markup_opts(opts) do
    Enum.each([:id, :class], fn key ->
      case Keyword.fetch(opts, key) do
        {:ok, value} when is_binary(value) ->
          unless value =~ ~r/^[A-Za-z0-9 _:\/\[\]\.-]*$/ do
            raise ArgumentError,
                  "QR #{key} must be a plain CSS token list, got: #{inspect(value)}"
          end

        {:ok, value} ->
          raise ArgumentError, "QR #{key} must be a string, got: #{inspect(value)}"

        :error ->
          :ok
      end
    end)

    opts
  end
end
