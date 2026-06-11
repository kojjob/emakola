defmodule EmakolaWeb.Hooks.RequirePlatformAdmin do
  @moduledoc "LiveView on_mount hook that restricts access to platform admin users."
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && Map.get(user, :is_owner, false) == true do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You don't have access to the platform admin.")
       |> redirect(to: "/")}
    end
  end
end
