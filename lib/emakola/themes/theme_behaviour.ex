defmodule Emakola.Themes.ThemeBehaviour do
  @moduledoc """
  Behaviour that all storefront themes must implement.

  Required callbacks: render_home, render_product_list, render_product_detail, name, css_variables.
  Optional callbacks: render_about, render_cart, render_checkout, render_blog_list, etc.
  When a theme doesn't implement an optional callback, ThemeRenderer falls back to DefaultRenderers.
  """

  # Required — every theme must implement these
  @callback render_home(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_product_list(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_product_detail(map()) :: Phoenix.LiveView.Rendered.t()
  @callback name() :: String.t()
  @callback css_variables() :: map()

  # Optional — themes can implement these for custom styling, otherwise DefaultRenderers handles them
  @callback render_about(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_downloads(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_contact(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_faq(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_policies(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_cart(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_checkout(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_blog_list(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_blog_post(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_recipe_list(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_recipe_detail(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_order_confirmation(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_tracking(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_category(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_wishlist(map()) :: Phoenix.LiveView.Rendered.t()
  @callback render_account(map()) :: Phoenix.LiveView.Rendered.t()

  # Optional — storefront chrome used by DefaultRenderers fallback pages.
  # Themes that implement these keep their own nav/footer on cart, account,
  # tracking, etc. (see Emakola.Themes.DefaultRenderers.Chrome); themes that
  # don't get Atelier's chrome on those pages. Assigns contract:
  # store (required), categories, cart_count, active_path.
  @callback storefront_nav(map()) :: Phoenix.LiveView.Rendered.t()
  @callback storefront_footer(map()) :: Phoenix.LiveView.Rendered.t()

  @optional_callbacks render_about: 1,
                      render_cart: 1,
                      render_checkout: 1,
                      render_blog_list: 1,
                      render_blog_post: 1,
                      render_recipe_list: 1,
                      render_recipe_detail: 1,
                      render_order_confirmation: 1,
                      render_tracking: 1,
                      render_category: 1,
                      render_wishlist: 1,
                      render_account: 1,
                      render_downloads: 1,
                      render_contact: 1,
                      render_faq: 1,
                      render_policies: 1,
                      storefront_nav: 1,
                      storefront_footer: 1
end
