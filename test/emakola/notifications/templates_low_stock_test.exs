defmodule Emakola.Notifications.TemplatesLowStockTest do
  use ExUnit.Case, async: true

  alias Emakola.Notifications.Templates

  describe "low_stock_realtime_sms/4" do
    test "formats real-time low stock alert message" do
      message = Templates.low_stock_realtime_sms("Kente Cloth", "SKU-001", 3, "Kente Kingdom")

      assert message =~ "Low stock alert"
      assert message =~ "Kente Cloth"
      assert message =~ "SKU-001"
      assert message =~ "3"
      assert message =~ "Kente Kingdom"
    end

    test "handles nil SKU" do
      message = Templates.low_stock_realtime_sms("Kente Cloth", nil, 5, "My Store")
      assert message =~ "N/A"
    end
  end

  describe "low_stock_digest_sms/2" do
    test "formats daily digest message" do
      message = Templates.low_stock_digest_sms(5, "Kente Kingdom")

      assert message =~ "5 items"
      assert message =~ "Kente Kingdom"
      assert message =~ "dashboard"
    end
  end
end
