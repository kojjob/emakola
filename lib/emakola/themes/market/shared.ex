defmodule Emakola.Themes.Market.Shared do
  @moduledoc """
  Shared helper functions for the Market theme.

  Provides image extraction and other utilities used across
  the home, product list, and product detail renderers.
  """
  use Phoenix.Component

  # ── CSS Variable Injection ──

  @doc """
  Injects theme CSS custom properties into the page as a <style> block.
  Place this as the first element inside the outermost div of each page.
  """
  attr :theme, :map, required: true

  def theme_styles(assigns) do
    ~H"""
    <style>
      :root {
        --theme-primary: <%= get_in(@theme, [:colors, :primary]) || "#1C1917" %>;
        --theme-accent: <%= get_in(@theme, [:colors, :accent]) || "#B45309" %>;
        --theme-bg: <%= get_in(@theme, [:colors, :background]) || "#FAFAF9" %>;
      }
    </style>
    """
  end

  @doc """
  Extract the first image URL from a product's images association.
  Returns thumbnail_url if available, falls back to url, then nil.
  """
  def first_image(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end

  @doc """
  Get the image at a specific index from a product's images.
  Falls back to medium_url, then url, then first_image.
  """
  def current_image(product, index) do
    case Enum.at(product.images, index) do
      %{medium_url: url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> first_image(product)
    end
  end

  @doc """
  Extract image URL from a category, if available.
  """
  def category_image(category) do
    if Map.has_key?(category, :image_url) do
      category.image_url
    else
      nil
    end
  end
end
