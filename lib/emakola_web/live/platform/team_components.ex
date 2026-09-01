defmodule EmakolaWeb.Platform.TeamComponents do
  @moduledoc """
  Function components for the platform "Team Studio": a split view with
  the staff roster and pending invites on the left and a member panel on
  the right (identity, security actions, and inline permission editing —
  no edit modal). The invite flow keeps its modal.

  Owner-only controls (is_owner toggle, deactivate/reactivate) are hidden
  for non-owner actors here AND enforced server-side in
  `Emakola.Accounts.PlatformTeam`.
  """
  use EmakolaWeb, :html

  alias Emakola.Security.SecretStorage

  @avatar_tints [
    "bg-rose-100 text-rose-600",
    "bg-amber-100 text-amber-600",
    "bg-blue-100 text-blue-600",
    "bg-emerald-100 text-emerald-600",
    "bg-sky-100 text-sky-600",
    "bg-violet-100 text-violet-600",
    "bg-indigo-100 text-indigo-600",
    "bg-green-100 text-green-700"
  ]

  @permission_descriptions %{
    manage_stores: "Directory, moderation, lifecycle",
    manage_merchants: "Onboarding and verifications",
    manage_team: "Invite and manage staff",
    view_audit_log: "Read audit and security events",
    manage_billing: "Finance, payments, refunds",
    manage_settings: "Feature flags and platform config",
    manage_announcements: "Broadcasts to merchants"
  }

  @status_filters [
    all: "All",
    owners: "Owners",
    twofa_off: "2FA off",
    deactivated: "Deactivated",
    invites: "Invites"
  ]

  attr :staff, :list, required: true
  attr :visible_staff, :list, required: true
  attr :invites, :list, required: true
  attr :session_counts, :map, required: true
  attr :presence, :map, required: true
  attr :status_filter, :atom, required: true
  attr :filter_counts, :map, required: true
  attr :filter_form, :any, required: true
  attr :filters_active, :boolean, required: true
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
          <h1 class="text-2xl font-bold text-gray-900 tracking-tight">Team</h1>
          <p class="text-sm text-gray-500 mt-1">Platform staff, permissions, and invites</p>
        </div>
        <button
          type="button"
          id="open-invite-modal"
          phx-click="open_invite_modal"
          class="inline-flex items-center gap-1.5 px-4 py-2 rounded-[10px] text-[13px] font-semibold text-white bg-slate-900 hover:bg-slate-800 transition-colors"
        >
          <.icon name="hero-plus" class="size-3.5" /> Invite staff
        </button>
      </div>

      <%= if is_nil(@staff) do %>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-12 text-center text-sm text-gray-400">
          Loading team…
        </div>
      <% else %>
        <div class="flex flex-col lg:flex-row bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden lg:h-[calc(100vh-15rem)] lg:min-h-[560px]">
          <.roster
            visible_staff={@visible_staff}
            invites={@invites}
            edit_user={@edit_user}
            presence={@presence}
            status_filter={@status_filter}
            filter_counts={@filter_counts}
            filter_form={@filter_form}
            filters_active={@filters_active}
            all_permissions={@all_permissions}
          />
          <div class="flex-1 min-w-0 overflow-y-auto">
            <.member_panel
              :if={@edit_user}
              user={@edit_user}
              session_counts={@session_counts}
              presence={Map.get(@presence, @edit_user.id, %{state: :offline, last_seen_at: nil})}
              owner_actor={@owner_actor}
              form={@edit_permissions_form}
              all_permissions={@all_permissions}
            />
            <div :if={is_nil(@edit_user)} class="p-6 lg:p-7">
              <.platform_empty_state
                icon="hero-user-group"
                title="No member selected"
                description="Choose a team member from the roster."
              />
            </div>
          </div>
        </div>
      <% end %>

      <.invite_modal
        :if={@invite_modal_open}
        all_permissions={@all_permissions}
        form={@invite_form}
      />
    </div>
    """
  end

  attr :visible_staff, :list, required: true
  attr :invites, :list, required: true
  attr :edit_user, :map, required: true
  attr :presence, :map, required: true
  attr :status_filter, :atom, required: true
  attr :filter_counts, :map, required: true
  attr :filter_form, :any, required: true
  attr :filters_active, :boolean, required: true
  attr :all_permissions, :list, required: true

  defp roster(assigns) do
    assigns =
      assign(assigns,
        status_filters: @status_filters,
        hidden_count: assigns.filter_counts.all - length(assigns.visible_staff)
      )

    ~H"""
    <div class="w-full lg:w-[360px] shrink-0 border-b lg:border-b-0 lg:border-r border-gray-100 flex flex-col max-h-96 lg:max-h-none overflow-y-auto">
      <div class="p-4 border-b border-gray-100 space-y-2.5">
        <.form
          for={@filter_form}
          id="roster-filter-form"
          phx-change="filter"
          phx-debounce="300"
          class="flex gap-2"
        >
          <div class="relative flex-1 min-w-0">
            <.icon
              name="hero-magnifying-glass"
              class="size-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none"
            />
            <.input
              field={@filter_form[:search]}
              type="search"
              id="roster-search"
              placeholder="Search staff…"
              autocomplete="off"
              class="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-[10px] text-[13px] text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 transition-all"
            />
          </div>
          <select
            name="permission"
            id="roster-permission"
            class="h-9 rounded-[10px] border-slate-200 bg-white pr-8 text-[12.5px] font-medium text-gray-700"
          >
            <option value="">Any permission</option>
            <option
              :for={perm <- @all_permissions}
              value={perm}
              selected={@filter_form[:permission].value == to_string(perm)}
            >
              {permission_label(perm)}
            </option>
          </select>
        </.form>
        <div class="flex flex-wrap gap-1.5">
          <button
            :for={{status, label} <- @status_filters}
            type="button"
            id={"filter-#{status}"}
            phx-click="filter_status"
            phx-value-status={status}
            class={chip_classes(@status_filter == status)}
          >
            {label}
            <span class="opacity-60 tabular-nums">{Map.fetch!(@filter_counts, status)}</span>
          </button>
        </div>
      </div>

      <div class="p-2">
        <p
          id="roster-count"
          class="flex items-center px-3 pt-2 pb-1 text-[10px] font-semibold text-gray-400 uppercase tracking-[0.1em]"
        >
          <span :if={@filters_active}>
            Staff · {length(@visible_staff)} of {@filter_counts.all}
          </span>
          <span :if={!@filters_active}>Staff · {@filter_counts.all}</span>
          <button
            :if={@filters_active}
            type="button"
            id="clear-filters"
            phx-click="clear_filters"
            class="ml-auto normal-case tracking-normal text-[10.5px] font-semibold text-blue-600 hover:text-blue-700 cursor-pointer"
          >
            Clear filter
          </button>
        </p>
        <div
          :for={user <- @visible_staff}
          id={"staff-#{user.id}"}
          class={[
            "flex items-center gap-2 px-3 py-2.5 rounded-[10px] transition-colors",
            selected?(@edit_user, user) && "bg-blue-50 shadow-[inset_3px_0_0_#3b82f6]",
            !selected?(@edit_user, user) && "hover:bg-slate-50",
            user.deactivated_at && "opacity-60"
          ]}
        >
          <button
            type="button"
            id={"edit-staff-#{user.id}"}
            phx-click="open_edit_modal"
            phx-value-id={user.id}
            class="flex items-center gap-3 flex-1 min-w-0 text-left cursor-pointer"
          >
            <.presence_avatar user={user} presence={Map.get(@presence, user.id)} />
            <span class="min-w-0 flex-1">
              <span class={[
                "block text-[13.5px] font-semibold leading-tight truncate",
                if(selected?(@edit_user, user), do: "text-gray-900", else: "text-slate-700")
              ]}>
                {user.name || user.email}
              </span>
              <span class="block text-[11px] text-gray-400 truncate leading-tight mt-0.5">
                {user.email}
              </span>
              <span class="flex flex-wrap gap-1 mt-1">
                <span
                  :for={perm <- user.platform_permissions}
                  class="inline-flex px-1.5 py-px rounded text-[10px] font-medium bg-slate-100 text-slate-500"
                >
                  {perm}
                </span>
              </span>
            </span>
          </button>
          <span
            :if={user.is_owner}
            class="inline-flex px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-700 shrink-0"
          >
            OWNER
          </span>
          <span
            :if={user.deactivated_at}
            class="inline-flex px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-100 text-rose-700 shrink-0"
          >
            Deactivated
          </span>
          <span :if={SecretStorage.totp_configured?(user)} data-twofa="on" class="shrink-0">
            <.icon name="hero-shield-check" class="size-3.5 text-green-600" />
          </span>
          <span
            :if={!SecretStorage.totp_configured?(user)}
            data-twofa="off"
            class="inline-flex px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-50 text-rose-600 ring-1 ring-inset ring-rose-600/20 shrink-0"
          >
            2FA OFF
          </span>
        </div>
        <p
          :if={@hidden_count > 0}
          id="roster-hidden"
          class="flex items-center gap-2 mx-3 mt-2 px-3 py-2 rounded-[10px] bg-slate-50 text-[11.5px] text-gray-500"
        >
          <.icon name="hero-eye-slash" class="size-3.5 text-gray-400" />
          {@hidden_count} staff hidden by the filter
        </p>

        <p class="px-3 pt-4 pb-1 text-[10px] font-semibold text-gray-400 uppercase tracking-[0.1em]">
          Invites · {length(@invites)}
        </p>
        <p :if={@invites == []} class="px-3 py-2 text-[12px] text-gray-400">No open invites.</p>
        <div
          :for={invite <- @invites}
          id={"invite-#{invite.id}"}
          class="flex items-center gap-3 px-3 py-2.5 rounded-[10px]"
        >
          <span class="flex w-9 h-9 rounded-full items-center justify-center bg-slate-50 ring-1 ring-inset ring-slate-200 text-slate-400 shrink-0">
            <.icon name="hero-envelope" class="size-4" />
          </span>
          <div class="min-w-0 flex-1">
            <p class="text-[13px] font-semibold text-slate-700 truncate leading-tight">
              {invite.email}
            </p>
            <p class="text-[11px] text-gray-400 truncate leading-tight mt-0.5">
              {"Invited #{Calendar.strftime(invite.inserted_at, "%b %d")}"}
            </p>
          </div>
          <span class={[
            "inline-flex px-2 py-0.5 rounded-full text-[10px] font-bold shrink-0 ring-1 ring-inset",
            if(invite_days_left(invite) <= 2,
              do: "bg-rose-50 text-rose-600 ring-rose-600/20",
              else: "bg-amber-50 text-amber-700 ring-amber-600/20"
            )
          ]}>
            {"Expires in #{invite_days_left(invite)}d"}
          </span>
          <button
            type="button"
            id={"resend-invite-#{invite.id}"}
            phx-click="resend_invite"
            phx-value-id={invite.id}
            data-confirm="This will invalidate the previous invite link. Resend?"
            class="text-[11px] font-semibold text-blue-600 hover:text-blue-700 cursor-pointer"
          >
            Resend
          </button>
          <button
            type="button"
            id={"revoke-invite-#{invite.id}"}
            phx-click="revoke_invite"
            phx-value-id={invite.id}
            data-confirm={"Revoke the invite for #{invite.email}?"}
            class="text-[11px] font-semibold text-rose-600 hover:text-rose-700 cursor-pointer"
          >
            Revoke
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :user, :map, required: true
  attr :presence, :map, default: nil

  # The dot is the only place presence shows in the roster: green means
  # seen in the last few minutes, grey means seen before that, no dot
  # means no active session at all.
  defp presence_avatar(assigns) do
    assigns = assign(assigns, :state, (assigns.presence && assigns.presence.state) || :offline)

    ~H"""
    <span class="relative shrink-0" data-presence={@state} title={last_seen_label(@presence)}>
      <span class={[
        "flex w-9 h-9 rounded-full items-center justify-center text-[13px] font-bold",
        avatar_tint(@user)
      ]}>
        {initial(@user)}
      </span>
      <span
        :if={@state != :offline}
        class={[
          "absolute -right-0.5 -bottom-0.5 w-3 h-3 rounded-full ring-2 ring-white",
          if(@state == :online, do: "bg-green-500", else: "bg-slate-300")
        ]}
      >
      </span>
    </span>
    """
  end

  defp last_seen_label(%{state: :online}), do: "Online now"
  defp last_seen_label(%{state: :away, last_seen_at: at}), do: "Last seen #{relative_time(at)}"
  defp last_seen_label(_), do: "Never signed in"

  defp relative_time(at) do
    minutes = DateTime.diff(DateTime.utc_now(), at, :minute)

    cond do
      minutes < 60 -> "#{max(minutes, 1)}m ago"
      minutes < 1_440 -> "#{div(minutes, 60)}h ago"
      true -> "#{div(minutes, 1_440)}d ago"
    end
  end

  # Mirrors StoreLive.Index's filter chips so the two platform studios match.
  defp chip_classes(active?) do
    [
      "inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11.5px] transition-colors cursor-pointer",
      if(active?,
        do: "bg-slate-900 text-white font-semibold",
        else:
          "bg-slate-50 text-slate-600 font-medium ring-1 ring-inset ring-slate-200 hover:bg-slate-100"
      )
    ]
  end

  attr :user, :map, required: true
  attr :session_counts, :map, required: true
  attr :presence, :map, required: true
  attr :owner_actor, :boolean, required: true
  attr :form, :any, required: true
  attr :all_permissions, :list, required: true

  defp member_panel(assigns) do
    ~H"""
    <div id="team-panel" class="p-6 lg:p-7">
      <%!-- Identity + security actions --%>
      <div class="flex flex-wrap items-center gap-4">
        <span class={[
          "flex w-14 h-14 rounded-full items-center justify-center text-[22px] font-bold shrink-0",
          avatar_tint(@user)
        ]}>
          {initial(@user)}
        </span>
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2 flex-wrap">
            <h2 class="text-xl font-bold text-gray-900 tracking-tight truncate">
              {@user.name || @user.email}
            </h2>
            <.severity_pill :if={@user.is_owner} label="Owner" tone="amber" />
            <.severity_pill
              :if={SecretStorage.totp_configured?(@user)}
              label="2FA enabled"
              tone="green"
            />
            <.severity_pill
              :if={!SecretStorage.totp_configured?(@user)}
              label="2FA off"
              tone="slate"
            />
            <.severity_pill :if={@user.deactivated_at} label="Deactivated" tone="red" />
          </div>
          <p class="text-[13px] text-gray-500 mt-0.5 truncate">
            {"#{@user.email} · #{Emakola.Plural.count(Map.get(@session_counts, @user.id, 0), "active session")}"}
          </p>
        </div>
        <div class="flex items-center gap-2 flex-wrap">
          <button
            type="button"
            id={"force-logout-#{@user.id}"}
            phx-click="force_logout"
            phx-value-id={@user.id}
            data-confirm={"Sign #{@user.email} out of all sessions?"}
            class="inline-flex items-center px-3.5 py-2 rounded-[10px] text-[12.5px] font-semibold text-slate-600 bg-white ring-1 ring-inset ring-gray-200 hover:bg-slate-50 transition-colors cursor-pointer"
          >
            Force logout
          </button>
          <button
            type="button"
            id={"reset-totp-#{@user.id}"}
            phx-click="reset_totp"
            phx-value-id={@user.id}
            data-confirm={"Reset 2FA for #{@user.email}? They will re-enrol at next login."}
            class="inline-flex items-center px-3.5 py-2 rounded-[10px] text-[12.5px] font-semibold text-amber-700 bg-amber-50 ring-1 ring-inset ring-amber-600/20 hover:bg-amber-100 transition-colors cursor-pointer"
          >
            Reset 2FA
          </button>
          <button
            :if={@owner_actor && is_nil(@user.deactivated_at)}
            type="button"
            id={"deactivate-staff-#{@user.id}"}
            phx-click="deactivate"
            phx-value-id={@user.id}
            data-confirm={"Deactivate #{@user.email}? Their sessions will be revoked."}
            class="inline-flex items-center px-3.5 py-2 rounded-[10px] text-[12.5px] font-semibold text-rose-700 bg-rose-50 ring-1 ring-inset ring-rose-600/20 hover:bg-rose-100 transition-colors cursor-pointer"
          >
            Deactivate
          </button>
          <button
            :if={@owner_actor && @user.deactivated_at}
            type="button"
            id={"reactivate-staff-#{@user.id}"}
            phx-click="reactivate"
            phx-value-id={@user.id}
            class="inline-flex items-center px-3.5 py-2 rounded-[10px] text-[12.5px] font-semibold text-green-700 bg-green-50 ring-1 ring-inset ring-green-600/20 hover:bg-green-100 transition-colors cursor-pointer"
          >
            Reactivate
          </button>
          <button
            :if={@owner_actor}
            type="button"
            id={"remove-staff-#{@user.id}"}
            phx-click="remove"
            phx-value-id={@user.id}
            data-confirm={"Remove #{@user.email} from the team? They lose every platform permission and are signed out everywhere."}
            class="inline-flex items-center px-3.5 py-2 rounded-[10px] text-[12.5px] font-semibold text-white bg-rose-600 hover:bg-rose-700 transition-colors cursor-pointer"
          >
            Remove from team
          </button>
        </div>
      </div>

      <div class="h-px bg-gray-100 my-6"></div>

      <%!-- Permissions --%>
      <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
        Permissions
      </p>
      <.form for={@form} id="edit-permissions-form" phx-submit="save_permissions">
        <div class="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
          <label
            :for={perm <- @all_permissions}
            data-permission={perm}
            data-granted={permission_selected?(@form, perm)}
            class={[
              "flex items-center gap-3 rounded-xl px-4 py-3 cursor-pointer transition-colors ring-1 ring-inset",
              if(permission_selected?(@form, perm),
                do: "bg-blue-50/70 ring-blue-200 hover:bg-blue-50",
                else: "bg-white ring-gray-200 hover:bg-slate-50"
              )
            ]}
          >
            <input
              type="checkbox"
              name="permissions[]"
              value={perm}
              checked={permission_selected?(@form, perm)}
              class="rounded border-slate-300 text-blue-600 focus:ring-blue-500/20"
            />
            <span class="min-w-0">
              <span class="block text-[13.5px] font-semibold text-gray-900">
                {permission_label(perm)}
              </span>
              <span class="block text-[11.5px] text-gray-400">
                {permission_description(perm)}
              </span>
            </span>
          </label>
        </div>
        <div class="mt-3 flex items-center justify-between gap-3 flex-wrap">
          <div :if={@owner_actor} class="text-sm text-gray-700">
            <.input
              field={@form[:is_owner]}
              type="checkbox"
              id="edit-is-owner"
              label="Owner (full access, can manage owners)"
              class="rounded border-gray-300 text-amber-600 focus:ring-amber-500"
            />
          </div>
          <div :if={!@owner_actor}></div>
          <button
            type="submit"
            class="inline-flex items-center px-4 py-2 rounded-[10px] text-[13px] font-semibold text-white bg-slate-900 hover:bg-slate-800 transition-colors"
          >
            Save changes
          </button>
        </div>
      </.form>
      <p class="text-xs text-gray-400 mt-3">
        Changes apply on the member's next request. Owner-only controls stay with owners.
      </p>
    </div>
    """
  end

  defp selected?(nil, _user), do: false
  defp selected?(edit_user, user), do: edit_user.id == user.id

  defp invite_days_left(invite) do
    invite.expires_at
    |> DateTime.to_date()
    |> Date.diff(Date.utc_today())
    |> max(0)
  end

  defp avatar_tint(user) do
    Enum.at(@avatar_tints, :erlang.phash2(user.id, length(@avatar_tints)))
  end

  defp initial(user) do
    (user.name || user.email || "?") |> to_string() |> String.first() |> String.upcase()
  end

  defp permission_label(perm) do
    perm |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp permission_description(perm), do: Map.get(@permission_descriptions, perm, "")

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
          class="w-full py-2.5 bg-slate-900 hover:bg-slate-800 text-white text-sm font-semibold rounded-xl transition-colors"
        >
          Send invite
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
                <.icon name="hero-x-mark" class="size-5" />
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
