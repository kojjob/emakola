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

  # One row per notification type, feeding all five renderings below. These
  # were five parallel function families keyed on the same atom, which is
  # exactly how they drifted — a type could be added to one list and
  # forgotten in the others, and the fallback made the omission invisible.
  #
  # Every type in `Emakola.Notifications.Notification`'s constraint needs a
  # row here. Missing ones fall back to a neutral bell rather than rendering
  # blank.
  @notification_styles %{
    order_placed: {:emerald, "shopping_bag"},
    order_status_changed: {:blue, "local_shipping"},
    payment_received: {:emerald, "payments"},
    payout_sent: {:emerald, "account_balance"},
    new_message: {:blue, "chat_bubble"},
    verification_result: {:amber, "verified"},
    product_moderated: {:red, "gavel"},
    supplier_connection: {:amber, "handshake"},
    supplier_overdue: {:red, "schedule"},
    announcement: {:emerald, "campaign"},
    billing_warning: {:red, "warning"},
    system: {:emerald, "notifications"}
  }

  @default_style {:emerald, "notifications"}

  @doc "Returns the border color class for a notification type."
  def notification_border_class(type), do: type |> tone() |> border_class()

  @doc "Returns the unread dot color class for a notification type."
  def notification_dot_class(type), do: type |> tone() |> dot_class()

  @doc "Returns the icon background gradient class for a notification type."
  def notification_icon_bg_class(type), do: type |> tone() |> icon_bg_class()

  @doc "Returns the icon color class for a notification type."
  def notification_icon_color_class(type), do: type |> tone() |> icon_color_class()

  @doc "Returns the Material Symbol icon name for a notification type."
  def notification_icon(type) do
    {_tone, icon} = Map.get(@notification_styles, type, @default_style)
    icon
  end

  defp tone(type) do
    {tone, _icon} = Map.get(@notification_styles, type, @default_style)
    tone
  end

  # Spelled out rather than interpolated. Tailwind scans source for complete
  # class names, so a built string like "border-#{tone}-600" is never
  # generated and the colour silently does not apply.
  defp border_class(:emerald), do: "border-emerald-600 bg-emerald-600/[0.03]"
  defp border_class(:red), do: "border-red-600 bg-red-600/[0.03]"
  defp border_class(:amber), do: "border-amber-600 bg-amber-600/[0.03]"
  defp border_class(:blue), do: "border-blue-600 bg-blue-600/[0.03]"

  defp dot_class(:emerald), do: "bg-emerald-600"
  defp dot_class(:red), do: "bg-red-600"
  defp dot_class(:amber), do: "bg-amber-600"
  defp dot_class(:blue), do: "bg-blue-600"

  defp icon_bg_class(:emerald), do: "from-emerald-600/20 to-emerald-600/5"
  defp icon_bg_class(:red), do: "from-red-600/20 to-red-600/5"
  defp icon_bg_class(:amber), do: "from-amber-600/20 to-amber-600/5"
  defp icon_bg_class(:blue), do: "from-blue-600/20 to-blue-600/5"

  defp icon_color_class(:emerald), do: "text-emerald-600"
  defp icon_color_class(:red), do: "text-red-600"
  defp icon_color_class(:amber), do: "text-amber-600"
  defp icon_color_class(:blue), do: "text-blue-600"

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
