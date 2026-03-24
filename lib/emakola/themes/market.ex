defmodule Emakola.Themes.Market do
  @moduledoc """
  The Market theme — the default storefront theme for Emakola.

  Delegates rendering to specialised submodules:
  - `Emakola.Themes.Market.Home` — store landing page
  - `Emakola.Themes.Market.ProductList` — product listing / search
  - `Emakola.Themes.Market.ProductDetail` — single product view
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def name, do: "Market"

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#1C1917",
      "--theme-accent" => "#B45309",
      "--theme-bg" => "#FAFAF9"
    }
  end

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Market.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Market.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Market.ProductDetail, as: :render
end
