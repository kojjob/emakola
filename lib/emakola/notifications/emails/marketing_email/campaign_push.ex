defmodule Emakola.Notifications.Emails.MarketingEmail.CampaignPush do
  @moduledoc """
  Template C, "Campaign push": navy hero with the large lockup, a date pill,
  two photo tiles, one big button. For seasonal drives; use sparingly.

  Assigns: `campaign_name`, `headline`, `cta_label`, `cta_url` (required);
  `date_line`, `intro`, `tiles` (`[%{image_url, title, line}]`), `note`,
  `unsubscribe_url` (optional).
  """

  import Emakola.Notifications.Emails.MarketingEmail

  @spec render(map()) :: String.t()
  def render(assigns) do
    rows =
      hero_rows(assigns) <>
        intro_row(Map.get(assigns, :intro)) <>
        tiles_rows(Map.get(assigns, :tiles, [])) <>
        button_row(assigns.cta_label, assigns.cta_url, nil, "28px 28px 0") <>
        note_rows(Map.get(assigns, :note)) <>
        footer_row([{assigns.cta_label, assigns.cta_url}], Map.get(assigns, :unsubscribe_url))

    shell(rows, assigns.headline)
  end

  defp hero_rows(assigns) do
    date_pill =
      case Map.get(assigns, :date_line) do
        nil ->
          ""

        text ->
          """
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin-top: 20px;"><tr>
          <td style="background: #d4a843; border-radius: 999px; padding: 8px 18px; font-size: 14px; font-weight: 700; color: #0c1526;">#{escape(text)}</td>
          </tr></table>
          """
      end

    """
    <tr><td style="background: #0c1526; padding: 34px 32px 36px; text-align: center;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center"><tr>
    <td style="padding-right: 12px; vertical-align: middle;"><img src="#{static_url("/images/email/cowrie-coin.png")}" width="44" height="44" alt="" style="display: block; width: 44px; height: 44px;"></td>
    <td style="vertical-align: middle; font-size: 26px; font-weight: 700; color: #f1f5f9;">Makola<span style="color: #d4a843;">.io</span></td>
    </tr></table>
    <p style="margin: 28px 0 0; font-size: 12px; font-weight: 700; letter-spacing: .14em; text-transform: uppercase; color: #d4a843;">#{escape(assigns.campaign_name)}</p>
    <p style="margin: 12px 0 0; font-size: 38px; font-weight: 700; line-height: 1.15; color: #ffffff;">#{escape(assigns.headline)}</p>
    #{date_pill}
    </td></tr>
    """
  end

  defp intro_row(nil), do: ""

  defp intro_row(text) do
    "<tr><td style=\"padding: 30px 28px 0; text-align: center;\"><p style=\"margin: 0; font-size: 17px; line-height: 1.6; color: #475569;\">#{escape(text)}</p></td></tr>"
  end

  defp tiles_rows([]), do: ""

  defp tiles_rows(tiles) do
    cells =
      tiles
      |> Enum.with_index(1)
      |> Enum.map(&tile_cell/1)
      |> Enum.join(~s(<td width="10" style="width: 10px; font-size: 1px;">&nbsp;</td>))

    """
    <tr><td style="padding: 22px 28px 0;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse: collapse;"><tr>#{cells}</tr></table>
    </td></tr>
    """
  end

  defp tile_cell({tile, index}) do
    image =
      case Map.get(tile, :image_url) do
        nil ->
          ""

        url ->
          "<img src=\"#{escape(url)}\" width=\"267\" height=\"178\" alt=\"\" style=\"display: block; width: 100%; height: auto; border-radius: 12px 12px 0 0;\">"
      end

    """
    <td width="50%" style="background: #f8fafc; border-radius: 12px; vertical-align: top;">
    #{image}
    <div style="padding: 16px 16px 18px;">
    <p style="margin: 0; font-size: 12px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; color: #b98a1f;">#{ordinal(index)}</p>
    <p style="margin: 6px 0 0; font-size: 17px; font-weight: 700; line-height: 1.35; color: #0f172a;">#{escape(tile.title)}</p>
    <p style="margin: 6px 0 0; font-size: 14px; line-height: 1.5; color: #64748b;">#{escape(Map.get(tile, :line))}</p>
    </div>
    </td>
    """
  end

  defp ordinal(1), do: "One"
  defp ordinal(2), do: "Two"
  defp ordinal(3), do: "Three"
  defp ordinal(n), do: Integer.to_string(n)

  defp note_rows(nil), do: ""

  defp note_rows(text) do
    """
    <tr><td style="padding: 26px 28px 30px;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background: #faf5e8; border: 1px solid #ecdcb8; border-radius: 10px;"><tr>
    <td style="padding: 16px 18px;">
    <p style="margin: 0; font-size: 15px; font-weight: 600; color: #3f3418;">#{escape(text)}</p>
    <p style="margin: 3px 0 0; font-size: 14px; color: #7a6425;">Questions? <a href="#{support_whatsapp_url()}" style="color: #7a6425;">WhatsApp us</a></p>
    </td>
    </tr></table>
    </td></tr>
    """
  end
end
