defmodule Emakola.Billing.Workers.StripeHandler do
  @moduledoc "Processes Stripe webhook events via Oban."
  use Oban.Worker, queue: :billing, max_attempts: 5

  require Logger
  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => type, "data" => data}}) do
    case type do
      "checkout.session.completed" ->
        handle_checkout_completed(data)

      "customer.subscription.created" ->
        handle_subscription_created(data)

      "customer.subscription.updated" ->
        handle_subscription_updated(data)

      "customer.subscription.deleted" ->
        handle_subscription_deleted(data)

      "invoice.payment_succeeded" ->
        handle_payment_succeeded(data)

      "invoice.payment_failed" ->
        handle_payment_failed(data)

      _ ->
        Logger.info("Unhandled Stripe event: #{type}")
        :ok
    end
  end

  # ── Checkout Session ──

  defp handle_checkout_completed(%{"object" => session}) do
    metadata = session["metadata"] || %{}
    org_id = metadata["organisation_id"]
    plan_id = metadata["plan_id"]
    stripe_sub_id = session["subscription"]
    stripe_cust_id = session["customer"]

    if org_id && plan_id && stripe_sub_id do
      case Emakola.Billing.Subscription
           |> Ash.Changeset.for_create(:create, %{
             stripe_subscription_id: stripe_sub_id,
             stripe_customer_id: stripe_cust_id,
             status: :active,
             organisation_id: org_id,
             plan_id: plan_id
           })
           |> Ash.create() do
        {:ok, sub} ->
          Logger.info("Created subscription #{sub.id} for org #{org_id}")
          :ok

        {:error, error} ->
          Logger.error("Failed to create subscription: #{inspect(error)}")
          {:error, error}
      end
    else
      Logger.warning("Checkout session missing metadata: #{inspect(metadata)}")
      :ok
    end
  end

  # ── Subscription Events ──

  defp handle_subscription_created(%{"object" => sub}) do
    Logger.info("Stripe subscription created: #{sub["id"]}")
    :ok
  end

  defp handle_subscription_updated(%{"object" => sub}) do
    stripe_sub_id = sub["id"]

    case find_subscription_by_stripe_id(stripe_sub_id) do
      {:ok, subscription} ->
        attrs = %{
          status: parse_status(sub["status"]),
          cancel_at_period_end: sub["cancel_at_period_end"] || false
        }

        attrs =
          attrs
          |> maybe_put(:current_period_start, parse_timestamp(sub["current_period_start"]))
          |> maybe_put(:current_period_end, parse_timestamp(sub["current_period_end"]))

        case subscription
             |> Ash.Changeset.for_update(:update_from_stripe, attrs)
             |> Ash.update() do
          {:ok, _} ->
            Logger.info("Updated subscription #{stripe_sub_id}")
            :ok

          {:error, error} ->
            Logger.error("Failed to update subscription #{stripe_sub_id}: #{inspect(error)}")
            {:error, error}
        end

      {:error, :not_found} ->
        Logger.warning("Subscription not found for Stripe ID: #{stripe_sub_id}")
        :ok
    end
  end

  defp handle_subscription_deleted(%{"object" => sub}) do
    stripe_sub_id = sub["id"]

    case find_subscription_by_stripe_id(stripe_sub_id) do
      {:ok, subscription} ->
        case subscription
             |> Ash.Changeset.for_update(:cancel, %{})
             |> Ash.update() do
          {:ok, _} ->
            Logger.info("Canceled subscription #{stripe_sub_id}")
            :ok

          {:error, error} ->
            Logger.error("Failed to cancel subscription #{stripe_sub_id}: #{inspect(error)}")
            {:error, error}
        end

      {:error, :not_found} ->
        Logger.warning("Subscription not found for deletion: #{stripe_sub_id}")
        :ok
    end
  end

  # ── Invoice Events ──

  defp handle_payment_succeeded(%{"object" => invoice}) do
    stripe_sub_id = invoice["subscription"]

    case find_subscription_by_stripe_id(stripe_sub_id) do
      {:ok, subscription} ->
        attrs = %{
          invoice_number: invoice["number"] || "INV-#{invoice["id"]}",
          amount_cents: invoice["amount_paid"] || 0,
          status: :paid,
          stripe_invoice_id: invoice["id"],
          period_start: timestamp_to_date(invoice["period_start"]),
          period_end: timestamp_to_date(invoice["period_end"]),
          organisation_id: subscription.organisation_id
        }

        case Emakola.Billing.Invoice
             |> Ash.Changeset.for_create(:create, attrs)
             |> Ash.create() do
          {:ok, inv} ->
            Logger.info("Created invoice #{inv.id} for payment #{invoice["id"]}")
            :ok

          {:error, error} ->
            Logger.error("Failed to create invoice: #{inspect(error)}")
            {:error, error}
        end

      {:error, :not_found} ->
        Logger.warning("Subscription not found for invoice: #{stripe_sub_id}")
        :ok
    end
  end

  defp handle_payment_failed(%{"object" => invoice}) do
    stripe_sub_id = invoice["subscription"]

    case find_subscription_by_stripe_id(stripe_sub_id) do
      {:ok, subscription} ->
        attrs = %{
          invoice_number: invoice["number"] || "INV-#{invoice["id"]}",
          amount_cents: invoice["amount_due"] || 0,
          status: :failed,
          stripe_invoice_id: invoice["id"],
          period_start: timestamp_to_date(invoice["period_start"]),
          period_end: timestamp_to_date(invoice["period_end"]),
          organisation_id: subscription.organisation_id
        }

        case Emakola.Billing.Invoice
             |> Ash.Changeset.for_create(:create, attrs)
             |> Ash.create() do
          {:ok, inv} ->
            Logger.info("Created failed invoice #{inv.id} for #{invoice["id"]}")
            notify_payment_failure(subscription)
            :ok

          {:error, error} ->
            Logger.error("Failed to create failed invoice: #{inspect(error)}")
            {:error, error}
        end

      {:error, :not_found} ->
        Logger.warning("Subscription not found for failed invoice: #{stripe_sub_id}")
        :ok
    end
  end

  # ── Private Helpers ──

  defp find_subscription_by_stripe_id(stripe_sub_id) do
    case Emakola.Billing.Subscription
         |> Ash.Query.filter(stripe_subscription_id == ^stripe_sub_id)
         |> Ash.read(authorize?: false) do
      {:ok, [sub | _]} -> {:ok, sub}
      {:ok, []} -> {:error, :not_found}
      {:error, error} -> {:error, error}
    end
  end

  defp parse_status("active"), do: :active
  defp parse_status("past_due"), do: :past_due
  defp parse_status("canceled"), do: :canceled
  defp parse_status("incomplete"), do: :incomplete
  defp parse_status("trialing"), do: :trialing
  defp parse_status("unpaid"), do: :unpaid
  defp parse_status(_), do: :active

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(ts) when is_integer(ts) do
    DateTime.from_unix!(ts)
  end

  defp parse_timestamp(_), do: nil

  defp timestamp_to_date(nil), do: Date.utc_today()

  defp timestamp_to_date(ts) when is_integer(ts) do
    ts |> DateTime.from_unix!() |> DateTime.to_date()
  end

  defp timestamp_to_date(_), do: Date.utc_today()

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp notify_payment_failure(subscription) do
    case Emakola.Accounts.Membership
         |> Ash.Query.filter(organisation_id == ^subscription.organisation_id)
         |> Ash.Query.filter(role == :owner)
         |> Ash.read(authorize?: false) do
      {:ok, memberships} ->
        Enum.each(memberships, fn membership ->
          Emakola.Notifications.Notification
          |> Ash.Changeset.for_create(:create, %{
            type: :billing_warning,
            title: "Payment Failed",
            body:
              "Your latest payment could not be processed. Please update your payment method to avoid service interruption.",
            action_url: "/billing",
            user_id: membership.user_id
          })
          |> Ash.create()
        end)

      _ ->
        :ok
    end
  end
end
