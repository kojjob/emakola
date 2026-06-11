defmodule EmakolaWeb.Hooks.RequireAuth do
  @moduledoc """
  LiveView on_mount hook that redirects unauthenticated users to the login page.
  Must be used after AssignDefaults which loads current_user and current_merchant.

  Considers a user authenticated only if current_merchant is non-nil —
  a platform-staff session (current_user) does not grant merchant admin access.
  """
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if socket.assigns[:current_merchant] do
      {:cont, socket}
    else
      {:halt, push_navigate(socket, to: "/auth/login")}
    end
  end
end
