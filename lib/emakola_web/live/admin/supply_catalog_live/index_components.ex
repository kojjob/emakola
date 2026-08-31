defmodule EmakolaWeb.Admin.SupplyCatalogLive.IndexComponents do
  @moduledoc """
  The browse-suppliers card.

  Built for merchants who do not read fluently, so every fact is carried by a
  symbol in a fixed position and the words are the fallback rather than the
  channel: a coloured letter for the supplier (ticked when the reseller
  already deals with them), a tag for the price, coins for what stays with
  them, a bar for how much the supplier has left, a pin for dispatch.

  Digits are the exception worth naming — a trader who cannot read a sentence
  still reads `GH₵ 60`, so every money value here is a number, never a word.
  """

  use EmakolaWeb, :html

  import EmakolaWeb.Admin.SupplyCatalogLive.Glyphs

  @doc """
  Renders one offer in the browse grid.

  `margin` is `nil` for a supplier the merchant has no connection with, and
  the tile covers the amount instead of emptying it — the same locked
  language the offer page uses.
  """
  attr :id, :string, required: true
  attr :href, :string, required: true
  attr :title, :string, required: true
  attr :supplier, :string, required: true
  attr :image_url, :string, default: nil
  attr :price, :string, required: true
  attr :margin, :string, default: nil
  attr :connected?, :boolean, default: false
  attr :stock, :atom, required: true, values: [:in_stock, :low, :out]
  attr :dispatch, :string, default: nil
  attr :category, :string, default: nil

  def offer_card(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@href}
      class={[
        "group rounded-card border border-border bg-surface shadow-sm overflow-hidden",
        "flex flex-row sm:flex-col hover:shadow-md transition-shadow",
        @stock == :out && "opacity-70"
      ]}
    >
      <div
        data-role="card-art"
        class="relative w-[108px] shrink-0 sm:w-auto sm:h-[156px] bg-primary-soft flex items-center justify-center"
      >
        <.glyph name={:product} class="w-10 h-10 sm:w-14 sm:h-14 text-primary" stroke_width="1.5" />
        <img
          :if={@image_url}
          src={@image_url}
          alt={@title}
          class="absolute inset-0 w-full h-full object-cover group-hover:scale-[1.02] transition-transform"
        />
      </div>

      <div class="flex flex-col grow min-w-0">
        <div class="p-3.5 flex flex-col gap-3 grow">
          <div class="flex items-center gap-2.5">
            <span class="relative shrink-0">
              <span
                data-role="supplier-avatar"
                class={[
                  "w-[30px] h-[30px] rounded-[10px] flex items-center justify-center",
                  "text-[13px] font-extrabold text-white",
                  avatar_tone(@supplier)
                ]}
              >
                {String.first(@supplier)}
              </span>
              <span
                :if={@connected?}
                data-role="supplier-tick"
                class="absolute -right-1 -bottom-1 w-4 h-4 rounded-full bg-primary border-2 border-surface flex items-center justify-center"
              >
                <.glyph name={:check} class="w-2 h-2 text-white" stroke_width="4" />
              </span>
            </span>
            <span class="flex flex-col gap-1 min-w-0">
              <span class="text-[15px] font-bold leading-tight truncate">{@title}</span>
              <span class="text-[10px] text-slate-400 truncate">{@supplier}</span>
              <%!-- Its own line: beside the title it truncated to "Fashion & T…",
                  and a half-word is worth less than the 18px it saves. --%>
              <span
                :if={@category}
                data-role="card-category"
                class="self-start rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-bold text-text-muted truncate max-w-full"
                title={@category}
              >
                {@category}
              </span>
            </span>
          </div>

          <div class="flex flex-col gap-2 mt-auto">
            <span class="flex items-center gap-2.5">
              <.glyph name={:tag} class="w-5 h-5 text-text-muted" />
              <span class="flex flex-col">
                <span class="text-xl font-extrabold leading-tight tabular-nums">{@price}</span>
                <span class="text-[10px] text-slate-400">sells for</span>
              </span>
            </span>

            <span
              :if={@margin}
              data-role="card-margin"
              class="flex items-center gap-2.5 rounded-[11px] bg-primary-soft border border-emerald-200 px-2.5 py-2"
            >
              <.glyph name={:coins} class="w-5 h-5 text-primary-hover" />
              <span class="flex flex-col">
                <span class="text-[17px] font-extrabold leading-tight text-primary-hover tabular-nums">
                  {@margin}
                </span>
                <span class="text-[10px] font-bold text-primary">you keep</span>
              </span>
            </span>

            <span
              :if={is_nil(@margin)}
              data-role="card-locked"
              class="flex items-center gap-2.5 rounded-[11px] bg-slate-100 border border-border px-2.5 py-2"
            >
              <.glyph name={:lock} class="w-5 h-5 text-slate-400" stroke_width="2" />
              <span class="flex flex-col gap-1">
                <span class="block w-[76px] h-[15px] rounded-[5px] bg-border"></span>
                <span class="text-[10px] text-slate-400">you keep</span>
              </span>
            </span>
          </div>
        </div>

        <div class="flex items-center gap-2 px-3.5 py-2.5 border-t border-slate-100 bg-surface-subtle">
          <%!-- Length and colour, no number: SupplyStockStatus is status-only,
              because the wholesaler's raw count is not the reseller's to see. --%>
          <span
            data-role="stock-bar"
            class="w-[54px] h-1.5 rounded-full bg-border overflow-hidden shrink-0"
            title={stock_label(@stock)}
          >
            <span
              class={["block h-full rounded-full", stock_fill(@stock)]}
              style={stock_width(@stock)}
            >
            </span>
          </span>
          <span class={["text-[11px] font-bold", stock_text(@stock)]}>{stock_label(@stock)}</span>
          <span class="flex items-center gap-1.5 ml-auto">
            <.glyph
              name={:area}
              class={"w-[15px] h-[15px] " <> if(@dispatch, do: "text-cyan-600", else: "text-slate-400")}
              stroke_width="1.9"
            />
            <span :if={@dispatch} class="text-xs font-bold text-slate-700 tabular-nums">
              {@dispatch}
            </span>
            <span
              :if={is_nil(@dispatch)}
              class="rounded-full bg-slate-100 px-2 py-0.5 text-[11px] font-bold text-text-muted"
            >
              Ask
            </span>
          </span>
        </div>
      </div>
    </.link>
    """
  end

  # A supplier is recognised by the shape and hue of one letter long before
  # the name is read, so the colour has to be stable per supplier. Emerald is
  # deliberately absent: on this card green already means "money you keep".
  @avatar_tones ~w(bg-violet-600 bg-cyan-600 bg-amber-600 bg-rose-600 bg-indigo-600 bg-teal-600)

  defp avatar_tone(supplier) do
    Enum.at(@avatar_tones, :erlang.phash2(supplier, length(@avatar_tones)))
  end

  defp stock_fill(:in_stock), do: "bg-emerald-500"
  defp stock_fill(:low), do: "bg-amber-500"
  defp stock_fill(:out), do: "bg-rose-500"

  defp stock_width(:in_stock), do: "width: 100%"
  defp stock_width(:low), do: "width: 30%"
  defp stock_width(:out), do: "width: 6%"

  defp stock_text(:in_stock), do: "text-slate-500"
  defp stock_text(:low), do: "text-amber-700"
  defp stock_text(:out), do: "text-rose-700"

  defp stock_label(:in_stock), do: "In stock"
  defp stock_label(:low), do: "Low"
  defp stock_label(:out), do: "None left"
end
