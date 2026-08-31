defmodule EmakolaWeb.Admin.SupplyCatalogLive.ShowComponents do
  @moduledoc """
  Render components for the supplier offer page.

  The icon family itself lives in `Glyphs` — both catalogue pages draw from it.
  """

  use EmakolaWeb, :html

  import EmakolaWeb.Admin.SupplyCatalogLive.Glyphs

  @doc """
  Renders the 96px identity square: the supplier's photograph when they gave
  us one, the product glyph when they did not.

  The page used to hand half its width to an `aspect-square` frame that stayed
  empty for every offer without a photo — which is most of them.

  The glyph is drawn BEHIND the photograph rather than as its alternative.
  `app.js` hides an image that fails to load, and hiding it has to reveal
  something: a supplier whose file was deleted gets the glyph instead of an
  empty square.
  """
  attr :image_url, :string, default: nil
  attr :alt, :string, required: true

  def identity_slot(assigns) do
    ~H"""
    <div
      id="offer-identity"
      class="relative w-16 h-16 sm:w-24 sm:h-24 shrink-0 rounded-card overflow-hidden bg-primary-soft border border-emerald-100 flex items-center justify-center"
    >
      <.glyph name={:product} class="w-8 h-8 sm:w-11 sm:h-11 text-primary" stroke_width="1.6" />
      <img
        :if={@image_url}
        src={@image_url}
        alt={@alt}
        class="absolute inset-0 w-full h-full object-cover"
      />
    </div>
    """
  end

  @doc """
  Renders one tile in the money row.

  A tile with no `value` is LOCKED: the lock takes the icon square and the
  amount is drawn as a covered bar. An emptied cell reads as missing data; a
  covered one reads as a number somebody is holding back.

  A locked tile keeps its `tone`, so the chip stays violet or emerald rather
  than going grey: the lock and the covered bar already say "locked", and
  colour is what tells the three numbers apart at a glance.
  """
  attr :label, :string, required: true
  attr :sub, :string, required: true
  attr :value, :string, default: nil
  attr :icon, :atom, required: true
  attr :tone, :atom, default: :neutral, values: [:info, :accent, :neutral, :primary]
  attr :value_role, :string, default: nil, doc: "data-role on the amount, for tests to pin"
  attr :class, :string, default: nil
  slot :delta

  def money_tile(assigns) do
    ~H"""
    <div class={[
      "rounded-card border p-5 flex flex-col gap-3.5",
      @value && tile_wash(@tone),
      is_nil(@value) && "bg-gradient-to-br from-slate-100 to-surface border-border",
      @class
    ]}>
      <div class="flex items-start justify-between gap-3">
        <div class="flex flex-col gap-0.5">
          <span class={[
            "text-xs font-bold uppercase tracking-wider",
            @tone == :primary && @value && "text-primary-hover",
            !(@tone == :primary && @value) && "text-text-muted"
          ]}>
            {@label}
          </span>
          <span class="text-[11px] text-slate-400">{@sub}</span>
        </div>
        <div class={[
          "w-12 h-12 rounded-control flex items-center justify-center shrink-0 text-white",
          tile_chip(@tone)
        ]}>
          <.glyph name={if(@value, do: @icon, else: :lock)} class="w-6 h-6" stroke_width="1.8" />
        </div>
      </div>

      <div :if={@value} class="flex items-baseline gap-2.5 flex-wrap">
        <span
          data-role={@value_role}
          class={[
            "text-2xl sm:text-3xl font-bold tracking-tight tabular-nums",
            @tone == :primary && "text-primary-hover",
            @tone != :primary && "text-text"
          ]}
        >
          {@value}
        </span>
        {render_slot(@delta)}
      </div>

      <div :if={is_nil(@value)} class="flex flex-col gap-2">
        <span class="block w-21 h-[18px] rounded-md bg-border"></span>
        <span class="text-xs text-slate-400">Connect to see</span>
      </div>
    </div>
    """
  end

  defp tile_wash(:info), do: "bg-gradient-to-br from-info-soft to-surface border-border"
  defp tile_wash(:accent), do: "bg-gradient-to-br from-violet-50 to-surface border-border"

  defp tile_wash(:primary),
    do: "bg-gradient-to-br from-primary-soft to-surface border-emerald-200"

  defp tile_wash(_neutral), do: "bg-gradient-to-br from-slate-100 to-surface border-border"

  defp tile_chip(:info), do: "bg-info"
  defp tile_chip(:accent), do: "bg-violet-600"
  defp tile_chip(:primary), do: "bg-primary"
  defp tile_chip(_neutral), do: "bg-slate-500"

  @doc """
  Renders the page's one primary band — the action, and the reason to take it.

  Same shape, same place on the page in both states; only the verb changes.
  """
  attr :icon, :atom, required: true
  attr :title, :string, required: true
  attr :detail, :string, required: true
  attr :event, :string, required: true
  attr :action_label, :string, required: true

  def action_band(assigns) do
    ~H"""
    <div
      id="catalog-cta"
      class="rounded-card bg-primary-soft border border-emerald-200 p-5 flex flex-col sm:flex-row sm:items-center gap-4"
    >
      <div class="w-13 h-13 shrink-0 rounded-control bg-primary text-white flex items-center justify-center">
        <.glyph name={@icon} class="w-6 h-6" stroke_width="1.9" />
      </div>
      <div class="flex flex-col gap-1 grow min-w-0">
        <span class="text-[17px] font-bold text-emerald-950">{@title}</span>
        <span class="text-[13px] text-primary-hover leading-relaxed">{@detail}</span>
      </div>
      <button
        phx-click={@event}
        class="shrink-0 min-h-12 px-5 rounded-control bg-primary hover:bg-primary-hover text-white text-[15px] font-bold inline-flex items-center justify-center gap-2 cursor-pointer transition-colors"
      >
        <.glyph name={:plus} class="w-[18px] h-[18px]" stroke_width="2.1" />
        {@action_label}
      </button>
    </div>
    """
  end
end
