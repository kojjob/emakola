defmodule Emakola.Payments.RefundReconciliation do
  @moduledoc """
  Atomically records a processed gateway refund and reconciles its order.

  Refund webhooks can be delivered more than once or at the same time. The
  payment row is therefore re-read under `FOR UPDATE`; every decision is made
  from that fresh row, never from a struct loaded before the transaction. A
  full refund reconciles the associated order in the same database
  transaction, so the payment cannot commit as fully refunded while an
  unfulfilled order remains active.

  Paystack includes a refund identifier on production events. When one is
  available, it is recorded in payment metadata so a partial-refund replay is
  also a no-op. Some legacy/test payloads omit an identifier; those retain the
  existing semantics where equal amounts may represent separate partial
  refunds, with Oban's identical-args uniqueness providing replay protection.
  """

  import Ecto.Query, only: [from: 2]

  alias Emakola.Payments.Payment
  alias Emakola.Repo

  @processed_events_key "processed_refund_events"

  @type result :: %{
          payment: %Payment{},
          order_reconciliation: term(),
          replay?: boolean()
        }

  @doc """
  Records `amount` against the payment identified by `gateway_reference`.

  Options:

    * `:event_key` - stable gateway refund identifier, when present

  Returns `{:ok, result}` for both a newly processed event and an idempotent
  replay. Business-rule failures are returned as `{:error, {:invalid_refund,
  error}}`; missing references return `{:error, :payment_not_found}`.
  """
  @spec process(String.t(), pos_integer(), keyword()) :: {:ok, result()} | {:error, term()}
  def process(gateway_reference, amount, opts \\ [])

  def process(gateway_reference, amount, opts)
      when is_binary(gateway_reference) and is_integer(amount) and amount > 0 do
    event_key = normalize_event_key(Keyword.get(opts, :event_key))

    Repo.transaction(fn ->
      case Repo.one(locked_payment_query(gateway_reference)) do
        nil ->
          Repo.rollback(:payment_not_found)

        payment_id ->
          payment = Ash.get!(Payment, payment_id, authorize?: false)
          reconcile_locked_payment(payment, amount, event_key)
      end
    end)
    |> normalize_transaction()
  end

  def process(_gateway_reference, _amount, _opts), do: {:error, :invalid_refund_event}

  @doc false
  def locked_payment_query(gateway_reference) do
    from(p in "payments",
      where: p.gateway_reference == ^gateway_reference,
      lock: "FOR UPDATE",
      select: type(p.id, :binary_id)
    )
  end

  defp reconcile_locked_payment(%Payment{status: :refunded} = payment, _amount, _event_key) do
    result(payment, true, reconcile_order(payment))
  end

  defp reconcile_locked_payment(payment, amount, event_key)
       when not is_nil(event_key) do
    if processed_event?(payment, event_key) do
      result(payment, true, :not_fully_refunded)
    else
      apply_refund(payment, amount, event_key)
    end
  end

  defp reconcile_locked_payment(payment, amount, nil), do: apply_refund(payment, amount, nil)

  defp apply_refund(payment, amount, event_key) do
    cumulative = (payment.refunded_amount || 0) + amount

    params =
      %{refunded_amount: cumulative}
      |> maybe_put_metadata(payment, event_key)

    case payment
         |> Ash.Changeset.for_update(:mark_refunded, params)
         |> Ash.update(authorize?: false) do
      {:ok, updated} ->
        result(updated, false, reconcile_order(updated))

      {:error, %Ash.Error.Invalid{} = error} ->
        Repo.rollback({:invalid_refund, error})

      {:error, error} ->
        Repo.rollback(error)
    end
  end

  defp reconcile_order(%Payment{status: :refunded} = payment) do
    Emakola.Orders.RefundReconciliation.reconcile(payment)
  end

  defp reconcile_order(_payment), do: :not_fully_refunded

  defp result(payment, replay?, order_reconciliation) do
    %{
      payment: payment,
      replay?: replay?,
      order_reconciliation: order_reconciliation
    }
  end

  defp maybe_put_metadata(params, _payment, nil), do: params

  defp maybe_put_metadata(params, payment, event_key) do
    events =
      payment
      |> processed_events()
      |> then(&[event_key | &1])
      |> Enum.uniq()
      |> Enum.take(100)

    metadata = Map.put(payment.metadata || %{}, @processed_events_key, events)
    Map.put(params, :metadata, metadata)
  end

  defp processed_event?(payment, event_key), do: event_key in processed_events(payment)

  defp processed_events(%Payment{metadata: metadata}) when is_map(metadata) do
    case Map.get(metadata, @processed_events_key, []) do
      events when is_list(events) -> Enum.filter(events, &is_binary/1)
      _ -> []
    end
  end

  defp processed_events(_payment), do: []

  defp normalize_event_key(nil), do: nil
  defp normalize_event_key(value) when is_binary(value), do: value
  defp normalize_event_key(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_event_key(_value), do: nil

  defp normalize_transaction({:ok, result}), do: {:ok, result}
  defp normalize_transaction({:error, reason}), do: {:error, reason}
end
