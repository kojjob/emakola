defmodule EmakolaWeb.LayoutHelpers do
  @moduledoc """
  Pure display helpers shared by layout templates and layout-level
  components (SidebarComponents, platform layout, review/security
  components). Lives outside `Layouts` so components imported BY the
  layouts can call these without a circular module dependency.
  `Layouts` delegates to keep existing call sites working.
  """

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
end
