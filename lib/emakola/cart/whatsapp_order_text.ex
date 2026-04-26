defmodule Emakola.Cart.WhatsappOrderText do
  @moduledoc """
  Formats a customer's cart into a pre-filled WhatsApp message for the
  "Order via WhatsApp" CTA.

  The button on the cart page generates a `wa.me/{number}?text=<encoded>`
  link that, when tapped, opens WhatsApp with the message ready to send.
  No API call required — works on every device, no merchant catalog
  setup needed. This is the lowest-friction path for West African
  customers who are already in WhatsApp daily.

  ## Output shape

      Hello {Store Name},

      I'd like to order:
      • 2 × Ankara Wrap Dress (M, Red) — GH₵ 240.00
      • 1 × Kente Throw Pillow — GH₵ 85.00

      Total: GH₵ 565.00

      My contact: 0241234567 (optional)

      Sent from {Store Name}'s online shop:
      https://example.com/s/store-slug

  Lines for empty fields (no customer name, no contact) are omitted so
  the message stays clean.
  """

  alias EmakolaWeb.Helpers.Currency

  @doc """
  Builds the WhatsApp message body. Returns a plain string ready to be
  passed through `URI.encode_www_form/1` for the wa.me link.

  ## Required

    * `store` — must have `:name` and `:slug`
    * `cart` — list of items with `:product_title`, `:variant_info`,
      `:quantity`, `:unit_price`

  ## Optional

    * `currency` — defaults to "GHS"
    * `customer_name`, `customer_phone` — included when provided
    * `total` — includes a Total line when provided
    * `storefront_host` — defaults to the configured Endpoint URL
  """
  @spec build(map(), [map()], keyword()) :: String.t()
  def build(store, cart, opts \\ []) do
    currency = Keyword.get(opts, :currency, store_currency(store))
    customer_name = Keyword.get(opts, :customer_name)
    customer_phone = Keyword.get(opts, :customer_phone)
    total = Keyword.get(opts, :total)

    storefront_host =
      Keyword.get_lazy(opts, :storefront_host, fn -> EmakolaWeb.Endpoint.url() end)

    [
      greeting(store, customer_name),
      "",
      "I'd like to order:",
      Enum.map_join(cart, "\n", &line_for(&1, currency)),
      "",
      total_line(total, currency),
      contact_line(customer_phone),
      "",
      "Sent from #{store.name}'s online shop:",
      "#{storefront_host}/s/#{store.slug}?ref=whatsapp"
    ]
    |> Enum.reject(&(&1 == nil))
    |> Enum.join("\n")
  end

  @doc """
  Builds the full wa.me URL with the message pre-encoded.

  Returns nil if the store has no `whatsapp_number`.
  """
  @spec link(map(), [map()], keyword()) :: String.t() | nil
  def link(store, cart, opts \\ []) do
    case Map.get(store, :whatsapp_number) do
      nil ->
        nil

      "" ->
        nil

      number ->
        text = build(store, cart, opts) |> URI.encode_www_form()
        digits = number |> to_string() |> String.replace(~r/[^\d]/, "")
        "https://wa.me/#{digits}?text=#{text}"
    end
  end

  defp greeting(%{name: name}, nil), do: "Hello #{name},"
  defp greeting(%{name: name}, ""), do: "Hello #{name},"

  defp greeting(%{name: name}, customer_name) when is_binary(customer_name),
    do: "Hello #{name}, this is #{customer_name}."

  defp line_for(item, currency) do
    qty = Map.get(item, :quantity, 1)
    title = Map.get(item, :product_title, "Item")
    variant_info = Map.get(item, :variant_info, "") |> normalise_variant()
    unit_price = Map.get(item, :unit_price, 0)
    line_total = unit_price * qty

    suffix = if variant_info == "", do: "", else: " (#{variant_info})"
    price_str = Currency.format_price(line_total, currency)

    "• #{qty} × #{title}#{suffix} — #{price_str}"
  end

  defp normalise_variant(nil), do: ""
  defp normalise_variant(""), do: ""
  defp normalise_variant(s) when is_binary(s), do: String.trim(s)
  defp normalise_variant(_), do: ""

  defp total_line(nil, _currency), do: nil
  defp total_line(total, currency), do: "Total: #{Currency.format_price(total, currency)}"

  defp contact_line(nil), do: nil
  defp contact_line(""), do: nil
  defp contact_line(phone), do: "My contact: #{phone}"

  defp store_currency(%{currency: c}) when is_binary(c) and c != "", do: c
  defp store_currency(_), do: "GHS"
end
