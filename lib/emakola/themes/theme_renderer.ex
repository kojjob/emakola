defmodule Emakola.Themes.ThemeRenderer do
  @moduledoc """
  Dispatches page rendering to theme modules when they implement the callback.

  Usage in LiveViews:

      def render(assigns) do
        case Emakola.Themes.ThemeRenderer.theme_render(assigns, :cart) do
          {:ok, rendered} -> rendered
          :default -> ~H"<div>...your default template...</div>"
        end
      end

  This allows themes to progressively override pages without requiring
  DefaultRenderer modules for every page upfront.
  """

  @page_callbacks %{
    home: :render_home,
    product_list: :render_product_list,
    product_detail: :render_product_detail,
    about: :render_about,
    cart: :render_cart,
    checkout: :render_checkout,
    blog_list: :render_blog_list,
    blog_post: :render_blog_post,
    recipe_list: :render_recipe_list,
    recipe_detail: :render_recipe_detail,
    order_confirmation: :render_order_confirmation,
    tracking: :render_tracking,
    category: :render_category,
    wishlist: :render_wishlist,
    account: :render_account
  }

  @doc """
  Attempts to render a page through the theme module.

  Returns `{:ok, rendered}` if the theme implements that page,
  or `:default` if the LiveView should use its own template.
  """
  @spec theme_render(map(), atom()) :: {:ok, Phoenix.LiveView.Rendered.t()} | :default
  def theme_render(%{theme_module: nil}, _page), do: :default

  def theme_render(%{theme_module: theme_module} = assigns, page) do
    callback = Map.get(@page_callbacks, page)
    Code.ensure_loaded(theme_module)

    if callback && function_exported?(theme_module, callback, 1) do
      {:ok, apply(theme_module, callback, [assigns])}
    else
      :default
    end
  end

  def theme_render(_assigns, _page), do: :default

  @doc """
  Returns the list of page types the ThemeRenderer knows about.
  """
  def page_types, do: Map.keys(@page_callbacks)
end
