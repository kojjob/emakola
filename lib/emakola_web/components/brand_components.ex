defmodule EmakolaWeb.BrandComponents do
  @moduledoc """
  The Makola.io mark, drawn inline so it can move.

  The mark is a market stall: pitched roof, scalloped valance, two posts and a
  counter. Rendering it inline rather than as `<img>` costs one extra element
  per page and buys animation, per-tone recolouring and no second request —
  which matters on the connections our merchants actually have.

  Motion lives in `assets/css/app.css`. Every part is authored in its finished
  state and the keyframes sit behind `prefers-reduced-motion: no-preference`,
  so a viewer who has asked for stillness gets the mark, never an empty box.

  For a plain static mark in a context that cannot take inline SVG (email,
  `og:image`, the press kit) use `/images/emakola-logo.svg` instead.
  """

  use Phoenix.Component

  @gold "#d4a843"
  @ink "#0c1526"
  @snow "#f1f5f9"

  @valance "M5 23 H59 V29 A4.5 4.5 0 0 1 50 29 A4.5 4.5 0 0 1 41 29 A4.5 4.5 0 0 1 32 29 " <>
             "A4.5 4.5 0 0 1 23 29 A4.5 4.5 0 0 1 14 29 A4.5 4.5 0 0 1 5 29 Z"

  # Six half-discs spanning the same 54px the one-piece valance covers. Only the
  # loading state needs them apart, so only it pays for the extra five elements.
  @scallops [
    "M5 29 A4.5 4.5 0 0 0 14 29 Z",
    "M14 29 A4.5 4.5 0 0 0 23 29 Z",
    "M23 29 A4.5 4.5 0 0 0 32 29 Z",
    "M32 29 A4.5 4.5 0 0 0 41 29 Z",
    "M41 29 A4.5 4.5 0 0 0 50 29 Z",
    "M50 29 A4.5 4.5 0 0 0 59 29 Z"
  ]

  @doc """
  Renders the Makola.io stall mark.

  ## Motion

    * `"none"` — still. The default; use it anywhere the mark is furniture.
    * `"reveal"` — the stall assembles over 1.1s. First paint only.
    * `"loading"` — the awning ripples. Our spinner.
    * `"awaiting"` — a coin falls in through the front. Payment pending.
    * `"paid"` — the counter turns green and a tick lands. Plays once.
    * `"splash"` — the mark breathes. Cold start.

  ## Examples

      <.logo_mark motion="reveal" tone="reversed" size={32} />
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
      |> assign(:structure, if(assigns.tone == "reversed", do: @snow, else: @ink))
      |> assign(:gold, @gold)
      |> assign(:valance, @valance)
      |> assign(:scallops, @scallops)
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
      <circle :if={@motion == "awaiting"} class="logo-coin" cx="32" cy="38" r="4.6" fill="#b98a1f" />
      <path class="logo-roof" d="M32 7 L59 23 H5 Z" fill={@structure} />
      <rect :if={@motion == "loading"} x="5" y="23" width="54" height="6" fill={@gold} />
      <path
        :for={scallop <- if(@motion == "loading", do: @scallops, else: [])}
        class="logo-scallop"
        d={scallop}
        fill={@gold}
      />
      <path :if={@motion != "loading"} class="logo-valance" d={@valance} fill={@gold} />
      <rect class="logo-post-l" x="10" y="29" width="5" height="15" rx="1.5" fill={@structure} />
      <rect class="logo-post-r" x="49" y="29" width="5" height="15" rx="1.5" fill={@structure} />
      <rect class="logo-bar" x="6" y="43" width="52" height="6" rx="3" fill={@gold} />
      <path
        class="logo-front"
        d="M11 49 H53 V57 A3 3 0 0 1 50 60 H14 A3 3 0 0 1 11 57 Z"
        fill={@structure}
      />
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
end
