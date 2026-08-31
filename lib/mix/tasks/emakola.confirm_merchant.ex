defmodule Mix.Tasks.Emakola.ConfirmMerchant do
  @shortdoc "Marks a merchant's email verified, by hand"

  @moduledoc """
  Break-glass for a merchant who cannot get past the verification gate.

      mix emakola.confirm_merchant kwame@kentekingdom.com

  Access is gated on a verified address, which means email delivery is now
  load-bearing for sign-in. Production once ran three weeks on a deleted mail
  key without anyone noticing; if that happens again, this is how a locked-out
  merchant gets back in without a database console.

  Use it when you have verified the person some other way — they called, you
  know the shop. It is not a substitute for the emailed link.
  """

  use Mix.Task

  require Ash.Query

  @impl Mix.Task
  def run([email]) do
    Mix.Task.run("app.start")

    case find(email) do
      nil ->
        Mix.shell().error("No merchant with that email: #{email}")
        exit({:shutdown, 1})

      %{confirmed_at: %DateTime{} = at} = merchant ->
        Mix.shell().info("#{merchant.email} was already verified on #{DateTime.to_date(at)}")

      merchant ->
        merchant
        |> Ash.Changeset.for_update(:update_profile, %{})
        |> Ash.Changeset.force_change_attribute(:confirmed_at, DateTime.utc_now())
        |> Ash.update!(authorize?: false)

        Mix.shell().info("Verified #{merchant.email} — they can sign in now.")
    end
  end

  def run(_args) do
    Mix.shell().error("Usage: mix emakola.confirm_merchant <email>")
    exit({:shutdown, 1})
  end

  defp find(email) do
    Emakola.Accounts.Merchant
    |> Ash.Query.filter(email == ^String.downcase(String.trim(email)))
    |> Ash.read_one!(authorize?: false)
  end
end
