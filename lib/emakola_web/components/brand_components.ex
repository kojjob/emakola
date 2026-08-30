defmodule EmakolaWeb.BrandComponents do
  @moduledoc """
  The Makola.io mark, drawn inline so it can move.

  The mark is a cowrie struck as a coin: one gold circle, one ink slit, ten
  teeth. The cowrie was West Africa's money before any bank printed one, and
  the circle makes it read as shell and coin in the same glance. Rendering it
  inline rather than as `<img>` costs one extra element per page and buys
  animation, per-tone recolouring and no second request — which matters on the
  connections our merchants actually have.

  Motion lives in `assets/css/app.css`. Every part is authored in its finished
  state and the keyframes sit behind `prefers-reduced-motion: no-preference`,
  so a viewer who has asked for stillness gets the mark, never an empty box.

  For a plain static mark in a context that cannot take inline SVG (email,
  `og:image`, the press kit) use `/images/emakola-logo.svg` instead.

  ## Where this mark does not go

  Not on the storefront. A shopper is buying from the merchant's shop, not from
  us — the storefront is themed per merchant for exactly that reason, and the
  MoMo waiting state is deliberately painted in the network's own colours
  because that is the cue the shopper needs. Our mark belongs on merchant and
  platform surfaces.

  Not inline beside button text either. At 16px the teeth fill in and there is
  nothing left to animate; keep the existing icon spinners for that.
  """

  use Phoenix.Component

  @gold "#d4a843"
  @ink "#0c1526"
  @coin_gold "#b98a1f"

  @slit "M31 11 C27 21 27 43 30 53"

  # Ten teeth, five per side, ordered top-to-bottom down each side of the slit.
  # Separate paths so the loading shimmer and the reveal can address each one.
  @teeth [
    "M26.5 17 L22.5 15.5",
    "M25.2 24 L20.8 23",
    "M24.8 31 L20.2 30.7",
    "M25 38 L20.6 38.5",
    "M26 45 L22 46.5",
    "M34 17.5 L38 16",
    "M33 24.5 L37.3 23.6",
    "M32.7 31.5 L37 31.3",
    "M32.9 38.5 L37 39",
    "M33.8 45.5 L37.6 46.8"
  ]

  @doc """
  Renders the Makola.io cowrie-coin mark.

  ## Motion

    * `"none"` — still. The default; use it anywhere the mark is furniture.
    * `"reveal"` — the coin is struck and the teeth bite in over 1.1s. First paint only.
    * `"loading"` — the teeth shimmer down the shell. Our spinner.
    * `"awaiting"` — a small coin falls and sinks into the slit. Payment pending.
    * `"paid"` — the face flashes green and a tick lands. Plays once.
    * `"splash"` — the mark breathes. Cold start.

  ## Tone

  The coin is tone-invariant: the gold face and ink detail read on light and
  dark surfaces alike, so `"ink"` and `"reversed"` render identically. The
  attribute stays so existing call sites keep compiling.

  ## Examples

      <.logo_mark motion="reveal" size={32} />
      <.logo_mark motion="loading" label="Loading" />
  """
  attr :motion, :string, default: "none", values: ~w(none reveal loading awaiting paid splash)
  attr :tone, :string, default: "ink", values: ~w(ink reversed)
  attr :size, :integer, default: 40
  attr :label, :string, default: nil, doc: "accessible name; omit to render it decoratively"
  attr :class, :any, default: nil

  def logo_mark(assigns) do
    assigns =
      assigns
      |> assign(:gold, @gold)
      |> assign(:ink, @ink)
      |> assign(:coin_gold, @coin_gold)
      |> assign(:slit, @slit)
      |> assign(:teeth, @teeth)
      |> assign(
        :motion_class,
        if(assigns.motion == "none", do: nil, else: "logo-#{assigns.motion}")
      )

    ~H"""
    <svg
      viewBox="0 0 64 64"
      width={@size}
      height={@size}
      class={[@motion_class, @class]}
      role={@label && "img"}
      aria-label={@label}
      aria-hidden={is_nil(@label) && "true"}
    >
      <circle class="logo-face" cx="32" cy="32" r="26" fill={@gold} />
      <path
        class="logo-slit"
        d={@slit}
        stroke={@ink}
        stroke-width="5"
        stroke-linecap="round"
        fill="none"
      />
      <g class="logo-teeth" stroke={@ink} stroke-width="3" stroke-linecap="round" fill="none">
        <path :for={tooth <- @teeth} class="logo-tooth" d={tooth} />
      </g>
      <circle :if={@motion == "awaiting"} class="logo-coin" cx="32" cy="26" r="5" fill={@coin_gold} />
      <g :if={@motion == "paid"} class="logo-tick">
        <circle cx="48" cy="14" r="12" fill="#10b981" />
        <path
          d="M42 14 L46.5 18.5 L54 10.5"
          fill="none"
          stroke="#ffffff"
          stroke-width="3.2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </g>
    </svg>
    """
  end

  @doc """
  A block-level loading state for a panel that is waiting on data.

  Replaces a bare "Loading…" line. The teeth shimmer, the label says what is
  being waited on, and the whole thing announces itself once to a screen
  reader — the mark stays decorative so the label is not read twice.

  For an inline spinner beside button text, keep `hero-arrow-path`.

  ## Examples

      <.brand_loader label="Checking invite" />
      <.brand_loader label="Loading offers" size={48} />
  """
  attr :label, :string, default: "Loading"
  attr :size, :integer, default: 56
  attr :tone, :string, default: "ink", values: ~w(ink reversed)
  attr :class, :any, default: nil

  def brand_loader(assigns) do
    ~H"""
    <div
      class={["flex flex-col items-center justify-center gap-3 py-16", @class]}
      role="status"
      aria-live="polite"
    >
      <.logo_mark motion="loading" tone={@tone} size={@size} />
      <span class="text-sm text-slate-500">{@label}</span>
    </div>
    """
  end
end
