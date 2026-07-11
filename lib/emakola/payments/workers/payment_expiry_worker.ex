defmodule Emakola.Payments.Workers.PaymentExpiryWorker do
  @moduledoc """
  Fails gateway payments still `:pending` after 24 hours and releases their
  refund-liability recovery reservations.

  An abandoned checkout otherwise holds its reservation forever — the gateway
  sends no `charge.failed` for a session the customer simply walked away from —
  permanently blocking debt recovery from the merchant's future earnings.
  Gateways mark unpaid sessions abandoned well inside this window; the terminal
  `:failed` state then guards any pathological late success webhook (the
  handlers refuse to override terminal states and log instead).
  """

  use Oban.Worker, queue: :payments, max_attempts: 3, unique: [period: 300, fields: [:args]]

  require Ash.Query

  alias Emakola.Payments.{Payment, PaymentSplit, RefundLiability}

  @stale_after_hours 24

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cutoff = DateTime.add(DateTime.utc_now(), -@stale_after_hours, :hour)

    Payment
    |> Ash.Query.filter(status == :pending and inserted_at < ^cutoff)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&expire_payment/1)

    :ok
  end

  defp expire_payment(payment) do
    {:ok, _} =
      Emakola.Repo.transaction(fn ->
        current = locked_payment!(payment.id)

        if current.status == :pending do
          PaymentSplit
          |> Ash.Query.filter(payment_id == ^current.id)
          |> Ash.read!(authorize?: false)
          |> RefundLiability.release!()

          current
          |> Ash.Changeset.for_update(:mark_failed, %{
            gateway_response: %{"reason" => "expired_unpaid"}
          })
          |> Ash.update!(authorize?: false)
        else
          :skipped
        end
      end)

    :ok
  end

  defp locked_payment!(id) do
    Payment
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end
end
