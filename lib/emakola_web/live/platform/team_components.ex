defmodule EmakolaWeb.Platform.TeamComponents do
  @moduledoc """
  Function components for the platform team management page: staff table,
  pending invites table, and the invite / edit-permissions modals.

  Owner-only controls (is_owner toggle, deactivate/reactivate) are hidden
  for non-owner actors here AND enforced server-side in
  `Emakola.Accounts.PlatformTeam`.
  """
  use EmakolaWeb, :html

  attr :staff, :list, required: true
  attr :invites, :list, required: true
  attr :session_counts, :map, required: true
  attr :owner_actor, :boolean, required: true
  attr :invite_modal_open, :boolean, required: true
  attr :invite_form, :any, required: true
  attr :edit_user, :map, required: true
  attr :edit_permissions_form, :any, required: true
  attr :all_permissions, :list, required: true

  def team_page(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <div class="mb-6 flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Team</h1>
          <p class="text-sm text-gray-500 mt-1">Platform staff, permissions, and invites</p>
        </div>
        <button
          type="button"
          id="open-invite-modal"
          phx-click="open_invite_modal"
          class="inline-flex items-center gap-2 px-4 py-2.5 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl transition-colors"
        >
          Invite team member
        </button>
      </div>

      <%= if is_nil(@staff) do %>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-12 text-center text-sm text-gray-400">
          Loading team…
        </div>
      <% else %>
        <.staff_table staff={@staff} session_counts={@session_counts} owner_actor={@owner_actor} />
        <.invites_table invites={@invites} />
      <% end %>

      <.invite_modal
        :if={@invite_modal_open}
        all_permissions={@all_permissions}
        form={@invite_form}
      />
      <.edit_modal
        :if={@edit_user}
        user={@edit_user}
        form={@edit_permissions_form}
        all_permissions={@all_permissions}
        owner_actor={@owner_actor}
      />
    </div>
    """
  end

  attr :staff, :list, required: true
  attr :session_counts, :map, required: true
  attr :owner_actor, :boolean, required: true

  defp staff_table(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden mb-8">
      <div class="px-6 py-4 border-b border-gray-100">
        <h2 class="text-lg font-semibold text-gray-900">Staff</h2>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
              <th class="px-6 py-3">Member</th>
              <th class="px-6 py-3">Permissions</th>
              <th class="px-6 py-3">Status</th>
              <th class="px-6 py-3">Sessions</th>
              <th class="px-6 py-3">2FA</th>
              <th class="px-6 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr
              :for={user <- @staff}
              id={"staff-#{user.id}"}
              class="hover:bg-gray-50 transition-colors"
            >
              <td class="px-6 py-4">
                <div class="flex items-center gap-2 min-w-0">
                  <div class="min-w-0">
                    <p class="font-medium text-gray-900 truncate">{user.name || "—"}</p>
                    <p class="text-xs text-gray-400 truncate">{user.email}</p>
                  </div>
                  <span
                    :if={user.is_owner}
                    class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-amber-100 text-amber-700 shrink-0"
                  >
                    Owner
                  </span>
                </div>
              </td>
              <td class="px-6 py-4">
                <div class="flex flex-wrap gap-1">
                  <span
                    :for={perm <- user.platform_permissions}
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-600"
                  >
                    {perm}
                  </span>
                </div>
              </td>
              <td class="px-6 py-4">
                <span class={[
                  "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                  if(is_nil(user.deactivated_at),
                    do: "bg-green-100 text-green-700",
                    else: "bg-red-100 text-red-700"
                  )
                ]}>
                  {if is_nil(user.deactivated_at), do: "Active", else: "Deactivated"}
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-gray-500">
                {Map.get(@session_counts, user.id, 0)}
              </td>
              <td class="px-6 py-4">
                <span class={[
                  "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
                  if(user.totp_secret,
                    do: "bg-blue-100 text-blue-700",
                    else: "bg-slate-100 text-slate-500"
                  )
                ]}>
                  {if user.totp_secret, do: "Enabled", else: "Off"}
                </span>
              </td>
              <td class="px-6 py-4 text-right whitespace-nowrap">
                <.row_action
                  id={"edit-staff-#{user.id}"}
                  event="open_edit_modal"
                  user_id={user.id}
                  label="Edit"
                />
                <.row_action
                  id={"force-logout-#{user.id}"}
                  event="force_logout"
                  user_id={user.id}
                  label="Force logout"
                  confirm={"Sign #{user.email} out of all sessions?"}
                />
                <.row_action
                  id={"reset-totp-#{user.id}"}
                  event="reset_totp"
                  user_id={user.id}
                  label="Reset 2FA"
                  confirm={"Reset 2FA for #{user.email}? They will re-enrol at next login."}
                />
                <.row_action
                  :if={@owner_actor && is_nil(user.deactivated_at)}
                  id={"deactivate-staff-#{user.id}"}
                  event="deactivate"
                  user_id={user.id}
                  label="Deactivate"
                  confirm={"Deactivate #{user.email}? Their sessions will be revoked."}
                  danger
                />
                <.row_action
                  :if={@owner_actor && user.deactivated_at}
                  id={"reactivate-staff-#{user.id}"}
                  event="reactivate"
                  user_id={user.id}
                  label="Reactivate"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :event, :string, required: true
  attr :user_id, :string, required: true
  attr :label, :string, required: true
  attr :confirm, :string, default: nil
  attr :danger, :boolean, default: false
  attr :rest, :global

  defp row_action(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      phx-click={@event}
      phx-value-id={@user_id}
      data-confirm={@confirm}
      class={[
        "inline-flex items-center px-2 py-1 rounded-md text-xs font-medium transition-colors ml-1",
        if(@danger,
          do: "text-rose-600 hover:bg-rose-50",
          else: "text-blue-600 hover:bg-blue-50"
        )
      ]}
      {@rest}
    >
      {@label}
    </button>
    """
  end

  attr :invites, :list, required: true

  defp invites_table(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-100">
        <h2 class="text-lg font-semibold text-gray-900">Pending invites</h2>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
              <th class="px-6 py-3">Email</th>
              <th class="px-6 py-3">Permissions</th>
              <th class="px-6 py-3">Invited</th>
              <th class="px-6 py-3">Expires</th>
              <th class="px-6 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr :if={@invites == []}>
              <td colspan="5" class="px-6 py-8 text-center text-sm text-gray-400">
                No pending invites
              </td>
            </tr>
            <tr
              :for={invite <- @invites}
              id={"invite-#{invite.id}"}
              class="hover:bg-gray-50 transition-colors"
            >
              <td class="px-6 py-4 text-sm font-medium text-gray-900">{invite.email}</td>
              <td class="px-6 py-4">
                <div class="flex flex-wrap gap-1">
                  <span
                    :for={perm <- invite.permissions}
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-600"
                  >
                    {perm}
                  </span>
                </div>
              </td>
              <td class="px-6 py-4 text-sm text-gray-500">
                {Calendar.strftime(invite.inserted_at, "%b %d, %Y")}
              </td>
              <td class="px-6 py-4 text-sm text-gray-500">
                {Calendar.strftime(invite.expires_at, "%b %d, %Y")}
              </td>
              <td class="px-6 py-4 text-right whitespace-nowrap">
                <button
                  type="button"
                  id={"resend-invite-#{invite.id}"}
                  phx-click="resend_invite"
                  phx-value-id={invite.id}
                  data-confirm="This will invalidate the previous invite link. Resend?"
                  class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-blue-600 hover:bg-blue-50 ml-1"
                >
                  Resend
                </button>
                <button
                  type="button"
                  id={"revoke-invite-#{invite.id}"}
                  phx-click="revoke_invite"
                  phx-value-id={invite.id}
                  data-confirm={"Revoke the invite for #{invite.email}?"}
                  class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-rose-600 hover:bg-rose-50 ml-1"
                >
                  Revoke
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :all_permissions, :list, required: true
  attr :form, :any, required: true

  defp invite_modal(assigns) do
    ~H"""
    <.team_modal title="Invite team member" cancel_event="close_invite_modal">
      <.form for={@form} id="invite-form" phx-submit="send_invite" class="space-y-4">
        <div>
          <label for="invite-email" class="block text-sm font-medium text-gray-700 mb-1">
            Email
          </label>
          <.input
            field={@form[:email]}
            type="email"
            id="invite-email"
            required
            placeholder="colleague@example.com"
            class="w-full px-3 py-2 bg-white border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
          />
        </div>
        <.permission_checkboxes all_permissions={@all_permissions} form={@form} />
        <button
          type="submit"
          class="w-full py-2.5 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl transition-colors"
        >
          Send invite
        </button>
      </.form>
    </.team_modal>
    """
  end

  attr :user, :map, required: true
  attr :all_permissions, :list, required: true
  attr :owner_actor, :boolean, required: true
  attr :form, :any, required: true

  defp edit_modal(assigns) do
    ~H"""
    <.team_modal title={"Edit permissions — #{@user.email}"} cancel_event="close_edit_modal">
      <.form
        for={@form}
        id="edit-permissions-form"
        phx-submit="save_permissions"
        class="space-y-4"
      >
        <.permission_checkboxes
          all_permissions={@all_permissions}
          form={@form}
        />
        <%= if @owner_actor do %>
          <div class="pt-2 border-t border-gray-100 text-sm text-gray-700">
            <.input
              field={@form[:is_owner]}
              type="checkbox"
              id="edit-is-owner"
              label="Owner (full access, can manage owners)"
              class="rounded border-gray-300 text-amber-600 focus:ring-amber-500"
            />
          </div>
        <% end %>
        <button
          type="submit"
          class="w-full py-2.5 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl transition-colors"
        >
          Save changes
        </button>
      </.form>
    </.team_modal>
    """
  end

  attr :all_permissions, :list, required: true
  attr :form, :any, required: true

  defp permission_checkboxes(assigns) do
    ~H"""
    <fieldset>
      <legend class="block text-sm font-medium text-gray-700 mb-2">Permissions</legend>
      <div class="space-y-2">
        <label :for={perm <- @all_permissions} class="flex items-center gap-2 text-sm text-gray-700">
          <input
            type="checkbox"
            name="permissions[]"
            value={perm}
            checked={permission_selected?(@form, perm)}
            class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
          />
          {perm}
        </label>
      </div>
    </fieldset>
    """
  end

  defp permission_selected?(form, permission) do
    Enum.any?(List.wrap(form[:permissions].value), fn selected ->
      to_string(selected) == to_string(permission)
    end)
  end

  attr :title, :string, required: true
  attr :cancel_event, :string, required: true
  slot :inner_block, required: true

  defp team_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50">
      <div
        class="fixed inset-0 bg-black/50 backdrop-blur-sm"
        phx-click={@cancel_event}
        aria-hidden="true"
      >
      </div>
      <div class="fixed inset-0 overflow-y-auto" role="dialog" aria-modal="true">
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="w-full max-w-md bg-white rounded-2xl shadow-xl">
            <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <h2 class="text-lg font-semibold text-gray-900">{@title}</h2>
              <button
                type="button"
                phx-click={@cancel_event}
                class="p-1.5 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors"
                aria-label="Close"
              >
                <svg
                  class="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div class="px-6 py-5">
              {render_slot(@inner_block)}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
