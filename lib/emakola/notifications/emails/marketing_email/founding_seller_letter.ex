defmodule Emakola.Notifications.Emails.MarketingEmail.FoundingSellerLetter do
  @moduledoc """
  Template B, "Founding Seller letter": reads like a personal note from the
  founder, a gold box of what founding sellers get, WhatsApp as the only action.

  Assigns: `first_name`, `sender_name` (required); `intro` (list of paragraphs),
  `benefits` (list), `honest_line`, `sender_role`, `reply_time`, `unsubscribe_url`
  (optional).
  """

  import Emakola.Notifications.Emails.MarketingEmail

  @default_intro [
    "I am building shops for a small group of sellers who take orders on WhatsApp and Instagram. You send me photos and prices. I build the shop. You share one link.",
    "There is no monthly fee. If you do not sell, we earn nothing."
  ]
  @default_benefits [
    "Your shop built for you",
    "The lowest fee we will ever charge, locked in for good",
    "Your customers and your data stay yours"
  ]

  @spec render(map()) :: String.t()
  def render(assigns) do
    rows =
      header_band("Founding Seller") <>
        gold_rule() <>
        letter_rows(assigns) <>
        benefits_rows(Map.get(assigns, :benefits, @default_benefits)) <>
        honest_row(Map.get(assigns, :honest_line)) <>
        whatsapp_button_rows(assigns) <>
        signature_rows(assigns) <>
        footer_row([], Map.get(assigns, :unsubscribe_url))

    shell(rows, "Free shop, set up for you.")
  end

  defp letter_rows(assigns) do
    paragraphs =
      assigns
      |> Map.get(:intro, @default_intro)
      |> Enum.map_join("", fn text ->
        "<p style=\"margin: 14px 0 0; font-size: 17px; line-height: 1.65; color: #334155;\">#{escape(text)}</p>"
      end)

    """
    <tr><td style="padding: 28px 32px 0;">
    <p style="margin: 0; font-size: 30px; font-weight: 700; line-height: 1.25; color: #0f172a;">Free shop, set up for you.</p>
    <p style="margin: 18px 0 0; font-size: 17px; line-height: 1.65; color: #334155;">Hi #{escape(assigns.first_name)},</p>
    #{paragraphs}
    </td></tr>
    """
  end

  defp benefits_rows(benefits) do
    items =
      Enum.map_join(benefits, "", fn text ->
        """
        <tr>
        <td width="32" style="width: 32px; vertical-align: top; padding: 4px 0 8px; font-size: 18px; font-weight: 700; color: #b98a1f;">&#10003;</td>
        <td style="padding: 4px 0 8px; font-size: 16px; line-height: 1.5; color: #3f3418;">#{escape(text)}</td>
        </tr>
        """
      end)

    """
    <tr><td style="padding: 22px 32px 0;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background: #faf5e8; border: 1px solid #ecdcb8; border-radius: 12px;"><tr>
    <td style="padding: 18px 20px 12px;">
    <p style="margin: 0 0 8px; font-size: 12px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; color: #b98a1f;">What founding sellers get</p>
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse: collapse;">#{items}</table>
    </td>
    </tr></table>
    </td></tr>
    """
  end

  defp honest_row(nil), do: ""

  defp honest_row(text) do
    "<tr><td style=\"padding: 20px 32px 0;\"><p style=\"margin: 0; font-size: 15px; line-height: 1.6; color: #64748b;\">#{escape(text)}</p></td></tr>"
  end

  defp whatsapp_button_rows(assigns) do
    reply_time = Map.get(assigns, :reply_time, "a day")

    """
    <tr><td style="padding: 26px 32px 0;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
    <td style="background: #25d366; border-radius: 10px;"><a href="#{support_whatsapp_url()}" style="display: block; padding: 16px 28px; font-size: 17px; font-weight: 700; color: #0c1526; text-decoration: none;">Message me on WhatsApp</a></td>
    </tr></table>
    <p style="margin: 12px 0 0; font-size: 14px; color: #64748b;">Send your shop name and what you sell. I reply within #{escape(reply_time)}.</p>
    </td></tr>
    """
  end

  defp signature_rows(assigns) do
    role = Map.get(assigns, :sender_role, "Founder, Makola.io")

    """
    <tr><td style="padding: 30px 32px 30px;">
    <p style="margin: 0; font-size: 16px; font-weight: 700; color: #0f172a;">#{escape(assigns.sender_name)}</p>
    <p style="margin: 2px 0 0; font-size: 14px; color: #64748b;">#{escape(role)}</p>
    </td></tr>
    """
  end
end
