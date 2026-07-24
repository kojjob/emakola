defmodule Emakola.Notifications.Channels.WhatsAppTest do
  use ExUnit.Case, async: false

  alias Emakola.Notifications.Channels.WhatsApp

  # ── Test data helpers ──────────────────────────────────────────

  defp build_order(attrs \\ []) do
    Map.merge(
      %{
        order_number: "ORD-20260325-WA001",
        total: 50_000,
        currency: "GHS",
        store_id: Ash.UUID.generate()
      },
      Map.new(attrs)
    )
  end

  defp default_opts(extra \\ []) do
    Keyword.merge(
      [
        customer_phone: "+233244123456",
        store_name: "Accra Fashion Hub"
      ],
      extra
    )
  end

  # ── build_template_message/4 ───────────────────────────────────

  describe "build_template_message/4" do
    test "builds correct message structure for WhatsApp Cloud API" do
      params = [%{type: "text", text: "ORD-123"}]
      message = WhatsApp.build_template_message("+233244123456", "order_confirmation", params)

      assert message.messaging_product == "whatsapp"
      assert message.to == "233244123456"
      assert message.type == "template"
      assert message.template.name == "order_confirmation"
      assert message.template.language.code == "en"
    end

    test "strips non-numeric characters from phone number" do
      message = WhatsApp.build_template_message("+233 244-123 456", "test", [])
      assert message.to == "233244123456"
    end

    test "includes parameters in body component" do
      params = [
        %{type: "text", text: "ORD-123"},
        %{type: "text", text: "My Store"},
        %{type: "text", text: "GH₵500.00"}
      ]

      message = WhatsApp.build_template_message("+233244123456", "order_confirmation", params)
      [component] = message.template.components
      assert component.type == "body"
      assert length(component.parameters) == 3
    end

    test "accepts custom language code" do
      message = WhatsApp.build_template_message("+233244123456", "test", [], "fr")
      assert message.template.language.code == "fr"
    end
  end

  # ── send_order_confirmation/2 ──────────────────────────────────

  describe "send_order_confirmation/2 message formatting" do
    test "requires customer_phone option" do
      order = build_order()

      assert_raise KeyError, ~r/customer_phone/, fn ->
        WhatsApp.send_order_confirmation(order, [])
      end
    end
  end

  # ── send_shipping_update/2 ─────────────────────────────────────

  describe "send_shipping_update/2 message formatting" do
    test "requires customer_phone option" do
      order = build_order()

      assert_raise KeyError, ~r/customer_phone/, fn ->
        WhatsApp.send_shipping_update(order, [])
      end
    end
  end

  # ── send_delivery_confirmation/2 ───────────────────────────────

  describe "send_delivery_confirmation/2 message formatting" do
    test "requires customer_phone option" do
      order = build_order()

      assert_raise KeyError, ~r/customer_phone/, fn ->
        WhatsApp.send_delivery_confirmation(order, [])
      end
    end
  end

  # ── send_message/4 (WhatsAppProvider bridge) ───────────────────

  describe "send_message/4 behaviour declaration" do
    test "channel implements the WhatsAppProvider behaviour" do
      behaviours =
        WhatsApp.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Emakola.Notifications.WhatsAppProvider in behaviours
      assert function_exported?(WhatsApp, :send_message, 4)
    end
  end

  describe "send_message/4 with mocked HTTP" do
    setup do
      original_http = Application.get_env(:emakola, :http_client)
      original_wa = Application.get_env(:emakola, Emakola.Notifications.Channels.WhatsApp)

      Application.put_env(:emakola, :http_client, __MODULE__.MockHTTP)

      Application.put_env(:emakola, Emakola.Notifications.Channels.WhatsApp,
        api_token: "test_token_123",
        phone_number_id: "1234567890"
      )

      on_exit(fn ->
        if original_http,
          do: Application.put_env(:emakola, :http_client, original_http),
          else: Application.delete_env(:emakola, :http_client)

        if original_wa,
          do: Application.put_env(:emakola, Emakola.Notifications.Channels.WhatsApp, original_wa),
          else: Application.delete_env(:emakola, Emakola.Notifications.Channels.WhatsApp)
      end)

      :ok
    end

    test "sends an order template from a params map, in declared order" do
      params = %{
        order_number: "ORD-123",
        store_name: "Accra Fashion Hub",
        total: "500.00",
        currency: "GHS"
      }

      assert {:ok, result} =
               WhatsApp.send_message("+233244123456", "order_placed", params,
                 store_id: Ash.UUID.generate()
               )

      assert result.template == "order_placed"
      assert result.status == 200

      request_body = result.body["request_body"]
      assert request_body.template.name == "order_placed"
      [component] = request_body.template.components

      assert Enum.map(component.parameters, & &1.text) ==
               ["ORD-123", "Accra Fashion Hub", "500.00", "GHS"]
    end

    test "sends the supplier_fulfillment template" do
      params = %{
        order_number: "ORD-456",
        supplier_name: "Kumasi Crafts",
        items: "2x Kente Scarf",
        ship_to: "12 High St, Accra"
      }

      assert {:ok, result} =
               WhatsApp.send_message("+233244123456", "supplier_fulfillment", params,
                 store_id: Ash.UUID.generate()
               )

      assert result.template == "supplier_fulfillment"

      [component] = result.body["request_body"].template.components

      assert Enum.map(component.parameters, & &1.text) ==
               ["ORD-456", "Kumasi Crafts", "2x Kente Scarf", "12 High St, Accra"]
    end

    test "sends the supply_connection_update template" do
      params = %{
        counterparty: "Kumasi Crafts",
        event: "requested",
        url: "https://emakola.com/admin/settings/supply-network"
      }

      assert {:ok, result} =
               WhatsApp.send_message("+233244123456", "supply_connection_update", params,
                 store_id: Ash.UUID.generate()
               )

      assert result.template == "supply_connection_update"

      [component] = result.body["request_body"].template.components

      assert Enum.map(component.parameters, & &1.text) ==
               ["Kumasi Crafts", "requested", "https://emakola.com/admin/settings/supply-network"]
    end

    test "returns an error for an unknown template instead of guessing param order" do
      assert {:error, {:unknown_template, "nope"}} =
               WhatsApp.send_message("+233244123456", "nope", %{a: "b"}, [])
    end

    test "raises loudly when a declared param is missing from the map" do
      assert_raise KeyError, fn ->
        WhatsApp.send_message("+233244123456", "order_placed", %{order_number: "ORD-1"}, [])
      end
    end
  end

  # ── Integration with HTTP mock ─────────────────────────────────

  describe "send_order_confirmation/2 with mocked HTTP" do
    setup do
      # Store original config and set test config
      original_http = Application.get_env(:emakola, :http_client)
      original_wa = Application.get_env(:emakola, Emakola.Notifications.Channels.WhatsApp)

      Application.put_env(:emakola, :http_client, __MODULE__.MockHTTP)

      Application.put_env(:emakola, Emakola.Notifications.Channels.WhatsApp,
        api_token: "test_token_123",
        phone_number_id: "1234567890"
      )

      on_exit(fn ->
        if original_http,
          do: Application.put_env(:emakola, :http_client, original_http),
          else: Application.delete_env(:emakola, :http_client)

        if original_wa,
          do: Application.put_env(:emakola, Emakola.Notifications.Channels.WhatsApp, original_wa),
          else: Application.delete_env(:emakola, Emakola.Notifications.Channels.WhatsApp)
      end)

      :ok
    end

    test "sends order confirmation and returns success" do
      order = build_order()
      assert {:ok, result} = WhatsApp.send_order_confirmation(order, default_opts())
      assert result.template == "order_confirmation"
      assert result.status == 200
    end

    test "sends shipping update with tracking info" do
      order = build_order()

      opts =
        default_opts(
          tracking_number: "GP-2026-XYZ",
          carrier: "Ghana Post"
        )

      assert {:ok, result} = WhatsApp.send_shipping_update(order, opts)
      assert result.template == "order_shipped"
    end

    test "sends delivery confirmation" do
      order = build_order()
      assert {:ok, result} = WhatsApp.send_delivery_confirmation(order, default_opts())
      assert result.template == "order_delivered"
    end
  end

  # Mock HTTP client for testing
  defmodule MockHTTP do
    def post(_url, opts) do
      body = Keyword.get(opts, :json, %{})

      {:ok,
       %{
         status: 200,
         body: %{
           "messages" => [%{"id" => "wamid.test123"}],
           "messaging_product" => "whatsapp",
           "request_body" => body
         }
       }}
    end
  end
end
