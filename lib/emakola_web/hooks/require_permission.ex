defmodule EmakolaWeb.Hooks.RequirePermission do
  @moduledoc """
  LiveView on_mount hook that requires a specific platform permission:

      on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_team}

  Must run after AssignDefaults (and, in practice, RequirePlatformStaff —
  the user is already known to be staff). Staff lacking the permission are
  bounced to /platform, not the storefront.
  """
  import Phoenix.LiveView

  def on_mount(permission, _params, _session, socket) when is_atom(permission) do
    if Emakola.Accounts.PlatformPermissions.allowed?(socket.assigns[:current_user], permission) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You don't have permission to access that page.")
       |> redirect(to: "/platform")}
    end
  end
end
