defmodule EmakolaWeb.Hooks.RequireAuth do
  @moduledoc """
  LiveView on_mount hook that redirects unauthenticated users to the login page.
  Must be used after AssignDefaults which loads current_user and current_merchant.

  Considers a user authenticated only if current_merchant is non-nil —
  a platform-staff session (current_user) does not grant merchant admin access.
  """
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    merchant = socket.assigns[:current_merchant]

    cond do
      is_nil(merchant) ->
        {:halt, push_navigate(socket, to: "/auth/login")}

      # A session issued before the gate, or one whose verification was
      # revoked, must not keep its run of the app.
      not Emakola.Accounts.access_allowed?(merchant) ->
        {:halt, push_navigate(socket, to: "/auth/verify?email=#{to_string(merchant.email)}")}

      true ->
        {:cont, socket}
    end
  end
end
