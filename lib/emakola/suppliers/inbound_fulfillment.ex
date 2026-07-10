defmodule Emakola.Suppliers.InboundFulfillment do
  @moduledoc "Authorized cross-store boundary for wholesaler-owned Earn fulfillments."

  require Ash.Query

  alias Emakola.Orders.{Fulfillment, FulfillmentDeliveryProof}

  @otp_ttl_seconds 600
  @max_attempts 5

  def list(actor, wholesaler_store_id) do
    with :ok <- ensure_store_access(actor, wholesaler_store_id) do
      Fulfillment
      |> Ash.Query.filter(supplier.linked_store_id == ^wholesaler_store_id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.load([:delivery_proof, :supplier, order: :customer, line_items: :variant])
      |> Ash.read(authorize?: false)
    end
  end

  def get(actor, wholesaler_store_id, fulfillment_id) do
    with :ok <- ensure_store_access(actor, wholesaler_store_id) do
      fulfillment_for(wholesaler_store_id, fulfillment_id)
    end
  end

  def mark_shipped(actor, wholesaler_store_id, fulfillment_id, tracking_number) do
    with {:ok, fulfillment} <- get(actor, wholesaler_store_id, fulfillment_id) do
      Emakola.Orders.mark_fulfillment_shipped(
        fulfillment,
        %{tracking_number: String.trim(tracking_number)},
        authorize?: false
      )
    end
  end

  def request_delivery_code(actor, wholesaler_store_id, fulfillment_id) do
    with {:ok, fulfillment} <- get(actor, wholesaler_store_id, fulfillment_id),
         :ok <- delivery_code_rate_limit(fulfillment_id),
         :ok <- require_shipped(fulfillment),
         {:ok, phone} <- customer_phone(fulfillment.order),
         code <- generate_code(),
         {:ok, proof} <- persist_code(fulfillment, phone, code),
         :ok <- deliver_code(phone, code, fulfillment) do
      {:ok, proof}
    end
  end

  def verify_delivery(actor, wholesaler_store_id, fulfillment_id, code) do
    with :ok <- ensure_store_access(actor, wholesaler_store_id) do
      Emakola.Repo.transaction(fn ->
        proof = locked_proof!(wholesaler_store_id, fulfillment_id)

        case validate_code(proof, code) do
          :ok -> verify_and_deliver!(proof)
          {:error, reason} -> {:validation_error, reason}
        end
      end)
      |> unwrap_transaction()
    end
  end

  defp fulfillment_for(store_id, fulfillment_id) do
    Fulfillment
    |> Ash.Query.filter(id == ^fulfillment_id and supplier.linked_store_id == ^store_id)
    |> Ash.Query.load([:delivery_proof, :supplier, order: :customer, line_items: :variant])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :not_found}
      result -> result
    end
  end

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

  defp locked_proof!(store_id, fulfillment_id) do
    FulfillmentDeliveryProof
    |> Ash.Query.filter(
      fulfillment_id == ^fulfillment_id and fulfillment.supplier.linked_store_id == ^store_id
    )
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.Query.load(:fulfillment)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> Emakola.Repo.rollback(:delivery_code_not_requested)
      proof -> proof
    end
  end

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

    delivered = Emakola.Orders.mark_fulfillment_delivered!(proof.fulfillment, authorize?: false)
    delivered
  end

  defp deliver_code(phone, code, fulfillment) do
    message =
      "Your Makola delivery code is #{code}. Give it to the courier only after receiving order #{fulfillment.order.order_number}. It expires in 10 minutes."

    case sms_provider().send_sms(phone, message, store_id: fulfillment.store_id) do
      {:ok, _result} -> :ok
      _error -> {:error, :delivery_failed}
    end
  end

  defp customer_phone(%{customer: %{phone: phone}}) when is_binary(phone) and phone != "",
    do: {:ok, phone}

  defp customer_phone(%{shipping_address: address}) when is_map(address) do
    case Map.get(address, "phone") || Map.get(address, :phone) do
      phone when is_binary(phone) and phone != "" -> {:ok, phone}
      _ -> {:error, :customer_phone_missing}
    end
  end

  defp customer_phone(_order), do: {:error, :customer_phone_missing}

  defp require_shipped(%{status: :shipped}), do: :ok
  defp require_shipped(_fulfillment), do: {:error, :fulfillment_not_shipped}

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [_membership]} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_actor, _store_id), do: {:error, :forbidden}

  defp delivery_code_rate_limit(fulfillment_id) do
    case Emakola.RateLimit.check_rate("delivery_otp:send:#{fulfillment_id}", 3, 600_000) do
      {:allow, _count} -> :ok
      {:deny, _count} -> {:error, :rate_limited}
    end
  end

  defp generate_code do
    number = rem(:binary.decode_unsigned(:crypto.strong_rand_bytes(4)), 900_000) + 100_000
    Integer.to_string(number)
  end

  defp mask_phone(phone) do
    visible = String.slice(phone, -4, 4)
    String.duplicate("•", max(String.length(phone) - 4, 0)) <> visible
  end

  defp sms_provider,
    do: Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)

  defp unwrap_transaction({:ok, {:validation_error, reason}}), do: {:error, reason}
  defp unwrap_transaction({:ok, result}), do: {:ok, result}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
