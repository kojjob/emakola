defmodule EmakolaWeb.Hooks.RequirePlatformStaff do
  @moduledoc """
  LiveView on_mount hook that restricts access to active platform staff:
  users who are not deactivated and are either owners or hold at least one
  platform permission. Must run after AssignDefaults, which resolves
  `current_user` from the platform session.
  """
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if Emakola.Accounts.PlatformPermissions.staff?(socket.assigns[:current_user]) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You don't have access to the platform admin.")
       |> redirect(to: "/")}
    end
  end
end
