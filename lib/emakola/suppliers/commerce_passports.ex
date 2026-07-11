defmodule Emakola.Suppliers.CommercePassports do
  @moduledoc "Deterministic, inspectable commerce reliability with expiring evidence and appeals."

  require Ash.Query

  alias Emakola.Suppliers.{CommercePassport, ReputationAppeal, ReputationSignal}

  @valid_days 90

  def inspect(actor, store_id) do
    with :ok <- ensure_store_access(actor, store_id) do
      passport =
        CommercePassport
        |> Ash.Query.filter(store_id == ^store_id)
        |> Ash.Query.load(signals: :appeals)
        |> Ash.read_one!(authorize?: false)

      if passport, do: {:ok, passport}, else: refresh(actor, store_id)
    end
  end

  def refresh(actor, store_id) do
    with :ok <- ensure_store_access(actor, store_id) do
      metrics = metrics(store_id)
      score = score(metrics)
      now = DateTime.utc_now()
      expires_at = DateTime.add(now, @valid_days, :day)

      Emakola.Repo.transaction(fn ->
        passport = upsert_passport(store_id, metrics, score, now, expires_at)
        expire_active_signals(passport.id)

        metrics
        |> signal_specs(score)
        |> Enum.each(&create_signal(passport, &1, now, expires_at))

        Ash.load!(passport, [signals: :appeals], authorize?: false)
      end)
      |> normalize_transaction()
    end
  end

  def appeal(actor, store_id, signal_id, reason) when is_binary(reason) do
    with :ok <- ensure_store_access(actor, store_id),
         true <- String.length(String.trim(reason)) >= 10,
         {:ok, signal} <- Ash.get(ReputationSignal, signal_id, authorize?: false),
         true <- signal.store_id == store_id and signal.status == :active do
      Emakola.Repo.transaction(fn ->
        appeal =
          ReputationAppeal
          |> Ash.Changeset.for_create(:create, %{
            signal_id: signal.id,
            store_id: store_id,
            merchant_id: actor.id,
            reason: String.trim(reason)
          })
          |> Ash.create!(authorize?: false)

        signal
        |> Ash.Changeset.for_update(:mark_appealed, %{})
        |> Ash.update!(authorize?: false)

        appeal
      end)
      |> normalize_transaction()
    else
      false -> {:error, :invalid_appeal}
      error -> error
    end
  end

  def correct_signal(signal_id, appeal_id, attrs) do
    with {:ok, signal} <- Ash.get(ReputationSignal, signal_id, authorize?: false),
         {:ok, appeal} <- Ash.get(ReputationAppeal, appeal_id, authorize?: false),
         true <- appeal.signal_id == signal.id and appeal.status == :open do
      Emakola.Repo.transaction(fn ->
        corrected =
          signal
          |> Ash.Changeset.for_update(:correct, %{
            value: value(attrs, :value),
            impact: value(attrs, :impact),
            evidence: value(attrs, :evidence),
            correction_reason: value(attrs, :reason)
          })
          |> Ash.update!(authorize?: false)

        appeal
        |> Ash.Changeset.for_update(:resolve, %{
          status: :upheld,
          resolution: value(attrs, :reason),
          resolved_at: DateTime.utc_now()
        })
        |> Ash.update!(authorize?: false)

        corrected
      end)
      |> normalize_transaction()
    else
      false -> {:error, :appeal_not_open}
      error -> error
    end
  end

  defp metrics(store_id) do
    orders =
      Emakola.Orders.Order
      |> Ash.read!(authorize?: false, tenant: store_id)

    payments =
      Emakola.Payments.Payment
      |> Ash.Query.filter(store_id == ^store_id and status in [:success, :refunded])
      |> Ash.read!(authorize?: false)

    trainings =
      Emakola.Suppliers.FranchiseEnrollment
      |> Ash.Query.filter(reseller_store_id == ^store_id and status == :approved)
      |> Ash.read!(authorize?: false)

    delivered = Enum.count(orders, &(&1.status == :delivered))
    cancelled = Enum.count(orders, &(&1.status == :cancelled))
    resolved_orders = delivered + cancelled
    refunded = Enum.count(payments, &(&1.status == :refunded))

    %{
      "fulfilled_orders" => delivered,
      "cancelled_orders" => cancelled,
      "fulfillment_rate_bps" => ratio_bps(delivered, resolved_orders),
      "successful_payments" => length(payments),
      "refunded_payments" => refunded,
      "refund_rate_bps" => ratio_bps(refunded, length(payments)),
      "verified_training" => length(trainings)
    }
  end

  defp score(metrics) do
    fulfilled_points = min(metrics["fulfilled_orders"] * 20, 250)
    quality_points = div(metrics["fulfillment_rate_bps"] * 200, 10_000)
    training_points = min(metrics["verified_training"] * 25, 100)
    refund_penalty = div(metrics["refund_rate_bps"] * 300, 10_000)
    max(0, min(1_000, 350 + fulfilled_points + quality_points + training_points - refund_penalty))
  end

  defp tier(score) when score >= 750, do: :proven
  defp tier(score) when score >= 600, do: :reliable
  defp tier(_score), do: :starter

  defp signal_specs(metrics, score) do
    [
      {:fulfilled_orders, metrics["fulfilled_orders"], min(metrics["fulfilled_orders"] * 20, 250),
       "FULFILLED_ORDERS_90D", %{"delivered" => metrics["fulfilled_orders"]}},
      {:service_quality, metrics["fulfillment_rate_bps"],
       div(metrics["fulfillment_rate_bps"] * 200, 10_000), "FULFILLMENT_RATE_RESOLVED",
       %{"delivered" => metrics["fulfilled_orders"], "cancelled" => metrics["cancelled_orders"]}},
      {:refunds_disputes, metrics["refund_rate_bps"],
       -div(metrics["refund_rate_bps"] * 300, 10_000), "REFUND_RATE_SUCCESSFUL_PAYMENTS",
       %{
         "refunded" => metrics["refunded_payments"],
         "successful" => metrics["successful_payments"]
       }},
      {:verified_training, metrics["verified_training"],
       min(metrics["verified_training"] * 25, 100), "SUPPLIER_APPROVED_TRAINING",
       %{"approved_packages" => metrics["verified_training"], "resulting_score" => score}}
    ]
  end

  defp upsert_passport(store_id, metrics, score, now, expires_at) do
    existing =
      CommercePassport
      |> Ash.Query.filter(store_id == ^store_id)
      |> Ash.read_one!(authorize?: false)

    attrs = %{
      score: score,
      tier: tier(score),
      metrics: metrics,
      computed_at: now,
      expires_at: expires_at
    }

    if existing do
      existing |> Ash.Changeset.for_update(:refresh, attrs) |> Ash.update!(authorize?: false)
    else
      CommercePassport
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store_id))
      |> Ash.create!(authorize?: false)
    end
  end

  defp expire_active_signals(passport_id) do
    ReputationSignal
    |> Ash.Query.filter(passport_id == ^passport_id and status == :active)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn signal ->
      signal |> Ash.Changeset.for_update(:expire, %{}) |> Ash.update!(authorize?: false)
    end)
  end

  defp create_signal(passport, {kind, value, impact, reason_code, evidence}, now, expires_at) do
    fingerprint =
      :crypto.hash(
        :sha256,
        "#{kind}:#{DateTime.to_iso8601(now)}:#{inspect(evidence)}"
      )
      |> Base.url_encode64(padding: false)

    ReputationSignal
    |> Ash.Changeset.for_create(:create, %{
      passport_id: passport.id,
      store_id: passport.store_id,
      kind: kind,
      value: value,
      impact: impact,
      reason_code: reason_code,
      evidence: evidence,
      source_fingerprint: fingerprint,
      observed_at: now,
      expires_at: expires_at
    })
    |> Ash.create!(authorize?: false)
  end

  defp ratio_bps(_part, 0), do: 0
  defp ratio_bps(part, total), do: div(part * 10_000, total)
  defp value(map, key), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp normalize_transaction({:ok, result}), do: {:ok, result}
  defp normalize_transaction({:error, reason}), do: {:error, reason}

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [_]} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_, _), do: {:error, :forbidden}
end
