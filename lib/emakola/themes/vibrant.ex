defmodule Emakola.Themes.Vibrant do
  @moduledoc """
  Vibrant theme — bold, red-accented, expressive.

  Designed for fashion-forward and lifestyle brands.
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def id, do: "vibrant"

  @impl true
  def name, do: "Vibrant"

  @impl true
  def defaults do
    %{
      colors: %{
        primary: "#DC2626",
        secondary: "#FEF2F2",
        accent: "#EA580C",
        background: "#FAFAFA",
        text: "#18181B"
      },
      hero: %{
        title: "Bold & Beautiful",
        subtitle: "Express yourself with our collection"
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
      heading: "Playfair Display",
      body: "DM Sans",
      url:
        "https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Playfair+Display:wght@400;500;600;700&display=swap"
    }
  end

  @impl true
  def render_home(assigns) do
    Emakola.Themes.Vibrant.Home.render(assigns)
  end

  @impl true
  def render_product_list(assigns) do
    Emakola.Themes.Vibrant.ProductList.render(assigns)
  end

  @impl true
  def render_product_detail(assigns) do
    Emakola.Themes.Vibrant.ProductDetail.render(assigns)
  end
end

defmodule Emakola.Themes.Vibrant.Home do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold">Welcome</h1>
      <p class="text-gray-500 mt-2">Vibrant theme — rendering coming soon</p>
    </div>
    """
  end
end

defmodule Emakola.Themes.Vibrant.ProductList do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold">Shop All</h1>
      <p class="text-gray-500 mt-2">Vibrant product list — rendering coming soon</p>
    </div>
    """
  end
end

defmodule Emakola.Themes.Vibrant.ProductDetail do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold">Product Detail</h1>
      <p class="text-gray-500 mt-2">Vibrant product detail — rendering coming soon</p>
    </div>
    """
  end
end
