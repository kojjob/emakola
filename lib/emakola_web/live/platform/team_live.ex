defmodule EmakolaWeb.Platform.TeamLive do
  @moduledoc """
  Platform team management: staff roster with permission editing, owner
  controls, force logout, 2FA reset, deactivation, and invite lifecycle.

  Mount is gated by RequirePermission (:manage_team) and every mutating
  handle_event re-checks the permission — mount-time auth is never
  trusted (close_*_modal events are UI-only). Owner-only operations are
  additionally enforced in the service. Team lists are tiny, so plain
  assigns are used, not streams.
  """
  use EmakolaWeb, :live_view

  on_mount({EmakolaWeb.Hooks.RequirePermission, :manage_team})

  import EmakolaWeb.Platform.TeamComponents

  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Accounts.PlatformTeam
  alias Emakola.Accounts.Sessions

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Team")
      |> assign(:active_nav, :team)
      |> assign(:all_permissions, PlatformPermissions.all())
      |> assign(:invite_modal_open, false)
      |> assign(:edit_user, nil)

    # No DB queries in disconnected mount — render a loading shell first.
    socket =
      if connected?(socket) do
        load_team(socket)
      else
        assign(socket, staff: nil, invites: [], session_counts: %{})
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("open_invite_modal", _params, socket) do
    authorized(socket, fn socket -> {:noreply, assign(socket, :invite_modal_open, true)} end)
  end

  def handle_event("close_invite_modal", _params, socket),
    do: {:noreply, assign(socket, :invite_modal_open, false)}

  def handle_event("send_invite", %{"email" => email} = params, socket) do
    authorized(socket, fn socket ->
      permissions = PlatformPermissions.cast_list(Map.get(params, "permissions", []))

      case PlatformTeam.create_invite(email, permissions, socket.assigns.current_user) do
        {:ok, _invite} ->
          {:noreply,
           socket
           |> assign(:invite_modal_open, false)
           |> load_team()
           |> put_flash(:info, "Invite sent to #{email}.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, error_message(reason))}
      end
    end)
  end

  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      {:noreply, assign(socket, :edit_user, find_staff(socket, id))}
    end)
  end

  def handle_event("close_edit_modal", _params, socket),
    do: {:noreply, assign(socket, :edit_user, nil)}

  def handle_event("save_permissions", params, socket) do
    authorized(socket, fn socket ->
      case socket.assigns.edit_user do
        nil ->
          {:noreply, socket}

        user ->
          attrs = %{
            is_owner: requested_is_owner(params, user),
            platform_permissions:
              PlatformPermissions.cast_list(Map.get(params, "permissions", []))
          }

          case PlatformTeam.update_permissions(user, attrs, socket.assigns.current_user) do
            {:ok, _updated} ->
              {:noreply,
               socket
               |> assign(:edit_user, nil)
               |> load_team()
               |> put_flash(:info, "Permissions updated.")}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, error_message(reason))}
          end
      end
    end)
  end

  def handle_event("force_logout", %{"id" => id}, socket) do
    staff_action(socket, id, &PlatformTeam.force_logout/2, fn count ->
      "Signed out #{count} session(s)."
    end)
  end

  def handle_event("reset_totp", %{"id" => id}, socket) do
    staff_action(socket, id, &PlatformTeam.reset_totp/2, fn _ ->
      "2FA reset. They will re-enrol at next login."
    end)
  end

  def handle_event("deactivate", %{"id" => id}, socket) do
    staff_action(socket, id, &PlatformTeam.deactivate/2, fn _ -> "Staff member deactivated." end)
  end

  def handle_event("reactivate", %{"id" => id}, socket) do
    staff_action(socket, id, &PlatformTeam.reactivate/2, fn _ -> "Staff member reactivated." end)
  end

  def handle_event("revoke_invite", %{"id" => id}, socket) do
    invite_action(socket, id, &PlatformTeam.revoke_invite/2, "Invite revoked.")
  end

  def handle_event("resend_invite", %{"id" => id}, socket) do
    invite_action(socket, id, &PlatformTeam.resend_invite/2, "Invite resent.")
  end

  # Every event re-checks :manage_team against the current user; the
  # service layer checks again (belt and braces).
  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(socket.assigns.current_user, :manage_team) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, error_message(:unauthorized))}
    end
  end

  defp staff_action(socket, id, action, success_message) do
    authorized(socket, fn socket ->
      with %{} = user <- find_staff(socket, id),
           {:ok, result} <- action.(user, socket.assigns.current_user) do
        {:noreply, socket |> load_team() |> put_flash(:info, success_message.(result))}
      else
        nil -> {:noreply, socket}
        {:error, reason} -> {:noreply, put_flash(socket, :error, error_message(reason))}
      end
    end)
  end

  defp invite_action(socket, id, action, success_message) do
    authorized(socket, fn socket ->
      with %{} = invite <- Enum.find(socket.assigns.invites, &(&1.id == id)),
           {:ok, _result} <- action.(invite, socket.assigns.current_user) do
        {:noreply, socket |> load_team() |> put_flash(:info, success_message)}
      else
        nil -> {:noreply, socket}
        {:error, reason} -> {:noreply, put_flash(socket, :error, error_message(reason))}
      end
    end)
  end

  defp find_staff(socket, id), do: Enum.find(socket.assigns.staff || [], &(&1.id == id))

  # The is_owner field is only rendered for owner actors (with a hidden
  # "false" fallback, so the param is always present for them). An absent
  # param keeps ownership unchanged; crafted changes hit the service check.
  defp requested_is_owner(params, user) do
    case Map.fetch(params, "is_owner") do
      {:ok, value} -> value == "true"
      :error -> user.is_owner
    end
  end

  defp load_team(socket) do
    staff = ok_or_empty(PlatformTeam.list_staff())

    session_counts =
      Map.new(staff, fn user ->
        {user.id, length(ok_or_empty(Sessions.list_active_for_user(user.id)))}
      end)

    socket
    |> assign(:staff, staff)
    |> assign(:invites, ok_or_empty(PlatformTeam.list_open_invites()))
    |> assign(:session_counts, session_counts)
  end

  defp ok_or_empty({:ok, list}), do: list
  defp ok_or_empty({:error, _}), do: []

  defp error_message(:unauthorized), do: "You don't have permission to manage the team."
  defp error_message(:owner_required), do: "Only platform owners can do that."

  defp error_message(:email_delivery_failed), do: "Could not send the invite email."

  defp error_message(%Ash.Error.Invalid{errors: [error | _]}),
    do: Map.get(error, :message) || "Could not complete that action."

  defp error_message(_), do: "Could not complete that action."

  @impl true
  def render(assigns) do
    ~H"""
    <.team_page
      staff={@staff}
      invites={@invites}
      session_counts={@session_counts}
      owner_actor={@current_user.is_owner}
      invite_modal_open={@invite_modal_open}
      edit_user={@edit_user}
      all_permissions={@all_permissions}
    />
    """
  end
end
