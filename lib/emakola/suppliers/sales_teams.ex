defmodule Emakola.Suppliers.SalesTeams do
  @moduledoc "Flat consent-based commerce teams; rewards attach only to a declared transaction role."

  require Ash.Query
  alias Emakola.Suppliers.{SalesTeam, SalesTeamMember}

  @roles [:owner, :content, :seller, :support]
  @max_members 8

  def create(actor, store_id, name, allocations) when is_list(allocations) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, normalized} <- validate_allocations(actor, allocations) do
      Emakola.Repo.transaction(fn ->
        team =
          SalesTeam
          |> Ash.Changeset.for_create(:create, %{
            store_id: store_id,
            name: String.trim(name),
            created_by_id: actor.id
          })
          |> Ash.create!(authorize?: false)

        Enum.each(normalized, fn allocation ->
          owner? = allocation.merchant_id == actor.id

          SalesTeamMember
          |> Ash.Changeset.for_create(
            :invite,
            Map.merge(allocation, %{
              team_id: team.id,
              status: if(owner?, do: :active, else: :invited),
              consented_at: if(owner?, do: DateTime.utc_now(), else: nil)
            })
          )
          |> Ash.create!(authorize?: false)
        end)

        Ash.load!(team, [members: :merchant], authorize?: false)
      end)
      |> normalize_transaction()
    end
  end

  def list(actor, store_id) do
    with :ok <- ensure_store_access(actor, store_id) do
      Emakola.Suppliers.list_sales_teams_for_store(store_id, authorize?: false)
    end
  end

  def invitations(%Emakola.Accounts.Merchant{id: merchant_id}) do
    SalesTeamMember
    |> Ash.Query.filter(merchant_id == ^merchant_id and status == :invited)
    |> Ash.Query.load([:team])
    |> Ash.read(authorize?: false)
  end

  def invitations(_actor), do: {:error, :forbidden}

  def public_economics(team_id, store_id) when is_binary(team_id) do
    with {:ok, team} <- Ash.get(SalesTeam, team_id, authorize?: false),
         true <- team.store_id == store_id,
         {:ok, allocations} <- allocate(team, 10_000) do
      {:ok,
       %{
         id: team.id,
         name: team.name,
         members:
           Enum.map(allocations, fn allocation ->
             %{role: allocation.role, percent: div(allocation.split_bps, 100)}
           end)
       }}
    else
      _ -> {:error, :not_available}
    end
  end

  def public_economics(_team_id, _store_id), do: {:error, :not_available}

  def accept(actor, member_id) do
    with {:ok, member} <- Ash.get(SalesTeamMember, member_id, authorize?: false),
         true <- member.merchant_id == actor.id do
      member |> Ash.Changeset.for_update(:accept, %{}) |> Ash.update(authorize?: false)
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  def decline(actor, member_id) do
    with {:ok, member} <- Ash.get(SalesTeamMember, member_id, authorize?: false),
         true <- member.merchant_id == actor.id do
      member |> Ash.Changeset.for_update(:decline, %{}) |> Ash.update(authorize?: false)
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  def allocate(team, amount) when is_integer(amount) and amount >= 0 do
    team = Ash.load!(team, :members, authorize?: false)

    cond do
      team.status != :active ->
        {:error, :team_closed}

      Enum.any?(team.members, &(&1.status != :active or is_nil(&1.consented_at))) ->
        {:error, :consent_incomplete}

      Enum.sum(Enum.map(team.members, & &1.split_bps)) != 10_000 ->
        {:error, :invalid_split_total}

      true ->
        {:ok, exact_allocations(team.members, amount)}
    end
  end

  def settle_attributed_payment(%{order_id: nil}), do: :ok

  def settle_attributed_payment(payment) do
    order =
      Ash.get!(Emakola.Orders.Order, payment.order_id,
        authorize?: false,
        tenant: payment.store_id
      )

    team_id = order.attribution["sales_team_id"]

    with team_id when is_binary(team_id) <- team_id,
         {:ok, team} <- Ash.get(SalesTeam, team_id, authorize?: false),
         true <- team.store_id == payment.store_id,
         {:ok, base} <- settlement_base(payment.id),
         {:ok, allocations} <- allocate(team, base) do
      persist_settlements(payment, order, team, allocations, base)
    else
      _ineligible -> :ok
    end
  end

  def reverse_attributed_payment(payment) do
    settlements =
      Emakola.Suppliers.SalesTeamSettlement
      |> Ash.Query.filter(payment_id == ^payment.id)
      |> Ash.read!(authorize?: false)

    Enum.each(settlements, fn settlement ->
      reversed = div(settlement.amount * payment.refunded_amount, payment.amount)

      if reversed > settlement.reversed_amount do
        settlement
        |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed})
        |> Ash.update!(authorize?: false)
      end
    end)

    :ok
  end

  defp exact_allocations(members, amount) do
    allocations =
      Enum.map(
        members,
        &%{
          team_member_id: &1.id,
          merchant_id: &1.merchant_id,
          role: &1.role,
          split_bps: &1.split_bps,
          amount: div(amount * &1.split_bps, 10_000)
        }
      )

    remainder = amount - Enum.sum(Enum.map(allocations, & &1.amount))
    owner_index = Enum.find_index(allocations, &(&1.role == :owner)) || 0

    List.update_at(
      allocations,
      owner_index,
      &Map.update!(&1, :amount, fn value -> value + remainder end)
    )
  end

  defp validate_allocations(actor, allocations) do
    normalized = Enum.map(allocations, &normalize_allocation/1)
    ids = Enum.map(normalized, & &1.merchant_id)

    checks = [
      {invalid_team_size?(normalized), :invalid_team_size},
      {invalid_allocation?(normalized), :invalid_allocation},
      {duplicate_members?(ids), :duplicate_member},
      {owner_count_invalid?(normalized), :owner_required},
      {actor_not_owner?(actor, normalized), :actor_must_be_owner},
      {non_positive_split?(normalized), :split_must_be_positive},
      {split_total_invalid?(normalized), :split_total_must_equal_10000},
      {missing_merchant?(ids), :merchant_not_found}
    ]

    case Enum.find(checks, fn {failed?, _reason} -> failed? end) do
      nil -> {:ok, normalized}
      {true, reason} -> {:error, reason}
    end
  end

  defp invalid_team_size?(allocations),
    do: allocations == [] or length(allocations) > @max_members

  defp invalid_allocation?(allocations) do
    Enum.any?(allocations, fn allocation ->
      allocation.role not in @roles or not is_integer(allocation.split_bps) or
        not is_binary(allocation.merchant_id)
    end)
  end

  defp duplicate_members?(ids), do: length(Enum.uniq(ids)) != length(ids)
  defp owner_count_invalid?(allocations), do: Enum.count(allocations, &(&1.role == :owner)) != 1

  defp actor_not_owner?(actor, allocations),
    do: not Enum.any?(allocations, &(&1.merchant_id == actor.id and &1.role == :owner))

  defp non_positive_split?(allocations), do: Enum.any?(allocations, &(&1.split_bps <= 0))

  defp split_total_invalid?(allocations),
    do: Enum.sum(Enum.map(allocations, & &1.split_bps)) != 10_000

  defp missing_merchant?(ids), do: Enum.any?(ids, &(not merchant_exists?(&1)))

  defp normalize_allocation(allocation) do
    role = value(allocation, :role)
    role = if is_binary(role), do: Enum.find(@roles, &(Atom.to_string(&1) == role)), else: role
    split = value(allocation, :split_bps)
    split = if is_binary(split), do: parse_split(split), else: split
    %{merchant_id: value(allocation, :merchant_id), role: role, split_bps: split}
  end

  defp parse_split(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp merchant_exists?(id),
    do: match?({:ok, _}, Ash.get(Emakola.Accounts.Merchant, id, authorize?: false))

  defp settlement_base(payment_id) do
    allocations =
      Emakola.Payments.PaymentSplit
      |> Ash.Query.filter(payment_id == ^payment_id and role in [:merchant, :dropshipper])
      |> Ash.read!(authorize?: false)

    case allocations do
      [allocation] when allocation.amount >= 0 -> {:ok, allocation.amount}
      _ -> {:error, :ineligible_settlement_base}
    end
  end

  # Transactional and per-member idempotent: a crash that persisted only some
  # member rows is healed by the retry (missing members are filled in), and the
  # transaction prevents new partial states. The (payment_id, team_member_id)
  # unique identity remains the last line of defense against duplicates.
  defp persist_settlements(payment, order, team, allocations, base) do
    {:ok, :ok} =
      Emakola.Repo.transaction(fn ->
        settled_member_ids =
          Emakola.Suppliers.SalesTeamSettlement
          |> Ash.Query.filter(payment_id == ^payment.id)
          |> Ash.read!(authorize?: false)
          |> MapSet.new(& &1.team_member_id)

        now = DateTime.utc_now()

        allocations
        |> Enum.reject(&MapSet.member?(settled_member_ids, &1.team_member_id))
        |> Enum.each(fn allocation ->
          Emakola.Suppliers.SalesTeamSettlement
          |> Ash.Changeset.for_create(:create, %{
            store_id: payment.store_id,
            order_id: order.id,
            payment_id: payment.id,
            team_id: team.id,
            team_member_id: allocation.team_member_id,
            merchant_id: allocation.merchant_id,
            role: allocation.role,
            split_bps: allocation.split_bps,
            settlement_base: base,
            amount: allocation.amount,
            settled_at: now
          })
          |> Ash.create!(authorize?: false)
        end)

        :ok
      end)

    :ok
  end

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

  defp ensure_store_access(_actor, _store_id), do: {:error, :forbidden}
end
