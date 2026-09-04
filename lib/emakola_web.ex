defmodule EmakolaWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use EmakolaWeb, :controller
      use EmakolaWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  # robots.txt is intentionally NOT static — it's served dynamically per host by
  # SitemapController (apex platform rules vs. per-store subdomain rules). The
  # legacy priv/static/robots.txt is now unused (kept, not deleted).
  def static_paths,
    do:
      ~w(assets css fonts images tour uploads videos favicon.ico favicon.svg manifest.json sw.js offline.html)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: EmakolaWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      # Capture errors raised in mount/handle_event/handle_info and report to Sentry.
      on_mount(Sentry.LiveViewHook)

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: EmakolaWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import EmakolaWeb.CoreComponents
      import EmakolaWeb.SidebarComponents
      import EmakolaWeb.AdminComponents
      import EmakolaWeb.PlatformComponents
      import EmakolaWeb.AnnouncementComponents
      # Storefront components — use explicit import in storefront LiveViews
      # import EmakolaWeb.StorefrontComponents

      # Common modules used in templates
      alias Phoenix.LiveView.JS
      alias EmakolaWeb.Layouts

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: EmakolaWeb.Endpoint,
        router: EmakolaWeb.Router,
        statics: EmakolaWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
