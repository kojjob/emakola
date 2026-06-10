defmodule EmakolaWeb.Helpers.CssColor do
  @moduledoc """
  Boundary for merchant-controlled colors flowing into CSS contexts
  (<style> blocks, style= attributes). Only strict hex passes; anything
  else falls back — defends against CSS injection from theme_config.
  """
  @hex ~r/^#[0-9a-fA-F]{3,8}$/

  def safe_css_color(value, default) when is_binary(value) do
    if value =~ @hex, do: value, else: default
  end

  def safe_css_color(_value, default), do: default
end
