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

    ~H"""
    <div
      :if={!@all_done}
      id="setup-journey"
      class="rounded-card border border-border bg-surface p-4 sm:p-5"
    >
      <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:gap-6">
        <div class="flex items-center gap-4 min-w-0">
          <svg width="56" height="56" viewBox="0 0 64 64" class="shrink-0" aria-hidden="true">
            <circle cx="32" cy="32" r="27" fill="none" stroke="#e2e8f0" stroke-width="7" />
            <circle
              cx="32"
              cy="32"
              r="27"
              fill="none"
              stroke="#059669"
              stroke-width="7"
              stroke-linecap="round"
              stroke-dasharray="169.6"
              stroke-dashoffset={ring_offset(@completed, @total)}
              transform="rotate(-90 32 32)"
            />
            <text
              x="32"
              y="30"
              text-anchor="middle"
              class="fill-slate-900 font-extrabold"
              font-size="15"
            >
              {@completed}/{@total}
            </text>
            <text
              x="32"
              y="43"
              text-anchor="middle"
              class="fill-slate-400 font-semibold"
              font-size="8.5"
            >
              done
            </text>
          </svg>
          <div class="min-w-0">
            <h2 class="text-base font-extrabold text-slate-900">Set up your shop</h2>
            <p class="text-xs text-slate-500 mt-0.5">{@total} small steps. Do one now.</p>
          </div>
        </div>

        <div
          :if={@next_step}
          class="flex flex-1 items-center gap-3 rounded-[13px] border-2 border-emerald-600 px-4 py-3 shadow-lg shadow-emerald-600/15"
        >
          <div class="flex size-10 shrink-0 items-center justify-center rounded-control bg-primary-soft">
            <span class="material-symbols-outlined text-xl text-emerald-600">{@next_step.icon}</span>
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-[10px] font-extrabold uppercase tracking-wider text-emerald-600">
              Do this now
            </p>
            <p class="text-sm font-bold text-slate-900 truncate">{@next_step.title}</p>
          </div>
          <.link
            navigate={@next_step.cta_path}
            class="inline-flex shrink-0 items-center gap-1.5 rounded-control bg-primary px-4 py-2.5 text-xs font-bold text-white transition-colors hover:bg-primary-hover"
          >
            Start <.icon name="hero-arrow-right" class="size-3" />
          </.link>
        </div>

        <div class="hidden lg:flex items-center gap-1.5" aria-hidden="true">
          <div
            :for={step <- @steps}
            class={[
              "h-[7px] w-8 rounded-full",
              if(step.done?, do: "bg-emerald-600", else: "bg-slate-200")
            ]}
          >
          </div>
        </div>
      </div>

      <%!-- The remaining steps, quiet, tappable --%>
      <div class="mt-4 flex flex-wrap gap-2">
        <.link
          :for={step <- @steps}
          :if={!step.done? && @next_step && step.key != @next_step.key}
          navigate={step.cta_path}
          class="inline-flex items-center gap-2 rounded-full border border-border bg-surface px-3.5 py-2 text-xs font-semibold text-slate-600 transition-colors hover:border-slate-300"
        >
          <span class="material-symbols-outlined text-base text-slate-400">{step.icon}</span>
          {step.title}
        </.link>
        <span
          :for={step <- @steps}
          :if={step.done?}
          class="inline-flex items-center gap-2 rounded-full bg-primary-soft px-3.5 py-2 text-xs font-semibold text-emerald-700 line-through"
        >
          <.icon name="hero-check" class="size-3.5" />
          {step.title}
        </span>
      </div>
    </div>
    """
  end

  # 169.6 is the ring circumference (2πr, r=27).
  defp ring_offset(_completed, 0), do: 169.6
  defp ring_offset(completed, total), do: Float.round(169.6 * (1 - completed / total), 1)
end
