defmodule Emakola.Notifications.Emails.OrderEmail do
  @moduledoc """
  Order confirmation email builder.

  Generates a beautiful HTML email with plain text fallback for order
  confirmation notifications. Includes line items, pricing, shipping
  address, and store branding.

  All monetary amounts are expected as integers in minor currency units
  (pesewas for GHS, kobo for NGN).
  """

  import Swoosh.Email
  alias Emakola.Notifications.Emails.EmailHelpers

  @doc """
  Builds an order confirmation email.

  ## Parameters
    - `order` — Order struct/map with :order_number, :total, :subtotal,
      :currency, :shipping_address, :line_items, :inserted_at
    - `customer` — Customer struct/map with :name, :email
    - `store` — Store struct/map with :name, :slug, :contact_email,
      :contact_phone, :whatsapp_number, :logo_url

  ## Returns
    A `%Swoosh.Email{}` ready for `Emakola.Mailer.deliver/1`.
  """
  def order_confirmation(order, customer, store) do
    email_address = to_string(customer.email)

    base =
      new()
      |> from(EmailHelpers.from_address(store))
      |> subject("Order Confirmed — #{order.order_number}")
      |> html_body(confirmation_html(order, customer, store))
      |> text_body(confirmation_text(order, customer, store))

    if email_address != "" do
      to(base, {customer.name || "", email_address})
    else
      # Caller must validate before sending — set to as raw list so struct builds
      %{base | to: [{customer.name || "", nil}]}
    end
  end

  # ── HTML template ────────────────────────────────────────────────

  defp confirmation_html(order, customer, store) do
    line_items_html = build_line_items_html(order.line_items, order.currency)
    address_html = build_address_html(order.shipping_address)
    track_url = "/s/#{store.slug}/track/#{order.order_number}"
    whatsapp_url = EmailHelpers.whatsapp_link(store.whatsapp_number)
    order_date = EmailHelpers.format_date(order.inserted_at)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Order Confirmation</title>
    </head>
    <body style="margin:0;padding:0;background-color:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
      <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;background-color:#f4f4f5;">
        <tr>
          <td align="center" style="padding:24px 16px;">
            <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.1);">

              <!-- Header -->
              <tr>
                <td style="background-color:#1a1a2e;padding:32px 24px;text-align:center;">
                  #{logo_html(store)}
                  <h1 style="color:#ffffff;font-size:24px;margin:8px 0 0 0;font-weight:600;">Order Confirmed</h1>
                </td>
              </tr>

              <!-- Greeting -->
              <tr>
                <td style="padding:32px 24px 16px 24px;">
                  <p style="font-size:16px;color:#374151;margin:0;">
                    Hi #{escape_html(customer.name || "there")},
                  </p>
                  <p style="font-size:16px;color:#374151;margin:8px 0 0 0;">
                    Thank you for your order from <strong>#{escape_html(store.name)}</strong>!
                    We've received your order and will process it shortly.
                  </p>
                </td>
              </tr>

              <!-- Order Info -->
              <tr>
                <td style="padding:0 24px;">
                  <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;background-color:#f9fafb;border-radius:6px;padding:16px;">
                    <tr>
                      <td style="padding:12px 16px;">
                        <p style="font-size:13px;color:#6b7280;margin:0;text-transform:uppercase;letter-spacing:0.5px;">Order Number</p>
                        <p style="font-size:18px;color:#111827;margin:4px 0 0 0;font-weight:700;">#{escape_html(order.order_number)}</p>
                      </td>
                      <td style="padding:12px 16px;text-align:right;">
                        <p style="font-size:13px;color:#6b7280;margin:0;text-transform:uppercase;letter-spacing:0.5px;">Order Date</p>
                        <p style="font-size:14px;color:#111827;margin:4px 0 0 0;">#{order_date}</p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              <!-- Line Items -->
              <tr>
                <td style="padding:24px;">
                  <h2 style="font-size:16px;color:#111827;margin:0 0 12px 0;font-weight:600;">Items Ordered</h2>
                  <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse;">
                    <tr style="border-bottom:2px solid #e5e7eb;">
                      <th style="text-align:left;padding:8px 0;font-size:12px;color:#6b7280;text-transform:uppercase;letter-spacing:0.5px;">Item</th>
                      <th style="text-align:center;padding:8px 0;font-size:12px;color:#6b7280;text-transform:uppercase;letter-spacing:0.5px;">Qty</th>
                      <th style="text-align:right;padding:8px 0;font-size:12px;color:#6b7280;text-transform:uppercase;letter-spacing:0.5px;">Price</th>
                      <th style="text-align:right;padding:8px 0;font-size:12px;color:#6b7280;text-transform:uppercase;letter-spacing:0.5px;">Total</th>
                    </tr>
                    #{line_items_html}
                  </table>
                </td>
              </tr>

              <!-- Totals -->
              <tr>
                <td style="padding:0 24px 24px 24px;">
                  <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;">
                    <tr>
                      <td style="padding:8px 0;font-size:14px;color:#6b7280;">Subtotal</td>
                      <td style="padding:8px 0;font-size:14px;color:#374151;text-align:right;">#{EmailHelpers.format_money(order.subtotal, order.currency)}</td>
                    </tr>
                    <tr>
                      <td style="padding:8px 0;font-size:14px;color:#6b7280;">Shipping</td>
                      <td style="padding:8px 0;font-size:14px;color:#374151;text-align:right;">#{shipping_amount(order)}</td>
                    </tr>
                    #{discount_html(order)}
                    <tr style="border-top:2px solid #e5e7eb;">
                      <td style="padding:12px 0;font-size:18px;color:#111827;font-weight:700;">Total</td>
                      <td style="padding:12px 0;font-size:18px;color:#111827;font-weight:700;text-align:right;">#{EmailHelpers.format_money(order.total, order.currency)}</td>
                    </tr>
                  </table>
                </td>
              </tr>

              #{address_html}

              <!-- Track Order Button -->
              <tr>
                <td style="padding:8px 24px 32px 24px;text-align:center;">
                  <a href="#{track_url}" style="display:inline-block;background-color:#2563eb;color:#ffffff;text-decoration:none;padding:14px 32px;border-radius:6px;font-size:16px;font-weight:600;">
                    Track Your Order
                  </a>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="background-color:#f9fafb;padding:24px;border-top:1px solid #e5e7eb;">
                  <p style="font-size:14px;color:#374151;margin:0;text-align:center;font-weight:600;">#{escape_html(store.name)}</p>
                  #{footer_contact_html(store)}
                  #{footer_whatsapp_html(whatsapp_url)}
                  <p style="font-size:12px;color:#9ca3af;margin:16px 0 0 0;text-align:center;">
                    You received this email because you placed an order with #{escape_html(store.name)}.
                  </p>
                </td>
              </tr>

            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
  end

  # ── Plain text template ──────────────────────────────────────────

  defp confirmation_text(order, customer, store) do
    line_items_text = build_line_items_text(order.line_items, order.currency)
    address_text = build_address_text(order.shipping_address)
    track_url = "/s/#{store.slug}/track/#{order.order_number}"
    whatsapp_url = EmailHelpers.whatsapp_link(store.whatsapp_number)

    """
    ORDER CONFIRMED — #{order.order_number}

    Hi #{customer.name || "there"},

    Thank you for your order from #{store.name}! We've received your order and will process it shortly.

    Order Number: #{order.order_number}
    Order Date: #{EmailHelpers.format_date(order.inserted_at)}

    ITEMS ORDERED
    #{line_items_text}
    Subtotal: #{EmailHelpers.format_money(order.subtotal, order.currency)}
    Shipping: #{shipping_amount(order)}
    #{discount_text(order)}Total: #{EmailHelpers.format_money(order.total, order.currency)}
    #{address_text}
    Track your order: #{track_url}

    ---
    #{store.name}
    #{if store.contact_email, do: "Email: #{store.contact_email}", else: ""}
    #{if store.contact_phone, do: "Phone: #{store.contact_phone}", else: ""}
    #{if whatsapp_url, do: "WhatsApp: #{whatsapp_url}", else: ""}
    """
    |> String.trim()
  end

  # ── HTML fragment builders ───────────────────────────────────────

  defp build_line_items_html(line_items, currency) when is_list(line_items) do
    Enum.map_join(line_items, "\n", fn item ->
      title = Map.get(item, :product_title) || Map.get(item, "product_title")
      sku = Map.get(item, :variant_sku) || Map.get(item, "variant_sku")
      qty = Map.get(item, :quantity) || Map.get(item, "quantity")
      unit = Map.get(item, :unit_price) || Map.get(item, "unit_price")
      total = Map.get(item, :line_total) || Map.get(item, "line_total")

      """
      <tr style="border-bottom:1px solid #f3f4f6;">
        <td style="padding:12px 0;">
          <p style="font-size:14px;color:#111827;margin:0;font-weight:500;">#{escape_html(title)}</p>
          #{if sku, do: "<p style=\"font-size:12px;color:#9ca3af;margin:2px 0 0 0;\">SKU: #{escape_html(sku)}</p>", else: ""}
        </td>
        <td style="padding:12px 0;text-align:center;font-size:14px;color:#374151;">#{qty}</td>
        <td style="padding:12px 0;text-align:right;font-size:14px;color:#374151;">#{EmailHelpers.format_money(unit, currency)}</td>
        <td style="padding:12px 0;text-align:right;font-size:14px;color:#111827;font-weight:500;">#{EmailHelpers.format_money(total, currency)}</td>
      </tr>
      """
    end)
  end

  defp build_line_items_html(_, _), do: ""

  defp build_line_items_text(line_items, currency) when is_list(line_items) do
    Enum.map_join(line_items, "\n", fn item ->
      title = Map.get(item, :product_title) || Map.get(item, "product_title")
      qty = Map.get(item, :quantity) || Map.get(item, "quantity")

      unit =
        EmailHelpers.format_money(
          Map.get(item, :unit_price) || Map.get(item, "unit_price"),
          currency
        )

      total =
        EmailHelpers.format_money(
          Map.get(item, :line_total) || Map.get(item, "line_total"),
          currency
        )

      "- #{title} x#{qty} @ #{unit} = #{total}"
    end)
  end

  defp build_line_items_text(_, _), do: ""

  defp build_address_html(nil), do: ""

  defp build_address_html(address) when is_map(address) do
    lines = EmailHelpers.format_address(address)

    if lines == [] do
      ""
    else
      address_lines = Enum.map_join(lines, "<br>", &escape_html/1)

      """
      <tr>
        <td style="padding:0 24px 24px 24px;">
          <h2 style="font-size:16px;color:#111827;margin:0 0 8px 0;font-weight:600;">Delivery Address</h2>
          <p style="font-size:14px;color:#374151;margin:0;line-height:1.6;">
            #{address_lines}
          </p>
        </td>
      </tr>
      """
    end
  end

  defp build_address_text(nil), do: ""

  defp build_address_text(address) when is_map(address) do
    lines = EmailHelpers.format_address(address)

    if lines == [] do
      ""
    else
      formatted = Enum.map_join(lines, "\n", &"  #{&1}")

      """

      DELIVERY ADDRESS
      #{formatted}
      """
    end
  end

  defp logo_html(%{logo_url: url}) when is_binary(url) and url != "" do
    """
    <img src="#{escape_html(url)}" alt="Store Logo" style="max-width:120px;max-height:60px;margin-bottom:8px;">
    """
  end

  defp logo_html(_store), do: ""

  defp footer_contact_html(store) do
    parts =
      [
        if(store.contact_email, do: escape_html(store.contact_email)),
        if(store.contact_phone, do: escape_html(store.contact_phone))
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [] do
      ""
    else
      """
      <p style="font-size:13px;color:#6b7280;margin:4px 0 0 0;text-align:center;">#{Enum.join(parts, " &bull; ")}</p>
      """
    end
  end

  defp footer_whatsapp_html(nil), do: ""

  defp footer_whatsapp_html(url) do
    """
    <p style="font-size:13px;color:#6b7280;margin:4px 0 0 0;text-align:center;">
      <a href="#{url}" style="color:#25d366;text-decoration:none;">Chat with us on WhatsApp</a>
    </p>
    """
  end

  defp discount_html(%{discount_amount: amount} = order)
       when is_integer(amount) and amount > 0 do
    """
    <tr>
      <td style="padding:8px 0;font-size:14px;color:#059669;">Discount</td>
      <td style="padding:8px 0;font-size:14px;color:#059669;text-align:right;">-#{EmailHelpers.format_money(amount, order.currency)}</td>
    </tr>
    """
  end

  defp discount_html(_), do: ""

  defp discount_text(%{discount_amount: amount} = order)
       when is_integer(amount) and amount > 0 do
    "Discount: -#{EmailHelpers.format_money(amount, order.currency)}\n"
  end

  defp discount_text(_), do: ""

  defp shipping_amount(order) do
    shipping = (order.total || 0) - (order.subtotal || 0)

    if shipping > 0 do
      EmailHelpers.format_money(shipping, order.currency)
    else
      "Free"
    end
  end

  defp escape_html(nil), do: ""

  defp escape_html(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
