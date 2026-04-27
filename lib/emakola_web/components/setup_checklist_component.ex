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
      |> assign(:progress_pct, if(total == 0, do: 0, else: round(completed / total * 100)))

    ~H"""
    <div :if={!@all_done} class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <%!-- Header with progress bar --%>
      <div class="px-5 py-4 border-b border-slate-100">
        <div class="flex items-center justify-between mb-3">
          <div class="flex items-center gap-2">
            <span class="material-symbols-outlined text-xl text-emerald-600">checklist</span>
            <h2 class="text-base font-bold text-slate-800">Finish setting up your store</h2>
          </div>
          <span class="text-xs font-semibold text-slate-500">
            {@completed} of {@total} done
          </span>
        </div>
        <div class="h-1.5 bg-slate-100 rounded-full overflow-hidden">
          <div
            class="h-full bg-emerald-500 transition-all duration-500 ease-out"
            style={"width: #{@progress_pct}%"}
          >
          </div>
        </div>
      </div>

      <%!-- Step list --%>
      <ul class="divide-y divide-slate-100">
        <li :for={step <- @steps} class="px-5 py-3 flex items-center gap-4">
          <%!-- Status icon --%>
          <div class={[
            "w-9 h-9 rounded-xl flex items-center justify-center shrink-0 transition-colors",
            if(step.done?, do: "bg-emerald-50", else: "bg-slate-50")
          ]}>
            <span :if={step.done?} class="material-symbols-outlined text-lg text-emerald-600">
              check_circle
            </span>
            <span :if={!step.done?} class="material-symbols-outlined text-lg text-slate-400">
              {step.icon}
            </span>
          </div>

          <%!-- Title + description --%>
          <div class="flex-1 min-w-0">
            <p class={[
              "text-sm font-semibold",
              if(step.done?, do: "text-slate-400 line-through", else: "text-slate-900")
            ]}>
              {step.title}
            </p>
            <p :if={!step.done?} class="text-xs text-slate-500 mt-0.5">
              {step.description}
            </p>
          </div>

          <%!-- CTA --%>
          <.link
            :if={!step.done?}
            navigate={step.cta_path}
            class="inline-flex items-center gap-1 text-sm font-medium text-emerald-600 hover:text-emerald-700 shrink-0"
          >
            {step.cta_label}
            <span class="material-symbols-outlined text-base">arrow_forward</span>
          </.link>
        </li>
      </ul>
    </div>
    """
  end
end
