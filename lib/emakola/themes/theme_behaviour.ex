defmodule Emakola.Themes.ThemeBehaviour do
  @moduledoc """
  Behaviour that all storefront themes must implement.

  Each callback receives a map of assigns and must return a HEEx template.
  """

  @callback render_home(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_product_list(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_product_detail(map()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Returns the theme name as a human-readable string.
  """
  @callback name() :: String.t()

  @doc """
  Returns the default CSS variables for this theme.
  """
  @callback css_variables() :: map()
end
