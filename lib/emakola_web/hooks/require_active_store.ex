defmodule EmakolaWeb.Hooks.RequireActiveStore do
  @moduledoc """
  Locks a merchant out of the admin when the PLATFORM has suspended, blocked,
  or archived their store. Runs after `RequireAuth` in the `:app` live_session
  and sends them to `/store-locked`, which explains why.

  Only the platform lifecycle `status` gates access. A merchant who has merely
  closed their OWN store (`active == false`, `status == :active`) keeps full
  admin access so they can re-open it. A merchant still onboarding (no store
  yet) passes through untouched.
  """
  import Phoenix.LiveView, only: [redirect: 2]

  def on_mount(:default, _params, _session, socket) do
    case socket.assigns[:current_store] do
      %{status: status} when status in [:suspended, :blocked, :archived] ->
        {:halt, redirect(socket, to: "/store-locked")}

      _ ->
        {:cont, socket}
    end
  end
end
