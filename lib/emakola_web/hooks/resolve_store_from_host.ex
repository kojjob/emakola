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
    case resolve(session) do
      {:ok, store} -> mount_store(store, socket)
      error -> bail(error, socket)
    end
  end

  defp resolve(session) do
    case session["store_host_slug"] do
      slug when is_binary(slug) -> StoreResolver.resolve(slug)
      _ -> {:error, :no_slug}
    end
  end

  defp mount_store(store, socket) do
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
  end

  # On a branded host "/" IS the storefront, which remounts through this very
  # hook and fails the same way — a redirect loop. Every failure must leave the
  # host entirely, so the redirect is absolute to the apex. The plug layer
  # (ResolveStoreHost) learned this same lesson first; keep them consistent.
  defp bail({:error, :unavailable}, socket) do
    {:halt, redirect(socket, external: EmakolaWeb.Endpoint.url() <> "/store-unavailable")}
  end

  defp bail(_error, socket) do
    {:halt,
     socket
     |> put_flash(:error, "Store not found")
     |> redirect(external: EmakolaWeb.Endpoint.url() <> "/")}
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
