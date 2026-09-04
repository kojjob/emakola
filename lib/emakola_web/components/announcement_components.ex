defmodule EmakolaWeb.AnnouncementComponents do
  @moduledoc """
  The platform announcement as a merchant sees it: a card on the Dashboard,
  first thing under the greeting (design/announcement-banner, A · Card,
  chosen 2026-09-04).

  Built for merchants who do not read well: the icon disc says what kind of
  news this is before a word is read, the tint carries the same meaning,
  and there is one big button. Info is emerald, the brand, not the blue a
  system warning would wear.
  """
  # Not `use EmakolaWeb, :html`: that imports this very module into itself.
  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [icon: 1]

  attr :announcement, :map, required: true, doc: "id, title, body, severity"

  attr :preview, :boolean,
    default: false,
    doc: "the composer's live preview: same card, nothing to dismiss"

  def announcement_banner(assigns) do
    assigns = assign(assigns, :style, severity_style(assigns.announcement.severity))

    ~H"""
    <div
      id={"announcement-#{@announcement.id}"}
      data-severity={@announcement.severity}
      class={[
        "relative overflow-hidden rounded-[18px] border-[1.5px] bg-white shadow-sm",
        "p-4 pt-[18px] flex flex-col gap-3.5 lg:flex-row lg:items-center lg:gap-[18px] lg:px-[22px] lg:py-[18px]",
        @style.border
      ]}
    >
      <div class={["absolute left-0 inset-y-0 w-[5px]", @style.bar]}></div>
      <div class="flex items-start gap-3.5 flex-1 min-w-0 pl-1.5 lg:items-center">
        <span class={[
          "flex items-center justify-center shrink-0 rounded-full text-white shadow-lg",
          "w-12 h-12 lg:w-[52px] lg:h-[52px] bg-gradient-to-br",
          @style.disc
        ]}>
          <.icon name={@style.icon} class="size-6 lg:size-[26px]" />
        </span>
        <div class="min-w-0">
          <p class="text-[16.5px] lg:text-[17px] font-extrabold tracking-tight text-text leading-tight">
            {@announcement.title}
          </p>
          <p class="text-[14.5px] text-text-muted mt-1 leading-snug">{@announcement.body}</p>
        </div>
      </div>
      <button
        type="button"
        phx-click={!@preview && "dismiss_announcement"}
        phx-value-id={!@preview && @announcement.id}
        disabled={@preview}
        class={[
          "h-12 w-full lg:w-[150px] shrink-0 rounded-[13px] text-white text-[15.5px] font-extrabold",
          "inline-flex items-center justify-center gap-2 shadow-lg transition-colors cursor-pointer",
          @style.button
        ]}
      >
        <.icon name="hero-check" class="size-5" /> Got it
      </button>
    </div>
    """
  end

  # Spelled out, never built from the severity name: Tailwind scans the
  # source for complete class names.
  defp severity_style(:critical) do
    %{
      icon: "hero-bell-alert",
      border: "border-red-300 shadow-red-600/10",
      bar: "bg-red-600",
      disc: "from-red-500 to-red-700 shadow-red-600/30",
      button: "bg-red-600 hover:bg-red-700 shadow-red-600/30"
    }
  end

  defp severity_style(:warning) do
    %{
      icon: "hero-exclamation-triangle",
      border: "border-amber-300 shadow-amber-600/10",
      bar: "bg-amber-500",
      disc: "from-amber-400 to-amber-600 shadow-amber-600/30",
      button: "bg-amber-600 hover:bg-amber-700 shadow-amber-600/30"
    }
  end

  defp severity_style(_info) do
    %{
      icon: "hero-megaphone",
      border: "border-emerald-200 shadow-emerald-600/10",
      bar: "bg-primary",
      disc: "from-emerald-500 to-emerald-700 shadow-emerald-600/30",
      button: "bg-primary hover:bg-primary-hover shadow-emerald-600/30"
    }
  end
end
