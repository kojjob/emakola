defmodule EmakolaWeb.Admin.SupplyNetworkLive.GoalComponents do
  @moduledoc false

  use EmakolaWeb, :html

  import EmakolaWeb.Admin.SupplyNetworkLive.Presentation

  attr :goal_progress, :any, required: true
  attr :hustle_listings, :list, required: true
  attr :hustle_opportunities, :list, required: true
  attr :hustle_plan, :any, required: true
  attr :hustle_shares, :list, required: true
  attr :income_goal, :any, required: true
  attr :income_goal_form, :any, required: true

  def goal(assigns) do
    ~H"""
    <section
      id="hustle-autopilot"
      aria-labelledby="hustle-autopilot-heading"
      class="overflow-hidden rounded-3xl border border-violet-200 bg-gradient-to-br from-violet-50 via-white to-emerald-50 p-6 shadow-sm sm:p-8"
    >
      <div class="flex items-start gap-4">
        <div class="flex size-12 shrink-0 items-center justify-center rounded-2xl bg-violet-600 text-white shadow-lg shadow-violet-200">
          <.icon name="hero-rocket-launch" class="size-6" />
        </div>
        <div>
          <span class="text-xs font-bold uppercase tracking-[0.18em] text-violet-700">
            Hustle Autopilot
          </span>
          <h2 id="hustle-autopilot-heading" class="mt-1 text-2xl font-bold text-slate-950">
            Turn an income goal into today's next action
          </h2>
          <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
            Makola uses real partner-product economics to estimate the sales needed and build a focused seven-day plan. Income is never guaranteed.
          </p>
        </div>
      </div>

      <%= if @income_goal do %>
        <div id="active-income-goal" class="mt-7 grid gap-6 lg:grid-cols-[0.8fr_1.2fr]">
          <div class="rounded-2xl bg-slate-950 p-5 text-white shadow-xl">
            <p class="text-xs font-bold uppercase tracking-wider text-violet-300">Your target</p>
            <p id="income-goal-target" class="mt-2 text-3xl font-black">
              {money(@income_goal.target_amount)}
            </p>
            <p class="mt-1 text-sm text-slate-300">
              over {Emakola.Plural.count(@income_goal.timeframe_days, "day")} · {Emakola.Plural.count(
                @income_goal.daily_minutes,
                "minute"
              )}/day
            </p>
            <div class="mt-5 grid grid-cols-2 gap-3">
              <div class="rounded-xl bg-white/10 p-3">
                <p class="text-[10px] uppercase text-slate-400">Estimated sales</p>
                <p id="income-goal-required-sales" class="mt-1 text-xl font-bold">
                  {@hustle_plan.required_sales}
                </p>
              </div>
              <div class="rounded-xl bg-white/10 p-3">
                <p class="text-[10px] uppercase text-slate-400">Per day</p>
                <p class="mt-1 text-xl font-bold">{@hustle_plan.daily_sales_target}</p>
              </div>
            </div>
            <p id="income-goal-disclaimer" class="mt-4 text-xs leading-5 text-slate-400">
              {@hustle_plan.disclaimer}
            </p>
          </div>

          <div>
            <div id="hustle-recommendations" class="mb-6">
              <h3 class="text-sm font-bold text-slate-900">Why these products</h3>
              <div class="mt-3 space-y-2">
                <article
                  :for={item <- Enum.take(@hustle_plan.recommended, 3)}
                  id={"hustle-recommendation-#{item.id}"}
                  class="rounded-xl border border-violet-100 bg-white p-3 shadow-sm"
                >
                  <div class="flex items-start justify-between gap-3">
                    <p class="text-sm font-bold text-slate-900">{item.title}</p>
                    <span class="rounded-full bg-violet-50 px-2 py-1 text-[10px] font-bold uppercase text-violet-700">
                      {item.confidence} evidence
                    </span>
                  </div>
                  <dl class="mt-3 grid grid-cols-4 gap-2 text-xs">
                    <div>
                      <dt class="text-slate-400">Supplier</dt>
                      <dd class="font-bold text-slate-700">{money(item.supplier_price)}</dd>
                    </div>
                    <div>
                      <dt class="text-slate-400">Customer</dt>
                      <dd class="font-bold text-slate-700">{money(item.retail_price)}</dd>
                    </div>
                    <div>
                      <dt class="text-slate-400">Fee</dt>
                      <dd class="font-bold text-slate-700">{money(item.platform_fee)}</dd>
                    </div>
                    <div>
                      <dt class="text-emerald-600">You earn</dt>
                      <dd class="font-bold text-emerald-700">{money(item.earning)}</dd>
                    </div>
                  </dl>
                  <p class="mt-2 text-[11px] leading-4 text-slate-500">{item.reason}</p>
                </article>
              </div>
            </div>
            <h3 class="text-sm font-bold text-slate-900">Your next seven actions</h3>
            <ol id="hustle-plan-actions" class="mt-3 space-y-2">
              <li
                :for={action <- @hustle_plan.actions}
                id={"hustle-action-#{action.day}"}
                class="flex items-center gap-3 rounded-xl border border-slate-200 bg-white p-3"
              >
                <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-violet-100 text-xs font-black text-violet-700">
                  {action.day}
                </span>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-semibold text-slate-800">{action.message}</p>
                  <p class="text-xs text-slate-400">
                    About {Emakola.Plural.count(action.minutes, "minute")}
                  </p>
                </div>
              </li>
            </ol>
          </div>
        </div>

        <div
          :if={@goal_progress}
          id="income-goal-progress"
          class="mt-6 rounded-2xl border border-emerald-200 bg-white p-5 shadow-sm"
        >
          <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p class="text-xs font-bold uppercase tracking-wider text-emerald-700">
                Real fulfilled earnings
              </p>
              <p id="goal-net-earned" class="mt-1 text-2xl font-black text-slate-950">
                {money(@goal_progress.net_earned)}
              </p>
              <p class="text-xs text-slate-500">
                {money(@goal_progress.remaining)} remaining toward this scenario
              </p>
            </div>
            <p id="goal-progress-percent" class="text-3xl font-black text-emerald-700">
              {@goal_progress.percent}%
            </p>
          </div>
          <div class="mt-4 h-2 overflow-hidden rounded-full bg-slate-100">
            <div
              class="h-full rounded-full bg-emerald-500 transition-all duration-500"
              style={"width: #{@goal_progress.percent}%"}
            >
            </div>
          </div>
          <dl class="mt-5 grid grid-cols-3 gap-3 sm:grid-cols-6">
            <div
              :for={
                {label, value} <- [
                  {"Published", @goal_progress.published},
                  {"Shared", @goal_progress.shared},
                  {"Clicked", @goal_progress.clicked},
                  {"Ordered", @goal_progress.ordered},
                  {"Fulfilled", @goal_progress.fulfilled},
                  {"Refunded", @goal_progress.refunded}
                ]
              }
              class="rounded-xl bg-slate-50 p-3 text-center"
            >
              <dt class="text-[10px] font-bold uppercase text-slate-400">{label}</dt>
              <dd class="mt-1 text-lg font-black text-slate-800">{value}</dd>
            </div>
          </dl>
          <div
            id="goal-next-action"
            class="mt-5 flex flex-wrap items-center gap-3 border-t border-slate-100 pt-4"
          >
            <p class="mr-auto text-sm font-semibold text-slate-700">
              {next_action_message(@goal_progress.next_action)}
            </p>
            <button
              :if={@goal_progress.next_action == :publish && @hustle_opportunities != []}
              id="goal-publish-product"
              phx-click="import_offer"
              phx-value-id={List.first(@hustle_opportunities).id}
              class="rounded-xl bg-violet-600 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-violet-700"
            >
              Add recommended product
            </button>
            <button
              :if={@goal_progress.next_action == :create_sales_kit && @hustle_listings != []}
              id="goal-create-sales-kit"
              phx-click="create_sales_kit"
              phx-value-id={List.first(@hustle_listings).id}
              class="rounded-xl bg-violet-600 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-violet-700"
            >
              Create Sales Kit
            </button>
            <a
              :if={@goal_progress.next_action in [:share, :follow_up] && @hustle_shares != []}
              id="goal-share-now"
              href={whatsapp_share_url(List.first(@hustle_shares))}
              phx-click="record_sales_share"
              phx-value-id={List.first(@hustle_shares).id}
              target="_blank"
              rel="noopener"
              class="rounded-xl bg-emerald-600 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-emerald-700"
            >
              Share now
            </a>
            <a
              :if={@goal_progress.next_action == :fulfill}
              id="goal-track-fulfillment"
              href="#first-money-journey"
              class="rounded-xl bg-amber-500 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-amber-600"
            >
              Track fulfillment
            </a>
          </div>
        </div>
      <% else %>
        <.form
          for={@income_goal_form}
          id="income-goal-form"
          phx-submit="create_income_goal"
          class="mt-7 grid gap-4 rounded-2xl border border-white/80 bg-white/80 p-5 shadow-sm backdrop-blur md:grid-cols-2 xl:grid-cols-4 xl:items-end"
        >
          <.input
            field={@income_goal_form[:target_amount]}
            type="number"
            min="1"
            step="0.01"
            label="Income target (GH₵)"
            required
          />
          <.input
            field={@income_goal_form[:timeframe_days]}
            type="select"
            label="Timeframe"
            options={[{"14 days", "14"}, {"30 days", "30"}, {"60 days", "60"}, {"90 days", "90"}]}
          />
          <.input
            field={@income_goal_form[:daily_minutes]}
            type="select"
            label="Daily time"
            options={[
              {"20 minutes", "20"},
              {"45 minutes", "45"},
              {"90 minutes", "90"},
              {"2 hours", "120"}
            ]}
          />
          <button
            id="build-income-plan"
            type="submit"
            class="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-violet-600 px-5 text-sm font-bold text-white shadow-md transition hover:-translate-y-0.5 hover:bg-violet-700"
          >
            <.icon name="hero-sparkles" class="size-4" /> Build my plan
          </button>
        </.form>
      <% end %>
    </section>
    """
  end
end
