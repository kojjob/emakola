defmodule Emakola.Payments.PayoutService do
  @moduledoc """
  Prepares a merchant payout — the decision half of the payout-execution engine.

  `prepare_payout/1` resolves a MoMo transfer destination, gathers the store's
  outstanding un-split (`split_mode: :none`) successful payments, creates a
  pending `Payout` for their sum, and stamps each covered payment (`paid_out_at`,
  `payout_id`) so it leaves the backlog and can never be paid twice. The actual
  gateway transfer is executed asynchronously by `Workers.PayoutWorker`.
  """
  alias Emakola.Payments
  alias Emakola.Payments.Payment
  alias Emakola.Stores

  # Paystack Ghana mobile-money telco codes (List Banks, type: mobile_money).
  @provider_codes %{"mtn" => "MTN", "vodafone" => "VOD", "airteltigo" => "ATL"}

  @doc """
  Resolve a usable MoMo transfer destination for a store, or `{:error,
  :no_momo_destination}` if none is configured. Shaped for
  `gateway.create_transfer_recipient/1`.
  """
  def transfer_destination(store_id) do
    with {:ok, %{payout_destination: %{"method" => "mobile_money"} = dest}} <-
           Stores.get_payout_account(store_id, authorize?: false, not_found_error?: false),
         bank_code when is_binary(bank_code) <- @provider_codes[dest["provider"]],
         number when is_binary(number) <- dest["number"] do
      {:ok,
       %{
         type: "mobile_money",
         name: dest["account_name"] || "",
         account_number: number,
         bank_code: bank_code,
         currency: "GHS"
       }}
    else
      _ -> {:error, :no_momo_destination}
    end
  end

  @doc "A store's outstanding un-split successful payments (the manual-payout backlog)."
  def outstanding_payments(store_id) do
    # "Outstanding" is defined once, on the resource — see
    # Payment.outstanding_for_payout.
    Payment
    |> Ash.Query.for_read(:outstanding_for_payout, %{store_id: store_id})
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Create a pending payout for a store's outstanding balance and stamp the covered
  payments. Returns `{:ok, payout}`, `{:error, :no_momo_destination}` or
  `{:error, :nothing_outstanding}` (validating the destination first so nothing is
  stamped when a payout can't be made).
  """
  def prepare_payout(store_id) do
    with {:ok, _dest} <- transfer_destination(store_id) do
      # One transaction with a row lock on the outstanding payments is the
      # serialization point: a concurrent approval blocks on `FOR UPDATE`, then
      # re-reads the now-stamped rows as empty — so the same balance can never be
      # claimed by two payouts (no double-pay).
      Emakola.Repo.transaction(fn ->
        payments =
          Payment
          |> Ash.Query.for_read(:outstanding_for_payout, %{store_id: store_id})
          |> Ash.Query.lock("FOR UPDATE")
          |> Ash.read!(authorize?: false)

        # Pay one currency per payout (stores are single-currency in practice);
        # take the currency of the claimed set rather than summing across currencies.
        currency = payments |> List.first(%{}) |> Map.get(:currency, "GHS")
        claimed = Enum.filter(payments, &(&1.currency == currency))

        if claimed == [] do
          Emakola.Repo.rollback(:nothing_outstanding)
        end

        amount = claimed |> Enum.map(& &1.amount) |> Enum.sum()
        reference = "po_" <> Ecto.UUID.generate()

        {:ok, payout} =
          Payments.create_payout(
            %{
              store_id: store_id,
              amount: amount,
              currency: currency,
              transfer_reference: reference
            },
            authorize?: false
          )

        Enum.each(claimed, fn payment ->
          {:ok, _} =
            Payments.mark_payment_paid_out(payment, %{payout_id: payout.id}, authorize?: false)
        end)

        payout
      end)
    else
      {:error, :no_momo_destination} = err -> err
    end
  end
end
