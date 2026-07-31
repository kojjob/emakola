defmodule Emakola.Orders.SusuChunks do
  @moduledoc """
  Chunk initiation + webhook accumulation for a susu plan (TC-3 Task 3) —
  the money core of lay-away.

  ## Initiation ordering (verified, not invented)

  `initiate_chunk/4` mirrors the EXACT sequence `CheckoutLive`/`PayLinkLive`
  already use for every other gateway payment: the gateway's HTTP call
  happens FIRST, and the `Payment` row is only created afterward, seeded
  with the reference the gateway returned (`Payment.:update` has no action
  that accepts `gateway_reference`, so there is no supported way to create
  a placeholder row first and stamp the reference on later — the existing
  pattern is also the only one the schema supports). The plan-row lock
  covers only the pre-flight validation (status/deadline/one-pending-chunk/
  amount bounds) — never the HTTP round trip.

  This does leave a narrow window: two genuinely concurrent
  `initiate_chunk/4` calls for the same plan can both pass the
  one-pending-chunk check (no `Payment` row exists for either yet) and
  both reach the gateway. That is the same structural shape every other
  gateway-payment call site in this codebase already accepts (see
  `Emakola.Suppliers.GroupBuys.create_customer_payment/4`, which has the
  identical gateway-then-payment order) — not a new risk introduced here.

  ## Confirmation

  `confirm_chunk/1` is the webhook success block's hook (guarded on
  `payment.susu_plan_id` — nil is an instant no-op, so ordinary
  order-based payments are byte-identical to before this module existed).
  It locks the plan row (`locked_plan_query/1`), re-reads the payment
  fresh (redelivery-safe idempotency: a payment already stamped
  `metadata["susu_counted"]` no-ops), and only then decides:

    * plan not `:pending`/`:active` (expired/cancelled/completed between
      initiation and webhook) -> the money is flagged on the payment for
      merchant refund attention (dedup'd note, mirrors
      `Emakola.Orders.PayLinkClaim`'s exact pattern) and logged. It is
      never counted.
    * first confirmed chunk against a `:pending` plan -> activates the
      plan (customer find-or-create by the stashed buyer phone, delivery
      address stored) and reserves stock for catalog plans
      (`Emakola.Orders.SusuStock.reserve/1`, Task 4). Insufficient stock
      cancels the plan and flags the payment for refund instead of
      leaving the buyer's money parked in a dead plan.
    * a contribution that would exceed the plan's `total_amount` (two
      chunks initiated before either confirmed, say) is likewise never
      recorded — flagged for refund instead of overshooting the total.
    * otherwise records the contribution and, if it exactly completes the
      plan, enqueues `Emakola.Payments.Workers.SusuCompletionWorker`
      (shell only — Task 5 implements the real work).

  Never raises into the calling webhook worker (same discipline as
  `ProtectionHolds.ensure_hold/1`).
  """

  import Ecto.Query, only: [from: 2]
  require Ash.Query
  require Logger

  alias Emakola.Orders.CheckoutService
  alias Emakola.Orders.SusuPlan
  alias Emakola.Orders.SusuStock
  alias Emakola.Payments.Payment
  alias Emakola.Repo

  @refund_note "⚠️ Susu chunk confirmed against a non-active plan — refund this payment."

  # Builds the FOR-UPDATE row lookup used by both `initiate_chunk/4` and
  # `confirm_chunk/1`. Exposed (not private) so `SusuChunksTest` can pass it
  # to `Ecto.Adapters.SQL.to_sql/3` and assert the lock clause is present —
  # mirrors `ProtectionRelease.locked_row_query/1` / `PayLinkClaim.locked_row_query/1`.
  @doc false
  def locked_plan_query(plan_id) do
    from(p in "susu_plans",
      where: p.id == type(^plan_id, :binary_id),
      lock: "FOR UPDATE",
      # Schemaless queries decode a `timestamp` column as NaiveDateTime by
      # default — the explicit `type/2` cast is required to get back a real
      # `DateTime` that `deadline_ok/1` can pass to `DateTime.compare/2`.
      select: %{status: p.status, deadline: type(p.deadline, :utc_datetime_usec)}
    )
  end

  @doc """
  Initiates a chunk payment toward `plan_code_or_struct` for `amount` (minor
  units). `buyer_params` (string-keyed map: "name", "phone", required for the
  very first chunk; "email", "address" optional) is stashed on the created
  payment's `metadata["susu_buyer"]` for `confirm_chunk/1` to read at
  activation — customer resolution does NOT happen here. `gateway` is the
  `Emakola.Payments.Gateway` implementation to call: an explicit, required
  argument (per this task's interface) rather than an `Application.get_env/3`
  read, for the same testability reason `Emakola.Suppliers.GroupBuys` takes
  its gateway as an argument.

  Returns `{:ok, %{payment: payment, gateway: gateway_response}}` or
  `{:error, reason}` — `:plan_not_found`, `:completed | :cancelled |
  :expired` (plan not usable), `:chunk_in_flight` (a payment already
  `:pending` for this plan), `:amount_below_min | :amount_above_remaining`,
  `:buyer_details_required` (first chunk missing name/phone), or whatever
  the gateway/payment-create call returns.
  """
  def initiate_chunk(plan_code_or_struct, amount, buyer_params, gateway) do
    with {:ok, plan_id} <- resolve_plan_id(plan_code_or_struct),
         {:ok, checked} <- validate_and_prepare(plan_id, amount, buyer_params) do
      do_initiate(checked, gateway)
    end
  end

  @doc """
  Accumulates a confirmed chunk payment onto its susu plan. A no-op for any
  payment not parented to a plan (`susu_plan_id` nil) — see moduledoc.
  Never raises.

  Runs in (up to) two separate locked transactions rather than one, by
  necessity: `SusuStock.reserve/1` (Task 4) manages its own transaction and
  — on insufficient stock — rescues its own `Ash.Error.Invalid` internally
  without issuing a rollback. Nested inside one of OUR transactions, that
  CHECK-constraint violation would still abort the surrounding Postgres
  transaction at the server level (a raised, DB-level constraint error
  poisons the whole enclosing transaction regardless of what Elixir code
  rescues), taking down the plan-cancel + refund-flag writes that need to
  follow it. So stock reservation runs OUTSIDE any transaction of ours —
  between the "activate" phase (`prepare/2`) and the "record contribution"
  phase (`finish_recording/2`), each independently locked.
  """
  def confirm_chunk(%Payment{susu_plan_id: nil}), do: :ok

  def confirm_chunk(%Payment{susu_plan_id: plan_id, id: payment_id}) do
    case prepare(plan_id, payment_id) do
      :short_circuited ->
        :ok

      {:record, plan, payment} ->
        finish_recording(plan_id, plan, payment)

      {:activate_catalog, activated_plan, payment} ->
        case SusuStock.reserve(activated_plan) do
          :ok ->
            finish_recording(plan_id, activated_plan, payment)

          {:error, :insufficient_stock} ->
            Emakola.Orders.cancel_susu_plan!(activated_plan, authorize?: false)
            flag_for_refund(payment, plan_id)
        end
    end

    :ok
  rescue
    error ->
      Logger.error(
        "[susu_chunks] confirm_chunk failed for payment=#{payment_id}: " <>
          Exception.format(:error, error, __STACKTRACE__)
      )

      :ok
  end

  # -- Initiation ------------------------------------------------------

  defp resolve_plan_id(%SusuPlan{id: id}), do: {:ok, id}

  defp resolve_plan_id(code) when is_binary(code) do
    case Emakola.Orders.get_susu_plan_by_code(code, authorize?: false) do
      {:ok, %SusuPlan{id: id}} -> {:ok, id}
      _ -> {:error, :plan_not_found}
    end
  end

  defp validate_and_prepare(plan_id, amount, buyer_params) do
    Repo.transaction(fn ->
      case Repo.one(locked_plan_query(plan_id)) do
        nil ->
          Repo.rollback(:plan_not_found)

        row ->
          result =
            with :ok <- status_ok(row.status),
                 :ok <- deadline_ok(row.deadline),
                 :ok <- one_pending_chunk_ok(plan_id),
                 plan <- Ash.get!(SusuPlan, plan_id, authorize?: false),
                 :ok <- amount_within_bounds(plan, amount),
                 :ok <- buyer_params_ok(row.status, buyer_params) do
              {:ok,
               %{
                 plan: plan,
                 amount: amount,
                 buyer_params: buyer_params,
                 first_chunk?: row.status == "pending"
               }}
            end

          case result do
            {:ok, checked} -> checked
            {:error, reason} -> Repo.rollback(reason)
          end
      end
    end)
  end

  defp status_ok("pending"), do: :ok
  defp status_ok("active"), do: :ok
  defp status_ok("completed"), do: {:error, :completed}
  defp status_ok("cancelled"), do: {:error, :cancelled}
  defp status_ok("expired"), do: {:error, :expired}

  defp deadline_ok(deadline) do
    if DateTime.compare(deadline, DateTime.utc_now()) == :lt,
      do: {:error, :expired},
      else: :ok
  end

  defp one_pending_chunk_ok(plan_id) do
    existing =
      Payment
      |> Ash.Query.filter(susu_plan_id == ^plan_id and status == :pending)
      |> Ash.read_one!(authorize?: false)

    if existing, do: {:error, :chunk_in_flight}, else: :ok
  end

  defp amount_within_bounds(plan, amount) do
    %{min: min, max: max} = SusuPlan.chunk_bounds(plan)

    cond do
      amount < min -> {:error, :amount_below_min}
      amount > max -> {:error, :amount_above_remaining}
      true -> :ok
    end
  end

  defp buyer_params_ok("pending", buyer_params) do
    if presence(buyer_params["name"]) && presence(buyer_params["phone"]),
      do: :ok,
      else: {:error, :buyer_details_required}
  end

  defp buyer_params_ok(_status, _buyer_params), do: :ok

  defp do_initiate(%{plan: plan, amount: amount, buyer_params: buyer_params} = checked, gateway) do
    store = Ash.get!(Emakola.Stores.Store, plan.store_id, authorize?: false)

    params = %{
      amount: amount,
      email: resolve_email(plan, store, buyer_params),
      currency: store.currency || "GHS",
      store_id: store.id,
      callback_url: susu_page_url(plan),
      return_url: susu_page_url(plan),
      metadata: %{payment_method: "susu_chunk"}
    }

    case gateway.initiate_payment(params) do
      {:ok, %{reference: reference} = resp} ->
        create_chunk_payment(checked, store, reference, resp)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_chunk_payment(
         %{plan: plan, amount: amount, buyer_params: buyer_params, first_chunk?: first_chunk?},
         store,
         reference,
         resp
       ) do
    case Emakola.Payments.create_payment(
           %{
             store_id: store.id,
             susu_plan_id: plan.id,
             amount: amount,
             currency: store.currency || "GHS",
             gateway: :paystack,
             gateway_reference: reference,
             metadata: susu_payment_metadata(first_chunk?, buyer_params),
             payout_held: true,
             payout_hold_reason: "susu_plan"
           },
           authorize?: false
         ) do
      {:ok, payment} -> {:ok, %{payment: payment, gateway: resp}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp susu_payment_metadata(true, buyer_params),
    do: %{"payment_method" => "susu_chunk", "susu_buyer" => buyer_params}

  defp susu_payment_metadata(false, _buyer_params), do: %{"payment_method" => "susu_chunk"}

  defp susu_page_url(plan), do: "#{EmakolaWeb.Endpoint.url()}/susu/#{plan.code}"

  # Email for the gateway charge: the buyer's own (or a phone placeholder,
  # same deterministic derivation checkout uses) when this chunk carries
  # buyer_params; otherwise (a returning buyer topping up an already-active
  # plan) the plan's already-resolved customer, falling back to the store's
  # contact address — mirrors `PayLinkLive.customer_email/2`.
  defp resolve_email(plan, store, buyer_params) do
    presence(buyer_params["email"]) ||
      case presence(buyer_params["phone"]) do
        nil -> customer_or_store_email(plan, store)
        phone -> CheckoutService.phone_placeholder_email(phone)
      end
  end

  defp customer_or_store_email(%SusuPlan{customer_id: nil}, store),
    do: store_fallback_email(store)

  defp customer_or_store_email(%SusuPlan{customer_id: customer_id}, store) do
    case Ash.get(Emakola.Customers.Customer, customer_id, authorize?: false) do
      {:ok, %{email: email}} when not is_nil(email) -> to_string(email)
      _ -> store_fallback_email(store)
    end
  end

  defp store_fallback_email(store),
    do: Map.get(store, :contact_email) || "checkout+#{store.slug}@emakola.com"

  # -- Confirmation ------------------------------------------------------

  # Phase 1: lock the plan row, resolve idempotency + plan-usability, and —
  # for the first confirmed chunk — activate (customer resolution, delivery
  # address, status -> :active). All pure Ash/Ecto writes with no
  # DB-constraint risk, so safe to run inside this lock. Stock reservation
  # deliberately does NOT happen here (see `confirm_chunk/1`'s doc).
  defp prepare(plan_id, payment_id) do
    {:ok, result} =
      Repo.transaction(fn ->
        row = Repo.one(locked_plan_query(plan_id))
        fresh_payment = Ash.get!(Payment, payment_id, authorize?: false)

        cond do
          already_counted?(fresh_payment) ->
            :short_circuited

          is_nil(row) or row.status not in ["pending", "active"] ->
            flag_for_refund(fresh_payment, plan_id)
            :short_circuited

          row.status == "pending" ->
            plan = Ash.get!(SusuPlan, plan_id, authorize?: false)
            activated = activate_plan!(plan, fresh_payment)

            case activated.type do
              :catalog -> {:activate_catalog, activated, fresh_payment}
              :custom -> {:record, activated, fresh_payment}
            end

          true ->
            plan = Ash.get!(SusuPlan, plan_id, authorize?: false)
            {:record, plan, fresh_payment}
        end
      end)

    result
  end

  # Phase 2: re-lock the plan (fresh — stock reservation, if it ran, was a
  # separate transaction and may have changed nothing we care about here
  # beyond `stock_reserved`) and record the contribution, guarding once
  # more against a delta that would overshoot `total_amount`.
  defp finish_recording(plan_id, plan, payment) do
    Repo.transaction(fn ->
      _row = Repo.one(locked_plan_query(plan_id))
      fresh_plan = Ash.get!(SusuPlan, plan.id, authorize?: false)

      if valid_contribution_amount?(payment.amount, fresh_plan) do
        contributed =
          Emakola.Orders.record_susu_contribution!(
            fresh_plan,
            %{amount_delta: payment.amount},
            authorize?: false
          )

        mark_counted!(payment)
        maybe_complete(contributed)
      else
        flag_for_refund(payment, plan_id)
      end
    end)

    :ok
  end

  defp valid_contribution_amount?(amount, plan) do
    is_integer(amount) and amount > 0 and amount <= SusuPlan.remaining(plan)
  end

  defp activate_plan!(plan, payment) do
    buyer = (payment.metadata || %{})["susu_buyer"] || %{}

    email =
      presence(buyer["email"]) || CheckoutService.phone_placeholder_email(buyer["phone"] || "")

    customer =
      Emakola.Customers.Customer
      |> Ash.ActionInput.for_action(:find_or_create, %{
        email: email,
        store_id: plan.store_id,
        name: buyer["name"],
        phone: buyer["phone"]
      })
      |> Ash.run_action!()

    Emakola.Orders.activate_susu_plan!(
      plan,
      %{customer_id: customer.id, delivery_address: delivery_address(plan, buyer)},
      authorize?: false
    )
  end

  defp delivery_address(%SusuPlan{collect_delivery: true}, buyer),
    do: %{"name" => buyer["name"], "phone" => buyer["phone"], "address" => buyer["address"]}

  defp delivery_address(%SusuPlan{collect_delivery: false}, _buyer), do: nil

  defp maybe_complete(%SusuPlan{contributed_amount: c, total_amount: t} = plan) when c == t do
    completed = Emakola.Orders.complete_susu_plan!(plan, authorize?: false)
    enqueue_completion_worker(completed.id)
  end

  defp maybe_complete(_plan), do: :ok

  defp enqueue_completion_worker(plan_id) do
    %{"susu_plan_id" => plan_id}
    |> Emakola.Payments.Workers.SusuCompletionWorker.new()
    |> Oban.insert!()
  end

  defp already_counted?(%Payment{metadata: metadata}),
    do: Map.get(metadata || %{}, "susu_counted") == true

  defp mark_counted!(payment) do
    payment
    |> Ash.Changeset.for_update(:update, %{
      metadata: Map.put(payment.metadata || %{}, "susu_counted", true)
    })
    |> Ash.update!(authorize?: false)
  end

  # Mirrors `PayLinkClaim.flag_for_refund/2`'s exact dedup-guard shape,
  # adapted to Payment's `metadata` map (Payment has no `notes` column).
  defp flag_for_refund(payment, plan_id) do
    note = Map.get(payment.metadata || %{}, "refund_note", "")

    if String.contains?(note, @refund_note) do
      :ok
    else
      Logger.error(
        "[susu_chunks] plan #{plan_id} not active — payment #{payment.id} needs a refund"
      )

      updated_note = String.trim("#{note}\n#{@refund_note}")

      payment
      |> Ash.Changeset.for_update(:update, %{
        metadata: Map.put(payment.metadata || %{}, "refund_note", updated_note)
      })
      |> Ash.update!(authorize?: false)
    end
  end

  defp presence(nil), do: nil

  defp presence(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: value)

  defp presence(_value), do: nil
end
