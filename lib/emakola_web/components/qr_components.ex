defmodule EmakolaWeb.QRComponents do
  @moduledoc """
  The shared way a QR code appears anywhere in Makola.

  A QR is the most literacy-free control the product has: the merchant shows a
  square, the buyer points a camera, and nobody types or reads anything. That
  is why the code leads every panel here rather than sitting beside a form
  field — on these screens it is the only element that needs no reading, so it
  earns the first position.

  The framing borrows from the object a trader already uses: a price card
  propped on the goods. The code sits on its own white plate with a real edge,
  captioned underneath in a few words, so it reads as something you could lift
  off the screen and pin up. The plate is not decoration — a QR needs a light
  quiet zone to scan at all.

  Every QR surface uses `qr_panel/1`, so the pay-link modal, the susu modal,
  the stall sign and the packing slip read as one family instead of four
  separately-invented cards.

  Markup comes from `EmakolaWeb.QR`, which builds every payload itself from
  internal identifiers, validates the only caller-supplied values that reach an
  attribute, and returns already-safe HTML. So there is no `raw/1` here: these
  components render a QR, they do not vouch for one.
  """
  use Phoenix.Component

  @doc """
  A QR code on its plate, captioned.

  Use `qr_panel/1` for a full surface; reach for this directly only when the
  code stands alone, as it does inside a modal.
  """
  attr :id, :string, required: true
  attr :svg, :any, required: true, doc: "safe markup from an EmakolaWeb.QR renderer"
  attr :caption, :string, default: nil, doc: "a few words at most — this is read at a glance"
  attr :class, :string, default: "", doc: "extra classes on the outer wrapper"

  def qr_code(assigns) do
    ~H"""
    <figure id={@id} class={["flex flex-col items-center gap-2.5", @class]}>
      <div class="bg-white p-3 rounded-card border border-slate-200 shadow-sm print:shadow-none print:border-0">
        <%!-- Bigger on paper than on screen. On screen the code sits beside its
              own controls and is scanned from arm's length; printed, it is a
              stall sign read across a stall, and a 1.7in square is too small
              for that. --%>
        <div class="w-40 h-40 print:w-72 print:h-72">{@svg}</div>
      </div>
      <figcaption
        :if={@caption}
        class="text-xs font-semibold tracking-wide text-slate-500 text-center print:text-base print:text-slate-900"
      >
        {@caption}
      </figcaption>
    </figure>
    """
  end

  @doc """
  A full QR surface: the code, what it is, and what to do with it.

  The right-hand column is deliberately bounded. A store URL is short, so
  letting its field stretch across a wide card strands the buttons at the far
  edge, far from the code they act on.

  The address is rendered twice on purpose. On screen it is a copy field, which
  is what a merchant actually uses. On paper it becomes plain text, because a
  buyer holding the printed sheet with no working camera has to be able to type
  it, and an input's chrome only gets in the way there.
  """
  attr :id, :string, required: true
  attr :svg, :any, required: true, doc: "safe markup from an EmakolaWeb.QR renderer"
  attr :title, :string, required: true, doc: "what this code is"
  attr :hint, :string, default: nil, doc: "what to do with it — keep it to a few words"
  attr :caption, :string, required: true, doc: "the label under the code itself"
  attr :url, :string, required: true, doc: "the address the code carries"
  attr :eyebrow, :string, default: nil, doc: "small line above the title, e.g. the store name"
  attr :class, :string, default: nil

  slot :actions, doc: "buttons — Copy, Print, and anything surface-specific"

  def qr_panel(assigns) do
    ~H"""
    <div id={@id} class={["flex flex-col sm:flex-row items-center sm:items-start gap-6", @class]}>
      <.qr_code id={"#{@id}-code"} svg={@svg} caption={@caption} class="shrink-0" />

      <div class="min-w-0 w-full max-w-md text-center sm:text-left">
        <p :if={@eyebrow} class="text-xs uppercase tracking-wide text-slate-400">{@eyebrow}</p>
        <h3 class="text-base font-bold text-slate-900">{@title}</h3>
        <p :if={@hint} class="text-sm text-slate-600 mt-1">{@hint}</p>

        <%!-- Screen: a field to copy from. Paper: the address as plain text. --%>
        <input
          type="text"
          id={"#{@id}-url"}
          readonly
          value={@url}
          class="mt-4 w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-control text-xs text-slate-700 print:hidden"
        />
        <p class="hidden print:block mt-3 text-sm text-slate-700 break-all">{@url}</p>

        <div
          :if={@actions != []}
          class="mt-3 flex flex-wrap justify-center sm:justify-start gap-2 print:hidden"
        >
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end
end
