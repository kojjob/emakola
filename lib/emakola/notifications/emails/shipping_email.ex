defmodule Emakola.Notifications.Emails.ShippingEmail do
  @moduledoc """
  Shipping notification email builder.

  Generates an HTML email with plain text fallback for order shipment
  notifications. Includes tracking information, estimated delivery,
  and delivery address.
  """

  import Swoosh.Email
  alias Emakola.Notifications.Emails.EmailHelpers

  @doc """
  Builds an order shipped notification email.

  ## Parameters
    - `order` — Order struct/map with :order_number, :shipping_address
    - `customer` — Customer struct/map with :name, :email
    - `store` — Store struct/map with :name, :slug, :contact_email, etc.
    - `tracking_info` — Map with :carrier, :tracking_number, :tracking_url,
      :estimated_delivery

  ## Returns
    A `%Swoosh.Email{}` ready for `Emakola.Mailer.deliver/1`.
  """
  def order_shipped(order, customer, store, tracking_info) do
    new()
    |> to({customer.name || "", to_string(customer.email)})
    |> from(EmailHelpers.from_address(store))
    |> subject("Your Order #{order.order_number} Has Shipped!")
    |> html_body(shipped_html(order, customer, store, tracking_info))
    |> text_body(shipped_text(order, customer, store, tracking_info))
  end

  # ── HTML template ────────────────────────────────────────────────

  defp shipped_html(order, customer, store, tracking_info) do
    address_html = build_address_html(order.shipping_address)
    whatsapp_url = EmailHelpers.whatsapp_link(store.whatsapp_number)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Order Shipped</title>
    </head>
    <body style="margin:0;padding:0;background-color:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
      <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;background-color:#f4f4f5;">
        <tr>
          <td align="center" style="padding:24px 16px;">
            <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.1);">

              <!-- Header -->
              <tr>
                <td style="background-color:#059669;padding:32px 24px;text-align:center;">
                  #{logo_html(store)}
                  <h1 style="color:#ffffff;font-size:24px;margin:8px 0 0 0;font-weight:600;">Your Order Has Shipped! 📦</h1>
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
                    <strong>#{escape_html(store.name)}</strong> is on its way to you.
                  </p>
                </td>
              </tr>

              <!-- Tracking Info -->
              <tr>
                <td style="padding:0 24px 24px 24px;">
                  <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;background-color:#ecfdf5;border-radius:6px;border:1px solid #a7f3d0;">
                    <tr>
                      <td style="padding:20px;">
                        <h2 style="font-size:16px;color:#065f46;margin:0 0 12px 0;font-weight:600;">Tracking Information</h2>

                        <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;">
                          <tr>
                            <td style="padding:4px 0;font-size:13px;color:#6b7280;width:140px;">Carrier</td>
                            <td style="padding:4px 0;font-size:14px;color:#111827;font-weight:500;">#{escape_html(tracking_info.carrier || tracking_info[:carrier])}</td>
                          </tr>
                          <tr>
                            <td style="padding:4px 0;font-size:13px;color:#6b7280;">Tracking Number</td>
                            <td style="padding:4px 0;font-size:14px;color:#111827;font-weight:500;font-family:monospace;">#{escape_html(tracking_info.tracking_number || tracking_info[:tracking_number])}</td>
                          </tr>
                          #{estimated_delivery_html(tracking_info)}
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              #{tracking_button_html(tracking_info)}

              #{address_html}

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

  defp shipped_text(order, customer, store, tracking_info) do
    address_text = build_address_text(order.shipping_address)
    whatsapp_url = EmailHelpers.whatsapp_link(store.whatsapp_number)
    tracking_url = tracking_info.tracking_url || tracking_info[:tracking_url]
    estimated = tracking_info.estimated_delivery || tracking_info[:estimated_delivery]

    """
    YOUR ORDER HAS SHIPPED! — #{order.order_number}

    Hi #{customer.name || "there"},

    Great news! Your order #{order.order_number} from #{store.name} is on its way to you.

    TRACKING INFORMATION
    Carrier: #{tracking_info.carrier || tracking_info[:carrier]}
    Tracking Number: #{tracking_info.tracking_number || tracking_info[:tracking_number]}
    #{if tracking_url, do: "Track your package: #{tracking_url}", else: ""}
    #{if estimated, do: "Estimated Delivery: #{estimated}", else: ""}
    #{address_text}
    ---
    #{store.name}
    #{if store.contact_email, do: "Email: #{store.contact_email}", else: ""}
    #{if store.contact_phone, do: "Phone: #{store.contact_phone}", else: ""}
    #{if whatsapp_url, do: "WhatsApp: #{whatsapp_url}", else: ""}
    """
    |> String.trim()
  end

  # ── HTML fragment builders ───────────────────────────────────────

  defp estimated_delivery_html(tracking_info) do
    estimated = tracking_info.estimated_delivery || tracking_info[:estimated_delivery]

    if estimated do
      """
      <tr>
        <td style="padding:4px 0;font-size:13px;color:#6b7280;">Estimated Delivery</td>
        <td style="padding:4px 0;font-size:14px;color:#111827;font-weight:500;">#{escape_html(estimated)}</td>
      </tr>
      """
    else
      ""
    end
  end

  defp tracking_button_html(tracking_info) do
    url = tracking_info.tracking_url || tracking_info[:tracking_url]

    if url do
      """
      <tr>
        <td style="padding:0 24px 24px 24px;text-align:center;">
          <a href="#{escape_html(url)}" style="display:inline-block;background-color:#059669;color:#ffffff;text-decoration:none;padding:14px 32px;border-radius:6px;font-size:16px;font-weight:600;">
            Track Your Package
          </a>
        </td>
      </tr>
      """
    else
      ""
    end
  end

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
          <h2 style="font-size:16px;color:#111827;margin:0 0 8px 0;font-weight:600;">Delivering To</h2>
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

      DELIVERING TO
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
