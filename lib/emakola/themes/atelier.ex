defmodule Emakola.Themes.Atelier do
  @moduledoc """
  Atelier theme — luxury, gold-accented, serif headings.

  Designed for high-end boutiques and premium brands.
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def id, do: "atelier"

  @impl true
  def name, do: "Atelier"

  @impl true
  def defaults do
    %{
      colors: %{
        primary: "#CA8A04",
        secondary: "#F5F5DC",
        accent: "#D4AF37",
        background: "#FAFAF9",
        text: "#1C1917"
      },
      hero: %{
        title: "Curated for you",
        subtitle: "Discover our exclusive collection"
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
      heading: "Cormorant Garamond",
      body: "Montserrat",
      url:
        "https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600;700&family=Montserrat:wght@400;500;600;700&display=swap"
    }
  end

  @impl true
  def render_home(assigns) do
    Emakola.Themes.Atelier.Home.render(assigns)
  end

  @impl true
  def render_product_list(assigns) do
    Emakola.Themes.Atelier.ProductList.render(assigns)
  end

  @impl true
  def render_product_detail(assigns) do
    Emakola.Themes.Atelier.ProductDetail.render(assigns)
  end
end

defmodule Emakola.Themes.Atelier.Home do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold">Welcome to the atelier</h1>
      <p class="text-gray-500 mt-2">Atelier theme — rendering coming soon</p>
    </div>
    """
  end
end

defmodule Emakola.Themes.Atelier.ProductList do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold">Shop All</h1>
      <p class="text-gray-500 mt-2">Atelier product list — rendering coming soon</p>
    </div>
    """
  end
end

defmodule Emakola.Themes.Atelier.ProductDetail do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="max-w-[1280px] mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold">Product Detail</h1>
      <p class="text-gray-500 mt-2">Atelier product detail — rendering coming soon</p>
    </div>
    """
  end
end
