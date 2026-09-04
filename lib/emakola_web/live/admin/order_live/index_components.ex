defmodule EmakolaWeb.Admin.OrderLive.IndexComponents do
  @moduledoc """
  The order list for merchants who do not read well (design/orders-redesign,
  A · Do these now, chosen 2026-09-04): the product photo says what was
  bought, the wallet's own colour says how it was paid, the badge says where
  the order is, WhatsApp is one tap away, and the money is the largest thing
  on the row. A waiting order is a card with one big button; everything
  else is a quiet row.
  """
  use EmakolaWeb, :html

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]
  import EmakolaWeb.LayoutHelpers, only: [relative_time: 1]

  # ── A waiting order: the work ──

  attr :order, :map, required: true
  attr :rail, :atom, default: nil

  def work_card(assigns) do
    ~H"""
    <div
      id={"order-row-#{@order.id}"}
      data-waiting
      class="flex flex-col gap-3 rounded-[18px] border-[1.5px] border-amber-400 bg-white p-3.5 shadow-sm"
    >
      <div class="flex items-center gap-3">
        <.order_photo order={@order} size={:lg} />
        <.link navigate={~p"/admin/orders/#{@order.id}"} class="min-w-0 flex-1">
          <p class="truncate text-base font-extrabold tracking-tight text-slate-900">
            {customer_name(@order)}
          </p>
          <p :if={items_summary(@order) != ""} class="mt-0.5 truncate text-[13.5px] text-slate-500">
            {items_summary(@order)}
          </p>
          <p class="mt-1 truncate font-mono text-[11px] text-slate-400">
            {@order.order_number} · {relative_time(@order.inserted_at)}
          </p>
        </.link>
        <div class="flex shrink-0 flex-col items-end gap-2">
          <p class="text-[22px] font-extrabold tabular-nums tracking-tight text-slate-900">
            {format_price(@order.total, @order.currency)}
          </p>
          <.whatsapp_disc order={@order} size={:md} />
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <.rail_or_unpaid rail={@rail} />
        <.supplier_pill :if={@order.supplier_alert} alert={@order.supplier_alert} />
      </div>
      <.link
        navigate={~p"/admin/orders/#{@order.id}"}
        class="inline-flex h-12 w-full items-center justify-center gap-2 rounded-[13px] bg-primary text-[15.5px] font-extrabold text-white shadow-lg shadow-emerald-600/25 transition-colors hover:bg-primary-hover"
      >
        Send it <.icon name="hero-arrow-right" class="size-[18px]" />
      </.link>
    </div>
    """
  end

  # ── Every other order: a quiet row ──

  attr :order, :map, required: true
  attr :rail, :atom, default: nil

  def order_row(assigns) do
    ~H"""
    <div
      id={"order-row-#{@order.id}"}
      class={[
        "flex items-center gap-3 px-4 py-3 sm:px-5 transition-colors hover:bg-slate-50/60",
        @order.status == :pending && "shadow-[inset_4px_0_0_theme(colors.amber.500)]"
      ]}
    >
      <.order_photo order={@order} size={:sm} />
      <.link navigate={~p"/admin/orders/#{@order.id}"} class="min-w-0 flex-1">
        <p class="truncate text-[15px] font-bold text-slate-900">{customer_name(@order)}</p>
        <%!-- Pure interpolations: a text node after a hole drifts under the
              formatter (see platform-stores-redesign). --%>
        <p class="truncate text-[12.5px] text-slate-500">
          <span :if={items_summary(@order) != ""}>{items_summary(@order) <> " · "}</span>
          <span class="font-mono text-[11px] text-slate-400">{@order.order_number}</span>
          <span>{" · " <> relative_time(@order.inserted_at)}</span>
        </p>
      </.link>
      <span :if={@rail} class="hidden lg:inline-flex"><.payment_rail_chip rail={@rail} /></span>
      <p class="shrink-0 text-[15px] font-extrabold tabular-nums text-slate-900">
        {format_price(@order.total, @order.currency)}
      </p>
      <.link
        :if={@order.status == :pending}
        navigate={~p"/admin/orders/#{@order.id}"}
        class="inline-flex shrink-0 items-center gap-1.5 rounded-control bg-primary px-4 py-2 text-xs font-bold text-white shadow-sm shadow-emerald-600/25 transition-colors hover:bg-primary-hover"
      >
        Send it <.icon name="hero-arrow-right" class="size-3" />
      </.link>
      <.supplier_pill :if={@order.supplier_alert} alert={@order.supplier_alert} />
      <.status_badge :if={@order.status != :pending} status={@order.status} variant={:order} />
    </div>
    """
  end

  # ── Pieces ──

  # The first product's photo; a merchant recognises a crate of eggs faster
  # than a name. Initials stay for an order with no picture.
  attr :order, :map, required: true
  attr :size, :atom, required: true, values: [:sm, :lg]

  def order_photo(assigns) do
    assigns = assign(assigns, :url, photo_url(assigns.order))

    ~H"""
    <img
      :if={@url}
      src={@url}
      alt=""
      class={[
        "shrink-0 object-cover bg-slate-100",
        @size == :lg && "size-[84px] rounded-[14px] lg:size-[72px]",
        @size == :sm && "size-[52px] rounded-xl lg:size-12"
      ]}
    />
    <div
      :if={is_nil(@url)}
      class={[
        "flex shrink-0 items-center justify-center rounded-full bg-primary-soft font-bold text-emerald-700",
        @size == :lg && "size-[84px] text-lg lg:size-[72px]",
        @size == :sm && "size-[52px] text-xs lg:size-12"
      ]}
    >
      {initials(@order)}
    </div>
    """
  end

  # A deep link to this customer's WhatsApp; nothing when there is no number.
  attr :order, :map, required: true
  attr :size, :atom, required: true, values: [:sm, :md]

  def whatsapp_disc(assigns) do
    assigns = assign(assigns, :href, whatsapp_url(assigns.order))

    ~H"""
    <a
      :if={@href}
      href={@href}
      target="_blank"
      rel="noopener"
      aria-label="WhatsApp the customer"
      class={[
        "flex shrink-0 items-center justify-center rounded-full bg-[#25D366] text-white shadow-md shadow-[#25D366]/30 transition-opacity hover:opacity-90",
        @size == :md && "size-10",
        @size == :sm && "size-8"
      ]}
    >
      <.icon
        name="hero-chat-bubble-oval-left-ellipsis"
        class={(@size == :md && "size-5") || "size-4"}
      />
    </a>
    """
  end

  attr :rail, :atom, default: nil

  defp rail_or_unpaid(assigns) do
    ~H"""
    <.payment_rail_chip :if={@rail} rail={@rail} />
    <span
      :if={is_nil(@rail)}
      class="inline-flex items-center gap-1.5 rounded-full bg-slate-100 px-2.5 py-1 text-xs font-bold text-slate-600"
    >
      <.icon name="hero-banknotes" class="size-3.5" /> Not paid yet
    </span>
    """
  end

  # Colour and icon are the signal; the words repeat it for whoever reads.
  attr :alert, :atom, required: true

  defp supplier_pill(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex shrink-0 items-center gap-1 rounded-full px-2 py-1 text-[11px] font-bold",
        supplier_alert_classes(@alert)
      ]}
      title={supplier_alert_label(@alert)}
    >
      <.icon name={supplier_alert_icon(@alert)} class="size-3.5" />
      <span class="hidden sm:inline">{supplier_alert_label(@alert)}</span>
    </span>
    """
  end

  defp supplier_alert_classes(:blocked), do: "bg-danger-soft text-danger"
  defp supplier_alert_classes(:unreachable), do: "bg-danger-soft text-danger"
  defp supplier_alert_classes(:waiting), do: "bg-warning-soft text-warning"
  defp supplier_alert_classes(:accepted), do: "bg-success-soft text-success"
  defp supplier_alert_classes(_other), do: "bg-slate-100 text-slate-600"

  defp supplier_alert_icon(:blocked), do: "hero-exclamation-triangle"
  defp supplier_alert_icon(:unreachable), do: "hero-signal-slash"
  defp supplier_alert_icon(:waiting), do: "hero-clock"
  defp supplier_alert_icon(:accepted), do: "hero-check-circle"
  defp supplier_alert_icon(_other), do: "hero-truck"

  defp supplier_alert_label(:blocked), do: "Supplier failed"
  defp supplier_alert_label(:unreachable), do: "Not delivered"
  defp supplier_alert_label(:waiting), do: "No reply"
  defp supplier_alert_label(:accepted), do: "Supplier has it"
  defp supplier_alert_label(_other), do: "Supplier"

  # ── Reading an order ──

  def customer_name(%{customer: %{name: name}}) when is_binary(name), do: name
  def customer_name(_order), do: "Unknown"

  # What was bought, in the fewest words: the product for one line, a count
  # for more.
  def items_summary(%{line_items: [%{quantity: 1, product_title: title}]}) when is_binary(title),
    do: title

  def items_summary(%{line_items: [%{quantity: quantity, product_title: title}]})
      when is_binary(title),
      do: "#{quantity} × #{title}"

  def items_summary(%{line_items: [_ | _] = items}), do: "#{length(items)} items"
  def items_summary(_order), do: ""

  defp photo_url(%{line_items: [%{variant: %{product: %{images: [image | _]}}} | _]}),
    do: image.thumbnail_url || image.url

  defp photo_url(_order), do: nil

  defp whatsapp_url(%{customer: %{phone: phone}} = order) when is_binary(phone) do
    case String.replace(phone, ~r/\D/, "") do
      "" ->
        nil

      digits ->
        # encode_www_form, not encode: a name with an ampersand would end the
        # message at the ampersand.
        text = "Hello #{customer_name(order)}, about your order #{order.order_number}"
        "https://wa.me/#{digits}?text=#{URI.encode_www_form(text)}"
    end
  end

  defp whatsapp_url(_order), do: nil

  defp initials(order) do
    order
    |> customer_name()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
    |> case do
      "" -> "?"
      initials -> initials
    end
  end
end
