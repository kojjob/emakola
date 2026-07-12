defmodule Emakola.Analytics.PdfReport do
  @moduledoc """
  Generates PDF analytics reports for a store within a date range.

  Uses ChromicPDF to render an HTML template into a professional
  US Letter PDF with store KPIs, order status breakdown, and top products.
  """

  require Ash.Query

  @doc """
  Generates a PDF binary for the given store and date range.

  Returns `{:ok, pdf_binary}` or `{:error, reason}`.
  """
  @spec generate(%{id: term(), name: String.t(), currency: String.t()}, Date.Range.t()) ::
          {:ok, binary()} | {:error, term()}
  def generate(store, date_range) do
    data = report_data(store, date_range)
    html = render_html(store, date_range, data)

    ChromicPDF.print_to_pdf({:html, html},
      print_to_pdf: %{
        paperWidth: 8.5,
        paperHeight: 11,
        marginTop: 0.5,
        marginBottom: 0.5,
        marginLeft: 0.5,
        marginRight: 0.5,
        printBackground: true
      }
    )
  end

  @doc """
  Computes report data for the given store and date range.

  Returns a map with:
  - `:total_revenue` - sum of order totals in minor units
  - `:order_count` - number of orders
  - `:avg_order_value` - average order total in minor units
  - `:top_products` - top 10 active products by title
  - `:order_status_breakdown` - map of status => count
  - `:currency` - store currency code
  """
  @spec report_data(%{id: term(), currency: String.t()}, Date.Range.t()) :: map()
  def report_data(store, date_range) do
    start_dt = date_range.first |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    end_dt = date_range.last |> Date.add(1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    store_id = store.id

    orders =
      Emakola.Orders.Order
      |> Ash.Query.filter(store_id == ^store_id)
      |> Ash.Query.filter(inserted_at >= ^start_dt)
      |> Ash.Query.filter(inserted_at < ^end_dt)
      |> Ash.read!(authorize?: false)

    total_revenue = orders |> Enum.map(& &1.total) |> Enum.sum()
    order_count = length(orders)

    avg_order_value =
      if order_count > 0, do: div(total_revenue, order_count), else: 0

    order_status_breakdown =
      orders
      |> Enum.group_by(& &1.status)
      |> Enum.map(fn {status, group} -> {status, length(group)} end)
      |> Enum.into(%{})

    top_products =
      Emakola.Catalog.Product
      |> Ash.Query.filter(store_id == ^store_id and status == :active)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(10)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.title)

    %{
      total_revenue: total_revenue,
      order_count: order_count,
      avg_order_value: avg_order_value,
      top_products: top_products,
      order_status_breakdown: order_status_breakdown,
      currency: store.currency || "GHS"
    }
  end

  # ── HTML Rendering ──────────────────────────────────────────────

  defp render_html(store, date_range, data) do
    currency_symbol = currency_symbol(data.currency)
    generated_at = DateTime.utc_now() |> Calendar.strftime("%B %d, %Y at %H:%M UTC")

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #1C1917; font-size: 13px; line-height: 1.5; }

        .header { background: #1C1917; color: #fff; padding: 32px 40px; }
        .header h1 { font-size: 22px; font-weight: 700; margin-bottom: 4px; }
        .header p { font-size: 12px; color: #a8a29e; }

        .section { padding: 24px 40px; }
        .section-title { font-size: 15px; font-weight: 700; color: #1C1917; margin-bottom: 16px; border-bottom: 2px solid #e7e5e4; padding-bottom: 8px; }

        .stats { display: flex; gap: 20px; margin-bottom: 8px; }
        .stat-card { flex: 1; background: #fafaf9; border: 1px solid #e7e5e4; border-radius: 8px; padding: 16px 20px; }
        .stat-card .label { font-size: 11px; color: #78716c; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px; }
        .stat-card .value { font-size: 22px; font-weight: 700; color: #1C1917; }

        table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
        th { text-align: left; font-size: 11px; color: #78716c; text-transform: uppercase; letter-spacing: 0.5px; padding: 8px 12px; border-bottom: 2px solid #e7e5e4; }
        td { padding: 10px 12px; border-bottom: 1px solid #f5f5f4; font-size: 13px; }
        tr:last-child td { border-bottom: none; }

        .footer { text-align: center; padding: 24px 40px; border-top: 1px solid #e7e5e4; color: #a8a29e; font-size: 11px; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>#{escape_html(store.name)} &mdash; Analytics Report</h1>
        <p>#{Date.to_string(date_range.first)} to #{Date.to_string(date_range.last)} &bull; Generated #{generated_at}</p>
      </div>

      <div class="section">
        <div class="section-title">Key Metrics</div>
        <div class="stats">
          <div class="stat-card">
            <div class="label">Total Revenue</div>
            <div class="value">#{currency_symbol}#{format_amount(data.total_revenue)}</div>
          </div>
          <div class="stat-card">
            <div class="label">Orders</div>
            <div class="value">#{data.order_count}</div>
          </div>
          <div class="stat-card">
            <div class="label">Avg. Order Value</div>
            <div class="value">#{currency_symbol}#{format_amount(data.avg_order_value)}</div>
          </div>
        </div>
      </div>

      #{render_status_table(data.order_status_breakdown)}

      #{render_top_products(data.top_products)}

      <div class="footer">
        #{escape_html(store.name)} &bull; Powered by Makola
      </div>
    </body>
    </html>
    """
  end

  defp render_status_table(breakdown) when map_size(breakdown) == 0 do
    """
    <div class="section">
      <div class="section-title">Order Status Breakdown</div>
      <p style="color: #78716c; font-size: 13px;">No orders in this period.</p>
    </div>
    """
  end

  defp render_status_table(breakdown) do
    rows =
      breakdown
      |> Enum.sort_by(fn {_status, count} -> -count end)
      |> Enum.map(fn {status, count} ->
        "<tr><td>#{status |> Atom.to_string() |> String.capitalize()}</td><td style=\"text-align:right\">#{count}</td></tr>"
      end)
      |> Enum.join("\n")

    """
    <div class="section">
      <div class="section-title">Order Status Breakdown</div>
      <table>
        <thead><tr><th>Status</th><th style="text-align:right">Count</th></tr></thead>
        <tbody>#{rows}</tbody>
      </table>
    </div>
    """
  end

  defp render_top_products([]) do
    """
    <div class="section">
      <div class="section-title">Top Products</div>
      <p style="color: #78716c; font-size: 13px;">No active products found.</p>
    </div>
    """
  end

  defp render_top_products(products) do
    rows =
      products
      |> Enum.with_index(1)
      |> Enum.map(fn {title, rank} ->
        "<tr><td>#{rank}</td><td>#{escape_html(title)}</td></tr>"
      end)
      |> Enum.join("\n")

    """
    <div class="section">
      <div class="section-title">Top Products</div>
      <table>
        <thead><tr><th>#</th><th>Product</th></tr></thead>
        <tbody>#{rows}</tbody>
      </table>
    </div>
    """
  end

  # ── Formatting helpers ──────────────────────────────────────────

  @doc false
  def format_amount(minor_units) when is_integer(minor_units) do
    whole_str = minor_units |> div(100) |> Emakola.Money.group_thousands()
    frac = rem(abs(minor_units), 100)

    "#{whole_str}.#{String.pad_leading(Integer.to_string(frac), 2, "0")}"
  end

  @doc false
  def currency_symbol("GHS"), do: "GH&#8373;"
  def currency_symbol("NGN"), do: "&#8358;"
  def currency_symbol(_), do: ""

  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape_html(nil), do: ""
end
