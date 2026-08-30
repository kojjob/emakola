defmodule Emakola.Themes.DefaultRenderers.Chrome do
  @moduledoc """
  Nav/footer for fallback storefront pages, dispatched to the active theme.

  Fallback pages (cart, checkout, account, ...) render inside whatever theme
  the store runs. Historically they hardwired Atelier's navbar/footer, which
  swapped the store's chrome for a different theme's mid-funnel on the 13
  non-Atelier themes. This component asks the active theme for its chrome:

    * theme module exports `storefront_nav/1` / `storefront_footer/1` → used
    * otherwise → Atelier's navbar/footer (the previous behavior)

  The assigns contract mirrors Atelier's navbar/footer:
  `store` (required), `categories`, `cart_count`, `active_path`.
  """
  use Phoenix.Component

  attr :theme_module, :any, default: nil
  attr :theme, :map, default: %{}
  attr :store, :map, required: true
  attr :categories, :list, default: []
  attr :cart_count, :integer, default: 0
  attr :active_path, :string, default: nil

  def navbar(assigns) do
    case chrome_fun(assigns.theme_module, :storefront_nav) do
      nil ->
        ~H"""
        <Emakola.Themes.Atelier.Shared.navbar
          store={@store}
          categories={@categories}
          cart_count={@cart_count}
          active_path={@active_path}
        />
        """

      fun ->
        fun.(assigns)
    end
  end

  attr :theme_module, :any, default: nil
  attr :theme, :map, default: %{}
  attr :store, :map, required: true
  attr :categories, :list, default: []

  def footer(assigns) do
    case chrome_fun(assigns.theme_module, :storefront_footer) do
      nil ->
        ~H"""
        <Emakola.Themes.Atelier.Shared.footer store={@store} categories={@categories} />
        """

      fun ->
        fun.(assigns)
    end
  end

  attr :theme_module, :any, default: nil
  attr :theme, :map, default: %{}
  attr :store, :map, required: true
  attr :cart_count, :integer, default: 0
  attr :active_tab, :atom, default: :home

  @doc """
  The mobile bottom tab bar, dispatched to the active theme.

  A theme exporting `storefront_bottom_nav/1` keeps its own bar on fallback
  pages (Dede's WhatsApp-first tabs, Pace's dark pill, ...); otherwise the
  generic Home/Search/Saved/Cart bar renders. Each branch is stamped with a
  `data-bottom-nav` marker so the parity guard can tell them apart.
  """
  def bottom_nav(assigns) do
    case chrome_fun(assigns.theme_module, :storefront_bottom_nav) do
      nil ->
        ~H"""
        <div class="contents" data-bottom-nav="fallback">
          <EmakolaWeb.StorefrontComponents.bottom_nav
            store_slug={@store.slug}
            active_tab={@active_tab}
            cart_count={@cart_count}
          />
        </div>
        """

      fun ->
        assigns = assign(assigns, :theme_bar, fun)

        ~H"""
        <div class="contents" data-bottom-nav="theme">
          {@theme_bar.(assigns)}
        </div>
        """
    end
  end

  defp chrome_fun(nil, _name), do: nil

  defp chrome_fun(mod, name) when is_atom(mod) do
    Code.ensure_loaded(mod)
    if function_exported?(mod, name, 1), do: &apply(mod, name, [&1])
  end

  defp chrome_fun(_mod, _name), do: nil
end
