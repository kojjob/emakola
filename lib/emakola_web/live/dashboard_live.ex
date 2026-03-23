defmodule EmakolaWeb.DashboardLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.DashboardComponents
  import EmakolaWeb.DashboardMetricComponents

  alias EmakolaWeb.DashboardHelpers

  @refresh_interval 30_000

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh, @refresh_interval)
      Phoenix.PubSub.subscribe(Emakola.PubSub, "org_events:all")
    end

    user = socket.assigns[:current_user]

    socket = socket |> assign(active_nav: :dashboard, page_title: "Dashboard")

    socket =
      try do
        load_all_data(socket, user)
      rescue
        _ -> assign_defaults(socket)
      end

    {:ok, socket}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)

    try do
      {:noreply, load_all_data(socket, socket.assigns[:current_user])}
    rescue
      _ -> {:noreply, socket}
    end
  end

  def handle_info({:app_event, _event}, socket) do
    try do
      {:noreply, load_all_data(socket, socket.assigns[:current_user])}
    rescue
      _ -> {:noreply, socket}
    end
  end

  def handle_info(_, socket), do: {:noreply, socket}

  def handle_event("dismiss_setup_banner", _, socket) do
    {:noreply, assign(socket, setup_banner_dismissed: true)}
  end

  def handle_event("refresh_data", _, socket) do
    {:noreply,
     socket
     |> load_all_data(socket.assigns[:current_user])
     |> put_flash(:info, "Dashboard refreshed")}
  end

  defp load_all_data(socket, user) do
    data = DashboardHelpers.load_dashboard_data(user)

    socket
    |> assign(data)
    |> assign(
      onboarding_complete: socket.assigns[:onboarding_complete] || false,
      setup_banner_dismissed: socket.assigns[:setup_banner_dismissed] || false
    )
  end

  defp assign_defaults(socket) do
    defaults = DashboardHelpers.default_assigns()

    socket
    |> assign(defaults)
    |> assign(
      onboarding_complete: socket.assigns[:onboarding_complete] || false,
      setup_banner_dismissed: socket.assigns[:setup_banner_dismissed] || false
    )
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.onboarding_banner
        onboarding_complete={@onboarding_complete}
        setup_banner_dismissed={@setup_banner_dismissed}
      />

      <.editorial_header
        system_status={@system_status}
        avg_latency={@avg_latency}
        current_plan_name={@current_plan_name}
        last_sync={@last_sync}
      />

      <%!-- Metrics Grid (Asymmetric Bento) --%>
      <section class="grid grid-cols-1 md:grid-cols-12 gap-6">
        <.metric_cards
          token_usage={@token_usage}
          token_quota_pct={@token_quota_pct}
          token_chart={@token_chart}
          total_orders={@total_orders}
          orders_chart={@orders_chart}
        />

        <.platform_health_card
          avg_latency={@avg_latency}
          error_rate={@error_rate}
          success_rate={@success_rate}
          success_chart={@success_chart}
        />

        <.quick_insights_sidebar
          cost_grade={@cost_grade}
          members_count={@members_count}
          api_uptime={@api_uptime}
          flags_enabled={@flags_enabled}
          notifications_count={@notifications_count}
          token_quota_pct={@token_quota_pct}
        />
      </section>

      <.recent_activity_table recent_activity={@recent_activity} />
    </div>
    """
  end
end
