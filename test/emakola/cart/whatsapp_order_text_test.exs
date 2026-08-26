defmodule Emakola.Cart.WhatsappOrderTextTest do
  @moduledoc """
  Pins the contract for the cart-to-WhatsApp message helper:

    * Builds a properly formatted multi-line message body
    * Includes greeting with merchant name + optional customer name
    * Lists each cart item with qty, title, variant, line price
    * Total line included only when supplied
    * Customer phone line included only when present
    * `link/3` returns `nil` when store has no whatsapp_number
    * `link/3` URL-encodes the message and normalises the phone number
  """
  use ExUnit.Case, async: true

  alias Emakola.Cart.WhatsappOrderText

  defp store(extra \\ %{}) do
    Map.merge(
      %{name: "Akosua's Boutique", slug: "akosua-boutique", currency: "GHS"},
      extra
    )
  end

  defp item(extra \\ %{}) do
    Map.merge(
      %{
        product_title: "Ankara Wrap Dress",
        variant_info: "M, Red",
        quantity: 2,
        unit_price: 12_000
      },
      extra
    )
  end

  describe "build/3" do
    test "produces a clean multi-line message with greeting + items + footer" do
      msg =
        WhatsappOrderText.build(store(), [item()], total: 24_000, storefront_host: "https://e.x")

      assert msg =~ "Hello Akosua's Boutique"
      assert msg =~ "I'd like to order:"
      assert msg =~ "• 2 × Ankara Wrap Dress (M, Red) — GH₵ 240"
      assert msg =~ "Total: GH₵ 240"
      assert msg =~ "Sent from Akosua's Boutique's online shop:"
      assert msg =~ "https://e.x/akosua-boutique?ref=whatsapp"
    end

    test "includes customer name in greeting when provided" do
      msg =
        WhatsappOrderText.build(
          store(),
          [item()],
          customer_name: "Yaw",
          total: 24_000,
          storefront_host: "https://e.x"
        )

      assert msg =~ "Hello Akosua's Boutique, this is Yaw."
    end

    test "omits Total line when total opt is missing" do
      msg = WhatsappOrderText.build(store(), [item()], storefront_host: "https://e.x")
      refute msg =~ "Total:"
    end

    test "includes contact line when customer_phone provided" do
      msg =
        WhatsappOrderText.build(
          store(),
          [item()],
          customer_phone: "0241234567",
          storefront_host: "https://e.x"
        )

      assert msg =~ "My contact: 0241234567"
    end

    test "omits contact line when customer_phone is nil or empty" do
      msg1 = WhatsappOrderText.build(store(), [item()], storefront_host: "https://e.x")
      refute msg1 =~ "My contact:"

      msg2 =
        WhatsappOrderText.build(store(), [item()],
          customer_phone: "",
          storefront_host: "https://e.x"
        )

      refute msg2 =~ "My contact:"
    end

    test "renders item without variant info gracefully" do
      msg =
        WhatsappOrderText.build(
          store(),
          [item(%{variant_info: nil})],
          storefront_host: "https://e.x"
        )

      assert msg =~ "• 2 × Ankara Wrap Dress — GH₵ 240"
      refute msg =~ "()"
    end

    test "uses store currency by default" do
      msg =
        WhatsappOrderText.build(store(%{currency: "NGN"}), [item()],
          storefront_host: "https://e.x"
        )

      assert msg =~ "₦"
    end

    test "currency override wins over store currency" do
      msg =
        WhatsappOrderText.build(store(), [item()],
          currency: "USD",
          storefront_host: "https://e.x"
        )

      assert msg =~ "$"
    end
  end

  describe "link/3" do
    test "builds wa.me URL with normalised phone + encoded message" do
      url =
        WhatsappOrderText.link(
          store(%{whatsapp_number: "+233 (24) 555-1234"}),
          [item()],
          total: 24_000,
          storefront_host: "https://e.x"
        )

      assert url =~ "https://wa.me/233245551234?text="
      # Body URL-encoded — verify a known fragment landed
      assert url =~ "I%27d+like+to+order"
    end

    test "returns nil when store has no whatsapp_number" do
      assert nil ==
               WhatsappOrderText.link(
                 store(%{whatsapp_number: nil}),
                 [item()],
                 storefront_host: "https://e.x"
               )

      assert nil ==
               WhatsappOrderText.link(
                 store(%{whatsapp_number: ""}),
                 [item()],
                 storefront_host: "https://e.x"
               )
    end
  end
end
