defmodule Emakola.Themes.Shared.RealPhotoBadge do
  @moduledoc "PDP trust badge for snap-verified products. The photo is the promise."
  use Phoenix.Component

  attr :product, :map, required: true

  def badge(assigns) do
    ~H"""
    <span
      :if={Map.get(@product, :snap_verified, false)}
      class="inline-flex items-center gap-1 rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-700"
      title="Photographed by seller"
    >
      📷 Real photo
    </span>
    """
  end
end
