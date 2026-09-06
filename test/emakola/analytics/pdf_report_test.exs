defmodule Emakola.Analytics.PdfReportTest do
  @moduledoc """
  Tests for analytics PDF report data aggregation.

  PDF generation tests that require Chrome are tagged with `:pdf` so they
  can be excluded in CI environments without a browser installed.
  """
  use Emakola.DataCase, async: false

  alias Emakola.Analytics.PdfReport
  alias Emakola.Factory

  setup do
    {_merchant, store} = Factory.create_merchant_with_store!()
    {:ok, store: store}
  end

  describe "report_data/2" do
    test "returns zeroes when no orders exist", %{store: store} do
      date_range = Date.range(Date.add(Date.utc_today(), -30), Date.utc_today())

      data = PdfReport.report_data(store, date_range)

      assert data.total_revenue == 0
      assert data.order_count == 0
      assert data.avg_order_value == 0
      assert data.order_status_breakdown == %{}
      assert data.currency == "GHS"
    end

    # Rewritten: this test used to assert total_revenue/order_count/
    # avg_order_value summed EVERY order, pending and cancelled included —
    # pinning the same bug Reports fixed for the screen (Order.paid_statuses/0).
    # The status breakdown stays over all orders, so it still sees all three.
    test "aggregates paid orders within date range; status breakdown sees all orders", %{
      store: store
    } do
      _pending = Factory.create_order!(store, %{total: 10_000, status: :pending})
      _confirmed = Factory.create_order!(store, %{total: 20_000, status: :confirmed})
      _cancelled = Factory.create_order!(store, %{total: 15_000, status: :cancelled})

      date_range = Date.range(Date.add(Date.utc_today(), -1), Date.utc_today())
      data = PdfReport.report_data(store, date_range)

      assert data.total_revenue == 20_000
      assert data.order_count == 1
      assert data.avg_order_value == 20_000
      assert data.order_status_breakdown[:pending] == 1
      assert data.order_status_breakdown[:confirmed] == 1
      assert data.order_status_breakdown[:cancelled] == 1
    end

    test "excludes orders outside date range", %{store: store} do
      _order = Factory.create_order!(store, %{total: 10_000})

      # Use a date range in the far past that won't include today's orders
      date_range = Date.range(~D[2020-01-01], ~D[2020-01-31])
      data = PdfReport.report_data(store, date_range)

      assert data.order_count == 0
      assert data.total_revenue == 0
    end

    test "does not include orders from other stores", %{store: store} do
      {_other_merchant, other_store} = Factory.create_merchant_with_store!()
      _other_order = Factory.create_order!(other_store, %{total: 99_999, status: :confirmed})
      _our_order = Factory.create_order!(store, %{total: 5_000, status: :confirmed})

      date_range = Date.range(Date.add(Date.utc_today(), -1), Date.utc_today())
      data = PdfReport.report_data(store, date_range)

      assert data.order_count == 1
      assert data.total_revenue == 5_000
    end

    # top_products used to be the ten newest :active products by title —
    # a product list wearing a "top" label with no sales behind it. It is
    # now the real best sellers (Dashboard.Stats.best_sellers/4): ranked by
    # units sold, and a product nobody bought does not appear.
    test "top_products lists best sellers by units sold, omitting an unsold product", %{
      store: store
    } do
      best = Factory.create_product!(store, %{title: "Best Seller"})
      best_variant = Factory.create_variant!(best, store)
      slow = Factory.create_product!(store, %{title: "Slow Mover"})
      slow_variant = Factory.create_variant!(slow, store)
      _unsold = Factory.create_product!(store, %{title: "Never Sold"})

      order = Factory.create_order!(store, %{total: 30_000, status: :confirmed})

      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: best_variant.id,
        quantity: 5
      })
      |> Ash.create!(authorize?: false)

      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: slow_variant.id,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

      date_range = Date.range(Date.add(Date.utc_today(), -1), Date.utc_today())
      data = PdfReport.report_data(store, date_range)

      assert [%{title: "Best Seller", quantity: 5} | rest] = data.top_products
      assert Enum.any?(rest, &(&1.title == "Slow Mover"))
      refute Enum.any?(data.top_products, &(&1.title == "Never Sold"))
    end

    test "respects store currency", %{store: _store} do
      {_merchant, ngn_store} = Factory.create_merchant_with_store!(%{currency: "NGN"})

      date_range = Date.range(Date.add(Date.utc_today(), -30), Date.utc_today())
      data = PdfReport.report_data(ngn_store, date_range)

      assert data.currency == "NGN"
    end
  end

  describe "format_amount/1" do
    test "formats minor units to major with two decimal places" do
      assert PdfReport.format_amount(0) == "0.00"
      assert PdfReport.format_amount(100) == "1.00"
      assert PdfReport.format_amount(10_050) == "100.50"
      assert PdfReport.format_amount(1_234_567) == "12,345.67"
    end
  end

  describe "currency_symbol/1" do
    test "returns correct symbols" do
      assert PdfReport.currency_symbol("GHS") == "GH&#8373;"
      assert PdfReport.currency_symbol("NGN") == "&#8358;"
      assert PdfReport.currency_symbol("USD") == ""
    end
  end

  @moduletag :pdf
  describe "generate/2" do
    @tag :pdf
    test "renders a valid PDF with the configured Chrome executable", %{store: store} do
      Factory.create_order!(store, %{total: 10_000})

      date_range = Date.range(Date.add(Date.utc_today(), -30), Date.utc_today())
      assert {:ok, pdf_binary} = PdfReport.generate(store, date_range)

      # ChromicPDF returns base64-encoded PDF by default.
      assert is_binary(pdf_binary)
      assert byte_size(pdf_binary) > 0

      decoded = Base.decode64!(pdf_binary)
      assert String.starts_with?(decoded, "%PDF")
    end
  end
end
