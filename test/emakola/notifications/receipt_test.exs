defmodule Emakola.Notifications.ReceiptTest do
  use ExUnit.Case, async: true

  alias Emakola.Notifications.Templates

  describe "order_confirmed_sms/2 receipt format" do
    test "includes item count when line_items loaded" do
      order = %{
        order_number: "ORD-20260326-ABC123",
        total: 15_000,
        currency: "GHS",
        line_items: [%{product_title: "Item 1"}, %{product_title: "Item 2"}]
      }

      store = %{name: "Kente Kingdom"}

      message = Templates.order_confirmed_sms(order, store)

      assert message =~ "ORD-20260326-ABC123"
      assert message =~ "2 item"
      assert message =~ "150.00"
      assert message =~ "Kente Kingdom"
    end

    test "works without line_items loaded" do
      order = %{
        order_number: "ORD-20260326-XYZ",
        total: 5_000,
        currency: "GHS"
      }

      store = %{name: "My Store"}

      message = Templates.order_confirmed_sms(order, store)

      assert message =~ "ORD-20260326-XYZ"
      assert message =~ "50.00"
    end
  end
end
