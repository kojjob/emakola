defmodule EmakolaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use EmakolaWeb, :html

  @doc """
  Renders a sidebar navigation link.
  """
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  def nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-transform active:scale-95",
        if(@active,
          do: "text-emerald-600 font-semibold bg-white editorial-shadow",
          else:
            "text-slate-900/60 font-medium hover:text-slate-900 hover:bg-slate-200/50 transition-colors duration-200"
        )
      ]}
    >
      <span class="material-symbols-outlined">{@icon}</span>
      <span>{@label}</span>
    </a>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <%!-- z-[60] outranks the modal's z-50: a flash raised from inside a modal
    (a failed invite, a save error) must sit above its blurred backdrop. --%>
    <div id={@id} aria-live="polite" class="fixed bottom-6 right-6 z-[60] flex flex-col-reverse gap-3">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center rounded-full border-2 border-slate-300 bg-slate-200 dark:border-slate-700 dark:bg-slate-800">
      <div class="absolute left-0 h-full w-1/3 rounded-full border border-slate-200 bg-white shadow-sm transition-[left] [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 dark:border-slate-600 dark:bg-slate-600" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  # Display helpers moved to LayoutHelpers (breaks the circular dependency
  # with SidebarComponents); delegates keep existing call sites working.
  defdelegate user_initials(user), to: EmakolaWeb.LayoutHelpers
  defdelegate notification_border_class(type), to: EmakolaWeb.LayoutHelpers
  defdelegate notification_dot_class(type), to: EmakolaWeb.LayoutHelpers
  defdelegate notification_icon_bg_class(type), to: EmakolaWeb.LayoutHelpers
  defdelegate notification_icon_color_class(type), to: EmakolaWeb.LayoutHelpers
  defdelegate notification_icon(type), to: EmakolaWeb.LayoutHelpers
  defdelegate relative_time(datetime), to: EmakolaWeb.LayoutHelpers

  # Embed all files in layouts/* within this module.
  # The app.html.heex template requires: @flash, @inner_content, @active_nav, @current_user
  # The root.html.heex template provides the HTML skeleton.
  embed_templates "layouts/*"
end
