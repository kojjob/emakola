defmodule EmakolaWeb.Hooks.ResolveStore do
  @moduledoc """
  LiveView on_mount hook that resolves the store from the URL slug.

  Ensures every storefront LiveView has `@store` assigned from the URL parameter,
  centralizing tenant resolution instead of relying on each LiveView to do it individually.
  Redirects to the landing page if the store slug is invalid.

  Also subscribes to theme update PubSub so storefront pages automatically
  refresh when the merchant changes design tokens or theme settings.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias EmakolaWeb.Helpers.StoreResolver

  @doc """
  `:default` serves the `/s/:slug` subfolder form; `:short` serves
  `makola.io/:slug`. They differ only in the link dialect the page renders in,
  so a visitor who arrived on a short URL keeps short URLs as they navigate.
  """
  def on_mount(:short, params, session, socket) do
    on_mount(:default, params, Map.put(session, "storefront_path_mode", :short), socket)
  end

  def on_mount(:default, %{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{}, store)
        theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

        # Subscribe to theme updates so storefront refreshes automatically
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{store.id}:theme")
        end

        on_store_subdomain? = Map.get(session, "on_store_subdomain?", false)

        EmakolaWeb.Storefront.Path.put_mode(
          cond do
            on_store_subdomain? -> :branded
            Map.get(session, "storefront_path_mode") == :short -> :short
            true -> :subfolder
          end
        )

        {:cont,
         socket
         |> assign(:store, store)
         |> assign(:theme, theme)
         |> assign(:theme_module, theme_module)
         |> assign(:theme_fonts, theme_module.fonts())
         |> assign(:on_store_subdomain?, on_store_subdomain?)
         |> attach_hook(:theme_update, :handle_info, &handle_theme_update/2)}

      {:error, :unavailable} ->
        {:halt, redirect(socket, to: "/store-unavailable")}

      {:error, :gone} ->
        raise EmakolaWeb.StoreGone

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
