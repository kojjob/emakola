defmodule Emakola.Notifications.MarketingMailer do
  @moduledoc """
  Sends the two marketing templates (`MarketingEmail.picture_first/1` and
  `MarketingEmail.update/1`) with a plain-text fallback. The subject defaults
  to the headline.
  """
  import Swoosh.Email

  alias Emakola.Mailer
  alias Emakola.Notifications.Emails.MarketingEmail

  @spec deliver_picture_first(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def deliver_picture_first(to_address, assigns) do
    deliver(
      to_address,
      assigns,
      MarketingEmail.picture_first(assigns),
      picture_first_text(assigns)
    )
  end

  @spec deliver_update(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def deliver_update(to_address, assigns) do
    deliver(to_address, assigns, MarketingEmail.update(assigns), update_text(assigns))
  end

  @spec deliver_founding_seller_letter(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def deliver_founding_seller_letter(to_address, assigns) do
    assigns = Map.put_new(assigns, :headline, "Free shop, set up for you.")

    deliver(
      to_address,
      assigns,
      MarketingEmail.founding_seller_letter(assigns),
      founding_seller_text(assigns)
    )
  end

  @spec deliver_campaign_push(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def deliver_campaign_push(to_address, assigns) do
    deliver(to_address, assigns, MarketingEmail.campaign_push(assigns), campaign_text(assigns))
  end

  defp deliver(to_address, assigns, html, text) do
    new()
    |> to(to_address)
    |> from(Mailer.from_address("Makola.io"))
    |> subject(Map.get(assigns, :subject) || assigns.headline)
    |> html_body(html)
    |> text_body(text)
    |> Mailer.deliver()
  end

  defp picture_first_text(assigns) do
    """
    #{assigns.headline}

    #{assigns.body}

    #{assigns.cta_label}: #{assigns.cta_url}

    Makola.io - Accra, Ghana
    """
  end

  defp founding_seller_text(assigns) do
    """
    Hi #{assigns.first_name},

    Free shop, set up for you. You send photos and prices, I build the shop, you share one link. No monthly fee.

    #{Map.get(assigns, :honest_line, "")}

    Message me on WhatsApp: #{MarketingEmail.support_whatsapp_url()}

    #{assigns.sender_name}, #{Map.get(assigns, :sender_role, "Founder, Makola.io")}
    """
  end

  defp campaign_text(assigns) do
    tiles =
      assigns
      |> Map.get(:tiles, [])
      |> Enum.map_join("\n", fn tile -> "- #{tile.title}: #{Map.get(tile, :line)}" end)

    """
    #{assigns.campaign_name}: #{assigns.headline}
    #{Map.get(assigns, :date_line, "")}

    #{tiles}

    #{assigns.cta_label}: #{assigns.cta_url}

    Makola.io - Accra, Ghana
    """
  end

  defp update_text(assigns) do
    items =
      assigns
      |> Map.get(:items, [])
      |> Enum.map_join("\n", fn item -> "- #{item.title}: #{Map.get(item, :line)}" end)

    action =
      case Map.get(assigns, :action) do
        nil -> ""
        %{label: label, url: url} -> "\n#{label}: #{url}\n"
      end

    """
    #{assigns.headline}

    #{assigns.body}

    #{items}
    #{action}
    Makola.io - Accra, Ghana
    """
  end
end
