defmodule EmakolaWeb.Platform.SettingsLive do
  @moduledoc """
  Platform-level feature flag management.

  Mount is gated by RequirePermission (:manage_settings). No DB queries run
  during the disconnected render — a nil flags state is assigned and the
  template renders a loading shell. Every mutating handle_event (toggle,
  save, delete) re-checks the permission against a freshly reloaded user so a
  post-mount revocation is caught before the write.
  """
  use EmakolaWeb, :live_view
  require Logger

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_settings}

  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.FeatureFlags

  @plans ~w(free starter pro enterprise)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:active_nav, :settings)
      |> assign(:search, "")
      |> assign(:filter, :all)
      |> assign(:plans, @plans)
      |> assign(:edit_flag_id, nil)
      |> assign(:delete_flag, nil)
      |> reset_form()

    socket =
      if connected?(socket) do
        load_flags(socket)
      else
        socket
        |> assign(all_flags: nil, stats: nil, filtered_count: 0)
        |> stream(:flags, [])
      end

    {:ok, socket}
  end

  # Re-check :manage_settings against a freshly reloaded user so a post-mount
  # permission revocation is caught before any write.
  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_settings) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to manage settings.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  # ── Events ─────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"search" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> put_flags()}
  end

  def handle_event("filter", %{"filter" => f}, socket) do
    {:noreply, socket |> assign(:filter, parse_filter(f)) |> put_flags()}
  end

  def handle_event("open_add_modal", _params, socket) do
    {:noreply, socket |> assign(:edit_flag_id, nil) |> reset_form()}
  end

  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.all_flags, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      flag ->
        {:noreply,
         socket
         |> assign(:edit_flag_id, id)
         |> assign(:form_key, flag.key)
         |> assign(:form_name, flag.name)
         |> assign(:form_description, flag.description || "")
         |> assign(:form_enabled, flag.enabled)
         |> assign(:form_plan, flag.required_plan)
         |> assign(:form_errors, %{})}
    end
  end

  def handle_event("open_delete_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_flag, Enum.find(socket.assigns.all_flags, &(&1.id == id)))}
  end

  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :form_errors, validate_params(params))}
  end

  def handle_event("save", params, socket) do
    authorized(socket, fn socket ->
      errors = validate_params(params)

      if errors == %{} do
        case socket.assigns.edit_flag_id do
          nil -> create_flag(socket, params)
          id -> do_update_flag(socket, id, params)
        end
      else
        {:noreply, assign(socket, :form_errors, errors)}
      end
    end)
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      with flag when not is_nil(flag) <- Enum.find(socket.assigns.all_flags, &(&1.id == id)),
           {:ok, updated} <- FeatureFlags.toggle_flag(flag, authorize?: false) do
        {:noreply, sync_flag(socket, updated)}
      else
        _ -> {:noreply, put_flash(socket, :error, "Could not update flag")}
      end
    end)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      with flag when not is_nil(flag) <- Enum.find(socket.assigns.all_flags, &(&1.id == id)),
           :ok <- FeatureFlags.destroy_flag(flag, authorize?: false) do
        all = Enum.reject(socket.assigns.all_flags, &(&1.id == id))

        {:noreply,
         socket
         |> assign(:all_flags, all)
         |> assign(:stats, compute_stats(all))
         |> assign(:delete_flag, nil)
         |> assign(
           :filtered_count,
           length(filtered(all, socket.assigns.search, socket.assigns.filter))
         )
         |> stream_delete(:flags, flag)
         |> put_flash(:info, "Feature flag deleted")}
      else
        _ -> {:noreply, put_flash(socket, :error, "Could not delete flag")}
      end
    end)
  end

  # ── Create / Update ────────────────────────────────────

  defp create_flag(socket, params) do
    attrs = %{
      key: String.trim(params["key"] || ""),
      name: String.trim(params["name"] || ""),
      description: params["description"] || "",
      enabled: params["enabled"] == "true",
      required_plan: parse_plan(params["required_plan"])
    }

    case FeatureFlags.create_flag(attrs, authorize?: false) do
      {:ok, _flag} ->
        {:noreply,
         socket
         |> reset_form()
         |> load_flags()
         |> put_flash(:info, "Feature flag created")
         |> push_event("close-modal", %{id: "flag-modal"})}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, format_error(error))}
    end
  end

  defp do_update_flag(socket, id, params) do
    case Enum.find(socket.assigns.all_flags, &(&1.id == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Flag not found")}

      flag ->
        attrs = %{
          name: String.trim(params["name"] || ""),
          description: params["description"] || "",
          enabled: params["enabled"] == "true",
          required_plan: parse_plan(params["required_plan"])
        }

        case FeatureFlags.update_flag(flag, attrs, authorize?: false) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> assign(:edit_flag_id, nil)
             |> reset_form()
             |> load_flags()
             |> put_flash(:info, "Feature flag updated")
             |> push_event("close-modal", %{id: "flag-modal"})}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, format_error(error))}
        end
    end
  end

  # ── Data ───────────────────────────────────────────────

  defp load_flags(socket) do
    all = list_all_flags()

    socket
    |> assign(:all_flags, all)
    |> assign(:stats, compute_stats(all))
    |> put_flags()
  end

  defp put_flags(socket) do
    visible = filtered(socket.assigns.all_flags, socket.assigns.search, socket.assigns.filter)

    socket
    |> assign(:filtered_count, length(visible))
    |> stream(:flags, visible, reset: true)
  end

  defp sync_flag(socket, updated) do
    all =
      Enum.map(socket.assigns.all_flags, fn f -> if f.id == updated.id, do: updated, else: f end)

    socket =
      socket
      |> assign(:all_flags, all)
      |> assign(:stats, compute_stats(all))
      |> assign(
        :filtered_count,
        length(filtered(all, socket.assigns.search, socket.assigns.filter))
      )

    if matches?(updated, socket.assigns.search, socket.assigns.filter) do
      stream_insert(socket, :flags, updated)
    else
      stream_delete(socket, :flags, updated)
    end
  end

  defp list_all_flags do
    case FeatureFlags.list_flags(authorize?: false) do
      {:ok, flags} -> Enum.sort_by(flags, & &1.name)
      _ -> []
    end
  rescue
    exception ->
      Logger.error(
        "[platform.settings_live] list_all_flags loading feature flags raised: #{Exception.message(exception)}"
      )

      []
  end

  defp filtered(all, search, filter) do
    q = normalize(search)

    all
    |> Enum.filter(&(matches_search?(&1, q) and matches_filter?(&1, filter)))
  end

  defp matches?(flag, search, filter),
    do: matches_search?(flag, normalize(search)) and matches_filter?(flag, filter)

  defp matches_search?(_flag, ""), do: true

  defp matches_search?(flag, q) do
    String.contains?(String.downcase(flag.name || ""), q) or
      String.contains?(String.downcase(flag.key || ""), q)
  end

  defp matches_filter?(_flag, :all), do: true
  defp matches_filter?(flag, :enabled), do: flag.enabled
  defp matches_filter?(flag, :disabled), do: not flag.enabled

  defp compute_stats(flags) do
    %{
      total: length(flags),
      enabled: Enum.count(flags, & &1.enabled),
      disabled: Enum.count(flags, &(not &1.enabled)),
      gated: Enum.count(flags, &(&1.required_plan not in [nil, ""]))
    }
  end

  # ── Helpers ────────────────────────────────────────────

  defp reset_form(socket) do
    socket
    |> assign(:form_key, "")
    |> assign(:form_name, "")
    |> assign(:form_description, "")
    |> assign(:form_enabled, true)
    |> assign(:form_plan, nil)
    |> assign(:form_errors, %{})
  end

  defp validate_params(params) do
    %{}
    |> maybe_error(:name, blank?(params["name"]), "Name is required")
    |> maybe_error(:key, params["key"] != nil and blank?(params["key"]), "Key is required")
  end

  defp maybe_error(errors, _field, false, _msg), do: errors
  defp maybe_error(errors, field, true, msg), do: Map.put(errors, field, msg)

  defp blank?(nil), do: true
  defp blank?(s) when is_binary(s), do: String.trim(s) == ""
  defp blank?(_), do: false

  defp normalize(s), do: s |> to_string() |> String.trim() |> String.downcase()

  defp parse_filter("enabled"), do: :enabled
  defp parse_filter("disabled"), do: :disabled
  defp parse_filter(_), do: :all

  defp parse_plan(p) when p in [nil, "", "none"], do: nil
  defp parse_plan(p) when p in @plans, do: p
  defp parse_plan(_), do: nil

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(fn
      %{message: msg} when is_binary(msg) -> msg
      other -> inspect(other)
    end)
    |> Enum.join(", ")
  end

  defp format_error(error), do: inspect(error)

  # ── Render ─────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Header --%>
      <div class="mb-6 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Settings</h1>
          <p class="text-sm text-gray-500 mt-1">
            {if @stats,
              do: "Platform feature flags (#{@stats.total} total)",
              else: "Loading feature flags…"}
          </p>
        </div>
        <button
          :if={@all_flags}
          type="button"
          phx-click={JS.push("open_add_modal") |> show_modal("flag-modal")}
          class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-semibold bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors"
        >
          <span class="material-symbols-outlined text-base">add</span> New flag
        </button>
      </div>

      <%!-- Loading shell (disconnected mount — no DB) --%>
      <div
        :if={is_nil(@all_flags)}
        class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center text-sm text-gray-400"
      >
        Loading feature flags…
      </div>

      <div :if={@all_flags}>
        <%!-- Stat strip --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <.stat label="Total" value={@stats.total} icon="flag" color="blue" />
          <.stat label="Enabled" value={@stats.enabled} icon="check_circle" color="emerald" />
          <.stat label="Plan-gated" value={@stats.gated} icon="workspace_premium" color="amber" />
          <.stat label="Disabled" value={@stats.disabled} icon="cancel" color="slate" />
        </div>

        <%!-- Toolbar --%>
        <div class="mb-5 flex items-center gap-3 flex-wrap">
          <form
            id="flag-search-form"
            phx-change="search"
            class="relative flex-1 min-w-[200px] max-w-sm"
          >
            <span class="material-symbols-outlined text-base text-gray-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none">
              search
            </span>
            <input
              type="search"
              name="search"
              value={@search}
              placeholder="Search by name or key..."
              phx-debounce="300"
              class="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 transition-all"
            />
          </form>
          <div class="flex items-center gap-1.5">
            <.chip filter="all" active={@filter} label="All" />
            <.chip filter="enabled" active={@filter} label="Enabled" />
            <.chip filter="disabled" active={@filter} label="Disabled" />
          </div>
        </div>

        <%!-- Empty states --%>
        <div
          :if={@stats.total == 0}
          class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center"
        >
          <span class="material-symbols-outlined text-4xl text-gray-300">flag</span>
          <p class="mt-2 text-sm font-medium text-gray-900">No feature flags yet</p>
          <p class="text-sm text-gray-400 mb-4">Create your first flag to start gating features.</p>
          <button
            type="button"
            phx-click={JS.push("open_add_modal") |> show_modal("flag-modal")}
            class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-semibold bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors"
          >
            <span class="material-symbols-outlined text-base">add</span> New flag
          </button>
        </div>

        <div
          :if={@stats.total > 0 and @filtered_count == 0}
          class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center text-sm text-gray-400"
        >
          No flags match your filters
        </div>

        <%!-- Card grid --%>
        <div
          id="flags"
          phx-update="stream"
          class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4"
        >
          <div
            :for={{dom_id, flag} <- @streams.flags}
            id={dom_id}
            class={[
              "bg-white rounded-2xl border border-gray-200 shadow-sm border-l-4 p-5 flex flex-col",
              if(flag.enabled, do: "border-l-blue-500", else: "border-l-slate-300 opacity-75")
            ]}
          >
            <div class="flex items-start justify-between gap-3">
              <h3 class="font-semibold text-gray-900 leading-tight">{flag.name}</h3>
              <button
                type="button"
                phx-click="toggle"
                phx-value-id={flag.id}
                role="switch"
                aria-checked={to_string(flag.enabled)}
                aria-label="Toggle flag"
                class={[
                  "relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors",
                  if(flag.enabled, do: "bg-blue-600", else: "bg-slate-300")
                ]}
              >
                <span class={[
                  "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                  if(flag.enabled, do: "translate-x-6", else: "translate-x-1")
                ]}>
                </span>
              </button>
            </div>

            <div class="flex items-center gap-2 mt-2 flex-wrap">
              <span class="font-mono text-xs px-2 py-0.5 rounded bg-slate-100 text-slate-600">
                {flag.key}
              </span>
              <span
                :if={flag.required_plan}
                class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 font-medium"
              >
                <span class="material-symbols-outlined" style="font-size: 12px;">
                  workspace_premium
                </span>
                {String.capitalize(flag.required_plan)}
              </span>
              <span :if={is_nil(flag.required_plan)} class="text-xs text-slate-400">All plans</span>
            </div>

            <p class="text-sm text-slate-500 mt-2 line-clamp-2">
              {if flag.description in [nil, ""], do: "No description", else: flag.description}
            </p>

            <div class="flex items-center justify-between mt-4 pt-3 border-t border-gray-100">
              <span class="text-xs text-slate-400">
                Updated {Calendar.strftime(flag.updated_at, "%b %d, %Y")}
              </span>
              <div class="flex items-center gap-3">
                <button
                  type="button"
                  phx-click={
                    JS.push("open_edit_modal", value: %{id: flag.id}) |> show_modal("flag-modal")
                  }
                  class="text-xs font-medium text-blue-600 hover:text-blue-700"
                >
                  Edit
                </button>
                <button
                  type="button"
                  phx-click={
                    JS.push("open_delete_modal", value: %{id: flag.id})
                    |> show_modal("delete-flag-modal")
                  }
                  class="text-xs font-medium text-rose-600 hover:text-rose-700"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Create / Edit modal --%>
      <.modal
        id="flag-modal"
        title={if @edit_flag_id, do: "Edit feature flag", else: "New feature flag"}
        size={:md}
      >
        <form id="flag-form" phx-submit="save" phx-change="validate" class="space-y-4">
          <div>
            <label for="flag-key" class="block text-sm font-medium text-slate-700 mb-1.5">
              Key <span class="text-red-500">*</span>
            </label>
            <input
              type="text"
              id="flag-key"
              name="key"
              value={@form_key}
              disabled={@edit_flag_id != nil}
              placeholder="new_checkout"
              autocomplete="off"
              class={[
                "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:bg-slate-100 disabled:text-slate-400 font-mono",
                if(@form_errors[:key], do: "border-red-300 bg-red-50", else: "border-slate-300")
              ]}
            />
            <p :if={@edit_flag_id} class="mt-1 text-xs text-slate-400">
              Key can't be changed after creation.
            </p>
            <p :if={@form_errors[:key]} class="mt-1 text-xs text-red-600">{@form_errors[:key]}</p>
          </div>

          <div>
            <label for="flag-name" class="block text-sm font-medium text-slate-700 mb-1.5">
              Name <span class="text-red-500">*</span>
            </label>
            <input
              type="text"
              id="flag-name"
              name="name"
              value={@form_name}
              placeholder="New checkout"
              autocomplete="off"
              class={[
                "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
                if(@form_errors[:name], do: "border-red-300 bg-red-50", else: "border-slate-300")
              ]}
            />
            <p :if={@form_errors[:name]} class="mt-1 text-xs text-red-600">{@form_errors[:name]}</p>
          </div>

          <div>
            <label for="flag-description" class="block text-sm font-medium text-slate-700 mb-1.5">
              Description
            </label>
            <textarea
              id="flag-description"
              name="description"
              rows="3"
              placeholder="Optional description"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
            >{@form_description}</textarea>
          </div>

          <div>
            <label for="flag-plan" class="block text-sm font-medium text-slate-700 mb-1.5">
              Required plan
            </label>
            <select
              id="flag-plan"
              name="required_plan"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="" selected={is_nil(@form_plan)}>All plans (no gate)</option>
              <option :for={p <- @plans} value={p} selected={@form_plan == p}>
                {String.capitalize(p)}
              </option>
            </select>
          </div>

          <label class="flex items-center gap-2">
            <input type="hidden" name="enabled" value="false" />
            <input
              type="checkbox"
              name="enabled"
              value="true"
              checked={@form_enabled}
              class="h-4 w-4 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
            />
            <span class="text-sm text-slate-700">Enabled</span>
          </label>

          <div class="flex items-center justify-end gap-3 pt-2">
            <button
              type="button"
              phx-click={hide_modal("flag-modal")}
              class="px-4 py-2.5 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-xl hover:bg-slate-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="px-4 py-2.5 text-sm font-semibold bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors"
            >
              {if @edit_flag_id, do: "Update", else: "Create"}
            </button>
          </div>
        </form>
      </.modal>

      <%!-- Delete confirmation --%>
      <.confirm_modal
        id="delete-flag-modal"
        title="Delete feature flag"
        message={
          if @delete_flag,
            do: "Delete \"#{@delete_flag.name}\"? This action cannot be undone.",
            else: "Delete this feature flag? This action cannot be undone."
        }
        confirm_text="Delete"
        confirm_class="bg-rose-600 hover:bg-rose-700 text-white"
        on_confirm="delete"
        value={@delete_flag && @delete_flag.id}
        icon="warning"
        icon_class="text-rose-500"
      />
    </div>
    """
  end

  # ── Function components ─────────────────────────────────

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true

  defp stat(assigns) do
    color_classes = %{
      "blue" => "bg-blue-50 text-blue-600",
      "emerald" => "bg-emerald-50 text-emerald-600",
      "amber" => "bg-amber-50 text-amber-600",
      "slate" => "bg-slate-100 text-slate-600"
    }

    assigns =
      assign(
        assigns,
        :color_class,
        Map.get(color_classes, assigns.color, "bg-gray-50 text-gray-600")
      )

    ~H"""
    <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-5">
      <span class={"material-symbols-outlined text-xl rounded-lg p-2 #{@color_class}"}>
        {@icon}
      </span>
      <p class="text-2xl font-bold text-gray-900 tabular-nums mt-3">{@value}</p>
      <p class="text-sm text-gray-500 mt-1">{@label}</p>
    </div>
    """
  end

  attr :filter, :string, required: true
  attr :active, :atom, required: true
  attr :label, :string, required: true

  defp chip(assigns) do
    assigns = assign(assigns, :is_active, to_string(assigns.active) == assigns.filter)

    ~H"""
    <button
      type="button"
      phx-click="filter"
      phx-value-filter={@filter}
      class={[
        "px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors",
        if(@is_active,
          do: "bg-blue-600 text-white",
          else: "bg-white border border-gray-200 text-gray-600 hover:bg-gray-50"
        )
      ]}
    >
      {@label}
    </button>
    """
  end
end
