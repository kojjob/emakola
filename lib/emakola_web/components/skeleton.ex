defmodule EmakolaWeb.Skeleton do
  @moduledoc """
  Reusable skeleton loading state components.

  These components provide visual placeholders while content is loading,
  following the Midnight Architect design system with animate-pulse effects.

  ## Examples

      <Skeleton.card />
      <Skeleton.table_row />
      <Skeleton.text_block />
  """
  use Phoenix.Component

  @doc """
  Renders a skeleton card placeholder.

  Displays a card-shaped loading skeleton with header, title, and content lines.
  """
  attr :class, :string, default: nil

  def card(assigns) do
    ~H"""
    <div class={["bg-slate-100 rounded-xl p-6 animate-pulse", @class]}>
      <div class="h-3 bg-slate-200 rounded w-1/3 mb-4"></div>
      <div class="h-8 bg-slate-200 rounded w-1/2 mb-6"></div>
      <div class="h-2 bg-slate-200 rounded w-full"></div>
    </div>
    """
  end

  @doc """
  Renders a skeleton table row placeholder.

  Displays a row with an avatar circle, two text lines, and a trailing badge.
  """
  attr :class, :string, default: nil

  def table_row(assigns) do
    ~H"""
    <div class={["flex items-center gap-4 px-6 py-4 animate-pulse", @class]}>
      <div class="w-10 h-10 rounded-full bg-slate-200"></div>
      <div class="flex-1 space-y-2">
        <div class="h-3 bg-slate-200 rounded w-1/4"></div>
        <div class="h-2 bg-slate-200 rounded w-1/3"></div>
      </div>
      <div class="h-4 bg-slate-200 rounded w-16"></div>
    </div>
    """
  end

  @doc """
  Renders a skeleton text block placeholder.

  Displays three lines of varying widths to simulate a loading paragraph.
  """
  attr :class, :string, default: nil

  def text_block(assigns) do
    ~H"""
    <div class={["space-y-2 animate-pulse", @class]}>
      <div class="h-3 bg-slate-200 rounded w-3/4"></div>
      <div class="h-3 bg-slate-200 rounded w-1/2"></div>
      <div class="h-3 bg-slate-200 rounded w-2/3"></div>
    </div>
    """
  end
end
