defmodule EmakolaWeb.QRComponents do
  @moduledoc """
  The shared way a QR code appears anywhere in Makola.

  A QR is the most literacy-free control the product has: the merchant shows a
  square, the buyer points a camera, and nobody types or reads anything. The
  framing here protects that. The code sits on its own white plate because a
  QR needs a light quiet zone to scan at all, and the caption stays to a few
  words — a merchant who struggles with a sentence still recognises a picture
  with three words under it.

  Markup comes from `EmakolaWeb.QR`, which builds every payload itself from
  internal identifiers, validates the only caller-supplied values that reach an
  attribute, and returns already-safe HTML. So there is no `raw/1` here: this
  component renders a QR, it does not vouch for one.
  """
  use Phoenix.Component

  @doc """
  Renders a QR code on a scannable white plate with an optional short caption.

  Pass `svg` from one of `EmakolaWeb.QR`'s renderers.
  """
  attr :id, :string, required: true
  attr :svg, :any, required: true, doc: "safe markup from an EmakolaWeb.QR renderer"
  attr :caption, :string, default: nil, doc: "a few words at most — this is read at a glance"
  attr :class, :string, default: "", doc: "extra classes on the outer wrapper"

  def qr_code(assigns) do
    ~H"""
    <figure id={@id} class={["flex flex-col items-center gap-2", @class]}>
      <div class="bg-white p-3 rounded-card border border-slate-200 print:border-0">
        <%!-- Bigger on paper than on screen. On screen the code sits beside its
              own controls and is scanned from arm's length; printed, it is a
              stall sign read across a stall, and a 1.7in square is too small
              for that. --%>
        <div class="w-40 h-40 print:w-72 print:h-72">{@svg}</div>
      </div>
      <figcaption
        :if={@caption}
        class="text-xs font-medium text-slate-500 text-center print:text-base"
      >
        {@caption}
      </figcaption>
    </figure>
    """
  end
end
