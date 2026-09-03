defmodule Emakola.Notifications.Emails.MarketingEmail do
  @moduledoc """
  Marketing emails on the Makola.io brand chassis: a 600px white card, navy
  header band with the Cowrie Coin, gold button, dark footer.

  Four templates, all picture-first for merchants who read slowly:

    * `picture_first/1` — one photo, one short headline, one button, three steps.
      The default.
    * `update/1` — one lead story, a few short items, one action. Used for
      newsletters, announcements and general updates.
    * `founding_seller_letter/1` — a personal note from the founder with
      WhatsApp as the only action, for outreach to the first sellers.
    * `campaign_push/1` — navy hero, date pill, two photo tiles, one big button,
      for seasonal drives.

  Everything is table layout with spacer cells (no `border-spacing`, no bare
  `div` rules) so it survives Outlook. Copy is escaped; facts arrive as assigns.
  """

  alias __MODULE__.{CampaignPush, FoundingSellerLetter, PictureFirst, Update}

  @font "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"

  @spec picture_first(map()) :: String.t()
  def picture_first(assigns), do: PictureFirst.render(assigns)

  @spec update(map()) :: String.t()
  def update(assigns), do: Update.render(assigns)

  @spec founding_seller_letter(map()) :: String.t()
  def founding_seller_letter(assigns), do: FoundingSellerLetter.render(assigns)

  @spec campaign_push(map()) :: String.t()
  def campaign_push(assigns), do: CampaignPush.render(assigns)

  # ── Chassis ─────────────────────────────────────────────────────

  @doc "Wraps card rows in the full email document."
  def shell(rows, title) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>#{escape(title)}</title>
    </head>
    <body style="margin: 0; padding: 0; background: #f4f1e9;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background: #f4f1e9;">
    <tr><td align="center" style="padding: 32px 16px 40px; font-family: #{@font};">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="width: 600px; max-width: 100%; border-collapse: collapse; background: #ffffff; border-radius: 12px; overflow: hidden;">
    #{rows}
    </table>
    </td></tr>
    </table>
    </body>
    </html>
    """
  end

  @doc "Navy band with the coin lockup on the left and a gold eyebrow on the right."
  def header_band(eyebrow, right_line \\ nil) do
    right =
      if right_line,
        do:
          "<p style=\"margin: 4px 0 0; font-size: 13px; color: #8896ab;\">#{escape(right_line)}</p>",
        else: ""

    """
    <tr><td style="background: #0c1526; padding: 18px 26px;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"><tr>
    <td style="vertical-align: middle;">#{logo_lockup()}</td>
    <td align="right" style="vertical-align: middle;">
    <p style="margin: 0; font-size: 12px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; color: #d4a843;">#{escape(eyebrow)}</p>
    #{right}
    </td>
    </tr></table>
    </td></tr>
    """
  end

  def logo_lockup do
    """
    <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
    <td style="padding-right: 10px; vertical-align: middle;"><img src="#{static_url("/images/email/cowrie-coin.png")}" width="28" height="28" alt="" style="display: block; width: 28px; height: 28px;"></td>
    <td style="vertical-align: middle; font-size: 18px; font-weight: 700; color: #f1f5f9; font-family: #{@font};">Makola<span style="color: #d4a843;">.io</span></td>
    </tr></table>
    """
  end

  def gold_rule,
    do:
      ~s(<tr><td style="background: #d4a843; height: 5px; font-size: 1px; line-height: 1px;">&nbsp;</td></tr>)

  def hairline do
    """
    <tr><td style="padding: 28px 28px 0;"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"><tr>
    <td style="height: 1px; background: #e2e8f0; font-size: 1px; line-height: 1px;">&nbsp;</td></tr></table></td></tr>
    """
  end

  @doc "Centered gold button. `note` is an optional grey line under it."
  def button_row(label, url, note \\ nil, padding \\ "24px 28px 0") do
    note_html =
      if note,
        do: "<p style=\"margin: 12px 0 0; font-size: 14px; color: #64748b;\">#{escape(note)}</p>",
        else: ""

    """
    <tr><td align="center" style="padding: #{padding};">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
    <td style="background: #d4a843; border-radius: 10px;"><a href="#{escape(url)}" style="display: block; padding: 16px 44px; font-size: 17px; font-weight: 700; color: #0c1526; text-decoration: none; font-family: #{@font};">#{escape(label)}</a></td>
    </tr></table>
    #{note_html}
    </td></tr>
    """
  end

  @doc "wa.me link for the platform support number."
  def support_whatsapp_url do
    number = Application.get_env(:emakola, :support_whatsapp)
    "https://wa.me/#{String.replace(to_string(number), ~r/[^0-9]/, "")}"
  end

  @doc "Green box pointing at the platform WhatsApp number."
  def whatsapp_row(title, line) do
    url = support_whatsapp_url()

    """
    <tr><td style="padding: 26px 28px 30px;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 10px;"><tr>
    <td style="padding: 16px 18px; vertical-align: middle;">
    <p style="margin: 0; font-size: 15px; font-weight: 600; color: #14532d;">#{escape(title)}</p>
    <p style="margin: 3px 0 0; font-size: 14px; color: #166534;">#{escape(line)} &mdash; <a href="#{url}" style="color: #166534;">WhatsApp</a></p>
    </td>
    </tr></table>
    </td></tr>
    """
  end

  @doc "Dark footer. Links are `{label, url}` pairs; the unsubscribe link is added when given."
  def footer_row(links, unsubscribe_url) do
    all_links =
      if unsubscribe_url, do: links ++ [{"Stop these emails", unsubscribe_url}], else: links

    link_html =
      all_links
      |> Enum.map(fn {label, url} ->
        "<a href=\"#{escape(url)}\" style=\"color: #8896ab;\">#{escape(label)}</a>"
      end)
      |> Enum.join(" &nbsp;&middot;&nbsp; ")

    """
    <tr><td style="background: #0c1526; padding: 22px 28px; text-align: center;">
    <p style="margin: 0; font-size: 13px; color: #8896ab;">Makola.io &middot; Accra, Ghana</p>
    <p style="margin: 8px 0 0; font-size: 12px; color: #64748b;">#{link_html}</p>
    </td></tr>
    """
  end

  # ── Text helpers ────────────────────────────────────────────────

  def escape(nil), do: ""

  def escape(value) do
    value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end

  @doc "Escapes, then turns newlines into `<br>` so plain announcement bodies keep their breaks."
  def paragraphs(text), do: text |> escape() |> String.replace(~r/\r?\n/, "<br>")

  def static_url(path), do: EmakolaWeb.Endpoint.url() <> path

  def font, do: @font
end
