defmodule EmakolaWeb.Hooks.RedirectIfPlatformStaff do
  @moduledoc """
  LiveView on_mount hook for the platform login page: active platform staff
  who already hold a session are sent straight to /platform. Must run after
  AssignDefaults, which resolves `current_user` from the platform session.
  """
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if Emakola.Accounts.PlatformPermissions.staff?(socket.assigns[:current_user]) do
      {:halt, redirect(socket, to: "/platform")}
    else
      {:cont, socket}
    end
  end
end
