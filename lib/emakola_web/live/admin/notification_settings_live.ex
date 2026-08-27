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

  @impl true
  def handle_event("save_preferences", %{"preferences" => params}, socket) do
    merchant = socket.assigns.current_merchant

    # Only events this page offers, cast through an allowlist — the names
    # arrive from the client.
    Enum.each(params, fn {event_name, channels} ->
      case Preferences.cast_event(event_name) do
        nil ->
          :ok

        event ->
          if event in Preferences.configurable_events() do
            Preferences.put_channels(merchant, event, checked_channels(channels))
          end
      end
    end)

    {:noreply,
     socket
     |> put_flash(:info, "Saved.")
     |> load()}
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

  # `in_app` is never in the form, so it is never removed here — it is added
  # back by `Preferences.channels_for/3` regardless of what is stored.
  defp checked_channels(channels) when is_map(channels) do
    channels
    |> Enum.filter(fn {_name, value} -> value in ["true", "on", true] end)
    |> Enum.map(fn {name, _value} -> Preferences.cast_channel_name(name) end)
    |> Enum.reject(&is_nil/1)
  end

  defp checked_channels(_channels), do: []

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
    <div class="max-w-3xl mx-auto px-4 py-8 space-y-8">
      <div>
        <h1 class="text-2xl font-semibold text-slate-900">Notifications</h1>
        <p class="text-sm text-slate-500 mt-1">
          Choose how Makola reaches you. Messages in your dashboard are always on.
        </p>
      </div>

      <.form
        for={%{}}
        id="notification-preferences"
        phx-submit="save_preferences"
        class="rounded-2xl border border-slate-200 bg-white overflow-hidden"
      >
        <table class="w-full text-sm">
          <thead class="bg-slate-50 text-slate-500">
            <tr>
              <th class="text-left font-medium px-4 py-3">What happens</th>
              <th :for={channel <- Preferences.switchable_channels()} class="font-medium px-3 py-3">
                {channel_label(channel)}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr :for={event <- Preferences.configurable_events()}>
              <td class="px-4 py-3 text-slate-700">{event_label(event)}</td>
              <td
                :for={channel <- Preferences.switchable_channels()}
                class="px-3 py-3 text-center"
              >
                <input type="hidden" name={"preferences[#{event}][#{channel}]"} value="false" />
                <input
                  type="checkbox"
                  name={"preferences[#{event}][#{channel}]"}
                  value="true"
                  checked={channel in Map.get(@chosen, event, [])}
                  class="w-4 h-4 rounded border-slate-300 text-emerald-600 cursor-pointer"
                />
              </td>
            </tr>

            <tr :for={event <- Preferences.always_on()} class="bg-slate-50/60">
              <td class="px-4 py-3 text-slate-700">{event_label(event)}</td>
              <td
                colspan={length(Preferences.switchable_channels())}
                class="px-3 py-3 text-center text-xs text-slate-500"
              >
                Always on — {always_on_reason(event)}
              </td>
            </tr>
          </tbody>
        </table>

        <div class="px-4 py-3 bg-slate-50 border-t border-slate-100 flex justify-end">
          <button
            type="submit"
            class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700 transition-colors cursor-pointer"
          >
            Save
          </button>
        </div>
      </.form>

      <.form
        for={%{}}
        id="quiet-hours"
        phx-submit="save_quiet_hours"
        class="rounded-2xl border border-slate-200 bg-white p-4 space-y-4"
      >
        <div>
          <h2 class="text-base font-semibold text-slate-900">Quiet hours</h2>
          <p class="text-sm text-slate-500 mt-1">
            Nothing will ring your phone between these times. It waits, and reaches you
            after. Money and new orders always get through.
          </p>
        </div>

        <div class="flex items-end gap-4">
          <label class="block">
            <span class="block text-xs font-medium text-slate-500 mb-1">From</span>
            <input
              type="time"
              name="quiet_hours[start]"
              value={@quiet_start}
              class="rounded-lg border-slate-300 text-sm"
            />
          </label>
          <label class="block">
            <span class="block text-xs font-medium text-slate-500 mb-1">Until</span>
            <input
              type="time"
              name="quiet_hours[end]"
              value={@quiet_end}
              class="rounded-lg border-slate-300 text-sm"
            />
          </label>
          <button
            type="submit"
            class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700 transition-colors cursor-pointer"
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
