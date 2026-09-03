defmodule Emakola.Notifications.Emails.MarketingEmail.PictureFirst do
  @moduledoc """
  Template A, "Picture first": one real photo, one short headline, one button,
  three steps, a WhatsApp fallback. The default marketing email.

  Assigns: `headline`, `body`, `cta_label`, `cta_url` (required);
  `hero_url`, `hero_alt`, `steps`, `note`, `unsubscribe_url` (optional).
  """

  import Emakola.Notifications.Emails.MarketingEmail

  @default_hero "/images/landing/hero-market-woman.jpg"
  @default_steps ["Add a photo", "Share the link", "Get the order"]

  @spec render(map()) :: String.t()
  def render(assigns) do
    rows =
      header_band("For people who sell") <>
        hero_row(assigns) <>
        gold_rule() <>
        headline_row(assigns) <>
        button_row(assigns.cta_label, assigns.cta_url, Map.get(assigns, :note, "No monthly fee.")) <>
        hairline() <>
        steps_row(Map.get(assigns, :steps, @default_steps)) <>
        whatsapp_row("Rather talk than read?", "Send a voice note") <>
        footer_row([{"See a shop", static_url("/stores")}], Map.get(assigns, :unsubscribe_url))

    shell(rows, assigns.headline)
  end

  defp hero_row(assigns) do
    url = Map.get(assigns, :hero_url) || static_url(@default_hero)
    alt = Map.get(assigns, :hero_alt, "A seller on the phone at her stall")

    """
    <tr><td style="padding: 0; line-height: 0;">
    <img src="#{escape(url)}" width="600" height="338" alt="#{escape(alt)}" style="display: block; width: 100%; height: auto;">
    </td></tr>
    """
  end

  defp headline_row(assigns) do
    """
    <tr><td style="padding: 32px 28px 0; text-align: center;">
    <p style="margin: 0; font-size: 34px; font-weight: 700; line-height: 1.2; color: #0f172a;">#{escape(assigns.headline)}</p>
    <p style="margin: 14px 0 0; font-size: 17px; line-height: 1.6; color: #475569;">#{escape(assigns.body)}</p>
    </td></tr>
    """
  end

  defp steps_row(steps) do
    cells =
      steps
      |> Enum.map(&step_cell/1)
      |> Enum.join(~s(<td width="8" style="width: 8px; font-size: 1px;">&nbsp;</td>))

    """
    <tr><td style="padding: 26px 28px 0;">
    <p style="margin: 0 0 16px; font-size: 12px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; color: #b98a1f; text-align: center;">How it works</p>
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse: collapse;"><tr>#{cells}</tr></table>
    </td></tr>
    """
  end

  defp step_cell(label) do
    """
    <td width="33%" style="background: #f8fafc; border-radius: 12px; padding: 22px 14px; text-align: center; vertical-align: top;">
    <p style="margin: 0; font-size: 15px; font-weight: 600; color: #0f172a; line-height: 1.4;">#{escape(label)}</p>
    </td>
    """
  end
end
