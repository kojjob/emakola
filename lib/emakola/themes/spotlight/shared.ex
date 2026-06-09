defmodule Emakola.Themes.Spotlight.Shared do
  @moduledoc "Shared Spotlight components."
  use Phoenix.Component

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root { --theme-bg:#FBF9F5; --theme-accent:#7C3AED; --theme-primary:#16130F; }
    </style>
    """
  end
end
