defmodule Emakola.Themes.Market do
  @moduledoc """
  Market theme — clean, modern, blue-accented.

  The default theme for all new stores.
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def id, do: "market"

  @impl true
  def name, do: "Market"

  @impl true
  def defaults do
    %{
      colors: %{
        primary: "#2563EB",
        secondary: "#F1F5F9",
        accent: "#B45309",
        background: "#FAFAF9",
        text: "#0F172A"
      },
      hero: %{
        title: "Welcome to our store",
        subtitle: "Browse our collection"
      },
      sections: %{
        show_featured: true,
        show_categories: true,
        show_about: true
      }
    }
  end

  @impl true
  def fonts do
    %{
      heading: "Inter",
      body: "Inter",
      url: "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"
    }
  end

  @impl true
  def render_home(assigns) do
    Emakola.Themes.Market.Home.render(assigns)
  end

  @impl true
  def render_product_list(assigns) do
    Emakola.Themes.Market.ProductList.render(assigns)
  end

  @impl true
  def render_product_detail(assigns) do
    Emakola.Themes.Market.ProductDetail.render(assigns)
  end
end

defmodule Emakola.Themes.Market.Home do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold">Welcome to the store</h1>
      <p class="text-gray-500 mt-2">Market theme — rendering coming soon</p>
    </div>
    """
  end
end

defmodule Emakola.Themes.Market.ProductList do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold">Shop All</h1>
      <p class="text-gray-500 mt-2">Market product list — rendering coming soon</p>
    </div>
    """
  end
end

defmodule Emakola.Themes.Market.ProductDetail do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold">Product Detail</h1>
      <p class="text-gray-500 mt-2">Market product detail — rendering coming soon</p>
    </div>
    """
  end
end
