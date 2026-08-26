defmodule Emakola.Notifications.Emails.DeliveryEmail do
  @moduledoc """
  Delivery confirmation email builder.

  Generates an HTML email with plain text fallback when an order
  has been delivered. Includes a thank-you message and a prompt
  to leave a review.
  """

  import Swoosh.Email
  alias EmakolaWeb.SEO.Canonical
  alias Emakola.Notifications.Emails.EmailHelpers

  @doc """
  Builds an order delivery confirmation email.

  ## Parameters
    - `order` — Order struct/map with :order_number, :total, :currency,
      :line_items, :inserted_at
    - `customer` — Customer struct/map with :name, :email
    - `store` — Store struct/map with :name, :slug, :contact_email,
      :contact_phone, :whatsapp_number, :logo_url

  ## Returns
    A `%Swoosh.Email{}` ready for `Emakola.Mailer.deliver/1`.
  """
  def order_delivered(order, customer, store) do
    new()
    |> to({customer.name || "", to_string(customer.email)})
    |> from(EmailHelpers.from_address(store))
    |> subject("Your Order #{order.order_number} Has Been Delivered!")
    |> html_body(delivered_html(order, customer, store))
    |> text_body(delivered_text(order, customer, store))
  end

  # ── HTML template ────────────────────────────────────────────────

  defp delivered_html(order, customer, store) do
    line_items_html = build_line_items_html(order.line_items, order.currency)
    review_url = Canonical.path(store, "/orders/#{order.order_number}/review")
    whatsapp_url = EmailHelpers.whatsapp_link(store.whatsapp_number)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Order Delivered</title>
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
                  <h1 style="color:#d4a843;font-size:24px;margin:8px 0 0 0;font-weight:600;">Order Delivered!</h1>
                </td>
              </tr>

              <!-- Greeting -->
              <tr>
                <td style="padding:32px 24px 16px 24px;">
                  <p style="font-size:16px;color:#374151;margin:0;">
                    Hi #{escape_html(customer.name || "there")},
                  </p>
                  <p style="font-size:16px;color:#374151;margin:8px 0 0 0;">
                    Great news! Your order <strong>#{escape_html(order.order_number)}</strong> from
                    <strong>#{escape_html(store.name)}</strong> has been delivered.
                  </p>
                  <p style="font-size:16px;color:#374151;margin:8px 0 0 0;">
                    Thank you for shopping with us! We hope you love your purchase.
                  </p>
                </td>
              </tr>

              <!-- Order Summary -->
              <tr>
                <td style="padding:0 24px;">
                  <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;background-color:#f9fafb;border-radius:6px;padding:16px;">
                    <tr>
                      <td style="padding:12px 16px;">
                        <p style="font-size:13px;color:#6b7280;margin:0;text-transform:uppercase;letter-spacing:0.5px;">Order Number</p>
                        <p style="font-size:18px;color:#111827;margin:4px 0 0 0;font-weight:700;">#{escape_html(order.order_number)}</p>
                      </td>
                      <td style="padding:12px 16px;text-align:right;">
                        <p style="font-size:13px;color:#6b7280;margin:0;text-transform:uppercase;letter-spacing:0.5px;">Total</p>
                        <p style="font-size:18px;color:#111827;margin:4px 0 0 0;font-weight:700;">#{EmailHelpers.format_money(order.total, order.currency)}</p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              #{if line_items_html != "", do: line_items_section_html(line_items_html), else: ""}

              <!-- Review Prompt -->
              <tr>
                <td style="padding:24px;text-align:center;">
                  <p style="font-size:16px;color:#374151;margin:0 0 16px 0;">
                    How was your experience? We'd love to hear your feedback!
                  </p>
                  <a href="#{review_url}" style="display:inline-block;background-color:#d4a843;color:#1a1a2e;text-decoration:none;padding:14px 32px;border-radius:6px;font-size:16px;font-weight:600;">
                    Leave a Review
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

  defp delivered_text(order, customer, store) do
    line_items_text = build_line_items_text(order.line_items, order.currency)
    review_url = Canonical.path(store, "/orders/#{order.order_number}/review")
    whatsapp_url = EmailHelpers.whatsapp_link(store.whatsapp_number)

    """
    ORDER DELIVERED! — #{order.order_number}

    Hi #{customer.name || "there"},

    Great news! Your order #{order.order_number} from #{store.name} has been delivered.
    Thank you for shopping with us! We hope you love your purchase.

    Order Number: #{order.order_number}
    Total: #{EmailHelpers.format_money(order.total, order.currency)}
    #{if line_items_text != "", do: "\nITEMS\n#{line_items_text}", else: ""}
    How was your experience? Leave a review: #{review_url}

    ---
    #{store.name}
    #{if store.contact_email, do: "Email: #{store.contact_email}", else: ""}
    #{if store.contact_phone, do: "Phone: #{store.contact_phone}", else: ""}
    #{if whatsapp_url, do: "WhatsApp: #{whatsapp_url}", else: ""}
    """
    |> String.trim()
  end

  # ── HTML fragment builders ───────────────────────────────────────

  defp line_items_section_html(line_items_html) do
    """
    <tr>
      <td style="padding:24px;">
        <h2 style="font-size:16px;color:#111827;margin:0 0 12px 0;font-weight:600;">Items Delivered</h2>
        <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse;">
          <tr style="border-bottom:2px solid #e5e7eb;">
            <th style="text-align:left;padding:8px 0;font-size:12px;color:#6b7280;text-transform:uppercase;letter-spacing:0.5px;">Item</th>
            <th style="text-align:center;padding:8px 0;font-size:12px;color:#6b7280;text-transform:uppercase;letter-spacing:0.5px;">Qty</th>
            <th style="text-align:right;padding:8px 0;font-size:12px;color:#6b7280;text-transform:uppercase;letter-spacing:0.5px;">Price</th>
          </tr>
          #{line_items_html}
        </table>
      </td>
    </tr>
    """
  end

  defp build_line_items_html(line_items, currency)
       when is_list(line_items) and line_items != [] do
    Enum.map_join(line_items, "\n", fn item ->
      """
      <tr style="border-bottom:1px solid #f3f4f6;">
        <td style="padding:12px 0;">
          <p style="font-size:14px;color:#111827;margin:0;font-weight:500;">#{escape_html(item.product_title || item[:product_title])}</p>
        </td>
        <td style="padding:12px 0;text-align:center;font-size:14px;color:#374151;">#{item.quantity || item[:quantity]}</td>
        <td style="padding:12px 0;text-align:right;font-size:14px;color:#111827;font-weight:500;">#{EmailHelpers.format_money(item.line_total || item[:line_total], currency)}</td>
      </tr>
      """
    end)
  end

  defp build_line_items_html(_, _), do: ""

  defp build_line_items_text(line_items, currency)
       when is_list(line_items) and line_items != [] do
    Enum.map_join(line_items, "\n", fn item ->
      title = item.product_title || item[:product_title]
      qty = item.quantity || item[:quantity]
      total = EmailHelpers.format_money(item.line_total || item[:line_total], currency)
      "- #{title} x#{qty} = #{total}"
    end)
  end

  defp build_line_items_text(_, _), do: ""

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
