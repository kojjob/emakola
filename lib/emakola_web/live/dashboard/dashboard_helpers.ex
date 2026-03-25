defmodule EmakolaWeb.DashboardHelpers do
  @moduledoc "Data loading, metric computation, and chart generation for the admin dashboard."

  require Ash.Query

  @doc "Loads all dashboard data and returns updated socket assigns as a keyword list."
  def load_dashboard_data(user) do
    usage_count = safe_count(Emakola.Billing.UsageRecord)
    members_count = safe_count(Emakola.Accounts.Membership)
    notifications_count = safe_count(Emakola.Notifications.Notification)
    flags_enabled = count_enabled_flags()
    plans = load_plans()
    current_plan = List.first(plans)
    recent_events = load_recent_events()

    plan_limit = if current_plan, do: current_plan.max_api_calls_per_month, else: 1000
    usage_pct = if plan_limit > 0, do: min(round(usage_count / plan_limit * 100), 100), else: 0

    chart_data = generate_chart_data()

    [
      # Header
      user_name:
        if(user, do: user.name |> to_string() |> String.split() |> List.first(), else: ""),
      last_sync: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S UTC"),
      system_status: if(usage_pct < 90, do: :nominal, else: :warning),

      # Metric cards
      total_orders: format_number(usage_count),
      orders_chart: chart_data.orders,
      token_usage: format_number(usage_count),
      token_quota_pct: usage_pct,
      token_chart: chart_data.tokens,

      # Success rate card
      success_rate: calculate_success_rate(recent_events),
      avg_latency: "\u2014",
      error_rate: "0.00%",
      success_chart: chart_data.success,

      # Quick Insights
      current_plan_name: if(current_plan, do: current_plan.name, else: "Free"),
      members_count: members_count,
      notifications_count: notifications_count,
      flags_enabled: flags_enabled,
      cost_grade: calculate_cost_grade(usage_count),
      api_uptime: "99.99%",

      # Activity table
      recent_activity: recent_events |> Enum.take(10) |> format_event_activity()
    ]
  end

  @doc "Returns default assigns for the dashboard when data loading fails."
  def default_assigns do
    [
      user_name: "",
      last_sync: "\u2014",
      system_status: :nominal,
      total_orders: "0",
      orders_chart: [30, 30, 30, 30, 30, 30],
      token_usage: "0",
      token_quota_pct: 0,
      token_chart: [{30, 0.3}, {30, 0.3}, {30, 0.3}, {30, 0.3}, {30, 0.3}, {30, 0.3}],
      success_rate: 0.0,
      avg_latency: "\u2014",
      error_rate: "\u2014",
      success_chart: [50, 50, 50, 50, 50, 50, 50, 50, 50],
      current_plan_name: "Free",
      members_count: 0,
      notifications_count: 0,
      flags_enabled: 0,
      cost_grade: "\u2014",
      api_uptime: "99.99%",
      recent_activity: []
    ]
  end

  # ── Data Loaders ──
  defp safe_count(resource) do
    case resource |> Ash.Query.new() |> Ash.count() do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp load_plans do
    case Emakola.Billing.Plan |> Ash.Query.sort(sort_order: :asc) |> Ash.read() do
      {:ok, plans} -> plans
      _ -> []
    end
  end

  defp count_enabled_flags do
    case Emakola.FeatureFlags.FeatureFlag
         |> Ash.Query.filter(enabled: true)
         |> Ash.count() do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp load_recent_events do
    case Emakola.Analytics.AppEvent
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(50)
         |> Ash.read() do
      {:ok, events} -> events
      _ -> []
    end
  end

  defp format_event_activity(events) do
    Enum.map(events, fn e ->
      %{
        event_name: e.event_name,
        source: e.source || "system",
        timestamp: Calendar.strftime(e.inserted_at, "%H:%M:%S UTC")
      }
    end)
  end

  # ── Computed Metrics ──
  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}k"
  defp format_number(n), do: "#{n}"

  defp calculate_success_rate([]), do: 99.8

  defp calculate_success_rate(events) do
    total = length(events)

    successes =
      Enum.count(events, fn e ->
        not String.contains?(to_string(e.event_name), "fail")
      end)

    Float.round(successes / total * 100, 1)
  end

  defp calculate_cost_grade(usage) do
    cond do
      usage < 50 -> "A+"
      usage < 100 -> "A"
      usage < 200 -> "B+"
      usage < 500 -> "B"
      true -> "C"
    end
  end

  defp generate_chart_data do
    today = Date.utc_today()
    usage_counts = daily_counts(Emakola.Billing.UsageRecord, today, 6)

    %{
      orders: normalize_chart(usage_counts),
      tokens: normalize_token_chart(usage_counts),
      success: List.duplicate(50, 9)
    }
  end

  defp daily_counts(resource, today, num_days) do
    Enum.map((num_days - 1)..0//-1, fn days_ago ->
      day_start = today |> Date.add(-days_ago) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
      day_end = today |> Date.add(-days_ago + 1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

      case resource
           |> Ash.Query.new()
           |> Ash.Query.filter(inserted_at >= ^day_start and inserted_at < ^day_end)
           |> Ash.count() do
        {:ok, count} -> count
        _ -> 0
      end
    end)
  end

  defp normalize_chart(counts) do
    max_val = Enum.max(counts, fn -> 0 end)

    if max_val == 0 do
      List.duplicate(5, length(counts))
    else
      Enum.map(counts, fn c -> max(round(c / max_val * 100), 5) end)
    end
  end

  defp normalize_token_chart(counts) do
    max_val = Enum.max(counts, fn -> 0 end)

    if max_val == 0 do
      Enum.map(counts, fn _ -> {5, 0.3} end)
    else
      Enum.map(counts, fn c ->
        pct = max(round(c / max_val * 100), 5)
        opacity = max(0.3, pct / 100)
        {pct, Float.round(opacity, 2)}
      end)
    end
  end
end
