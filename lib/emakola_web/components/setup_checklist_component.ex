defmodule EmakolaWeb.SetupChecklistComponent do
  @moduledoc """
  Renders the merchant's "store setup" checklist as a card on the
  Dashboard. Each step shows done/todo state with a material icon;
  pending steps link to their setup page. The whole card hides itself
  when all steps are complete so finished merchants aren't nagged.

  Pure presentation — accepts the pre-computed `steps` list from
  `Emakola.Onboarding.SetupChecklist`. The dashboard does the
  computation in mount and passes results in.

  ## Usage

      <SetupChecklistComponent.setup_checklist steps={@setup_steps} />
  """

  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [icon: 1]

  attr :steps, :list, required: true, doc: "list returned by SetupChecklist.steps/2"
  attr :celebrated?, :boolean, default: true, doc: "the all-done banner was already dismissed"
  attr :shop_path, :string, default: nil, doc: "public storefront path, for the See my shop link"

  def setup_checklist(assigns) do
    completed = Enum.count(assigns.steps, & &1.done?)
    total = length(assigns.steps)
    all_done = completed == total

    assigns =
      assigns
      |> assign(:completed, completed)
      |> assign(:total, total)
      |> assign(:all_done, all_done)
      |> assign(:next_step, Enum.find(assigns.steps, &(!&1.done?)))
      |> assign(
        :segments,
        assigns.steps
        |> Enum.drop(-1)
        |> Enum.with_index()
        |> Enum.map(fn {s, i} -> {s.done?, i} end)
      )

    ~H"""
    <div
      :if={@all_done && !@celebrated?}
      id="setup-celebration"
      class="flex flex-col gap-4 rounded-card bg-gradient-to-br from-emerald-600 to-emerald-700 p-5 sm:flex-row sm:items-center sm:gap-5 sm:px-6"
    >
      <svg width="44" height="44" viewBox="0 0 64 64" class="shrink-0" aria-hidden="true">
        <circle cx="32" cy="32" r="27" fill="none" stroke="rgba(255,255,255,0.25)" stroke-width="7" />
        <path
          d="M22 33l7 7 13-14"
          fill="none"
          stroke="#ffffff"
          stroke-width="5"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
      <div class="flex-1">
        <p class="text-base font-extrabold text-white">Your shop is ready</p>
        <p class="text-xs text-white/85 mt-0.5">All {@total} setup steps are done.</p>
      </div>
      <div class="flex items-center gap-2">
        <.link
          :if={@shop_path}
          navigate={@shop_path}
          class="rounded-control border border-white/30 bg-white/15 px-4 py-2.5 text-xs font-bold text-white transition-colors hover:bg-white/25"
        >
          See my shop
        </.link>
        <button
          id="setup-celebration-dismiss"
          type="button"
          phx-click="dismiss_setup_celebration"
          aria-label="Dismiss"
          class="flex size-9 items-center justify-center rounded-full text-white/70 transition-colors hover:bg-white/15 hover:text-white cursor-pointer"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
    </div>

    <div
      :if={!@all_done}
      id="setup-journey"
      class="rounded-card border border-border bg-surface p-5 sm:p-6"
    >
      <div class="flex items-center gap-3">
        <div class="min-w-0 flex-1">
          <h2 class="text-[17px] font-extrabold text-slate-900">Set up your shop</h2>
          <p class="mt-0.5 text-[13px] text-slate-500">
            {@completed} of {@total} done. One step at a time.
          </p>
        </div>
        <span class="flex items-center gap-1.5 rounded-full bg-primary-soft px-3.5 py-1.5 text-xs font-bold text-emerald-700">
          <.icon name="hero-check" class="size-3.5" /> {@completed}/{@total}
        </span>
      </div>

      <%!-- The journey, drawn as a tracker: done stops filled, the next stop
           ringed and carrying the page's only Start button. --%>
      <div
        class="relative mt-7 hidden sm:grid"
        style={"grid-template-columns: repeat(#{@total}, minmax(0, 1fr));"}
      >
        <div
          :for={{done?, index} <- @segments}
          class={[
            "absolute top-6 h-1 rounded-full",
            if(done?, do: "bg-emerald-600", else: "bg-slate-200")
          ]}
          style={segment_style(index, @total)}
        >
        </div>
        <div :for={step <- @steps} class="relative flex flex-col items-center gap-2.5 px-2">
          <div
            :if={step.done?}
            class="flex size-[52px] items-center justify-center rounded-full bg-emerald-600 border-4 border-white shadow-[0_0_0_1px_theme(colors.emerald.200)]"
          >
            <.icon name="hero-check" class="size-5 text-white" />
          </div>
          <div
            :if={!step.done? && current?(step, @next_step)}
            class="flex size-[52px] items-center justify-center rounded-full bg-primary-soft border-4 border-white shadow-[0_0_0_2.5px_theme(colors.emerald.600),0_8px_18px_rgba(5,150,105,0.25)]"
          >
            <span class="material-symbols-outlined text-2xl text-emerald-600">{step.icon}</span>
          </div>
          <div
            :if={!step.done? && !current?(step, @next_step)}
            class="flex size-[52px] items-center justify-center rounded-full bg-slate-100 border-4 border-white shadow-[0_0_0_1px_theme(colors.slate.200)]"
          >
            <span class="material-symbols-outlined text-2xl text-slate-400">{step.icon}</span>
          </div>

          <p :if={step.done?} class="text-center text-xs font-bold text-emerald-700">
            {step.title}
          </p>
          <div
            :if={!step.done? && current?(step, @next_step)}
            class="flex flex-col items-center gap-2"
          >
            <div class="text-center">
              <p class="text-[10px] font-extrabold uppercase tracking-wider text-emerald-600">
                Do this now
              </p>
              <p class="mt-0.5 text-[13px] font-extrabold text-slate-900">{step.title}</p>
            </div>
            <.link
              navigate={step.cta_path}
              class="inline-flex items-center gap-1.5 rounded-control bg-primary px-5 py-2.5 text-[13px] font-bold text-white shadow-lg shadow-emerald-600/30 transition-colors hover:bg-primary-hover"
            >
              Start <.icon name="hero-arrow-right" class="size-3" />
            </.link>
          </div>
          <p
            :if={!step.done? && !current?(step, @next_step)}
            class="text-center text-xs font-semibold text-slate-500"
          >
            {step.title}
          </p>
        </div>
      </div>

      <%!-- On the phone the tracker turns vertical, like package tracking. --%>
      <div class="mt-4 sm:hidden">
        <div :for={{step, index} <- Enum.with_index(@steps)} class="flex items-stretch gap-3.5">
          <div class="flex w-[42px] shrink-0 flex-col items-center">
            <div
              :if={index > 0}
              class={[
                "h-3.5 w-1 rounded-full",
                if(Enum.at(@steps, index - 1).done?, do: "bg-emerald-600", else: "bg-slate-200")
              ]}
            >
            </div>
            <div :if={index == 0} class="h-3.5"></div>
            <div
              :if={step.done?}
              class="flex size-[42px] items-center justify-center rounded-full bg-emerald-600 border-[3px] border-white shadow-[0_0_0_1px_theme(colors.emerald.200)]"
            >
              <.icon name="hero-check" class="size-4 text-white" />
            </div>
            <div
              :if={!step.done? && current?(step, @next_step)}
              class="flex size-[42px] items-center justify-center rounded-full bg-primary-soft border-[3px] border-white shadow-[0_0_0_2px_theme(colors.emerald.600),0_6px_14px_rgba(5,150,105,0.25)]"
            >
              <span class="material-symbols-outlined text-xl text-emerald-600">{step.icon}</span>
            </div>
            <div
              :if={!step.done? && !current?(step, @next_step)}
              class="flex size-[42px] items-center justify-center rounded-full bg-slate-100 border-[3px] border-white shadow-[0_0_0_1px_theme(colors.slate.200)]"
            >
              <span class="material-symbols-outlined text-xl text-slate-400">{step.icon}</span>
            </div>
          </div>

          <div class="flex min-w-0 flex-1 items-center gap-3 pt-3">
            <p :if={step.done?} class="text-sm font-bold text-emerald-700 line-through">
              {step.title}
            </p>
            <div
              :if={!step.done? && current?(step, @next_step)}
              class="flex min-w-0 flex-1 items-center gap-3"
            >
              <div class="min-w-0 flex-1">
                <p class="text-[9.5px] font-extrabold uppercase tracking-wider text-emerald-600">
                  Do this now
                </p>
                <p class="truncate text-sm font-extrabold text-slate-900">{step.title}</p>
              </div>
              <.link
                navigate={step.cta_path}
                class="inline-flex shrink-0 items-center gap-1.5 rounded-control bg-primary px-4 py-2.5 text-xs font-bold text-white transition-colors hover:bg-primary-hover"
              >
                Start <.icon name="hero-arrow-right" class="size-3" />
              </.link>
            </div>
            <p
              :if={!step.done? && !current?(step, @next_step)}
              class="text-sm font-semibold text-slate-500"
            >
              {step.title}
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp current?(step, next_step), do: next_step && step.key == next_step.key

  # Node centres sit at (100/2n) + i·(100/n) percent; segment i joins centres
  # i and i+1, coloured by whether step i is done.
  defp segment_style(index, total) do
    left = 100 / (2 * total) + index * 100 / total
    "left: #{Float.round(left, 2)}%; width: #{Float.round(100 / total, 2)}%;"
  end
end
