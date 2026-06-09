defmodule Emakola.Themes.Akoma.Shared do
  @moduledoc "Shared Akoma components: theme_styles, nav, footer, helpers."
  use Phoenix.Component

  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root { --theme-primary:#1A1A1A; --theme-accent:#2F5D50; --theme-bg:#F8F9F7; }
    </style>
    """
  end
end
