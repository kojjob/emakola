defmodule Emakola.Notifications.Dispatcher do
  @moduledoc """
  Dispatches order lifecycle notifications by enqueuing Oban jobs.

  Called from order status transition actions (inside after_action hooks) or
  from LiveView after a status change. Each event maps to a specific
  notification type sent via the `OrderNotificationWorker`.

  ## Contract

  `dispatch/2` is guaranteed to **never raise**. Callers running inside an
  Ash `after_action` hook can rely on this so that a notification subsystem
  failure does not roll back a successful domain transaction.

  All failures — known error tuples, unknown events, and unexpected
  exceptions — are logged and returned as `{:error, reason}`.

  ## Return values

    * `{:ok, %Oban.Job{}}` — job enqueued successfully
    * `{:error, :unknown_event}` — event not in the valid set
    * `{:error, {:oban_insert_failed, changeset}}` — Oban could not enqueue
    * `{:error, {:dispatch_raised, message}}` — something unexpected raised

  ## Susu coupling (TC-3 Task 8)

  Every event above is Order-based: `dispatch/2` requires an order-shaped
  map (`%{id: ..., store_id: ...}` — several call sites pass a minimal map
  rather than a real `%Order{}`, e.g. `ProtectionHolds`/`ProtectionRelease`)
  and routes to `OrderNotificationWorker`, which loads the real `Order` by
  id and drives buyer email/WhatsApp branching keyed on order fields.

  Pre-completion susu lifecycle events (plan activation, chunk progress,
  nudges, deadline warnings, non-completion end-of-life) have NO order —
  `Emakola.Orders.SusuPlan` doesn't create one until
  `Emakola.Orders.SusuCompletion.complete/1` runs. Coercing plan data
  through `OrderNotificationWorker`'s order-shaped `load_order/1` would
  mean forking that worker's `perform/1` into two disjoint code paths
  sharing nothing but the module file — not meaningfully "the same
  worker" despite the phrasing. `dispatch_susu/2` below +
  `Emakola.Notifications.Workers.SusuNotificationWorker` is the smaller,
  honest extension instead: a dedicated worker keyed on `susu_plan_id`,
  mirroring the ALREADY-established pattern of `SupplierNotificationWorker`
  (keyed on `fulfillment_id`, entirely separate from
  `OrderNotificationWorker`) rather than inventing a new shape.

  Post-completion susu events (`:susu_completed`, `:susu_merchant_completed`)
  DO have a real order by the time they fire (`SusuCompletion.complete/1`
  dispatches them right after confirming the freshly-created order), so
  those route through the ordinary `dispatch/2`/`OrderNotificationWorker`
  path — added to `@valid_events` exactly like the TC-2 protection events
  were.
  """

  require Logger

  alias Emakola.Notifications.Workers.EarningsNotificationWorker
  alias Emakola.Notifications.Workers.OrderNotificationWorker
  alias Emakola.Notifications.Workers.PushNotificationWorker
  alias Emakola.Notifications.Workers.SupplierNotificationWorker
  alias Emakola.Notifications.Workers.SusuNotificationWorker

  @valid_events ~w(
    order_placed order_confirmed order_shipped order_delivered order_cancelled
    protection_held protection_delivery_nudge protection_released protection_complaint
    susu_completed susu_merchant_completed
  )a

  @valid_susu_events ~w(
    susu_activated susu_chunk_received susu_nudge susu_deadline_warning susu_refunded
    susu_merchant_activated susu_merchant_expired
  )a

  @valid_earnings_events ~w(earnings_accrued)a

  @doc """
  Dispatch a notification for an order lifecycle event.

  Enqueues an Oban job to send SMS/WhatsApp notifications to the customer and
  merchant, and broadcasts a real-time PubSub event to the store topic.

  ## Parameters
    - `order` — an order struct/map with at least `:id` (and ideally `:store_id`)
    - `event` — one of #{inspect(@valid_events)}
  """
  @spec dispatch(map(), atom()) ::
          {:ok, Oban.Job.t()}
          | {:error,
             :unknown_event
             | :missing_order_id
             | {:oban_insert_failed, any()}
             | {:dispatch_raised, String.t()}}
  def dispatch(order, event) when event in @valid_events do
    do_dispatch(order, event)
  rescue
    exception ->
      Logger.error(
        "[notifications] dispatch raised for #{inspect(event)}: " <>
          Exception.message(exception),
        order_id: Map.get(order || %{}, :id),
        event: event
      )

      {:error, {:dispatch_raised, Exception.message(exception)}}
  end

  def dispatch(_order, event) do
    Logger.warning("[notifications] unknown event: #{inspect(event)}")
    {:error, :unknown_event}
  end

  @doc """
  Enqueue a `SupplierNotificationWorker` for each fulfillment ID in
  `fulfillment_ids`. The caller (Orders.Order confirm action) is responsible
  for filtering to pending supplier-owned fulfillments before calling this.

  Accepting explicit IDs removes the need for the Notifications context to
  query back into the Orders context, eliminating the bidirectional coupling.

  Never raises — failures are logged. Always returns `:ok`.
  """
  @spec dispatch_supplier_fulfillments(binary(), [binary()]) :: :ok
  def dispatch_supplier_fulfillments(order_id, fulfillment_ids)
      when is_binary(order_id) and is_list(fulfillment_ids) do
    Enum.each(fulfillment_ids, &enqueue_supplier_job/1)
    :ok
  rescue
    exception ->
      Logger.error(
        "[notifications] dispatch_supplier_fulfillments raised: " <>
          Exception.message(exception),
        order_id: order_id
      )

      :ok
  end

  def dispatch_supplier_fulfillments(_order_id, _fulfillment_ids), do: :ok

  @doc """
  Enqueue a `SupplierNotificationWorker` for a single fulfillment id. Used by
  the merchant manual send/resend UI.

  Returns `{:ok, %Oban.Job{}}` or `{:error, reason}`.
  """
  @spec dispatch_supplier_fulfillment(binary()) ::
          {:ok, Oban.Job.t()} | {:error, any()}
  def dispatch_supplier_fulfillment(fulfillment_id) do
    %{
      "fulfillment_id" => fulfillment_id,
      "resend" => true,
      "nonce" => System.unique_integer([:positive])
    }
    |> SupplierNotificationWorker.new(queue: :notifications)
    |> Oban.insert()
  rescue
    exception ->
      Logger.error(
        "[notifications] dispatch_supplier_fulfillment raised: " <>
          Exception.message(exception),
        fulfillment_id: fulfillment_id
      )

      {:error, {:dispatch_raised, Exception.message(exception)}}
  end

  @doc """
  Dispatch a notification for a susu plan lifecycle event — the plan-based
  counterpart to `dispatch/2` for events that occur BEFORE a susu plan's
  order exists. See the moduledoc's "Susu coupling" section for why this
  is a separate function/worker rather than routing through the
  order-based path.

  ## Parameters
    - `plan` — a susu plan struct/map with at least `:id` (and ideally
      `:store_id`, though nothing here reads it — `SusuNotificationWorker`
      re-loads the plan fresh by id)
    - `event` — one of #{inspect(@valid_susu_events)}

  Never raises — same contract as `dispatch/2`.
  """
  @spec dispatch_susu(map(), atom()) ::
          {:ok, Oban.Job.t()}
          | {:error,
             :unknown_event
             | :missing_plan_id
             | {:oban_insert_failed, any()}
             | {:dispatch_raised, String.t()}}
  def dispatch_susu(plan, event) when event in @valid_susu_events do
    do_dispatch_susu(plan, event)
  rescue
    exception ->
      Logger.error(
        "[notifications] dispatch_susu raised for #{inspect(event)}: " <>
          Exception.message(exception),
        plan_id: Map.get(plan || %{}, :id),
        event: event
      )

      {:error, {:dispatch_raised, Exception.message(exception)}}
  end

  def dispatch_susu(_plan, event) do
    Logger.warning("[notifications] unknown susu event: #{inspect(event)}")
    {:error, :unknown_event}
  end

  @doc """
  Dispatch an earnings-accrued notification for one settled, non-platform
  `PaymentSplit` recipient (money-surfaces PR-2 Task 3) — a plan-based-style
  counterpart to `dispatch_susu/2`, keyed on two ids (payment + recipient
  store) instead of one entity, since there's no single "earnings event"
  struct to load fresh the way `SusuNotificationWorker` reloads a plan.

  Called by `PaystackWebhookHandler.settle_splits/1` once per recipient
  whose split THIS call transitioned `:pending -> :settled` — that freshness
  filtering happens there, not here; this function has no dedup logic of its
  own beyond `EarningsNotificationWorker`'s Oban `unique`.

  ## Parameters
    - `payload` — `%{payment_id: ..., recipient_store_id: ...}`
    - `event` — one of #{inspect(@valid_earnings_events)}

  Never raises — same contract as `dispatch/2` / `dispatch_susu/2`.
  """
  @spec dispatch_earnings(map(), atom()) ::
          {:ok, Oban.Job.t()}
          | {:error,
             :unknown_event
             | :missing_earnings_ids
             | {:oban_insert_failed, any()}
             | {:dispatch_raised, String.t()}}
  def dispatch_earnings(payload, event) when event in @valid_earnings_events do
    do_dispatch_earnings(payload, event)
  rescue
    exception ->
      Logger.error(
        "[notifications] dispatch_earnings raised for #{inspect(event)}: " <>
          Exception.message(exception),
        payment_id: Map.get(payload || %{}, :payment_id),
        recipient_store_id: Map.get(payload || %{}, :recipient_store_id),
        event: event
      )

      {:error, {:dispatch_raised, Exception.message(exception)}}
  end

  def dispatch_earnings(_payload, event) do
    Logger.warning("[notifications] unknown earnings event: #{inspect(event)}")
    {:error, :unknown_event}
  end

  # ── Internal ──────────────────────────────────────────────────────────

  defp enqueue_supplier_job(fulfillment_id) do
    %{"fulfillment_id" => fulfillment_id}
    |> SupplierNotificationWorker.new(queue: :notifications)
    |> Oban.insert()
  end

  defp do_dispatch(%{id: order_id} = order, event) when not is_nil(order_id) do
    case enqueue_job(order_id, event) do
      {:ok, job} ->
        enqueue_push(order_id, event)
        maybe_broadcast(order, event)
        notify_merchants(order, event)
        {:ok, job}

      {:error, reason} ->
        Logger.error(
          "[notifications] Oban insert failed for #{inspect(event)}: #{inspect(reason)}",
          order_id: order_id,
          event: event
        )

        {:error, {:oban_insert_failed, reason}}
    end
  end

  defp do_dispatch(_order, event) do
    Logger.error("[notifications] cannot dispatch #{inspect(event)}: order has no :id")
    {:error, :missing_order_id}
  end

  # The merchant's in-app bell. Only a new order: the later status events are
  # the merchant's own doing, and a bell that tells you what you just did is
  # noise. Free and instant, unlike the SMS the worker above may send.
  defp notify_merchants(%{store_id: store_id, order_number: number}, :order_placed)
       when is_binary(store_id) do
    Emakola.Notifications.notify_store(store_id, :order_placed, %{
      title: "New order #{number}",
      action_url: "/admin/orders"
    })
  end

  defp notify_merchants(_order, _event), do: :ok

  # Mobile push fires only on new orders (Phase 0). Failures are logged and
  # swallowed — push must never break the primary notification path.
  defp enqueue_push(order_id, :order_placed) do
    %{order_id: order_id, event: "order_placed"}
    |> PushNotificationWorker.new(queue: :notifications)
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error("[notifications] push enqueue failed: #{inspect(reason)}",
          order_id: order_id
        )

        :ok
    end
  end

  defp enqueue_push(_order_id, _event), do: :ok

  defp enqueue_job(order_id, event) do
    %{order_id: order_id, event: Atom.to_string(event)}
    |> OrderNotificationWorker.new(queue: :notifications)
    |> Oban.insert()
  end

  defp maybe_broadcast(%{store_id: store_id} = order, event) when not is_nil(store_id) do
    Phoenix.PubSub.broadcast(
      Emakola.PubSub,
      "store:#{store_id}:orders",
      {:order_event, event, order}
    )
  end

  defp maybe_broadcast(_order, _event), do: :ok

  defp do_dispatch_susu(%{id: plan_id}, event) when not is_nil(plan_id) do
    %{"susu_plan_id" => plan_id, "event" => Atom.to_string(event)}
    |> SusuNotificationWorker.new(queue: :notifications)
    |> Oban.insert()
    |> case do
      {:ok, job} ->
        {:ok, job}

      {:error, reason} ->
        Logger.error(
          "[notifications] Oban insert failed for #{inspect(event)}: #{inspect(reason)}",
          plan_id: plan_id,
          event: event
        )

        {:error, {:oban_insert_failed, reason}}
    end
  end

  defp do_dispatch_susu(_plan, event) do
    Logger.error("[notifications] cannot dispatch #{inspect(event)}: plan has no :id")
    {:error, :missing_plan_id}
  end

  defp do_dispatch_earnings(
         %{payment_id: payment_id, recipient_store_id: recipient_store_id},
         event
       )
       when not is_nil(payment_id) and not is_nil(recipient_store_id) do
    %{
      "payment_id" => payment_id,
      "recipient_store_id" => recipient_store_id,
      "event" => Atom.to_string(event)
    }
    |> EarningsNotificationWorker.new(queue: :notifications)
    |> Oban.insert()
    |> case do
      {:ok, job} ->
        {:ok, job}

      {:error, reason} ->
        Logger.error(
          "[notifications] Oban insert failed for #{inspect(event)}: #{inspect(reason)}",
          payment_id: payment_id,
          recipient_store_id: recipient_store_id,
          event: event
        )

        {:error, {:oban_insert_failed, reason}}
    end
  end

  defp do_dispatch_earnings(_payload, event) do
    Logger.error(
      "[notifications] cannot dispatch #{inspect(event)}: missing payment_id/recipient_store_id"
    )

    {:error, :missing_earnings_ids}
  end
end
