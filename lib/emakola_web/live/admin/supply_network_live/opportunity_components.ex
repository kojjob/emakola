defmodule EmakolaWeb.Admin.SupplyNetworkLive.OpportunityComponents do
  @moduledoc false

  use EmakolaWeb, :html

  import EmakolaWeb.Admin.SupplyNetworkLive.Presentation

  attr :business_command_form, :any, required: true
  attr :pending_business_command, :any, required: true
  attr :starter_business_form, :any, required: true
  attr :streams, :map, required: true
  attr :supplier_demand_alert_count, :integer, required: true

  def opportunities(assigns) do
    ~H"""
    <.opportunity_radar
      business_command_form={@business_command_form}
      pending_business_command={@pending_business_command}
      starter_business_form={@starter_business_form}
      streams={@streams}
      supplier_demand_alert_count={@supplier_demand_alert_count}
    />
    <.business_in_a_box
      business_command_form={@business_command_form}
      pending_business_command={@pending_business_command}
      starter_business_form={@starter_business_form}
      streams={@streams}
      supplier_demand_alert_count={@supplier_demand_alert_count}
    />
    """
  end

  attr :business_command_form, :any, required: true
  attr :pending_business_command, :any, required: true
  attr :starter_business_form, :any, required: true
  attr :streams, :map, required: true
  attr :supplier_demand_alert_count, :integer, required: true

  def opportunity_radar(assigns) do
    ~H"""
    <section
      id="opportunity-radar"
      aria-labelledby="opportunity-radar-heading"
      class="rounded-3xl border border-sky-200 bg-sky-50/60 p-6 shadow-sm sm:p-8"
    >
      <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <span class="text-xs font-bold uppercase tracking-[0.18em] text-sky-700">
            Live Opportunity Radar
          </span>
          <h2 id="opportunity-radar-heading" class="mt-1 text-2xl font-bold text-slate-950">
            See demand without exposing customers
          </h2>
          <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
            Searches are fingerprinted, locations appear only after three attributed orders, and every price stays inside supplier bounds with no scarcity surcharge.
          </p>
        </div>
        <button
          id="refresh-opportunity-radar"
          phx-click="refresh_opportunity_radar"
          class="inline-flex h-10 items-center justify-center gap-2 rounded-xl border border-sky-200 bg-white px-4 text-xs font-bold text-sky-800 transition hover:bg-sky-100"
        >
          <.icon name="hero-arrow-path" class="size-4" /> Refresh signals
        </button>
      </div>

      <div id="opportunity-radar-items" phx-update="stream" class="mt-6 grid gap-4 lg:grid-cols-2">
        <div
          id="opportunity-radar-empty"
          class="hidden only:block rounded-2xl border border-dashed border-sky-200 bg-white p-8 text-center lg:col-span-2"
        >
          <p class="text-sm font-semibold text-slate-700">
            Connect to a supplier to begin collecting privacy-safe opportunity signals.
          </p>
        </div>
        <article
          :for={{dom_id, item} <- @streams.opportunity_radar}
          id={dom_id}
          class="rounded-2xl border border-sky-100 bg-white p-5 shadow-sm"
        >
          <div class="flex items-start justify-between gap-3">
            <div>
              <h3 class="font-bold text-slate-900">{item.title}</h3>
              <p class="mt-1 text-xs text-slate-400">{item.freshness.label}</p>
            </div>
            <span class="rounded-full bg-sky-50 px-2.5 py-1 text-[10px] font-bold uppercase text-sky-700">
              {item.confidence} confidence
            </span>
          </div>
          <p class="mt-4 text-xs leading-5 text-slate-600">{item.explanation}</p>
          <dl class="mt-4 grid grid-cols-4 gap-2">
            <div class="rounded-xl bg-slate-50 p-2 text-center">
              <dt class="text-[9px] font-bold uppercase text-slate-400">Views</dt>
              <dd class="mt-1 font-black text-slate-800">{item.views}</dd>
            </div>
            <div class="rounded-xl bg-slate-50 p-2 text-center">
              <dt class="text-[9px] font-bold uppercase text-slate-400">Searches</dt>
              <dd class="mt-1 font-black text-slate-800">{item.searches}</dd>
            </div>
            <div class="rounded-xl bg-slate-50 p-2 text-center">
              <dt class="text-[9px] font-bold uppercase text-slate-400">Fulfilled</dt>
              <dd class="mt-1 font-black text-emerald-700">{item.fulfilled}</dd>
            </div>
            <div class="rounded-xl bg-slate-50 p-2 text-center">
              <dt class="text-[9px] font-bold uppercase text-slate-400">Stock</dt>
              <dd class="mt-1 font-black text-slate-800">{item.stock}</dd>
            </div>
          </dl>
          <div class="mt-4 rounded-xl border border-emerald-100 bg-emerald-50 p-3">
            <div class="flex items-center justify-between gap-3">
              <div>
                <p class="text-[10px] font-bold uppercase text-emerald-700">
                  Ethical recommended price
                </p>
                <p class="mt-1 text-lg font-black text-emerald-800">{money(item.pricing.price)}</p>
              </div>
              <span class="rounded-full bg-white px-2 py-1 text-[10px] font-bold text-emerald-700">
                0 scarcity surcharge
              </span>
            </div>
            <p class="mt-2 text-[11px] leading-4 text-emerald-900/70">{item.pricing.reason}</p>
          </div>
          <p :if={item.regions != []} class="mt-3 text-xs text-slate-500">
            Privacy-safe demand regions: {Enum.map_join(item.regions, ", ", fn {region, count} ->
              "#{region} (#{count})"
            end)}
          </p>
        </article>
      </div>

      <div
        :if={@supplier_demand_alert_count > 0}
        id="supplier-demand-alerts"
        class="mt-6 rounded-2xl border border-amber-200 bg-amber-50 p-5"
      >
        <p class="text-xs font-bold uppercase tracking-wider text-amber-800">
          Supplier demand alerts
        </p>
        <div id="supplier-demand-alert-items" phx-update="stream" class="mt-3 space-y-2">
          <article
            :for={{dom_id, alert} <- @streams.supplier_demand_alerts}
            id={dom_id}
            class="rounded-xl bg-white p-3 text-sm text-slate-700 shadow-sm"
          >
            <span class="font-bold">{alert.metadata["title"]}</span>
            received {Emakola.Plural.count(alert.metadata["views"], "view")} and {Emakola.Plural.count(
              alert.metadata["matched_searches"],
              "matched search"
            )} but no orders in the {alert.metadata[
              "window_days"
            ]}-day window. Review price, content, availability, or trust signals.
          </article>
        </div>
      </div>
    </section>
    """
  end

  attr :business_command_form, :any, required: true
  attr :pending_business_command, :any, required: true
  attr :starter_business_form, :any, required: true
  attr :streams, :map, required: true
  attr :supplier_demand_alert_count, :integer, required: true

  def business_in_a_box(assigns) do
    ~H"""
    <section
      id="business-in-a-box"
      aria-labelledby="business-command-heading"
      class="rounded-3xl border border-cyan-200 bg-gradient-to-br from-cyan-50 to-white p-6 shadow-sm sm:p-8"
    >
      <div class="flex items-start gap-4">
        <div class="flex size-11 shrink-0 items-center justify-center rounded-2xl bg-cyan-600 text-white">
          <.icon name="hero-microphone" class="size-5" />
        </div>
        <div>
          <span class="text-xs font-bold uppercase tracking-[0.18em] text-cyan-700">
            Business-in-a-Box
          </span>
          <h2 id="business-command-heading" class="mt-1 text-xl font-bold text-slate-950">
            Say what you want to build
          </h2>
          <p class="mt-1 text-sm text-slate-600">
            Voice becomes editable text. Makola always shows the exact action and waits for confirmation before changing your store.
          </p>
        </div>
      </div>

      <.form
        for={@business_command_form}
        id="business-command-form"
        phx-submit="preview_business_command"
        class="mt-6"
      >
        <div
          id="voice-command-control"
          phx-hook=".VoiceCommand"
          class="flex flex-col gap-3 sm:flex-row"
        >
          <.input
            field={@business_command_form[:instruction]}
            type="text"
            placeholder="Add three products, create a Sales Kit…"
            required
            class="h-12 w-full rounded-xl border border-cyan-200 bg-white px-4 text-sm text-slate-900 outline-none transition focus:border-cyan-500 focus:ring-4 focus:ring-cyan-100"
          />
          <button
            id="voice-command-button"
            type="button"
            class="inline-flex h-12 shrink-0 items-center justify-center gap-2 rounded-xl border border-cyan-200 bg-white px-4 text-sm font-bold text-cyan-800 transition hover:bg-cyan-50"
          >
            <.icon name="hero-microphone" class="size-4" /> Speak
          </button>
          <button
            id="preview-business-command"
            type="submit"
            class="inline-flex h-12 shrink-0 items-center justify-center rounded-xl bg-cyan-700 px-5 text-sm font-bold text-white transition hover:bg-cyan-800"
          >
            Preview action
          </button>
        </div>
      </.form>

      <div
        :if={@pending_business_command}
        id="business-command-preview"
        class="mt-4 rounded-2xl border border-cyan-200 bg-white p-5 shadow-sm"
      >
        <p class="text-xs font-bold uppercase tracking-wide text-cyan-700">Confirmation required</p>
        <p class="mt-2 text-sm font-semibold text-slate-900">{@pending_business_command.preview}</p>
        <p class="mt-1 text-xs text-slate-500">
          Original instruction: “{@pending_business_command.original}”
        </p>
        <div class="mt-4 flex gap-2">
          <button
            id="confirm-business-command"
            phx-click="confirm_business_command"
            class="rounded-xl bg-cyan-700 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-cyan-800"
          >
            Confirm
          </button>
          <button
            id="cancel-business-command"
            phx-click="cancel_business_command"
            class="rounded-xl border border-slate-200 px-4 py-2.5 text-sm font-bold text-slate-600 transition hover:bg-slate-50"
          >
            Cancel
          </button>
        </div>
      </div>

      <div class="my-6 flex items-center gap-3">
        <span class="h-px flex-1 bg-cyan-100"></span>
        <span class="text-[10px] font-bold uppercase tracking-wider text-cyan-600">
          or launch a complete starter
        </span>
        <span class="h-px flex-1 bg-cyan-100"></span>
      </div>
      <.form
        for={@starter_business_form}
        id="starter-business-form"
        phx-submit="build_starter_business"
        class="grid gap-3 sm:grid-cols-[1fr_180px_auto] sm:items-end"
      >
        <.input
          field={@starter_business_form[:niche]}
          type="text"
          label="Your niche or audience"
          placeholder="Women’s fashion, school essentials…"
          required
        />
        <.input
          field={@starter_business_form[:count]}
          type="select"
          label="Starter size"
          options={[{"3 products", "3"}, {"5 products", "5"}]}
        />
        <button
          id="build-starter-business"
          type="submit"
          class="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-slate-950 px-5 text-sm font-bold text-white transition hover:-translate-y-0.5 hover:bg-cyan-800"
        >
          <.icon name="hero-building-storefront" class="size-4" /> Build starter business
        </button>
      </.form>
      <p class="mt-2 text-xs text-slate-500">
        This adds eligible products to your existing branded storefront, creates tracked links,
        and prepares content drafts for review. It never publishes claims without your approval.
      </p>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".VoiceCommand">
        export default {
          mounted() {
            const button = this.el.querySelector("#voice-command-button")
            const input = this.el.querySelector("input[name='business_command[instruction]']")
            const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition

            button.addEventListener("click", () => {
              if (!Recognition) {
                input.focus()
                input.placeholder = "Voice input is not supported by this browser. Type your instruction."
                return
              }

              const recognition = new Recognition()
              recognition.lang = document.documentElement.lang || "en-GH"
              recognition.interimResults = false
              button.textContent = "Listening…"
              recognition.onresult = event => {
                input.value = event.results[0][0].transcript
                input.dispatchEvent(new Event("input", {bubbles: true}))
              }
              recognition.onend = () => { button.textContent = "Speak" }
              recognition.onerror = () => { button.textContent = "Try again" }
              recognition.start()
            })
          }
        }
      </script>
    </section>
    """
  end
end
