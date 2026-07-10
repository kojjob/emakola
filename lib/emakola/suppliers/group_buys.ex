defmodule Emakola.Suppliers.GroupBuys do
  @moduledoc "Authorized threshold-campaign lifecycle with exact pricing and explicit refund dates."

  require Ash.Query

  alias Emakola.Suppliers.{GroupBuyCampaign, GroupBuyCommitment, ListingImporter}

  def create(actor, store_id, attrs) do
    listing_id = value(attrs, :listing_id)
    listing_variant_id = value(attrs, :listing_variant_id)

    with {:ok, listing} <- authorized_listing(actor, store_id, listing_id),
         {:ok, listing} <-
           Ash.load(listing, [listing_variants: :offer_variant], authorize?: false),
         %{} = mapping <- Enum.find(listing.listing_variants, &(&1.id == listing_variant_id)),
         {:ok, normalized} <- normalize(attrs, mapping) do
      GroupBuyCampaign
      |> Ash.Changeset.for_create(
        :create,
        Map.merge(normalized, %{
          store_id: store_id,
          listing_id: listing.id,
          listing_variant_id: mapping.id
        })
      )
      |> Ash.create(authorize?: false)
    else
      nil -> {:error, :variant_not_found}
      error -> error
    end
  end

  def list(actor, store_id) do
    with :ok <- ensure_store_access(actor, store_id) do
      Emakola.Suppliers.list_group_buy_campaigns_for_store(store_id, authorize?: false)
    end
  end

  def open(actor, store_id, campaign_id) do
    with {:ok, campaign} <- authorized_campaign(actor, store_id, campaign_id),
         :ok <- future_deadline(campaign.deadline),
         :ok <- valid_refund_deadline(campaign.deadline, campaign.refund_deadline) do
      campaign |> Ash.Changeset.for_update(:open, %{}) |> Ash.update(authorize?: false)
    end
  end

  def reserve(campaign_id, customer_id, quantity) when is_integer(quantity) and quantity > 0 do
    Emakola.Repo.transaction(fn ->
      campaign = locked_campaign!(campaign_id)

      with :ok <- reservable?(campaign, quantity) do
        GroupBuyCommitment
        |> Ash.Changeset.for_create(:create, %{
          campaign_id: campaign.id,
          store_id: campaign.store_id,
          customer_id: customer_id,
          quantity: quantity,
          amount: campaign.unit_price * quantity,
          status: :pending
        })
        |> Ash.create!(authorize?: false)
      else
        {:error, reason} -> Emakola.Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  def confirm_paid(commitment_id, payment) do
    Emakola.Repo.transaction(fn ->
      commitment = locked_commitment!(commitment_id)
      campaign = locked_campaign!(commitment.campaign_id)

      with :ok <- payable?(commitment, payment),
           :ok <- reservable?(campaign, commitment.quantity) do
        paid =
          commitment
          |> Ash.Changeset.for_update(:mark_paid, %{payment_id: payment.id})
          |> Ash.update!(authorize?: false)

        updated =
          campaign
          |> Ash.Changeset.for_update(:record_paid_quantity, %{quantity: commitment.quantity})
          |> Ash.update!(authorize?: false)

        if updated.committed_quantity >= updated.threshold_quantity do
          updated |> Ash.Changeset.for_update(:mark_funded, %{}) |> Ash.update!(authorize?: false)
        end

        paid
      else
        {:error, reason} -> Emakola.Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  def expire_and_refund(campaign_id, gateway \\ payment_gateway()) do
    with {:ok, campaign} <- Ash.get(GroupBuyCampaign, campaign_id, authorize?: false),
         {:ok, campaign} <- cancel_if_due(campaign) do
      commitments =
        GroupBuyCommitment
        |> Ash.Query.filter(campaign_id == ^campaign.id)
        |> Ash.read!(authorize?: false)

      Enum.each(commitments, &cancel_pending/1)
      results = Enum.map(commitments, &refund_paid(&1, gateway))

      refreshed =
        GroupBuyCommitment
        |> Ash.Query.filter(campaign_id == ^campaign.id)
        |> Ash.read!(authorize?: false)

      if refreshed != [] and Enum.all?(refreshed, &(&1.status in [:cancelled, :refunded])) do
        campaign
        |> Ash.Changeset.for_update(:mark_refunded, %{})
        |> Ash.update!(authorize?: false)
      end

      {:ok, %{campaign_id: campaign.id, results: results}}
    end
  end

  defp normalize(attrs, mapping) do
    with {:ok, threshold} <- integer(value(attrs, :threshold_quantity), 2, 1_000),
         {:ok, unit_price} <- integer(value(attrs, :unit_price), 1, mapping.retail_price),
         true <- unit_price >= mapping.offer_variant.supplier_price,
         {:ok, deadline} <- datetime(value(attrs, :deadline)),
         {:ok, refund_deadline} <- datetime(value(attrs, :refund_deadline)),
         :ok <- future_deadline(deadline),
         :ok <- valid_refund_deadline(deadline, refund_deadline) do
      {:ok,
       %{
         title: value(attrs, :title),
         threshold_quantity: threshold,
         unit_price: unit_price,
         deadline: deadline,
         refund_deadline: refund_deadline,
         terms: %{"automatic_refund_if_threshold_missed" => true, "customer_price_locked" => true}
       }}
    else
      false -> {:error, :price_below_supplier_floor}
      error -> error
    end
  end

  defp cancel_if_due(%{status: :refunded} = campaign), do: {:ok, campaign}
  defp cancel_if_due(%{status: :cancelled} = campaign), do: {:ok, campaign}

  defp cancel_if_due(%{status: :open} = campaign) do
    if DateTime.compare(DateTime.utc_now(), campaign.deadline) in [:eq, :gt] and
         campaign.committed_quantity < campaign.threshold_quantity do
      campaign |> Ash.Changeset.for_update(:cancel, %{}) |> Ash.update(authorize?: false)
    else
      {:error, :campaign_not_due}
    end
  end

  defp cancel_if_due(_campaign), do: {:error, :campaign_not_due}

  defp cancel_pending(%{status: :pending} = commitment),
    do: commitment |> Ash.Changeset.for_update(:cancel, %{}) |> Ash.update!(authorize?: false)

  defp cancel_pending(_commitment), do: :ok

  defp refund_paid(%{status: :paid, payment_id: payment_id} = commitment, gateway)
       when not is_nil(payment_id) do
    claimed =
      commitment |> Ash.Changeset.for_update(:claim_refund, %{}) |> Ash.update!(authorize?: false)

    payment = Ash.get!(Emakola.Payments.Payment, payment_id, authorize?: false)

    case gateway.process_refund(payment.gateway_reference, commitment.amount) do
      {:ok, response} ->
        reference = Map.get(response, :refund_reference) || Map.get(response, "refund_reference")

        _payment =
          payment
          |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: commitment.amount})
          |> Ash.update!(authorize?: false)

        _commitment =
          claimed
          |> Ash.Changeset.for_update(:mark_refunded, %{refund_reference: reference})
          |> Ash.update!(authorize?: false)

        {:ok, commitment.id}

      {:error, reason} ->
        _commitment =
          claimed
          |> Ash.Changeset.for_update(:mark_refund_failed, %{
            refund_error: inspect(reason) |> String.slice(0, 500)
          })
          |> Ash.update!(authorize?: false)

        {:error, commitment.id, reason}
    end
  end

  defp refund_paid(%{status: :paid} = commitment, _gateway) do
    claimed =
      commitment |> Ash.Changeset.for_update(:claim_refund, %{}) |> Ash.update!(authorize?: false)

    _commitment =
      claimed
      |> Ash.Changeset.for_update(:mark_refund_failed, %{refund_error: "payment_missing"})
      |> Ash.update!(authorize?: false)

    {:error, commitment.id, :payment_missing}
  end

  defp refund_paid(commitment, _gateway), do: {:skipped, commitment.id, commitment.status}

  defp payment_gateway,
    do: Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)

  defp authorized_listing(actor, store_id, listing_id) do
    with {:ok, listings} <- ListingImporter.list(actor, store_id),
         %{} = listing <- Enum.find(listings, &(&1.id == listing_id)) do
      {:ok, listing}
    else
      nil -> {:error, :forbidden}
      error -> error
    end
  end

  defp authorized_campaign(actor, store_id, campaign_id) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, campaign} <- Ash.get(GroupBuyCampaign, campaign_id, authorize?: false),
         true <- campaign.store_id == store_id do
      {:ok, campaign}
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  defp reservable?(
         %{
           status: :open,
           deadline: deadline,
           committed_quantity: committed,
           threshold_quantity: threshold
         },
         quantity
       ) do
    cond do
      DateTime.compare(DateTime.utc_now(), deadline) != :lt -> {:error, :campaign_closed}
      committed + quantity > threshold -> {:error, :quantity_exceeds_remaining}
      true -> :ok
    end
  end

  defp reservable?(_campaign, _quantity), do: {:error, :campaign_closed}

  defp payable?(%{status: :pending, amount: amount}, %{status: :success, amount: amount}), do: :ok
  defp payable?(_commitment, _payment), do: {:error, :payment_mismatch}

  defp locked_campaign!(id) do
    GroupBuyCampaign
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end

  defp locked_commitment!(id) do
    GroupBuyCommitment
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end

  defp future_deadline(deadline),
    do:
      if(DateTime.compare(deadline, DateTime.utc_now()) == :gt,
        do: :ok,
        else: {:error, :deadline_must_be_future}
      )

  defp valid_refund_deadline(deadline, refund),
    do:
      if(DateTime.compare(refund, deadline) in [:eq, :gt],
        do: :ok,
        else: {:error, :refund_deadline_invalid}
      )

  defp value(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, to_string(key))

  defp integer(value, min, max) when is_integer(value) and value >= min and value <= max,
    do: {:ok, value}

  defp integer(value, min, max) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> integer(number, min, max)
      _ -> {:error, :invalid_number}
    end
  end

  defp integer(_value, _min, _max), do: {:error, :invalid_number}
  defp datetime(%DateTime{} = value), do: {:ok, value}

  defp datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> {:error, :invalid_datetime}
    end
  end

  defp datetime(_value), do: {:error, :invalid_datetime}
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

  defp ensure_store_access(_actor, _store_id), do: {:error, :forbidden}
end
