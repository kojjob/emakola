defmodule EmakolaWeb.Platform.StoreLive.MetricsComponents do
  @moduledoc """
  The numbers on the platform Stores page: four platform-wide tiles from
  `Emakola.Platform.Stats`, the per-row merchants / products / last-order
  line, and the "Store at a glance" strip for the selected store, built
  from the aggregates Store already defines.
  """
  use EmakolaWeb, :html

  alias EmakolaWeb.Helpers.Currency

  @initial_tints [
    "bg-amber-100 text-amber-700",
    "bg-blue-100 text-blue-700",
    "bg-emerald-100 text-emerald-700",
    "bg-violet-100 text-violet-700"
  ]

  attr :stats, :map, required: true

  def platform_tiles(assigns) do
    ~H"""
    <div id="platform-store-stats" class="grid grid-cols-2 xl:grid-cols-4 gap-3.5 mb-5">
      <.tile
        stat="stores"
        label="Stores"
        value={@stats.stores}
        icon="hero-building-storefront"
        chip="from-blue-400 to-blue-600 shadow-blue-600/30"
      >
        <span class="inline-block w-1.5 h-1.5 rounded-full bg-green-500 mr-1.5"></span>
        {@stats.live} live · {@stats.stores - @stats.live} hidden
      </.tile>
      <.tile
        stat="merchants"
        label="Merchants"
        value={@stats.merchants}
        icon="hero-users"
        chip="from-emerald-400 to-emerald-600 shadow-emerald-600/30"
      >
        {@stats.multi_store} run more than one store · {@stats.joined_week} joined this week
      </.tile>
      <.tile
        stat="orders"
        label="Orders · 30 days"
        value={@stats.orders}
        icon="hero-shopping-cart"
        chip="from-violet-400 to-violet-600 shadow-violet-600/30"
      >
        <span class="font-semibold text-emerald-700">{Currency.format_price(@stats.gmv)} paid</span>
        · {@stats.sellers} stores sold something
      </.tile>
      <.tile
        stat="featured"
        label="Featured"
        value={@stats.featured}
        icon="hero-star"
        chip="from-amber-400 to-amber-600 shadow-amber-600/30"
      >
        {@stats.eligible} eligible for featuring
      </.tile>
    </div>
    """
  end

  attr :stat, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :chip, :string, required: true
  slot :inner_block, required: true

  defp tile(assigns) do
    ~H"""
    <div
      data-stat={@stat}
      class="relative overflow-hidden bg-white border border-gray-200 rounded-2xl px-5 py-[18px]"
    >
      <div class={["absolute inset-0 bg-gradient-to-r to-transparent", wash(@stat)]}></div>
      <div class="relative flex items-start justify-between">
        <span class="text-[13px] font-semibold text-slate-600">{@label}</span>
        <span class={[
          "flex h-[42px] w-[42px] items-center justify-center rounded-xl bg-gradient-to-br text-white shadow-lg",
          @chip
        ]}>
          <.icon name={@icon} class="size-[21px]" />
        </span>
      </div>
      <p class="relative text-[28px] font-extrabold text-gray-900 tracking-tight mt-2.5 tabular-nums">
        {@value}
      </p>
      <p class="relative text-xs font-medium text-slate-500 mt-1.5">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  defp wash("stores"), do: "from-blue-50/90"
  defp wash("merchants"), do: "from-emerald-50/90"
  defp wash("orders"), do: "from-violet-50/90"
  defp wash(_featured), do: "from-amber-50/70"

  attr :store, :map, required: true

  def row_meta(assigns) do
    ~H"""
    <p class="flex items-center gap-1.5 text-[11px] text-gray-400 mt-1 min-w-0">
      <.member_initials :if={@store.store_memberships != []} memberships={@store.store_memberships} />
      <span class="truncate">
        {count_word(length(@store.store_memberships), "merchant")} · {count_word(
          @store.product_count,
          "product"
        )} · {sold_label(@store.last_order_at)}
        <span :if={@store.payout_verified != true} class="text-amber-700 font-semibold">
          · no payout
        </span>
      </span>
    </p>
    """
  end

  attr :memberships, :list, required: true

  defp member_initials(assigns) do
    assigns = assign(assigns, :tints, @initial_tints)

    ~H"""
    <span class="inline-flex shrink-0">
      <span
        :for={{membership, index} <- @memberships |> Enum.take(3) |> Enum.with_index()}
        class={[
          "inline-flex h-[18px] w-[18px] items-center justify-center rounded-full text-[8.5px] font-bold ring-2 ring-white",
          index > 0 && "-ml-1.5",
          Enum.at(@tints, rem(index, length(@tints)))
        ]}
        title={merchant_email(membership.merchant)}
      >
        {initial(membership.merchant)}
      </span>
    </span>
    """
  end

  attr :store, :map, required: true

  def store_glance(assigns) do
    ~H"""
    <div id="store-glance" class="mt-6 pt-6 border-t border-gray-100">
      <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
        Store at a glance
      </p>
      <div class="grid grid-cols-2 xl:grid-cols-5 gap-2.5">
        <.glance key="merchants" label="Merchants" value={length(@store.store_memberships)}>
          <span class="flex items-center gap-1.5 min-w-0">
            <.member_initials
              :if={@store.store_memberships != []}
              memberships={@store.store_memberships}
            />
            <span class="truncate">{owner_line(@store.store_memberships)}</span>
          </span>
        </.glance>
        <.glance key="products" label="Products" value={@store.product_count}>
          last published {relative_days(@store.last_product_published_at)}
        </.glance>
        <.glance key="delivered" label="Delivered · 90d" value={@store.delivered_order_count_90d}>
          {@store.cancelled_order_count_90d} cancelled
        </.glance>
        <.glance key="last-order" label="Last order" value={relative_days(@store.last_order_at)}>
          {@store.successful_payment_count_90d} paid in 90d
        </.glance>
        <.glance key="views" label="Directory views" value={@store.view_count || 0}>
          {rating_line(@store)}
        </.glance>
      </div>
    </div>
    """
  end

  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  slot :inner_block, required: true

  defp glance(assigns) do
    ~H"""
    <div
      data-glance={@key}
      class="flex flex-col gap-1.5 px-4 py-3.5 rounded-xl ring-1 ring-inset ring-gray-200 bg-white min-w-0"
    >
      <span class="text-[11px] font-semibold text-gray-500">{@label}</span>
      <span class="text-[22px] font-extrabold text-gray-900 leading-none tabular-nums">{@value}</span>
      <span class="text-[11px] text-gray-400 truncate">{render_slot(@inner_block)}</span>
    </div>
    """
  end

  defp count_word(1, word), do: "1 #{word}"
  defp count_word(n, word), do: "#{n} #{word}s"

  defp sold_label(nil), do: "never sold"
  defp sold_label(at), do: "sold #{relative_days(at)}"

  def relative_days(nil), do: "never"

  def relative_days(at) do
    case Date.diff(Date.utc_today(), DateTime.to_date(at)) do
      0 -> "today"
      days -> "#{days}d ago"
    end
  end

  defp owner_line(memberships) do
    case Enum.find(memberships, &(&1.role == :owner)) do
      nil -> "no owner on record"
      owner -> "#{merchant_name(owner.merchant)} · owner"
    end
  end

  defp rating_line(%{verified_review_count: count, verified_review_rating_sum: sum})
       when is_integer(count) and count > 0 and is_integer(sum),
       do: "#{Float.round(sum / count, 1)} from #{count_word(count, "review")}"

  defp rating_line(_store), do: "no reviews yet"

  # Ash.CiString emails crash String.first/1 — always to_string first. A
  # merchant with no name shows the part of the email before the @, which
  # fits the strip; the full address is on the row's tooltip.
  defp merchant_name(%{name: name}) when is_binary(name) and name != "", do: name

  defp merchant_name(%{email: email}),
    do: email |> to_string() |> String.split("@") |> List.first()

  defp merchant_name(_), do: "?"

  defp merchant_email(%{email: email}), do: to_string(email)
  defp merchant_email(_), do: ""

  defp initial(merchant), do: merchant |> merchant_name() |> String.first() |> String.upcase()
end
