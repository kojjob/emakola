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
    <div id={@id} aria-live="polite" class="fixed bottom-6 right-6 z-50 flex flex-col-reverse gap-3">
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
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

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

  @doc """
  Extracts user initials from a user struct for avatar fallback.
  Returns "FP" if no user or no name.
  """
  def user_initials(nil), do: "FP"

  def user_initials(%{name: nil, email: email}) when not is_nil(email) do
    email |> to_string() |> String.first() |> String.upcase()
  end

  def user_initials(%{name: "", email: email}) when not is_nil(email) do
    email |> to_string() |> String.first() |> String.upcase()
  end

  def user_initials(%{name: name}) when is_binary(name) and name != "" do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  def user_initials(%{email: email}) when not is_nil(email) do
    email |> to_string() |> String.first() |> String.upcase()
  end

  def user_initials(_), do: "FP"

  # --- Notification helpers used by the app layout template ---

  @doc "Returns the border color class for a notification type."
  def notification_border_class(:agent_completed), do: "border-emerald-600 bg-emerald-600/[0.03]"
  def notification_border_class(:agent_failed), do: "border-red-600 bg-red-600/[0.03]"
  def notification_border_class(:billing_warning), do: "border-red-600 bg-red-600/[0.03]"
  def notification_border_class(:billing_updated), do: "border-amber-600 bg-amber-600/[0.03]"
  def notification_border_class(:team_invite), do: "border-amber-600 bg-amber-600/[0.03]"
  def notification_border_class(:team_removed), do: "border-red-600 bg-red-600/[0.03]"

  def notification_border_class(:system_announcement),
    do: "border-emerald-600 bg-emerald-600/[0.03]"

  def notification_border_class(_), do: "border-emerald-600 bg-emerald-600/[0.03]"

  @doc "Returns the unread dot color class for a notification type."
  def notification_dot_class(:agent_completed), do: "bg-emerald-600"
  def notification_dot_class(:agent_failed), do: "bg-red-600"
  def notification_dot_class(:billing_warning), do: "bg-red-600"
  def notification_dot_class(:billing_updated), do: "bg-amber-600"
  def notification_dot_class(:team_invite), do: "bg-amber-600"
  def notification_dot_class(:team_removed), do: "bg-red-600"
  def notification_dot_class(:system_announcement), do: "bg-emerald-600"
  def notification_dot_class(_), do: "bg-emerald-600"

  @doc "Returns the icon background gradient class for a notification type."
  def notification_icon_bg_class(:agent_completed), do: "from-emerald-500/20 to-emerald-500/5"
  def notification_icon_bg_class(:agent_failed), do: "from-red-600/20 to-red-600/5"
  def notification_icon_bg_class(:billing_warning), do: "from-red-600/20 to-red-600/5"
  def notification_icon_bg_class(:billing_updated), do: "from-amber-600/20 to-amber-600/5"
  def notification_icon_bg_class(:team_invite), do: "from-amber-600/20 to-amber-600/5"
  def notification_icon_bg_class(:team_removed), do: "from-red-600/20 to-red-600/5"
  def notification_icon_bg_class(:system_announcement), do: "from-emerald-600/20 to-emerald-600/5"
  def notification_icon_bg_class(_), do: "from-emerald-600/20 to-emerald-600/5"

  @doc "Returns the icon color class for a notification type."
  def notification_icon_color_class(:agent_completed), do: "text-emerald-500"
  def notification_icon_color_class(:agent_failed), do: "text-red-600"
  def notification_icon_color_class(:billing_warning), do: "text-red-600"
  def notification_icon_color_class(:billing_updated), do: "text-amber-600"
  def notification_icon_color_class(:team_invite), do: "text-amber-600"
  def notification_icon_color_class(:team_removed), do: "text-red-600"
  def notification_icon_color_class(:system_announcement), do: "text-emerald-600"
  def notification_icon_color_class(_), do: "text-emerald-600"

  @doc "Returns the Material Symbol icon name for a notification type."
  def notification_icon(:agent_completed), do: "check_circle"
  def notification_icon(:agent_failed), do: "error"
  def notification_icon(:billing_warning), do: "warning"
  def notification_icon(:billing_updated), do: "receipt_long"
  def notification_icon(:team_invite), do: "person_add"
  def notification_icon(:team_removed), do: "person_remove"
  def notification_icon(:system_announcement), do: "campaign"
  def notification_icon(_), do: "notifications"

  @doc "Formats a datetime as relative time (e.g., '2m', '1h', '3d')."
  def relative_time(nil), do: ""

  def relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "#{diff_seconds}s"
      diff_seconds < 3_600 -> "#{div(diff_seconds, 60)}m"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3_600)}h"
      diff_seconds < 604_800 -> "#{div(diff_seconds, 86_400)}d"
      true -> "#{div(diff_seconds, 604_800)}w"
    end
  end

  @doc false
  # Severity tint for the merchant announcement banner in app.html.heex.
  def announcement_classes(:critical), do: "bg-red-50 text-red-800 border-red-200"
  def announcement_classes(:warning), do: "bg-amber-50 text-amber-800 border-amber-200"
  def announcement_classes(_info), do: "bg-blue-50 text-blue-800 border-blue-200"

  # Embed all files in layouts/* within this module.
  # The app.html.heex template requires: @flash, @inner_content, @active_nav, @current_user
  # The root.html.heex template provides the HTML skeleton.
  embed_templates "layouts/*"
end
