defmodule EmakolaWeb.Admin.CampaignLive.Index do
  @moduledoc """
  Admin campaigns page with KPI cards, campaign cards grid, performance chart,
  quick start templates, and create/delete modals.
  Pixel-matched to design/prototypes/emakola-admin-campaigns.html.
  """
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Campaigns",
        active_nav: :campaigns,
        store_id: store_id,
        campaigns: sample_campaigns(),
        delete_campaign: nil
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("save_campaign", %{"campaign" => _params}, socket) do
    socket =
      socket
      |> put_flash(:info, "Campaign created successfully!")

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    campaign = Enum.find(socket.assigns.campaigns, &(&1.id == id))
    {:noreply, assign(socket, delete_campaign: campaign)}
  end

  @impl true
  def handle_event("delete_campaign", _params, socket) do
    socket =
      socket
      |> put_flash(:info, "Campaign deleted.")
      |> assign(delete_campaign: nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("use_template", %{"template" => _template}, socket) do
    # Placeholder — in the future, pre-fill form fields based on template
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Page Header --%>
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Campaigns</h1>
        <p class="text-sm text-slate-500 mt-1">Engage customers with targeted messages</p>
      </div>
      <button
        phx-click={show_modal("create-campaign-modal")}
        class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:ring-offset-2"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Create Campaign
      </button>
    </div>

    <%!-- KPI Cards --%>
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
      <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300 cursor-default">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Total Campaigns
          </span>
          <div class="w-9 h-9 bg-emerald-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-emerald-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M10.34 15.84c-.688-.06-1.386-.09-2.09-.09H7.5a4.5 4.5 0 110-9h.75c.704 0 1.402-.03 2.09-.09m0 9.18c.253.962.584 1.892.985 2.783.247.55.06 1.21-.463 1.511l-.657.38c-.551.318-1.26.117-1.527-.461a20.845 20.845 0 01-1.44-4.282m3.102.069a18.03 18.03 0 01-.59-4.59c0-1.586.205-3.124.59-4.59m0 9.18a23.848 23.848 0 018.835 2.535M10.34 6.66a23.847 23.847 0 008.835-2.535m0 0A23.74 23.74 0 0018.795 3m.38 1.125a23.91 23.91 0 011.014 5.395m-1.014 8.855c-.118.38-.245.754-.38 1.125m.38-1.125a23.91 23.91 0 001.014-5.395m0-3.46c.495.413.811 1.035.811 1.73 0 .695-.316 1.317-.811 1.73m0-3.46a24.347 24.347 0 010 3.46"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">{length(@campaigns)}</p>
        <p class="text-xs text-slate-400 mt-2">
          {count_by_status(@campaigns, :active)} active, {count_by_status(@campaigns, :scheduled)} scheduled, {count_by_status(
            @campaigns,
            :draft
          )} drafts
        </p>
      </div>

      <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300 cursor-default">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Messages Sent
          </span>
          <div class="w-9 h-9 bg-violet-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-violet-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">2,847</p>
        <div class="flex items-center gap-1.5 mt-2">
          <span class="inline-flex items-center gap-0.5 text-xs font-semibold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full">
            <svg
              class="w-3 h-3"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M4.5 19.5l15-15m0 0H8.25m11.25 0v11.25"
              />
            </svg>
            +34.2%
          </span>
          <span class="text-xs text-slate-400">vs last month</span>
        </div>
      </div>

      <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300 cursor-default">
        <div class="flex items-center justify-between mb-4">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Avg. Open Rate
          </span>
          <div class="w-9 h-9 bg-amber-50 rounded-xl flex items-center justify-center">
            <svg
              class="w-[18px] h-[18px] text-amber-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z"
              /><path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
              />
            </svg>
          </div>
        </div>
        <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">72.4%</p>
        <div class="flex items-center gap-1.5 mt-2">
          <span class="inline-flex items-center gap-0.5 text-xs font-semibold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full">
            <svg
              class="w-3 h-3"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M4.5 19.5l15-15m0 0H8.25m11.25 0v11.25"
              />
            </svg>
            +5.1%
          </span>
          <span class="text-xs text-slate-400">vs last month</span>
        </div>
      </div>
    </div>

    <%!-- Campaign Cards --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-8">
      <div
        :for={campaign <- @campaigns}
        class="bg-white rounded-2xl border border-slate-200 p-6 hover:shadow-md hover:border-slate-300 transition-all duration-300 relative"
      >
        <div class="flex items-start justify-between mb-4">
          <div class="flex items-center gap-3">
            <div class={"w-10 h-10 #{channel_bg(campaign.channel)} rounded-xl flex items-center justify-center"}>
              <.channel_icon channel={campaign.channel} />
            </div>
            <div>
              <h3 class="text-base font-bold text-slate-900">{campaign.name}</h3>
              <p class="text-xs text-slate-500 mt-0.5">{campaign.channel_label}</p>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <span class={"inline-flex items-center px-2.5 py-1 rounded-full text-[11px] font-semibold #{status_classes(campaign.status)}"}>
              {String.capitalize(to_string(campaign.status))}
            </span>
            <button
              phx-click={
                JS.push("confirm_delete", value: %{id: campaign.id})
                |> show_modal("delete-campaign-modal")
              }
              class="p-1.5 rounded-lg hover:bg-red-50 transition-colors cursor-pointer"
              aria-label={"Delete #{campaign.name}"}
            >
              <svg
                class="w-4 h-4 text-slate-400 hover:text-red-500"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"
                />
              </svg>
            </button>
          </div>
        </div>
        <p class="text-sm text-slate-600 mb-4">{campaign.description}</p>
        <div class={"grid #{if campaign.status in [:active], do: "grid-cols-3", else: "grid-cols-2"} gap-3 mb-4"}>
          <div :for={stat <- campaign.stats} class={"text-center py-2.5 #{stat.bg} rounded-xl"}>
            <p class={"text-lg font-bold #{stat.color} font-mono"}>{stat.value}</p>
            <p class="text-[10px] text-slate-400 font-medium uppercase tracking-wider">
              {stat.label}
            </p>
          </div>
        </div>
        <div class="flex items-center gap-2 text-xs text-slate-400">
          <svg
            class="w-3.5 h-3.5"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5"
            />
          </svg>
          {campaign.date_label}
        </div>
      </div>
    </div>

    <%!-- Campaign Performance Chart --%>
    <div class="bg-white rounded-2xl border border-slate-200 p-6 mb-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h2 class="text-base font-bold text-slate-900">Campaign Performance</h2>
          <p class="text-xs text-slate-400 mt-0.5">Last 6 campaigns: sent vs opened vs clicked</p>
        </div>
        <div class="flex items-center gap-4 text-xs">
          <div class="flex items-center gap-1.5">
            <span class="w-3 h-3 rounded-sm bg-emerald-900"></span><span class="text-slate-500">Sent</span>
          </div>
          <div class="flex items-center gap-1.5">
            <span class="w-3 h-3 rounded-sm bg-emerald-500"></span><span class="text-slate-500">Opened</span>
          </div>
          <div class="flex items-center gap-1.5">
            <span class="w-3 h-3 rounded-sm bg-emerald-200"></span><span class="text-slate-500">Clicked</span>
          </div>
        </div>
      </div>
      <div class="relative" style="height: 260px;">
        <svg
          viewBox="0 0 720 260"
          class="w-full h-full"
          preserveAspectRatio="xMidYMid meet"
          role="img"
          aria-label="Bar chart showing campaign performance"
        >
          <line x1="60" y1="30" x2="700" y2="30" stroke="#F1F5F9" stroke-width="1" />
          <line x1="60" y1="80" x2="700" y2="80" stroke="#F1F5F9" stroke-width="1" />
          <line x1="60" y1="130" x2="700" y2="130" stroke="#F1F5F9" stroke-width="1" />
          <line x1="60" y1="180" x2="700" y2="180" stroke="#F1F5F9" stroke-width="1" />
          <text
            x="50"
            y="34"
            text-anchor="end"
            class="text-[10px] fill-slate-400"
            font-family="monospace"
            font-size="10"
          >
            500
          </text>
          <text
            x="50"
            y="84"
            text-anchor="end"
            class="text-[10px] fill-slate-400"
            font-family="monospace"
            font-size="10"
          >
            375
          </text>
          <text
            x="50"
            y="134"
            text-anchor="end"
            class="text-[10px] fill-slate-400"
            font-family="monospace"
            font-size="10"
          >
            250
          </text>
          <text
            x="50"
            y="184"
            text-anchor="end"
            class="text-[10px] fill-slate-400"
            font-family="monospace"
            font-size="10"
          >
            125
          </text>
          <rect x="80" y="68" width="22" height="152" rx="4" fill="#064E3B" />
          <rect x="104" y="98" width="22" height="122" rx="4" fill="#10B981" />
          <rect x="128" y="148" width="22" height="72" rx="4" fill="#A7F3D0" />
          <rect x="185" y="48" width="22" height="172" rx="4" fill="#064E3B" />
          <rect x="209" y="68" width="22" height="152" rx="4" fill="#10B981" />
          <rect x="233" y="118" width="22" height="102" rx="4" fill="#A7F3D0" />
          <rect x="290" y="28" width="22" height="192" rx="4" fill="#064E3B" />
          <rect x="314" y="78" width="22" height="142" rx="4" fill="#10B981" />
          <rect x="338" y="138" width="22" height="82" rx="4" fill="#A7F3D0" />
          <rect x="395" y="88" width="22" height="132" rx="4" fill="#064E3B" />
          <rect x="419" y="108" width="22" height="112" rx="4" fill="#10B981" />
          <rect x="443" y="158" width="22" height="62" rx="4" fill="#A7F3D0" />
          <rect x="500" y="108" width="22" height="112" rx="4" fill="#064E3B" />
          <rect x="524" y="128" width="22" height="92" rx="4" fill="#10B981" />
          <rect x="548" y="168" width="22" height="52" rx="4" fill="#A7F3D0" />
          <rect x="605" y="58" width="22" height="162" rx="4" fill="#064E3B" />
          <rect x="629" y="88" width="22" height="132" rx="4" fill="#10B981" />
          <rect x="653" y="128" width="22" height="92" rx="4" fill="#A7F3D0" />
          <text x="115" y="242" text-anchor="middle" class="text-[10px] fill-slate-400" font-size="10">
            Flash Sale
          </text>
          <text x="220" y="242" text-anchor="middle" class="text-[10px] fill-slate-400" font-size="10">
            Welcome
          </text>
          <text x="325" y="242" text-anchor="middle" class="text-[10px] fill-slate-400" font-size="10">
            Cart Recovery
          </text>
          <text x="430" y="242" text-anchor="middle" class="text-[10px] fill-slate-400" font-size="10">
            New Arrivals
          </text>
          <text x="535" y="242" text-anchor="middle" class="text-[10px] fill-slate-400" font-size="10">
            Loyalty
          </text>
          <text x="640" y="242" text-anchor="middle" class="text-[10px] fill-slate-400" font-size="10">
            Re-stock
          </text>
        </svg>
      </div>
    </div>

    <%!-- Quick Start Templates --%>
    <div class="mb-8">
      <h2 class="text-base font-bold text-slate-900 mb-1">Quick Start Templates</h2>
      <p class="text-xs text-slate-400 mb-4">
        Launch a campaign in minutes with these proven templates
      </p>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
          <div class="w-10 h-10 bg-amber-50 rounded-xl flex items-center justify-center mb-4">
            <svg
              class="w-5 h-5 text-amber-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 00-3 3h15.75m-12.75-3h11.218c1.121-2.3 2.1-4.684 2.924-7.138a60.114 60.114 0 00-16.536-1.84M7.5 14.25L5.106 5.272M6 20.25a.75.75 0 11-1.5 0 .75.75 0 011.5 0zm12.75 0a.75.75 0 11-1.5 0 .75.75 0 011.5 0z"
              />
            </svg>
          </div>
          <h3 class="text-sm font-bold text-slate-900 mb-1">Abandoned Cart</h3>
          <p class="text-xs text-slate-500 mb-4">
            Recover lost sales with automated reminders at 1hr and 24hr intervals
          </p>
          <button
            phx-click={
              JS.push("use_template", value: %{template: "abandoned_cart"})
              |> show_modal("create-campaign-modal")
            }
            class="w-full inline-flex items-center justify-center gap-2 px-4 py-2 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
          >
            Use Template
          </button>
        </div>
        <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
          <div class="w-10 h-10 bg-emerald-50 rounded-xl flex items-center justify-center mb-4">
            <svg
              class="w-5 h-5 text-emerald-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15.182 15.182a4.5 4.5 0 01-6.364 0M21 12a9 9 0 11-18 0 9 9 0 0118 0zM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75zm-.375 0h.008v.015h-.008V9.75zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75zm-.375 0h.008v.015h-.008V9.75z"
              />
            </svg>
          </div>
          <h3 class="text-sm font-bold text-slate-900 mb-1">Welcome Series</h3>
          <p class="text-xs text-slate-500 mb-4">
            Greet new customers with a 3-message onboarding sequence
          </p>
          <button
            phx-click={
              JS.push("use_template", value: %{template: "welcome_series"})
              |> show_modal("create-campaign-modal")
            }
            class="w-full inline-flex items-center justify-center gap-2 px-4 py-2 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
          >
            Use Template
          </button>
        </div>
        <div class="bg-white rounded-2xl border border-slate-200 p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300">
          <div class="w-10 h-10 bg-violet-50 rounded-xl flex items-center justify-center mb-4">
            <svg
              class="w-5 h-5 text-violet-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15.59 14.37a6 6 0 01-5.84 7.38v-4.8m5.84-2.58a14.98 14.98 0 006.16-12.12A14.98 14.98 0 009.631 8.41m5.96 5.96a14.926 14.926 0 01-5.841 2.58m-.119-8.54a6 6 0 00-7.381 5.84h4.8m2.581-5.84a14.927 14.927 0 00-2.58 5.84m2.699 2.7c-.103.021-.207.041-.311.06a15.09 15.09 0 01-2.448-2.448 14.9 14.9 0 01.06-.312m-2.24 2.39a4.493 4.493 0 00-1.757 4.306 4.493 4.493 0 004.306-1.758M16.5 9a1.5 1.5 0 11-3 0 1.5 1.5 0 013 0z"
              />
            </svg>
          </div>
          <h3 class="text-sm font-bold text-slate-900 mb-1">Product Launch</h3>
          <p class="text-xs text-slate-500 mb-4">
            Announce new products with a teaser, launch, and follow-up flow
          </p>
          <button
            phx-click={
              JS.push("use_template", value: %{template: "product_launch"})
              |> show_modal("create-campaign-modal")
            }
            class="w-full inline-flex items-center justify-center gap-2 px-4 py-2 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
          >
            Use Template
          </button>
        </div>
      </div>
    </div>

    <%!-- Create Campaign Modal --%>
    <.modal
      id="create-campaign-modal"
      title="Create Campaign"
      size={:md}
      icon="hero-megaphone"
      icon_class="text-emerald-600"
    >
      <form phx-submit="save_campaign" id="create-campaign-form" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Campaign Name</label>
          <input
            type="text"
            name="campaign[name]"
            required
            placeholder="e.g. Easter Sale Blast"
            class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Channel</label>
          <select
            name="campaign[channel]"
            class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500"
          >
            <option value="whatsapp">WhatsApp</option>
            <option value="sms">SMS</option>
            <option value="both">WhatsApp + SMS</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Description</label>
          <textarea
            name="campaign[description]"
            rows="3"
            placeholder="Brief description of the campaign..."
            class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500"
          ></textarea>
        </div>
      </form>
      <:footer>
        <div class="flex items-center justify-end gap-3">
          <button
            type="button"
            phx-click={hide_modal("create-campaign-modal")}
            class="px-4 py-2.5 text-sm font-medium text-slate-700 hover:bg-slate-100 rounded-xl transition-colors cursor-pointer"
          >
            Cancel
          </button>
          <button
            type="submit"
            form="create-campaign-form"
            class="px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
          >
            Create Campaign
          </button>
        </div>
      </:footer>
    </.modal>

    <%!-- Delete Confirmation Modal --%>
    <.confirm_modal
      id="delete-campaign-modal"
      title="Delete Campaign"
      message={"Are you sure you want to delete \"#{if @delete_campaign, do: @delete_campaign.name, else: ""}\"? This action cannot be undone."}
      confirm_text="Delete"
      confirm_class="bg-red-600 hover:bg-red-700 text-white"
      on_confirm="delete_campaign"
      value={if @delete_campaign, do: @delete_campaign.id}
      icon="hero-trash"
      icon_class="text-red-500"
    />
    """
  end

  # ── Components ──

  defp channel_icon(%{channel: :whatsapp} = assigns) do
    ~H"""
    <svg class="w-5 h-5 text-emerald-600" viewBox="0 0 24 24" fill="currentColor">
      <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
    </svg>
    """
  end

  defp channel_icon(%{channel: :sms} = assigns) do
    ~H"""
    <svg
      class="w-5 h-5 text-blue-600"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"
      />
    </svg>
    """
  end

  defp channel_icon(%{channel: :both} = assigns) do
    ~H"""
    <svg
      class="w-5 h-5 text-violet-600"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z"
      />
    </svg>
    """
  end

  defp channel_bg(:whatsapp), do: "bg-emerald-50"
  defp channel_bg(:sms), do: "bg-blue-50"
  defp channel_bg(:both), do: "bg-violet-50"

  defp status_classes(:active), do: "bg-emerald-50 text-emerald-700"
  defp status_classes(:scheduled), do: "bg-blue-50 text-blue-700"
  defp status_classes(:draft), do: "bg-slate-100 text-slate-600"
  defp status_classes(_), do: "bg-slate-100 text-slate-600"

  defp count_by_status(campaigns, status), do: Enum.count(campaigns, &(&1.status == status))

  # ── Data ──

  defp sample_campaigns do
    [
      %{
        id: "1",
        name: "Welcome Series",
        channel: :whatsapp,
        channel_label: "WhatsApp",
        status: :active,
        description: "3-message series for new customers",
        stats: [
          %{value: "456", label: "Sent", bg: "bg-slate-50", color: "text-slate-900"},
          %{value: "89%", label: "Opened", bg: "bg-slate-50", color: "text-emerald-600"},
          %{value: "34%", label: "Clicked", bg: "bg-slate-50", color: "text-slate-900"}
        ],
        date_label: "Running since 01/02/2026"
      },
      %{
        id: "2",
        name: "Abandoned Cart Recovery",
        channel: :both,
        channel_label: "WhatsApp + SMS",
        status: :active,
        description: "Reminder after 1hr and 24hr of cart abandonment",
        stats: [
          %{value: "1,247", label: "Sent", bg: "bg-slate-50", color: "text-slate-900"},
          %{value: "18%", label: "Recovered", bg: "bg-slate-50", color: "text-emerald-600"},
          %{
            value: "GH\u20B5 12,480",
            label: "Revenue",
            bg: "bg-slate-50",
            color: "text-slate-900"
          }
        ],
        date_label: "Running since 15/01/2026"
      },
      %{
        id: "3",
        name: "Easter Sale Announcement",
        channel: :sms,
        channel_label: "SMS",
        status: :scheduled,
        description: "Blast to all customers about Easter 25% off",
        stats: [
          %{value: "1,842", label: "Target", bg: "bg-slate-50", color: "text-slate-900"},
          %{value: "15/04/2026", label: "Send Date", bg: "bg-blue-50", color: "text-blue-700"}
        ],
        date_label: "Scheduled: 15/04/2026"
      },
      %{
        id: "4",
        name: "Re-engagement",
        channel: :whatsapp,
        channel_label: "WhatsApp",
        status: :draft,
        description: "Win back customers inactive for 30+ days",
        stats: [
          %{value: "386", label: "Target", bg: "bg-slate-50", color: "text-slate-900"},
          %{value: "3 messages", label: "Sequence", bg: "bg-slate-50", color: "text-slate-600"}
        ],
        date_label: "Created: 18/03/2026"
      }
    ]
  end

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end
end
