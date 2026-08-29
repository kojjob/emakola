defmodule EmakolaWeb.Admin.NotificationSettingsLive do
  @moduledoc """
  Where a merchant turns the noise down.

  Two things are shown as fixed rather than as controls that do nothing:

    * the in-app bell, which costs nothing and needs no phone number, so it
      is never switchable
    * the events in `Preferences.always_on/0` — payouts, orders, verification
      — which a merchant must not be able to silence

  Rendering a switch for either would be a control that looks live and is
  not, which is the one thing this project rules out. They appear with a
  reason instead.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Notifications.Preferences
  alias EmakolaWeb.LayoutHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Notifications", active_nav: :settings) |> load()}
  end

  defp load(socket) do
    merchant = socket.assigns.current_merchant
    settings = Preferences.settings(merchant)

    assign(socket,
      settings: settings,
      chosen: chosen_map(merchant),
      quiet_start: format_time(settings.quiet_hours_start),
      quiet_end: format_time(settings.quiet_hours_end)
    )
  end

  # What each switch should read as right now: the merchant's override where
  # they set one, the default everywhere else.
  defp chosen_map(merchant) do
    Map.new(Preferences.configurable_events(), fn event ->
      {event, Preferences.channels_for(merchant, event)}
    end)
  end

  defp format_time(nil), do: ""
  defp format_time(%Time{} = time), do: time |> Time.to_string() |> String.slice(0, 5)

  # One tap, saved. No Save button to find, understand and remember — this
  # page is read by people who do not read fluently, and a switch that is
  # already on is its own confirmation.
  @impl true
  def handle_event(
        "toggle_channel",
        %{"notification" => event_name, "channel" => channel_name},
        socket
      ) do
    merchant = socket.assigns.current_merchant

    # Both names arrive from the client. Allowlists, and the event must be one
    # this page actually offers — an always-on event has no switch, so a
    # request to change one is forged and is ignored rather than honoured.
    with event when not is_nil(event) <- Preferences.cast_event(event_name),
         true <- event in Preferences.configurable_events(),
         channel when not is_nil(channel) <- Preferences.cast_channel_name(channel_name) do
      current = Preferences.channels_for(merchant, event)

      wanted =
        if channel in current do
          List.delete(current, channel)
        else
          [channel | current]
        end

      # in_app is never stored — channels_for/3 always adds it back.
      Preferences.put_channels(merchant, event, wanted -- [:in_app])

      {:noreply, load(socket)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("save_quiet_hours", %{"quiet_hours" => params}, socket) do
    merchant = socket.assigns.current_merchant

    case {parse_time(params["start"]), parse_time(params["end"])} do
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "That start time did not look right.")}

      {_, :error} ->
        {:noreply, put_flash(socket, :error, "That end time did not look right.")}

      {start, finish} ->
        Preferences.put_quiet_hours(merchant, start, finish)

        {:noreply, socket |> put_flash(:info, "Saved.") |> load()}
    end
  end

  # Unmatched events must not crash the page.
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # Blank clears the window rather than erroring: "I no longer want quiet
  # hours" is a normal thing to express with an empty field.
  defp parse_time(value) when value in [nil, ""], do: nil

  defp parse_time(value) do
    case Time.from_iso8601(value <> ":00") do
      {:ok, time} -> time
      _ -> :error
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-6 space-y-6">
      <.admin_page_header
        title="Notifications"
        subtitle="Choose how Makola reaches you. Messages in your dashboard are always on."
        icon="hero-bell"
      />

      <div
        id="notification-preferences"
        class="rounded-card border border-slate-200 bg-white overflow-hidden shadow-sm"
      >
        <div class="px-5 pt-4 pb-3">
          <h2 class="text-base font-extrabold text-slate-900">What Makola tells you about</h2>
          <p class="mt-0.5 text-[12.5px] text-slate-500">
            Tap a channel to turn it on or off for each event.
          </p>
        </div>

        <div
          :for={event <- Preferences.configurable_events()}
          class="flex flex-col gap-3 border-t border-slate-100 px-5 py-3.5 sm:flex-row sm:items-center"
        >
          <div class="flex min-w-0 flex-1 items-center gap-3">
            <div class={[
              "shrink-0 w-11 h-11 rounded-xl bg-gradient-to-br flex items-center justify-center",
              LayoutHelpers.notification_icon_bg_class(event)
            ]}>
              <span class={[
                "material-symbols-outlined text-xl",
                LayoutHelpers.notification_icon_color_class(event)
              ]}>
                {LayoutHelpers.notification_icon(event)}
              </span>
            </div>
            <span class="text-sm font-bold text-slate-900">{event_label(event)}</span>
          </div>
          <div class="flex shrink-0 flex-wrap gap-1.5">
            <button
              :for={channel <- Preferences.switchable_channels()}
              type="button"
              phx-click="toggle_channel"
              phx-value-notification={event}
              phx-value-channel={channel}
              role="switch"
              aria-checked={to_string(channel in Map.get(@chosen, event, []))}
              aria-label={"#{channel_label(channel)} for #{event_label(event)}"}
              class={[
                "inline-flex min-h-[36px] items-center gap-1.5 rounded-full px-3.5 text-[11.5px] font-bold transition-colors cursor-pointer",
                if(channel in Map.get(@chosen, event, []),
                  do: "bg-primary text-white",
                  else: "border border-border bg-white text-slate-400 hover:border-slate-300"
                )
              ]}
            >
              <.icon
                :if={channel in Map.get(@chosen, event, [])}
                name="hero-check"
                class="size-3"
              />
              {channel_label(channel)}
            </button>
          </div>
        </div>

        <div
          :for={event <- Preferences.always_on()}
          class="flex items-center gap-3 border-t border-slate-100 bg-slate-50/50 px-5 py-3.5"
        >
          <div class={[
            "shrink-0 w-11 h-11 rounded-xl bg-gradient-to-br flex items-center justify-center",
            LayoutHelpers.notification_icon_bg_class(event)
          ]}>
            <span class={[
              "material-symbols-outlined text-xl",
              LayoutHelpers.notification_icon_color_class(event)
            ]}>
              {LayoutHelpers.notification_icon(event)}
            </span>
          </div>
          <div class="min-w-0 flex-1">
            <span class="text-sm font-bold text-slate-900">{event_label(event)}</span>
            <p class="text-[11.5px] text-slate-400">{always_on_reason(event)}</p>
          </div>
          <span class="inline-flex shrink-0 items-center gap-1 rounded-full bg-emerald-50 px-2.5 py-1 text-[11px] font-bold text-emerald-700">
            <span class="material-symbols-outlined text-sm">lock</span> Always on
          </span>
        </div>
      </div>

      <.form
        for={%{}}
        id="quiet-hours"
        phx-submit="save_quiet_hours"
        class="rounded-card border border-slate-200 bg-white p-4 space-y-4 shadow-sm"
      >
        <div class="flex items-center gap-3.5">
          <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-slate-900">
            <span class="material-symbols-outlined text-xl text-amber-400">bedtime</span>
          </div>
          <div>
            <h2 class="text-base font-extrabold text-slate-900">Quiet hours</h2>
            <p class="text-[12.5px] text-slate-500">
              Nothing rings your phone between these times — it waits, and reaches
              you after. Money and new orders always get through.
            </p>
          </div>
        </div>

        <div class="flex items-end gap-4">
          <label class="block">
            <span class="block text-xs font-medium text-slate-500 mb-1">From</span>
            <input
              type="time"
              name="quiet_hours[start]"
              value={@quiet_start}
              class="rounded-control border border-slate-300 px-3 py-2 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary"
            />
          </label>
          <label class="block">
            <span class="block text-xs font-medium text-slate-500 mb-1">Until</span>
            <input
              type="time"
              name="quiet_hours[end]"
              value={@quiet_end}
              class="rounded-control border border-slate-300 px-3 py-2 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary"
            />
          </label>
          <button
            type="submit"
            class="rounded-control bg-primary hover:bg-primary-hover px-4 py-2.5 text-sm font-semibold text-white transition-colors cursor-pointer"
          >
            Save
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp channel_label(:whatsapp), do: "WhatsApp"
  defp channel_label(:sms), do: "SMS"
  defp channel_label(:email), do: "Email"

  defp event_label(:new_message), do: "Someone messages you"
  defp event_label(:order_status_changed), do: "An order changes"
  defp event_label(:supplier_connection), do: "A supplier request"
  defp event_label(:announcement), do: "News from Makola"
  defp event_label(:billing_warning), do: "A billing problem"
  defp event_label(:system), do: "Account notices"
  defp event_label(:order_placed), do: "A new order"
  defp event_label(:payment_received), do: "You get paid"
  defp event_label(:payout_sent), do: "A payout is sent"
  defp event_label(:verification_result), do: "Your shop is checked"
  defp event_label(:product_moderated), do: "A product is reviewed"
  defp event_label(other), do: other |> to_string() |> String.replace("_", " ")

  defp always_on_reason(:payout_sent), do: "you should always know when money moves"
  defp always_on_reason(:payment_received), do: "you should always know when money moves"
  defp always_on_reason(:order_placed), do: "a buyer is waiting"
  defp always_on_reason(_event), do: "this affects whether your shop can sell"
end
