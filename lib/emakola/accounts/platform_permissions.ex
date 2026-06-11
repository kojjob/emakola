defmodule Emakola.Accounts.PlatformPermissions do
  @moduledoc """
  Catalog of fine-grained platform-staff permissions.

  Owners (`is_owner: true`) bypass permission checks entirely; deactivated
  users are always denied. Use `cast_list/1` to safely cast user-supplied
  permission strings — invalid entries are dropped.
  """

  @permissions [
    :manage_stores,
    :manage_merchants,
    :manage_team,
    :view_audit_log,
    :manage_billing,
    :manage_settings
  ]

  @spec all() :: [atom()]
  def all, do: @permissions

  @spec allowed?(map() | nil, atom()) :: boolean()
  def allowed?(nil, _permission), do: false

  def allowed?(%{deactivated_at: deactivated_at}, _permission)
      when not is_nil(deactivated_at),
      do: false

  def allowed?(%{is_owner: true}, _permission), do: true

  def allowed?(%{platform_permissions: permissions}, permission) when is_list(permissions),
    do: permission in permissions

  def allowed?(_user, _permission), do: false

  @spec valid?(term()) :: boolean()
  def valid?(permission), do: permission in @permissions

  @spec cast_list([String.t() | atom()]) :: [atom()]
  def cast_list(values) when is_list(values) do
    values
    |> Enum.map(&Emakola.SafeAtom.to_atom_in(&1, @permissions, nil))
    |> Enum.reject(&is_nil/1)
  end
end
