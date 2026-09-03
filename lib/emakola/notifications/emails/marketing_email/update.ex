defmodule Emakola.Notifications.Emails.MarketingEmail.Update do
  @moduledoc """
  Template D, "Newsletter and updates": one lead story, a few short items, one
  action. Used for announcements, newsletters and general updates.

  Assigns: `headline`, `body` (required); `update_type`, `month`,
  `lead_image_url`, `lead_image_alt`, `read_more_url`, `items`
  (`[%{title, line, url}]`), `action` (`%{headline, label, url}`),
  `unsubscribe_url` (optional).
  """

  import Emakola.Notifications.Emails.MarketingEmail

  @spec render(map()) :: String.t()
  def render(assigns) do
    rows =
      header_band(Map.get(assigns, :update_type, "Update"), Map.get(assigns, :month)) <>
        lead_rows(assigns) <>
        items_rows(Map.get(assigns, :items, [])) <>
        action_rows(Map.get(assigns, :action)) <>
        whatsapp_row("Reply to this email, or send a voice note.", "We read every one") <>
        footer_row([{"Past updates", static_url("/blog")}], Map.get(assigns, :unsubscribe_url))

    shell(rows, assigns.headline)
  end

  defp lead_rows(assigns) do
    """
    <tr><td style="padding: 28px 28px 0;">
    <p style="margin: 0; font-size: 12px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; color: #b98a1f;">The main thing</p>
    <p style="margin: 8px 0 0; font-size: 27px; font-weight: 700; line-height: 1.25; color: #0f172a;">#{escape(assigns.headline)}</p>
    </td></tr>
    #{lead_image(assigns)}
    <tr><td style="padding: 16px 28px 0;">
    <p style="margin: 0; font-size: 16px; line-height: 1.6; color: #475569;">#{paragraphs(assigns.body)}</p>
    #{read_more(Map.get(assigns, :read_more_url))}
    </td></tr>
    """
  end

  defp lead_image(%{lead_image_url: url} = assigns) when is_binary(url) do
    alt = Map.get(assigns, :lead_image_alt, "")

    """
    <tr><td style="padding: 18px 28px 0; line-height: 0;">
    <img src="#{escape(url)}" width="544" height="300" alt="#{escape(alt)}" style="display: block; width: 100%; height: auto; border-radius: 12px;">
    </td></tr>
    """
  end

  defp lead_image(_assigns), do: ""

  defp read_more(nil), do: ""

  defp read_more(url) do
    "<p style=\"margin: 12px 0 0; font-size: 15px; font-weight: 600;\"><a href=\"#{escape(url)}\" style=\"color: #b98a1f; text-decoration: none;\">Read the whole story &rarr;</a></p>"
  end

  defp items_rows([]), do: ""

  defp items_rows(items) do
    spacer =
      ~s(<tr><td colspan="2" style="height: 10px; font-size: 1px; line-height: 1px;">&nbsp;</td></tr>)

    rows = items |> Enum.map(&item_row/1) |> Enum.join(spacer)

    hairline() <>
      """
      <tr><td style="padding: 24px 28px 0;">
      <p style="margin: 0 0 14px; font-size: 12px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; color: #b98a1f;">Also this month</p>
      <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse: collapse;">#{rows}</table>
      </td></tr>
      """
  end

  defp item_row(item) do
    title =
      case Map.get(item, :url) do
        nil ->
          escape(item.title)

        url ->
          "<a href=\"#{escape(url)}\" style=\"color: #0f172a; text-decoration: none;\">#{escape(item.title)}</a>"
      end

    """
    <tr>
    <td width="6" style="width: 6px; background: #d4a843; border-radius: 10px 0 0 10px; font-size: 1px;">&nbsp;</td>
    <td style="padding: 14px 16px; background: #f8fafc; border-radius: 0 10px 10px 0; vertical-align: top;">
    <p style="margin: 0; font-size: 16px; font-weight: 600; color: #0f172a;">#{title}</p>
    <p style="margin: 3px 0 0; font-size: 14px; line-height: 1.5; color: #64748b;">#{escape(Map.get(item, :line))}</p>
    </td>
    </tr>
    """
  end

  defp action_rows(nil), do: ""

  defp action_rows(action) do
    headline =
      case Map.get(action, :headline) do
        nil ->
          ""

        text ->
          "<p style=\"margin: 8px 0 0; font-size: 19px; font-weight: 700; line-height: 1.35; color: #0f172a;\">#{escape(text)}</p>"
      end

    """
    <tr><td style="padding: 22px 28px 0;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background: #faf5e8; border: 1px solid #ecdcb8; border-radius: 12px;"><tr>
    <td style="padding: 20px 22px;">
    <p style="margin: 0; font-size: 12px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; color: #b98a1f;">Do this today</p>
    #{headline}
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin-top: 14px;"><tr>
    <td style="background: #d4a843; border-radius: 10px;"><a href="#{escape(action.url)}" style="display: block; padding: 14px 30px; font-size: 16px; font-weight: 700; color: #0c1526; text-decoration: none;">#{escape(action.label)}</a></td>
    </tr></table>
    </td>
    </tr></table>
    </td></tr>
    """
  end
end
