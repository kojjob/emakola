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

  defp exact_allocations(members, amount) do
    allocations =
      Enum.map(
        members,
        &%{merchant_id: &1.merchant_id, role: &1.role, amount: div(amount * &1.split_bps, 10_000)}
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

    cond do
      normalized == [] or length(normalized) > @max_members ->
        {:error, :invalid_team_size}

      Enum.any?(
        normalized,
        &(&1.role not in @roles or not is_integer(&1.split_bps) or not is_binary(&1.merchant_id))
      ) ->
        {:error, :invalid_allocation}

      length(Enum.uniq(ids)) != length(ids) ->
        {:error, :duplicate_member}

      Enum.count(normalized, &(&1.role == :owner)) != 1 ->
        {:error, :owner_required}

      not Enum.any?(normalized, &(&1.merchant_id == actor.id and &1.role == :owner)) ->
        {:error, :actor_must_be_owner}

      Enum.any?(normalized, &(&1.split_bps <= 0)) ->
        {:error, :split_must_be_positive}

      Enum.sum(Enum.map(normalized, & &1.split_bps)) != 10_000 ->
        {:error, :split_total_must_equal_10000}

      Enum.any?(ids, &(not merchant_exists?(&1))) ->
        {:error, :merchant_not_found}

      true ->
        {:ok, normalized}
    end
  end

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
