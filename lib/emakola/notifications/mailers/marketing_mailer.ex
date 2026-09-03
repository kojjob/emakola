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
