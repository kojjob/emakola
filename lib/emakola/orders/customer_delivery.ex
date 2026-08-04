defmodule Emakola.Orders.CustomerDelivery do
  @moduledoc """
  Proof of delivery for a **customer** order — the leg where delivery fraud
  actually happens.

  `FulfillmentDeliveryProof` (a short-lived, attempt-capped OTP the buyer reads
  to the courier) already existed, but its only caller was
  `Emakola.Suppliers.InboundFulfillment`, which covers the wholesaler-to-merchant
  leg and scopes every lookup by `supplier.linked_store_id`. On a customer order
  there is no supplier in that position, so none of it was reachable: a merchant
  marked their own order delivered, which stamped `release_after`, and
  `:auto_timer` paid them out. Self-attested delivery has no counterparty.

  This module is the same mechanism scoped by `store_id` instead — the
  fulfilment's own store. It deliberately does not try to generalise
  `InboundFulfillment`: the two differ precisely in *who is allowed to ask*,
  which is the security boundary, and collapsing them would put that decision
  behind a flag.

  The OTP is the only release path in the system that requires a second party
  to assent. `:buyer_confirmed` needs the buyer to find the tracking page, and
  `:auto_timer` is time passing — neither is proof.
  """

  require Ash.Query

  alias Emakola.Orders.Fulfillment
  alias Emakola.Orders.FulfillmentDeliveryProof

  @otp_ttl_seconds 600
  @max_attempts 5

  @doc """
  Issues a delivery code for a shipped fulfilment and sends it to the buyer.

  Rate limited per fulfilment: three sends per ten minutes, so a merchant
  cannot brute-force a buyer's phone with repeated codes.

  `return_code: true` returns the plaintext code instead of the proof record.
  It exists for tests — the code is otherwise never returned to the caller,
  because the merchant must not learn a code the buyer alone should hold.
  """
  @spec request_delivery_code(binary(), binary(), keyword()) ::
          {:ok, FulfillmentDeliveryProof.t() | binary()} | {:error, term()}
  def request_delivery_code(store_id, fulfillment_id, opts \\ []) do
    with {:ok, fulfillment} <- fulfillment_for(store_id, fulfillment_id),
         :ok <- rate_limit(fulfillment_id),
         :ok <- require_shipped(fulfillment),
         {:ok, phone} <- customer_phone(fulfillment.order),
         code <- generate_code(),
         {:ok, proof} <- persist_code(fulfillment, phone, code),
         :ok <- deliver_code(phone, code, fulfillment) do
      if Keyword.get(opts, :return_code, false), do: {:ok, code}, else: {:ok, proof}
    end
  end

  @doc """
  Verifies a code read out by the buyer and, on success, marks the fulfilment
  delivered — which releases any buyer-protection hold via the resource's own
  `ReleaseProtectionHoldOnVerify` change.

  The row is locked `FOR UPDATE` for the whole check-and-increment so two
  concurrent guesses cannot both slip past the attempt cap.
  """
  @spec verify_delivery(binary(), binary(), binary()) :: {:ok, Fulfillment.t()} | {:error, term()}
  def verify_delivery(store_id, fulfillment_id, code) do
    Emakola.Repo.transaction(fn ->
      case locked_proof(store_id, fulfillment_id) do
        nil ->
          {:validation_error, :delivery_code_not_requested}

        proof ->
          case validate_code(proof, code) do
            :ok -> verify_and_deliver!(proof)
            {:error, reason} -> {:validation_error, reason}
          end
      end
    end)
    |> unwrap_transaction()
  end

  # -- lookup -----------------------------------------------------------------

  # Scoped by the fulfilment's own store. A merchant can only ever act on their
  # own store's fulfilments, and a missing row is :not_found rather than
  # :forbidden so the caller cannot probe for another store's ids.
  defp fulfillment_for(store_id, fulfillment_id) do
    Fulfillment
    |> Ash.Query.filter(id == ^fulfillment_id and store_id == ^store_id)
    |> Ash.Query.load([:delivery_proof, order: :customer])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, fulfillment} -> {:ok, fulfillment}
      error -> error
    end
  end

  defp locked_proof(store_id, fulfillment_id) do
    FulfillmentDeliveryProof
    |> Ash.Query.filter(fulfillment_id == ^fulfillment_id and fulfillment.store_id == ^store_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.Query.load(:fulfillment)
    |> Ash.read_one!(authorize?: false)
  end

  # -- issue ------------------------------------------------------------------

  defp rate_limit(fulfillment_id) do
    case Emakola.RateLimit.check_rate("delivery_otp:customer:#{fulfillment_id}", 3, 600_000) do
      {:allow, _count} -> :ok
      {:deny, _count} -> {:error, :rate_limited}
    end
  end

  defp require_shipped(%{status: :shipped}), do: :ok
  defp require_shipped(_fulfillment), do: {:error, :fulfillment_not_shipped}

  defp customer_phone(%{customer: %{phone: phone}}) when is_binary(phone) and phone != "",
    do: {:ok, phone}

  defp customer_phone(%{shipping_address: address}) when is_map(address) do
    case Map.get(address, "phone") || Map.get(address, :phone) do
      phone when is_binary(phone) and phone != "" -> {:ok, phone}
      _ -> {:error, :customer_phone_missing}
    end
  end

  defp customer_phone(_order), do: {:error, :customer_phone_missing}

  defp generate_code do
    number = rem(:binary.decode_unsigned(:crypto.strong_rand_bytes(4)), 900_000) + 100_000
    Integer.to_string(number)
  end

  # Only the hash and a masked recipient are stored. The plaintext code exists
  # in memory long enough to be sent and nowhere else.
  defp persist_code(fulfillment, phone, code) do
    attrs = %{
      code_hash: Bcrypt.hash_pwd_salt(code),
      expires_at: DateTime.add(DateTime.utc_now(), @otp_ttl_seconds, :second),
      sent_to: mask_phone(phone)
    }

    case fulfillment.delivery_proof do
      %FulfillmentDeliveryProof{} = proof ->
        proof
        |> Ash.Changeset.for_update(:reissue, attrs)
        |> Ash.update(authorize?: false)

      _ ->
        attrs
        |> Map.put(:fulfillment_id, fulfillment.id)
        |> Emakola.Orders.issue_fulfillment_delivery_proof(authorize?: false)
    end
  end

  defp mask_phone(phone) do
    visible = String.slice(phone, -4, 4)
    String.duplicate("•", max(String.length(phone) - 4, 0)) <> visible
  end

  defp deliver_code(phone, code, fulfillment) do
    message =
      "Your Makola delivery code is #{code}. Give it to the courier only after you have received order #{fulfillment.order.order_number}. It expires in 10 minutes."

    case sms_provider().send_sms(phone, message, store_id: fulfillment.store_id) do
      {:ok, _result} -> :ok
      _error -> {:error, :delivery_failed}
    end
  end

  # -- verify -----------------------------------------------------------------

  defp validate_code(%{verified_at: verified_at}, _code) when not is_nil(verified_at),
    do: {:error, :already_verified}

  defp validate_code(%{fulfillment: %{status: status}}, _code) when status != :shipped,
    do: {:error, :fulfillment_not_shipped}

  defp validate_code(%{attempts: attempts}, _code) when attempts >= @max_attempts,
    do: {:error, :too_many_attempts}

  defp validate_code(proof, code) do
    cond do
      DateTime.compare(proof.expires_at, DateTime.utc_now()) != :gt ->
        {:error, :expired}

      is_binary(code) and Bcrypt.verify_pass(String.trim(code), proof.code_hash) ->
        :ok

      true ->
        proof
        |> Ash.Changeset.for_update(:record_attempt, %{})
        |> Ash.update!(authorize?: false)

        {:error, :invalid_code}
    end
  end

  defp verify_and_deliver!(proof) do
    proof
    |> Ash.Changeset.for_update(:verify, %{})
    |> Ash.update!(authorize?: false)

    Emakola.Orders.mark_fulfillment_delivered!(proof.fulfillment, authorize?: false)
  end

  defp sms_provider,
    do: Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)

  defp unwrap_transaction({:ok, {:validation_error, reason}}), do: {:error, reason}
  defp unwrap_transaction({:ok, result}), do: {:ok, result}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
