defmodule Emakola.FeatureFlags do
  use Ash.Domain

  resources do
    resource Emakola.FeatureFlags.FeatureFlag do
      define(:create_flag, action: :create)
      define(:list_flags, action: :read)
      define(:get_flag, action: :read, get_by: [:id])
      define(:get_flag_by_key, action: :read, get_by: [:key])
    end
  end

  @doc "Check if a feature is enabled for a given org/plan context."
  def enabled?(key, opts \\ []) when is_atom(key) or is_binary(key) do
    key = to_string(key)
    org_id = Keyword.get(opts, :org_id)
    plan_slug = Keyword.get(opts, :plan_slug)

    case get_flag_by_key(key) do
      {:ok, flag} ->
        evaluate_flag(flag, org_id, plan_slug)

      {:error, _} ->
        false
    end
  end

  defp evaluate_flag(%{enabled: false}, _org_id, _plan_slug), do: false

  defp evaluate_flag(%{enabled: true, required_plan: nil}, _org_id, _plan_slug), do: true

  defp evaluate_flag(%{enabled: true, required_plan: _required}, _org_id, nil), do: false

  defp evaluate_flag(%{enabled: true, required_plan: required}, _org_id, plan_slug) do
    plan_hierarchy = ["free", "starter", "pro", "enterprise"]
    required_idx = Enum.find_index(plan_hierarchy, &(&1 == required))
    current_idx = Enum.find_index(plan_hierarchy, &(&1 == plan_slug))

    cond do
      is_nil(required_idx) or is_nil(current_idx) -> false
      current_idx >= required_idx -> true
      true -> false
    end
  end
end
