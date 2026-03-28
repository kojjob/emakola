defmodule EmakolaWeb.Hooks.ResolveStore do
  @moduledoc """
  LiveView on_mount hook that resolves the store from the URL slug.

  Ensures every storefront LiveView has `@store` assigned from the URL parameter,
  centralizing tenant resolution instead of relying on each LiveView to do it individually.
  Redirects to the landing page if the store slug is invalid.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias EmakolaWeb.Helpers.StoreResolver

  def on_mount(:default, %{"store_slug" => slug}, _session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})
        theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

        {:cont,
         socket
         |> assign(:store, store)
         |> assign(:theme, theme)
         |> assign(:theme_module, theme_module)
         |> assign(:theme_fonts, theme_module.fonts())}

      {:error, :not_found} ->
        {:halt,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:halt,
     socket
     |> put_flash(:error, "Store not found")
     |> redirect(to: "/")}
  end
end
