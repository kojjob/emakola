defmodule EmakolaWeb.Hooks.ResolveStoreFromHost do
  @moduledoc """
  LiveView on_mount hook for the host-routed storefront (storefront served at
  ROOT on a store's own subdomain). Reads the store slug from the session — set
  by `EmakolaWeb.Plugs.ResolveStoreHost` from `conn.host` — instead of the URL,
  because `socket.host_uri` is the configured PHX_HOST, not the request subdomain.

  Mirrors `EmakolaWeb.Hooks.ResolveStore`: assigns `@store`/`@theme`/
  `@theme_module`/`@theme_fonts`, records the on-subdomain flag for
  `EmakolaWeb.Storefront.Path`, and subscribes to theme-update PubSub so the page
  refreshes when the merchant changes design tokens. Always on a store's own
  subdomain here, so the flag is `true`. Redirects to `/` if the slug is missing
  or the store can't be loaded.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias EmakolaWeb.Helpers.StoreResolver

  def on_mount(:default, _params, session, socket) do
    with slug when is_binary(slug) <- session["store_host_slug"],
         {:ok, store} <- StoreResolver.resolve(slug) do
      theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{}, store)
      theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

      if connected?(socket) do
        Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{store.id}:theme")
      end

      EmakolaWeb.Storefront.Path.put_on_store_subdomain(true)

      {:cont,
       socket
       |> assign(:store, store)
       |> assign(:theme, theme)
       |> assign(:theme_module, theme_module)
       |> assign(:theme_fonts, theme_module.fonts())
       |> assign(:on_store_subdomain?, true)
       |> attach_hook(:theme_update, :handle_info, &handle_theme_update/2)}
    else
      _ ->
        {:halt,
         socket
         |> put_flash(:error, "Store not found")
         |> redirect(to: "/")}
    end
  end

  defp handle_theme_update({:theme_updated, updated_store}, socket) do
    theme = Emakola.Themes.ThemeResolver.resolve(updated_store.theme_config || %{}, updated_store)
    theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

    {:halt,
     socket
     |> assign(:store, updated_store)
     |> assign(:theme, theme)
     |> assign(:theme_module, theme_module)
     |> assign(:theme_fonts, theme_module.fonts())}
  end

  defp handle_theme_update(_message, socket), do: {:cont, socket}
end
