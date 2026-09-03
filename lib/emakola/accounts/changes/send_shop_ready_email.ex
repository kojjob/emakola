defmodule Emakola.Accounts.Changes.SendShopReadyEmail do
  @moduledoc """
  After a merchant confirms their email, send the picture-first marketing
  email: one photo, five words, one button into their shop.

  Registration sends exactly one email, the confirmation (#597). This is the
  next moment, once the address is proven, so it never doubles up. Best-effort:
  a mail provider being down must never make a confirmation fail.
  """
  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, merchant ->
      send_shop_ready(merchant)
      {:ok, merchant}
    end)
  end

  # Only an after-action hook is added, so the update itself stays atomic.
  @impl true
  def atomic(changeset, opts, context), do: {:ok, change(changeset, opts, context)}

  @doc "The email itself, so a mailer test and this change agree on the copy."
  def assigns do
    %{
      subject: "Your shop is ready to set up",
      headline: "Your shop. One link. Free.",
      body:
        "Your email is confirmed. Customers pick what they want and order from your link. Set yours up in a few minutes.",
      cta_label: "Set up my shop",
      cta_url: EmakolaWeb.Endpoint.url() <> "/admin"
    }
  end

  defp send_shop_ready(merchant) do
    case Emakola.Notifications.MarketingMailer.deliver_picture_first(
           to_string(merchant.email),
           assigns()
         ) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("[accounts] shop-ready email not sent: #{inspect(reason)}")
    end
  rescue
    exception ->
      Logger.error("[accounts] shop-ready email raised: #{Exception.message(exception)}")
  end
end
