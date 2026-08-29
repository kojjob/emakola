defmodule Emakola.Stores.Workers.DirectoryRankingWorker.DropEmail do
  @moduledoc """
  Tells a merchant their shop left the featured rails, and how to return.

  Sent only on the eligible → ineligible transition. Staying ineligible is
  not news, and a shop that was never eligible has nothing to lose — the
  nightly run stays silent for both. A demotion with reasons attached is a
  to-do list; a silent one is a support ticket.

  Follows the low-stock alert's shape: plain text, one action, sent to the
  store's owner (falling back to the store contact email), and a delivery
  failure never fails the ranking run.
  """

  import Swoosh.Email

  require Ash.Query
  require Logger

  alias Emakola.Accounts.StoreMembership

  @reasons %{
    abandoned: "Nothing new sold or listed for a while",
    incomplete: "Your shop page is missing photo, words or contact",
    no_payout: "Your MoMo payout needs setting up again",
    conduct: "A problem on your account needs resolving"
  }

  def send_drop(store, disqualifiers) do
    case recipient(store) do
      nil ->
        Logger.warning("[directory.drop_email] no recipient for store=#{store.id}")
        :ok

      {name, email} ->
        new()
        |> to({name, email})
        |> from({"Makola.io", "noreply@makola.io"})
        |> subject("#{store.name} left the featured shops — here is how to get back")
        |> text_body(body(store, disqualifiers))
        |> Emakola.Mailer.deliver()
        |> case do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning("[directory.drop_email] delivery failed: #{inspect(reason)}")
        end
    end
  rescue
    exception ->
      Logger.error("[directory.drop_email] raised: #{Exception.message(exception)}")
      :ok
  end

  defp body(store, disqualifiers) do
    reasons =
      disqualifiers
      |> Enum.map(&Map.get(@reasons, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.map_join("\n", &("  - " <> &1))

    """
    Hello,

    #{store.name} is no longer in the featured shops on Makola.io.
    Nothing else changed — your shop is still open and still selling.

    What changed:

    #{reasons}

    Fix the items above and the nightly check brings you back
    automatically. Your dashboard shows the same list:

    https://makola.io/admin

    Questions? Reply to this email or message us on WhatsApp.

    — Makola.io
    """
  end

  defp recipient(store) do
    owner =
      StoreMembership
      |> Ash.Query.filter(store_id == ^store.id and role == :owner)
      |> Ash.Query.load(:merchant)
      |> Ash.read!(authorize?: false)
      |> List.first()

    cond do
      owner && owner.merchant && owner.merchant.email ->
        {owner.merchant.name || to_string(owner.merchant.email), to_string(owner.merchant.email)}

      store.contact_email ->
        {store.name, store.contact_email}

      true ->
        nil
    end
  end
end
